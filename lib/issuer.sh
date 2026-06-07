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
    else
        echo ""
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
        auto|*)
            if command_exists certbot; then
                ISSUER_BACKEND="certbot"
            elif [[ -n "$(_acme_bin)" ]]; then
                ISSUER_BACKEND="acme.sh"
            else
                die "No certificate issuer found. Install certbot or acme.sh first."
            fi
            ;;
    esac
    log INFO "Using issuer: ${ISSUER_BACKEND}"
}

_set_certbot_paths() {
    local primary="$1"
    local base="/etc/letsencrypt/live/${primary}"
    SRC_FULLCHAIN="${base}/fullchain.pem"
    SRC_PRIVKEY="${base}/privkey.pem"
    SRC_CERT="${base}/cert.pem"
    SRC_CHAIN="${base}/chain.pem"
}

_set_acme_paths() {
    local primary="$1"
    local base
    base="$(dirname "$(_acme_bin)")/${primary}_ecc"
    SRC_FULLCHAIN="${base}/fullchain.cer"
    SRC_PRIVKEY="${base}/${primary}.key"
    SRC_CERT="${base}/${primary}.cer"
    SRC_CHAIN="${base}/ca.cer"
}

issue_certbot() {
    local primary="$1"
    local email="${AUTOSSL_EMAIL:-admin@${primary}}"
    local -a cmd args=()
    local d use_dns=0

    if has_wildcard; then
        detect_dns_provider || die "Wildcard requires DNS challenge. Configure Cloudflare credentials."
        use_dns=1
    elif detect_dns_provider; then
        use_dns=1
    fi

    cmd=(certbot certonly --non-interactive --agree-tos --email "$email" --cert-name "$primary")
    [[ "$DRY_RUN" -eq 1 ]] && cmd+=(--dry-run)
    [[ "$FORCE" -eq 1 ]] && cmd+=(--force-renewal)

    for d in "${DOMAINS[@]}"; do
        cmd+=(-d "$d")
    done

    if [[ "$use_dns" -eq 1 ]]; then
        read -ra args <<< "$(cloudflare_certbot_args)"
        cloudflare_prepare_env
        cmd+=("${args[@]}")
    else
        cmd+=(--standalone --preferred-challenges http)
    fi

    log INFO "Issuing certificate via certbot (${use_dns:+DNS}${use_dns:-HTTP} challenge)..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would run: ${cmd[*]}"
    else
        "${cmd[@]}" || die "certbot issuance failed."
    fi
    _set_certbot_paths "$primary"
}

issue_acme_sh() {
    local primary="$1"
    local acme="$(_acme_bin)"
    local -a cmd=()
    local d use_dns=0

    if has_wildcard; then
        detect_dns_provider || die "Wildcard requires DNS challenge. Set CF_Token or configure cloudflare.ini."
        use_dns=1
    elif detect_dns_provider; then
        use_dns=1
    fi

    cmd=("$acme" --issue)
    for d in "${DOMAINS[@]}"; do
        cmd+=(-d "$d")
    done

    if [[ "$use_dns" -eq 1 ]]; then
        cloudflare_prepare_env
        cmd+=(--dns "$DNS_ACME_HOOK")
    else
        cmd+=(--standalone)
    fi

    [[ "$FORCE" -eq 1 ]] && cmd+=(--force)
    [[ "$DRY_RUN" -eq 1 ]] && cmd+=(--test)

    log INFO "Issuing certificate via acme.sh..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would run: ${cmd[*]}"
    else
        "${cmd[@]}" || die "acme.sh issuance failed."
    fi
    _set_acme_paths "$primary"
}

issue_certificate() {
    local primary
    primary="$(primary_domain)"
    case "$ISSUER_BACKEND" in
        certbot)  issue_certbot "$primary" ;;
        acme.sh)  issue_acme_sh "$primary" ;;
        *) die "Unknown issuer: ${ISSUER_BACKEND}" ;;
    esac
}

renew_certbot() {
    local primary="$1"
    local -a cmd=(certbot renew --cert-name "$primary" --non-interactive)
    [[ "$DRY_RUN" -eq 1 ]] && cmd+=(--dry-run)
    [[ "$FORCE" -eq 1 ]] && cmd+=(--force-renewal)
    log INFO "Renewing ${primary} via certbot..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would run: ${cmd[*]}"
    else
        "${cmd[@]}" || return 1
    fi
    _set_certbot_paths "$primary"
    return 0
}

renew_acme_sh() {
    local primary="$1"
    local acme="$(_acme_bin)"
    local -a cmd=("$acme" --renew -d "$primary")
    [[ "$FORCE" -eq 1 ]] && cmd+=(--force)
    [[ "$DRY_RUN" -eq 1 ]] && cmd+=(--test)
    log INFO "Renewing ${primary} via acme.sh..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would run: ${cmd[*]}"
    else
        "${cmd[@]}" || return 1
    fi
    _set_acme_paths "$primary"
    return 0
}
