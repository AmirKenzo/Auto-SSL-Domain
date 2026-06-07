#!/usr/bin/env bash
# AutoSSL — DNS provider detection

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

_has_cloudflare_credentials() {
    [[ -n "${CF_Token:-}" || -n "${CF_API_TOKEN:-}" ]] && return 0
    [[ -n "${CF_Key:-}" && -n "${CF_Email:-}" ]] && return 0
    local p
    for p in "${CF_CRED_PATHS[@]}"; do
        _cf_ini_valid "$p" && return 0
    done
    return 1
}

detect_dns_cloudflare() {
    if _has_cloudflare_credentials; then
        DNS_PROVIDER="cloudflare"
        DNS_ACME_HOOK="dns_cf"
        log INFO "Detected DNS provider: cloudflare"
        return 0
    fi
    return 1
}

detect_dns_provider() {
    DNS_PROVIDER=""
    DNS_ACME_HOOK=""
    detect_dns_cloudflare && return 0
    log WARN "No DNS provider detected."
    return 1
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

    die "Cloudflare token missing. Set CF_Token or edit /etc/autossl/cloudflare.ini"
}

cloudflare_prepare_env() {
    [[ -n "${CF_API_TOKEN:-}" && -z "${CF_Token:-}" ]] && export CF_Token="$CF_API_TOKEN"
}
