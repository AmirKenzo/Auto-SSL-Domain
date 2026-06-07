#!/usr/bin/env bash
# AutoSSL — certbot & acme.sh issuance

ISSUER_BACKEND=""
SRC_FULLCHAIN=""
SRC_PRIVKEY=""
SRC_CERT=""
SRC_CHAIN=""

_acme_bin() {
    if [[ -f "${HOME}/.acme.sh/acme.sh" ]]; then
        echo "${HOME}/.acme.sh/acme.sh"
    elif [[ -f "/root/.acme.sh/acme.sh" ]]; then
        echo "/root/.acme.sh/acme.sh"
    fi
}

detect_issuer() {
    local forced="${1:-auto}"
    case "$forced" in
        certbot)
            command_exists certbot || die "certbot not found."
            ISSUER_BACKEND="certbot"
            ;;
        acme.sh|acme)
            [[ -n "$(_acme_bin)" ]] || die "acme.sh not found."
            ISSUER_BACKEND="acme.sh"
            ;;
        *)
            if command_exists certbot; then
                ISSUER_BACKEND="certbot"
            elif [[ -n "$(_acme_bin)" ]]; then
                ISSUER_BACKEND="acme.sh"
            else
                die "No certificate issuer found. Install certbot or acme.sh."
            fi
            ;;
    esac
    log INFO "Using issuer: ${ISSUER_BACKEND}"
}

_set_certbot_paths() {
    local base="/etc/letsencrypt/live/$1"
    SRC_FULLCHAIN="${base}/fullchain.pem"
    SRC_PRIVKEY="${base}/privkey.pem"
    SRC_CERT="${base}/cert.pem"
    SRC_CHAIN="${base}/chain.pem"
}

_set_acme_paths() {
    local base="$(dirname "$(_acme_bin)")/$1_ecc"
    SRC_FULLCHAIN="${base}/fullchain.cer"
    SRC_PRIVKEY="${base}/$1.key"
    SRC_CERT="${base}/$1.cer"
    SRC_CHAIN="${base}/ca.cer"
}

# DNS only for wildcard (*.domain) or --dns flag. Normal domains use HTTP (no API key).
_use_dns_challenge() {
    has_wildcard && return 0
    [[ "${CHALLENGE_MODE:-}" == "dns" ]] && return 0
    return 1
}

issue_certbot() {
    local primary="$1"
    local email="${AUTOSSL_EMAIL:-admin@${primary}}"
    local -a cmd args
    local d challenge="HTTP"

    if _use_dns_challenge; then
        detect_dns_provider || die "Wildcard/DNS mode needs Cloudflare API token (CF_Token or /etc/autossl/cloudflare.ini)."
        read -ra args <<< "$(cloudflare_certbot_args)"
        challenge="DNS"
    fi

    cmd=(certbot certonly --non-interactive --agree-tos --email "$email" --cert-name "$primary")
    if [[ "$DRY_RUN" -eq 1 ]]; then cmd+=(--dry-run); fi
    if [[ "$FORCE" -eq 1 ]];  then cmd+=(--force-renewal); fi
    for d in "${DOMAINS[@]}"; do cmd+=(-d "$d"); done

    if [[ "$challenge" == "DNS" ]]; then
        cloudflare_prepare_env
        cmd+=("${args[@]}")
    else
        cmd+=(--standalone --preferred-challenges http)
        log INFO "HTTP challenge — port 80 must be free (no API key needed)."
    fi

    log INFO "Issuing certificate via certbot (${challenge} challenge)..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would run: ${cmd[*]}"
    else
        if ! "${cmd[@]}"; then
            die "certbot failed. Check: /var/log/letsencrypt/letsencrypt.log"
        fi
    fi
    _set_certbot_paths "$primary"
}

issue_acme_sh() {
    local primary="$1" acme="$(_acme_bin)"
    local -a cmd
    local d challenge="HTTP"

    if _use_dns_challenge; then
        detect_dns_provider || die "Wildcard/DNS mode needs CF_Token."
        challenge="DNS"
    fi

    cmd=("$acme" --issue)
    for d in "${DOMAINS[@]}"; do cmd+=(-d "$d"); done
    if [[ "$challenge" == "DNS" ]]; then
        cloudflare_prepare_env
        cmd+=(--dns "$DNS_ACME_HOOK")
    else
        cmd+=(--standalone)
        log INFO "HTTP challenge — port 80 must be free (no API key needed)."
    fi
    if [[ "$FORCE" -eq 1 ]]; then cmd+=(--force); fi
    if [[ "$DRY_RUN" -eq 1 ]]; then cmd+=(--test); fi

    log INFO "Issuing certificate via acme.sh (${challenge} challenge)..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would run: ${cmd[*]}"
    else
        if ! "${cmd[@]}"; then
            die "acme.sh failed."
        fi
    fi
    _set_acme_paths "$primary"
}

issue_certificate() {
    local primary="$(primary_domain)"
    case "$ISSUER_BACKEND" in
        certbot) issue_certbot "$primary" ;;
        acme.sh) issue_acme_sh "$primary" ;;
        *) die "Unknown issuer: ${ISSUER_BACKEND}" ;;
    esac
}

renew_certbot() {
    local primary="$1"
    local -a cmd=(certbot renew --cert-name "$primary" --non-interactive)
    if [[ "$DRY_RUN" -eq 1 ]]; then cmd+=(--dry-run); fi
    if [[ "$FORCE" -eq 1 ]];  then cmd+=(--force-renewal); fi
    log INFO "Renewing ${primary} via certbot..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would run: ${cmd[*]}"
    elif ! "${cmd[@]}"; then
        return 1
    fi
    _set_certbot_paths "$primary"
}

renew_acme_sh() {
    local primary="$1" acme="$(_acme_bin)"
    local -a cmd=("$acme" --renew -d "$primary")
    if [[ "$FORCE" -eq 1 ]]; then cmd+=(--force); fi
    if [[ "$DRY_RUN" -eq 1 ]]; then cmd+=(--test); fi
    log INFO "Renewing ${primary} via acme.sh..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would run: ${cmd[*]}"
    elif ! "${cmd[@]}"; then
        return 1
    fi
    _set_acme_paths "$primary"
}
