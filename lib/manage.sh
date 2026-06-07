#!/usr/bin/env bash
# AutoSSL — update & uninstall

AUTOSSL_BRANCH="${AUTOSSL_BRANCH:-main}"
REPO_URL="${REPO_URL:-https://github.com/AmirKenzo/Auto-SSL-Domain.git}"
BIN_PATH="/usr/local/bin/autossl"

cmd_update() {
    local dir="${AUTOSSL_INSTALL_DIR}"

    [[ "$(id -u)" -eq 0 ]] || die "Run as root: sudo autossl update"
    print_banner
    log INFO "Updating AutoSSL..."

    if [[ -d "${dir}/.git" ]]; then
        git -C "$dir" fetch origin "$AUTOSSL_BRANCH"
        git -C "$dir" checkout "$AUTOSSL_BRANCH"
        git -C "$dir" reset --hard "origin/${AUTOSSL_BRANCH}"
    elif [[ -f "${dir}/scripts/install.sh" ]]; then
        bash "${dir}/scripts/install.sh"
        return
    else
        die "Install not found. Run: bash <(curl -Ls .../scripts/install.sh)"
    fi

    chmod +x "${dir}/autossl.sh"
    log INFO "Updated successfully. Version: ${AUTOSSL_VERSION}"
}

cmd_uninstall() {
    local dir="${AUTOSSL_INSTALL_DIR}"

    [[ "$(id -u)" -eq 0 ]] || die "Run as root: sudo autossl uninstall"
    print_banner

    echo "This will remove:"
    echo "  - ${BIN_PATH}"
    echo "  - ${dir}"
    echo ""
    confirm "Uninstall AutoSSL?" "n" || { log INFO "Cancelled."; return; }

    rm -f "$BIN_PATH"
    rm -rf "$dir"

    if confirm "Also remove /etc/autossl and /var/log/autossl?" "n"; then
        rm -rf /etc/autossl /var/log/autossl
        log INFO "Config and logs removed."
    else
        log INFO "Kept /etc/autossl and /var/log/autossl"
    fi

    log INFO "AutoSSL uninstalled."
}
