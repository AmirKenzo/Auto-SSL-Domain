#!/usr/bin/env bash
# AutoSSL — panel deployment targets

PANEL_NAME=""
PANEL_TARGET=""

select_panel() {
    local primary="$1" num custom target

    echo ""
    echo "Where should the certificate be copied?"
    echo "  [1] Marzban    → /var/lib/marzban/certs/${primary}/"
    echo "  [2] Pasarguard → /var/lib/pasarguard/certs/${primary}/"
    echo "  [3] Manual     → /etc/autossl/certs/${primary}/"
    echo ""

    while true; do
        read -rp "Choice [1-3] (default 3): " num
        num="${num:-3}"
        case "$num" in
            1) PANEL_NAME="marzban";    target="/var/lib/marzban/certs/${primary}"; break ;;
            2) PANEL_NAME="pasarguard"; target="/var/lib/pasarguard/certs/${primary}"; break ;;
            3)
                PANEL_NAME="none"
                custom="$(prompt "Custom path (empty = /etc/autossl/certs/${primary}/)" "")"
                target="${custom:-/etc/autossl/certs/${primary}}"
                break
                ;;
            *) echo "Invalid. Enter 1, 2, or 3." ;;
        esac
    done

    can_create_dir "$target" || die "Cannot create directory: ${target}"
    ensure_dir "$target"
    PANEL_TARGET="$target"
    log INFO "Deploy target: ${PANEL_TARGET}"
}
