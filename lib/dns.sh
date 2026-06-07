#!/usr/bin/env bash
# AutoSSL — DNS provider detection (pluggable)

DNS_PROVIDER=""
DNS_ACME_HOOK=""
DNS_CERTBOT_PLUGIN=""

CF_CRED_PATHS=(
    "/etc/autossl/cloudflare.ini"
    "/etc/letsencrypt/cloudflare.ini"
    "${HOME}/.cloudflare.ini"
)

_has_cloudflare_credentials() {
    [[ -n "${CF_Token:-}" || -n "${CF_API_TOKEN:-}" ]] && return 0
    [[ -n "${CF_Key:-}" && -n "${CF_Email:-}" ]] && return 0
    local p
    for p in "${CF_CRED_PATHS[@]}"; do
        [[ -f "$p" ]] && return 0
    done
    return 1
}

_apex_domain() {
    local domain="$1"
    domain="${domain#\*.}"
    local parts count
    count=$(grep -o '\.' <<< "$domain" | wc -l)
    if (( count >= 1 )); then
        echo "$domain" | awk -F. '{print $(NF-1)"."$NF}'
    else
        echo "$domain"
    fi
}

_uses_cloudflare_ns() {
    local domain="$1"
    local apex ns_out
    apex="$(_apex_domain "$domain")"
    if command_exists dig; then
        ns_out="$(dig +short NS "$apex" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
        [[ "$ns_out" == *cloudflare.com* ]] && return 0
    fi
    return 1
}

detect_dns_cloudflare() {
    if _has_cloudflare_credentials; then
        DNS_PROVIDER="cloudflare"
        DNS_ACME_HOOK="dns_cf"
        DNS_CERTBOT_PLUGIN="dns-cloudflare"
        log INFO "Detected DNS provider: cloudflare (API credentials found)"
        return 0
    fi
    local d
    for d in "${DOMAINS[@]}"; do
        if _uses_cloudflare_ns "$d"; then
            DNS_PROVIDER="cloudflare"
            DNS_ACME_HOOK="dns_cf"
            DNS_CERTBOT_PLUGIN="dns-cloudflare"
            log INFO "Detected DNS provider: cloudflare (nameservers for $d)"
            return 0
        fi
    done
    return 1
}

# --- Route53 stub (pluggable) ---
detect_dns_route53() {
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        DNS_PROVIDER="route53"
        DNS_ACME_HOOK="dns_aws"
        DNS_CERTBOT_PLUGIN="dns-route53"
        log INFO "Detected DNS provider: route53 (AWS credentials found)"
        return 0
    fi
    return 1
}

# Register providers here — add new detect_dns_* functions above
detect_dns_provider() {
    DNS_PROVIDER=""
    DNS_ACME_HOOK=""
    DNS_CERTBOT_PLUGIN=""

    detect_dns_cloudflare && return 0
    detect_dns_route53 && return 0

    log WARN "No DNS provider auto-detected. DNS challenge may require manual setup."
    return 1
}

cloudflare_certbot_args() {
    local args=()
    local p
    for p in "${CF_CRED_PATHS[@]}"; do
        if [[ -f "$p" ]]; then
            args+=(--dns-cloudflare --dns-cloudflare-credentials "$p")
            echo "${args[@]}"
            return
        fi
    done
    echo "--dns-cloudflare"
}

cloudflare_prepare_env() {
    [[ -n "${CF_API_TOKEN:-}" && -z "${CF_Token:-}" ]] && export CF_Token="$CF_API_TOKEN"
}
