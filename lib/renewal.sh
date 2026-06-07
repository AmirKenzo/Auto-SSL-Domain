#!/usr/bin/env bash
# AutoSSL — manual renewal only

renew_one() {
    local primary="$1" rc=0

    load_cert_state "$primary" || { log ERROR "Not tracked: ${primary}"; return 1; }

    string_to_domains "$domains"
    detect_issuer "${backend:-auto}"

    case "$ISSUER_BACKEND" in
        certbot) renew_certbot "$primary" || return 1 ;;
        acme.sh) renew_acme_sh "$primary"   || return 1 ;;
    esac

    if [[ -n "$deploy_path" ]]; then
        set +e
        deploy_certificates "$SRC_FULLCHAIN" "$SRC_PRIVKEY" "$deploy_path" 0
        rc=$?
        set -e
        [[ "$rc" -ne 0 ]] && { log ERROR "Redeploy failed: ${primary}"; return 1; }
        log INFO "Redeployed to ${deploy_path}"
    fi

    save_cert_state "$primary" "$domains" "$panel" "$deploy_path" "$ISSUER_BACKEND"
    log INFO "Renewed: ${primary}"
}

renew_all() {
    local primary rc=0 found=0
    while IFS= read -r primary; do
        [[ -z "$primary" ]] && continue
        found=1
        renew_one "$primary" || rc=1
    done < <(list_tracked_domains)
    [[ "$found" -eq 0 ]] && die "No tracked certificates."
    return "$rc"
}
