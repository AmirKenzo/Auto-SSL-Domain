#!/usr/bin/env bash
# AutoSSL — certificate deployment

deploy_certificates() {
    local src_fullchain="$1"
    local src_privkey="$2"
    local src_cert="$3"
    local src_chain="$4"
    local target_dir="$5"
    local confirm_overwrite="${6:-1}"

    local f
    can_create_dir "$target_dir" || { log ERROR "Cannot write to: ${target_dir}"; return 1; }

    for f in "$src_fullchain" "$src_privkey" "$src_cert" "$src_chain"; do
        [[ ! -f "$f" ]] && { log ERROR "Missing source file: $f"; return 1; }
    done

    local has_existing=0
    for f in "${CERT_FILES[@]}"; do
        [[ -f "${target_dir}/${f}" ]] && has_existing=1
    done

    if [[ "$has_existing" -eq 1 && "$confirm_overwrite" -eq 1 && "$FORCE" -eq 0 ]]; then
        echo "EXISTING_CERTS"
        return 2
    fi

    [[ "$has_existing" -eq 1 ]] && backup_existing_certs "$target_dir"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would deploy certificates to ${target_dir}"
        for f in "${CERT_FILES[@]}"; do
            log DRY-RUN "  -> ${target_dir}/${f}"
        done
        return 0
    fi

    ensure_dir "$target_dir"
    cp -a "$src_fullchain" "${target_dir}/fullchain.pem"
    cp -a "$src_privkey"   "${target_dir}/privkey.pem"
    cp -a "$src_cert"      "${target_dir}/cert.pem"
    cp -a "$src_chain"     "${target_dir}/chain.pem"
    chmod 600 "${target_dir}/privkey.pem"
    chmod 644 "${target_dir}/fullchain.pem" "${target_dir}/cert.pem" "${target_dir}/chain.pem"
    log INFO "Certificates deployed to ${target_dir}"
    return 0
}
