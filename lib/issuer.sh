#!/usr/bin/env bash
# AutoSSL — certbot & acme.sh issuance

ISSUER_BACKEND=""
DNS_BACKEND=""
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

_use_dns_challenge() {
    has_wildcard && return 0
    [[ "${CHALLENGE_MODE:-}" == "dns" ]] && return 0
    return 1
}

_certbot_issue_result() {
    local primary="$1" rc="$2"
    _set_certbot_paths "$primary"
    if [[ "$rc" -ne 0 ]]; then
        if [[ -e "$SRC_FULLCHAIN" && -e "$SRC_PRIVKEY" ]]; then
            log WARN "Certificate already valid — deploying existing cert."
        else
            die "certbot failed. Check: /var/log/letsencrypt/letsencrypt.log"
        fi
    fi
}

issue_certbot() {
    local primary="$1"
    local email="${AUTOSSL_EMAIL:-admin@${primary}}"
    local -a cmd cf_args
    local d challenge="HTTP"

    if _use_dns_challenge; then
        challenge="DNS"
        DNS_BACKEND="$(resolve_dns_backend)"
    fi

    if [[ "$challenge" == "HTTP" ]]; then
        cmd=(certbot certonly --non-interactive --agree-tos --email "$email" --cert-name "$primary"
             --standalone --preferred-challenges http)
        log INFO "HTTP challenge — port 80 must be free (no API key needed)."
    elif [[ "$DNS_BACKEND" == "cloudflare" ]]; then
        read -ra cf_args <<< "$(cloudflare_certbot_args)"
        cloudflare_prepare_env
        cmd=(certbot certonly --non-interactive --agree-tos --email "$email" --cert-name "$primary")
        cmd+=("${cf_args[@]}")
        log INFO "DNS challenge — Cloudflare API (automatic)."
    else
        print_manual_dns_banner
        cmd=(certbot certonly --agree-tos --email "$email" --cert-name "$primary"
             --manual --preferred-challenges dns)
        log INFO "DNS challenge — manual TXT record (no API key)."
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then cmd+=(--dry-run); fi
    if [[ "$FORCE" -eq 1 ]];  then cmd+=(--force-renewal); fi
    for d in "${DOMAINS[@]}"; do cmd+=(-d "$d"); done

    log INFO "Issuing certificate via certbot (${challenge} challenge)..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would run: ${cmd[*]}"
        _set_certbot_paths "$primary"
        return
    fi

    local rc=0
    "${cmd[@]}" || rc=$?
    [[ "$DNS_BACKEND" == "manual" && "$rc" -eq 0 ]] && wait_after_manual_dns
    _certbot_issue_result "$primary" "$rc"
}

issue_acme_sh() {
    local primary="$1" acme="$(_acme_bin)"
    local -a cmd
    local d challenge="HTTP"

    if _use_dns_challenge; then
        challenge="DNS"
        DNS_BACKEND="$(resolve_dns_backend)"
    fi

    cmd=("$acme" --issue)
    for d in "${DOMAINS[@]}"; do cmd+=(-d "$d"); done

    if [[ "$challenge" == "HTTP" ]]; then
        cmd+=(--standalone)
        log INFO "HTTP challenge — port 80 must be free (no API key needed)."
    elif [[ "$DNS_BACKEND" == "cloudflare" ]]; then
        cloudflare_prepare_env
        cmd+=(--dns "$DNS_ACME_HOOK")
        log INFO "DNS challenge — Cloudflare API (automatic)."
    else
        print_manual_dns_banner
        cmd+=(--dns --yes-I-know-dns-manual-mode-enough-go-ahead-please)
        log INFO "DNS challenge — manual TXT record (no API key)."
    fi

    if [[ "$FORCE" -eq 1 ]]; then cmd+=(--force); fi
    if [[ "$DRY_RUN" -eq 1 ]]; then cmd+=(--test); fi

    log INFO "Issuing certificate via acme.sh (${challenge} challenge)..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would run: ${cmd[*]}"
        _set_acme_paths "$primary"
        return
    fi

    if ! "${cmd[@]}"; then
        die "acme.sh failed."
    fi
    [[ "$DNS_BACKEND" == "manual" ]] && wait_after_manual_dns
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
