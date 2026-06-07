#!/usr/bin/env bash
# AutoSSL — certificate state tracking

save_cert_state() {
    local primary="$1"
    local domains_str="$2"
    local panel="$3"
    local deploy_path="$4"
    local backend="$5"
    local state_file="${AUTOSSL_STATE}/${primary}.conf"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would save state to ${state_file}"
        return 0
    fi

    cat > "$state_file" <<EOF
# AutoSSL state — ${primary}
domains="${domains_str}"
panel="${panel}"
deploy_path="${deploy_path}"
backend="${backend}"
challenge="${CHALLENGE_MODE:-http}"
dns_backend="${DNS_BACKEND:-}"
updated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
EOF
    chmod 600 "$state_file"
    log INFO "State saved: ${state_file}"
}

load_cert_state() {
    local primary="$1"
    local state_file="${AUTOSSL_STATE}/${primary}.conf"
    [[ -f "$state_file" ]] || return 1
    # shellcheck source=/dev/null
    source "$state_file"
    return 0
}

list_tracked_domains() {
    local f
    for f in "${AUTOSSL_STATE}"/*.conf; do
        [[ -f "$f" ]] || continue
        basename "$f" .conf
    done
}

domains_to_string() {
    local IFS=' '
    echo "${DOMAINS[*]}"
}

string_to_domains() {
    normalize_domains "$1"
}
