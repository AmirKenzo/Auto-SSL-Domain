#!/usr/bin/env bash
# AutoSSL — list certificates

_cert_expiry_info() {
    local cert="$1"
    local days enddate

    [[ -f "$cert" ]] || { echo "-1|unknown|N/A"; return; }

    days="$(days_until_expiry "$cert")"
    enddate="$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)"
    enddate="${enddate:-N/A}"

    if [[ "$days" -eq -1 ]]; then
        echo "-1|unknown|N/A"
    elif [[ "$days" -lt 0 ]]; then
        echo "${days}|expired|${enddate}"
    elif [[ "$days" -le 14 ]]; then
        echo "${days}|warning|${enddate}"
    else
        echo "${days}|ok|${enddate}"
    fi
}

_get_san_domains() {
    local cert="$1"
    [[ -f "$cert" ]] || return
    openssl x509 -in "$cert" -noout -ext subjectAltName 2>/dev/null \
        | tr ',' '\n' | sed -n 's/^[[:space:]]*DNS://p' | tr '\n' ' '
}

_print_cert_row() {
    local name="$1" domains="$2" panel="$3" path="$4" days="$5" expiry="$6" status="$7"
    local color="$GREEN" label

    case "$status" in
        expired) color="$RED";    label="EXPIRED ($(( -days ))d ago)" ;;
        warning) color="$YELLOW"; label="${days} days left" ;;
        ok)      color="$GREEN";   label="${days} days left" ;;
        *)       color="$DIM";    label="unknown" ;;
    esac

    echo -e "  ${BOLD}${MAGENTA}${name}${NC}"
    echo -e "    ${DIM}Domains${NC}   ${CYAN}${domains}${NC}"
    echo -e "    ${DIM}Panel${NC}     ${panel}"
    echo -e "    ${DIM}Path${NC}      ${path}"
    echo -e "    ${DIM}Expires${NC}   ${expiry}"
    echo -e "    ${DIM}Status${NC}    ${color}${label}${NC}"
    echo ""
}

cmd_list() {
    local primary cert_path info domains panel path days expiry status
    local found=0 st_domains st_panel st_path

    print_banner
    echo -e "  ${BOLD}Your Certificates${NC}"
    echo ""

    while IFS= read -r primary; do
        [[ -z "$primary" ]] && continue
        found=1

        st_domains="" st_panel="—" st_path="—"
        cert_path=""
        unset domains panel deploy_path backend updated_at

        if load_cert_state "$primary"; then
            st_domains="${domains:-}"
            st_panel="${panel:-manual}"
            st_path="${deploy_path:-—}"
            cert_path="${deploy_path}/fullchain.pem"
        fi

        if [[ ! -f "$cert_path" && -f "/etc/letsencrypt/live/${primary}/fullchain.pem" ]]; then
            cert_path="/etc/letsencrypt/live/${primary}/fullchain.pem"
            st_path="/etc/letsencrypt/live/${primary}"
        fi

        if [[ -z "$st_domains" && -f "$cert_path" ]]; then
            st_domains="$(_get_san_domains "$cert_path")"
        fi
        [[ -z "$st_domains" ]] && st_domains="$primary"

        IFS='|' read -r days status expiry <<< "$(_cert_expiry_info "$cert_path")"
        _print_cert_row "$primary" "$st_domains" "$st_panel" "$st_path" "$days" "$expiry" "$status"

    done < <(list_tracked_domains)

    if [[ -d /etc/letsencrypt/live ]]; then
        for primary in /etc/letsencrypt/live/*/; do
            [[ -d "$primary" ]] || continue
            primary="$(basename "$primary")"
            [[ "$primary" == "README" ]] && continue
            [[ -f "${AUTOSSL_STATE}/${primary}.conf" ]] && continue

            cert_path="/etc/letsencrypt/live/${primary}/fullchain.pem"
            [[ -f "$cert_path" ]] || continue
            found=1

            st_domains="$(_get_san_domains "$cert_path")"
            [[ -z "$st_domains" ]] && st_domains="$primary"

            IFS='|' read -r days status expiry <<< "$(_cert_expiry_info "$cert_path")"
            _print_cert_row "$primary" "$st_domains" "certbot" "/etc/letsencrypt/live/${primary}" "$days" "$expiry" "$status"
        done
    fi

    if [[ "$found" -eq 0 ]]; then
        echo -e "  ${YELLOW}⚠${NC}  No certificates found."
        echo -e "  ${DIM}Run: autossl issue${NC}"
        echo ""
        return
    fi

    echo -e "  ${DIM}Commands: autossl check  |  autossl renew -d <domain>${NC}"
    echo ""
}
