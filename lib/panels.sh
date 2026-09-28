#!/usr/bin/env bash
# AutoSSL — panel deployment targets

PANEL_NAME=""
PANEL_TARGET=""

select_panel() {
    local primary="$1" num custom target

    echo ""
    echo -e "  ${BOLD}Select deployment target:${NC}"
    echo ""
    echo -e "    ${GREEN}[1]${NC} Manual        ${DIM}→ /etc/autossl/certs/${primary}/${NC}"
    echo -e "    ${GREEN}[2]${NC} Marzban       ${DIM}→ /var/lib/marzban/certs/${primary}/${NC}"
    echo -e "    ${GREEN}[3]${NC} Pasarguard    ${DIM}→ /var/lib/pasarguard/certs/${primary}/${NC}"
    echo -e "    ${GREEN}[4]${NC} PasarguardBot ${DIM}→ /var/lib/pasarguardbot/certs/${primary}/${NC}"
    echo -e "    ${GREEN}[5]${NC} PG-Node       ${DIM}→ /var/lib/pg-node/certs/${primary}/${NC}"
    echo ""

    while true; do
        read -rp "$(echo -e "  ${CYAN}›${NC} Choice ${DIM}[1-5, default 1]${NC}: ")" num
        num="${num:-1}"
        case "$num" in
            1)
                PANEL_NAME="none"
                custom="$(prompt "Custom path (empty = /etc/autossl/certs/${primary}/)" "")"
                target="${custom:-/etc/autossl/certs/${primary}}"
                break
                ;;
            2) PANEL_NAME="marzban";       target="/var/lib/marzban/certs/${primary}"; break ;;
            3) PANEL_NAME="pasarguard";    target="/var/lib/pasarguard/certs/${primary}"; break ;;
            4) PANEL_NAME="pasarguardbot"; target="/var/lib/pasarguardbot/certs/${primary}"; break ;;
            5) PANEL_NAME="pg-node";       target="/var/lib/pg-node/certs/${primary}"; break ;;
            *) echo -e "  ${RED}✖${NC}  Invalid. Enter 1, 2, 3, 4, or 5." ;;
        esac
    done

    can_create_dir "$target" || die "Cannot create: ${target}"
    ensure_dir "$target"
    PANEL_TARGET="$target"
    log INFO "Deploy target: ${PANEL_TARGET}"
}

PASARGUARDBOT_DIR="/opt/pasarguardbot"
PASARGUARDBOT_ENV="${PASARGUARDBOT_DIR}/.env"

# panel_post_deploy: hook for panel-specific steps after a successful deploy_certificates() call
panel_post_deploy() {
    local panel="$1" target="$2"

    case "$panel" in
        pasarguardbot) _pasarguardbot_sync "$target" ;;
    esac
}

_pasarguardbot_sync() {
    local target="$1"

    if [[ ! -f "$PASARGUARDBOT_ENV" ]]; then
        log WARN "PasarguardBot not found at ${PASARGUARDBOT_DIR} — set SSL_CERTFILE/SSL_KEYFILE in its .env manually."
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would set SSL_CERTFILE/SSL_KEYFILE in ${PASARGUARDBOT_ENV} and run: pasarguardbot restart"
        return 0
    fi

    set_env_var "$PASARGUARDBOT_ENV" "SSL_CERTFILE" "${target}/fullchain.pem"
    set_env_var "$PASARGUARDBOT_ENV" "SSL_KEYFILE"  "${target}/privkey.pem"
    log INFO "Updated ${PASARGUARDBOT_ENV} with new certificate paths."

    if command_exists pasarguardbot; then
        if pasarguardbot restart; then
            log INFO "PasarguardBot restarted."
        else
            log ERROR "PasarguardBot restart failed — restart it manually."
        fi
    else
        log WARN "pasarguardbot command not found — restart it manually to load the new certificate."
    fi
}
