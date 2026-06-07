#!/usr/bin/env bash
# AutoSSL — shared utilities

AUTOSSL_VERSION="2.1.0"
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
BOLD='\033[1m'
NC='\033[0m'

log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${ts} [${level}] ${msg}" >> "$AUTOSSL_LOG_FILE" 2>/dev/null || true
    case "$level" in
        INFO)    echo -e "${GREEN}[INFO]${NC} ${msg}" ;;
        WARN)    echo -e "${YELLOW}[WARN]${NC} ${msg}" ;;
        ERROR)   echo -e "${RED}[ERROR]${NC} ${msg}" ;;
        DEBUG)   [[ "$VERBOSE" -eq 1 ]] && echo -e "${CYAN}[DEBUG]${NC} ${msg}" ;;
        DRY-RUN) echo -e "${CYAN}[DRY-RUN]${NC} ${msg}" ;;
    esac
}

die() {
    log ERROR "$*"
    exit 1
}

ensure_dir() {
    local dir="$1"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log DRY-RUN "Would create directory: $dir"
        return 0
    fi
    mkdir -p "$dir" || die "Failed to create directory: $dir"
}

command_exists() {
    command -v "$1" &>/dev/null
}

is_linux() {
    [[ -f /etc/os-release ]]
}

is_writable() {
    local path="$1"
    local check="$path"
    [[ ! -e "$path" ]] && check="$(dirname "$path")"
    [[ -w "$check" ]]
}

print_banner() {
    echo ""
    echo "============================================================"
    echo "  AutoSSL v${AUTOSSL_VERSION} — Let's Encrypt Automation"
    echo "============================================================"
    echo ""
}

progress() {
    local step="$1" total="$2" msg="$3"
    echo ""
    echo -e "${BOLD}[${step}/${total}] ${msg}${NC}"
    echo "----------------------------------------"
}

confirm() {
    local msg="$1" default="${2:-n}"
    local hint
    [[ "$default" == "y" ]] && hint="Y/n" || hint="y/N"
    read -rp "${msg} (${hint}): " ans
    ans="${ans:-$default}"
    [[ "$ans" =~ ^[Yy] ]]
}

prompt() {
    local msg="$1" default="${2:-}"
    local suffix=""
    [[ -n "$default" ]] && suffix=" [${default}]"
    read -rp "${msg}${suffix}: " val
    echo "${val:-$default}"
}

init_autossl() {
    ensure_dir "$AUTOSSL_BASE"
    ensure_dir "$AUTOSSL_CERTS"
    ensure_dir "$AUTOSSL_STATE"
    ensure_dir "$AUTOSSL_LOG_DIR"
    chmod 700 "$AUTOSSL_BASE" 2>/dev/null || true
}
