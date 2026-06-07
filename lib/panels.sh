#!/usr/bin/env bash
# AutoSSL — panel deployment targets

PANEL_NAME=""
PANEL_TARGET=""

select_panel() {
    local primary="$1" num custom target

    echo ""
    echo -e "  ${BOLD}Select deployment target:${NC}"
    echo ""
    echo -e "    ${GREEN}[1]${NC} Marzban     ${DIM}→ /var/lib/marzban/certs/${primary}/${NC}"
    echo -e "    ${GREEN}[2]${NC} Pasarguard  ${DIM}→ /var/lib/pasarguard/certs/${primary}/${NC}"
    echo -e "    ${GREEN}[3]${NC} Manual      ${DIM}→ /etc/autossl/certs/${primary}/${NC}"
    echo ""

    while true; do
        read -rp "$(echo -e "  ${CYAN}›${NC} Choice ${DIM}[1-3, default 3]${NC}: ")" num
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
            *) echo -e "  ${RED}✖${NC}  Invalid. Enter 1, 2, or 3." ;;
        esac
    done

    can_create_dir "$target" || die "Cannot create: ${target}"
    ensure_dir "$target"
    PANEL_TARGET="$target"
    log INFO "Deploy target: ${PANEL_TARGET}"
}
