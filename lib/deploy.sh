#!/usr/bin/env bash
# AutoSSL — certificate deployment (fullchain.pem + privkey.pem only)

_copy_real_file() {
    local src="$1" dst="$2" mode="$3"
    rm -f "$dst"
    cp -L "$src" "$dst" || die "Failed to copy: ${src}"
    chmod "$mode" "$dst"
}

deploy_certificates() {
    local src_fullchain="$1"
    local src_privkey="$2"
    local target_dir="$3"
    local confirm_overwrite="${4:-1}"

    can_create_dir "$target_dir" || { log ERROR "Cannot write to: ${target_dir}"; return 1; }

    [[ -e "$src_fullchain" ]] || { log ERROR "Missing: ${src_fullchain}"; return 1; }
    [[ -e "$src_privkey"   ]] || { log ERROR "Missing: ${src_privkey}"; return 1; }

    local has_existing=0 f
    for f in "${CERT_FILES[@]}"; do
        [[ -e "${target_dir}/${f}" ]] && has_existing=1
    done

    if [[ "$has_existing" -eq 1 && "$confirm_overwrite" -eq 1 && "$FORCE" -eq 0 ]]; then
        echo "EXISTING_CERTS"
        return 2
    fi

    if [[ "$has_existing" -eq 1 ]]; then backup_existing_certs "$target_dir"; fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would deploy to ${target_dir}"
        log DRY-RUN "  -> fullchain.pem, privkey.pem"
        return 0
    fi

    ensure_dir "$target_dir"
    _copy_real_file "$src_fullchain" "${target_dir}/fullchain.pem" 644
    _copy_real_file "$src_privkey"   "${target_dir}/privkey.pem"   600

    # remove legacy files from older versions
    rm -f "${target_dir}/cert.pem" "${target_dir}/chain.pem"

    log INFO "Deployed fullchain.pem + privkey.pem → ${target_dir}"
    return 0
}
