#!/usr/bin/env bash
# AutoSSL — DNS challenge (Cloudflare API optional, manual fallback)

DNS_PROVIDER=""
DNS_ACME_HOOK=""
CF_CREDS_FILE=""
CF_CRED_PATHS=(
    "/etc/autossl/cloudflare.ini"
    "/etc/letsencrypt/cloudflare.ini"
    "${HOME}/.cloudflare.ini"
)

_cf_ini_valid() {
    local f="$1"
    [[ -f "$f" ]] || return 1
    grep -qE '^\s*dns_cloudflare_api_token\s*=\s*\S+' "$f" 2>/dev/null && return 0
    grep -qE '^\s*dns_cloudflare_api_key\s*=\s*\S+' "$f" 2>/dev/null && return 0
    return 1
}

# API key only when user explicitly set env vars or configured credentials file
has_cloudflare_api() {
    [[ -n "${CF_Token:-}" || -n "${CF_API_TOKEN:-}" ]] && return 0
    [[ -n "${CF_Key:-}" && -n "${CF_Email:-}" ]] && return 0
    local p
    for p in "${CF_CRED_PATHS[@]}"; do
        _cf_ini_valid "$p" && return 0
    done
    return 1
}

# Returns: cloudflare | manual
resolve_dns_backend() {
    if has_cloudflare_api; then
        DNS_PROVIDER="cloudflare"
        DNS_ACME_HOOK="dns_cf"
        echo "cloudflare"
    else
        DNS_PROVIDER="manual"
        echo "manual"
    fi
}

cloudflare_certbot_args() {
    local p token tmp
    for p in "${CF_CRED_PATHS[@]}"; do
        if _cf_ini_valid "$p"; then
            CF_CREDS_FILE="$p"
            echo "--dns-cloudflare --dns-cloudflare-credentials ${p}"
            return
        fi
    done

    token="${CF_Token:-${CF_API_TOKEN:-}}"
    if [[ -n "$token" ]]; then
        tmp="/etc/autossl/.cf-token.ini"
        printf 'dns_cloudflare_api_token = %s\n' "$token" > "$tmp"
        chmod 600 "$tmp"
        CF_CREDS_FILE="$tmp"
        echo "--dns-cloudflare --dns-cloudflare-credentials ${tmp}"
        return
    fi

    die "Cloudflare API requested but no token found. Set CF_Token or edit /etc/autossl/cloudflare.ini"
}

cloudflare_prepare_env() {
    [[ -n "${CF_API_TOKEN:-}" && -z "${CF_Token:-}" ]] && export CF_Token="$CF_API_TOKEN"
}

print_manual_dns_banner() {
    echo ""
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}Manual DNS Challenge${NC}  ${DIM}(no API key required)${NC}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BOLD}Steps:${NC}"
    echo -e "    ${GREEN}1.${NC} A ${CYAN}TXT record${NC} will be shown below (_acme-challenge...)"
    echo -e "    ${GREEN}2.${NC} Add it in your DNS panel ${DIM}(Cloudflare, etc.)${NC}"
    echo -e "    ${GREEN}3.${NC} Wait 1–2 minutes for DNS propagation"
    echo -e "    ${GREEN}4.${NC} Press ${BOLD}Enter${NC} when prompted to continue"
    echo ""
    if has_wildcard; then
        echo -e "  ${DIM}Wildcard domains require TXT on: _acme-challenge.yourdomain.com${NC}"
        echo ""
    fi
}

wait_after_manual_dns() {
    echo ""
    echo -e "  ${GREEN}✔${NC}  DNS challenge step finished."
    echo ""
}
