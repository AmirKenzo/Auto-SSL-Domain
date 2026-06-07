#!/usr/bin/env bash
# AutoSSL — domain validation

DOMAIN_REGEX='^(\*\.)?([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'

validate_domain() {
    local domain="$1"
    domain="${domain,,}"

    [[ -z "$domain" ]] && return 1
    [[ ${#domain} -gt 253 ]] && return 1
    [[ ! "$domain" =~ $DOMAIN_REGEX ]] && return 1

    if [[ "$domain" == *.* ]]; then
        local base="${domain#\*.}"
        [[ "$domain" == "*."* && $(grep -o '\.' <<< "$base" | wc -l) -lt 1 ]] && return 1
    fi
    return 0
}

normalize_domains() {
    local raw="$1"
    local -a result=()
    local -A seen=()
    local word

    raw="${raw//,/ }"
    for word in $raw; do
        word="${word,,}"
        word="${word// /}"
        [[ -z "$word" ]] && continue
        [[ -n "${seen[$word]:-}" ]] && continue
        seen[$word]=1
        result+=("$word")
    done
    DOMAINS=("${result[@]}")
}

validate_domains() {
    local d
    for d in "${DOMAINS[@]}"; do
        if ! validate_domain "$d"; then
            log ERROR "Invalid domain: $d"
            return 1
        fi
    done
    return 0
}

has_wildcard() {
    local d
    for d in "${DOMAINS[@]}"; do
        [[ "$d" == "*."* ]] && return 0
    done
    return 1
}

primary_domain() {
    local d
    for d in "${DOMAINS[@]}"; do
        [[ "$d" != "*."* ]] && { echo "$d"; return; }
    done
    if [[ ${#DOMAINS[@]} -gt 0 ]]; then
        echo "${DOMAINS[0]#\*.}"
    else
        echo "unknown"
    fi
}

prompt_domains() {
    echo ""
    echo -e "  ${BOLD}Enter domain(s)${NC} ${DIM}(space-separated)${NC}"
    echo -e "  ${DIM}e.g. example.com  |  example.com www.example.com  |  *.example.com${NC}"
    echo ""
    normalize_domains "$(prompt "Domains")"
}
