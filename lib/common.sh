#!/usr/bin/env bash
# AutoSSL — shared utilities

AUTOSSL_VERSION="2.4.0"
AUTOSSL_BASE="${AUTOSSL_BASE:-/etc/autossl}"
AUTOSSL_CERTS="${AUTOSSL_BASE}/certs"
AUTOSSL_STATE="${AUTOSSL_BASE}/state"
AUTOSSL_LOG_DIR="${AUTOSSL_LOG_DIR:-/var/log/autossl}"
AUTOSSL_LOG_FILE="${AUTOSSL_LOG_DIR}/autossl.log"

DRY_RUN=0
FORCE=0
VERBOSE=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${ts} [${level}] ${msg}" >> "$AUTOSSL_LOG_FILE" 2>/dev/null || true
    case "$level" in
        INFO)    echo -e "  ${GREEN}✔${NC}  ${msg}" ;;
        WARN)    echo -e "  ${YELLOW}⚠${NC}  ${msg}" ;;
        ERROR)   echo -e "  ${RED}✖${NC}  ${msg}" ;;
        DEBUG)   [[ "$VERBOSE" -eq 1 ]] && echo -e "  ${CYAN}●${NC}  ${msg}" ;;
        DRY-RUN) echo -e "  ${CYAN}○${NC}  ${msg}" ;;
    esac
}

die() {
    log ERROR "$*"
    exit 1
}

ensure_dir() {
    local path="$1"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would create: ${path}"
        return 0
    fi
    mkdir -p "$path" || die "Failed to create: ${path}"
}

command_exists() {
    command -v "$1" &>/dev/null
}

is_linux() {
    [[ -f /etc/os-release ]]
}

can_create_dir() {
    local path="$1"
    local parent="$path"
    while [[ ! -e "$parent" && "$parent" != "/" ]]; do
        parent="$(dirname "$parent")"
    done
    [[ -w "$parent" ]]
}

print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}${MAGENTA}AutoSSL${NC} ${DIM}v${AUTOSSL_VERSION}${NC}  ${BLUE}— Let's Encrypt SSL Manager${NC}      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

progress() {
    local step="$1" total="$2" msg="$3"
    echo ""
    echo -e "  ${BOLD}${BLUE}▶ Step ${step}/${total}${NC}  ${msg}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
}

confirm() {
    local msg="$1" default="${2:-n}"
    local hint
    if [[ "$default" == "y" ]]; then hint="Y/n"; else hint="y/N"; fi
    read -rp "$(echo -e "  ${YELLOW}?${NC} ${msg} (${hint}): ")" ans
    ans="${ans:-$default}"
    [[ "$ans" =~ ^[Yy] ]]
}

prompt() {
    local msg="$1" default="${2:-}"
    local suffix=""
    if [[ -n "$default" ]]; then suffix=" [${default}]"; fi
    read -rp "$(echo -e "  ${CYAN}›${NC} ${msg}${suffix}: ")" val
    echo "${val:-$default}"
}

print_success_box() {
    local primary="$1" panel="$2" target="$3"
    local fullchain="${target}/fullchain.pem"
    local privkey="${target}/privkey.pem"
    local days validity

    days="$(days_until_expiry "$fullchain" 2>/dev/null || echo -1)"
    if [[ "$days" -ge 0 ]]; then
        validity="${days} days"
    else
        validity="—"
    fi

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}Certificate installed successfully!${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
    printf "${GREEN}║${NC}  %-12s ${CYAN}%s${NC}\n" "Domain:" "$primary"
    printf "${GREEN}║${NC}  %-12s ${CYAN}%s${NC}\n" "Panel:" "$panel"
    printf "${GREEN}║${NC}  %-12s ${CYAN}%s${NC}\n" "Valid for:" "$validity"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}Use these paths in your panel:${NC}                         ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${DIM}Fullchain:${NC}                                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${CYAN}${fullchain}${NC}"
    echo -e "${GREEN}║${NC}                                                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${DIM}Privkey:${NC}                                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${CYAN}${privkey}${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

init_autossl() {
    ensure_dir "$AUTOSSL_BASE"
    ensure_dir "$AUTOSSL_CERTS"
    ensure_dir "$AUTOSSL_STATE"
    ensure_dir "$AUTOSSL_LOG_DIR"
    chmod 700 "$AUTOSSL_BASE" 2>/dev/null || true
}
