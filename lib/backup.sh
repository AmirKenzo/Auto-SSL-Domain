#!/usr/bin/env bash
# AutoSSL — certificate backup

CERT_FILES=(fullchain.pem privkey.pem cert.pem chain.pem)

backup_existing_certs() {
    local target_dir="$1"
    local existing=() f ts backup_dir

    for f in "${CERT_FILES[@]}"; do
        [[ -f "${target_dir}/${f}" ]] && existing+=("$f")
    done

    [[ ${#existing[@]} -eq 0 ]] && return 0

    ts="$(date '+%Y%m%d_%H%M%S')"
    backup_dir="${target_dir}/backup_${ts}"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would backup ${#existing[@]} file(s) to ${backup_dir}"
        return 0
    fi

    ensure_dir "$backup_dir"
    for f in "${existing[@]}"; do
        cp -a "${target_dir}/${f}" "${backup_dir}/${f}"
        log INFO "Backed up ${f} -> ${backup_dir}/"
    done
}
