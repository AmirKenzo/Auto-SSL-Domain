#!/usr/bin/env bash
# AutoSSL — certificate expiration check

days_until_expiry() {
    local cert_path="$1"
    local enddate days

    [[ -f "$cert_path" ]] || { echo "-1"; return 1; }
    command_exists openssl || { echo "-1"; return 1; }

    enddate="$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | cut -d= -f2)"
    [[ -z "$enddate" ]] && { echo "-1"; return 1; }

    local expiry_ts now_ts
    expiry_ts="$(date -d "$enddate" +%s 2>/dev/null || date -j -f '%b %d %T %Y %Z' "$enddate" +%s 2>/dev/null)"
    now_ts="$(date +%s)"
    days=$(( (expiry_ts - now_ts) / 86400 ))
    echo "$days"
}

check_expiration() {
    local cert_path="$1"
    local warn_days="${2:-30}"
    local days msg

    days="$(days_until_expiry "$cert_path")"
    if [[ "$days" -eq -1 ]]; then
        msg="Could not read certificate: ${cert_path}"
        log ERROR "$msg"
        echo "  ${msg}"
        return 1
    fi

    if [[ "$days" -lt 0 ]]; then
        msg="Certificate EXPIRED $(( -days )) day(s) ago."
        log ERROR "$msg"
    elif [[ "$days" -le "$warn_days" ]]; then
        msg="Certificate expires in ${days} day(s) — renewal recommended."
        log WARN "$msg"
    else
        msg="Certificate valid for ${days} more day(s)."
        log INFO "$msg"
    fi
    echo "  ${msg}"
}
