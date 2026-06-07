#!/usr/bin/env bash
# AutoSSL — main CLI entry point (pure Bash)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTOSSL_INSTALL_DIR="${AUTOSSL_INSTALL_DIR:-$SCRIPT_DIR}"

# shellcheck source=lib/common.sh
source "${AUTOSSL_INSTALL_DIR}/lib/common.sh"
# shellcheck source=lib/domain.sh
source "${AUTOSSL_INSTALL_DIR}/lib/domain.sh"
# shellcheck source=lib/dns.sh
source "${AUTOSSL_INSTALL_DIR}/lib/dns.sh"
# shellcheck source=lib/backup.sh
source "${AUTOSSL_INSTALL_DIR}/lib/backup.sh"
# shellcheck source=lib/deploy.sh
source "${AUTOSSL_INSTALL_DIR}/lib/deploy.sh"
# shellcheck source=lib/panels.sh
source "${AUTOSSL_INSTALL_DIR}/lib/panels.sh"
# shellcheck source=lib/issuer.sh
source "${AUTOSSL_INSTALL_DIR}/lib/issuer.sh"
# shellcheck source=lib/state.sh
source "${AUTOSSL_INSTALL_DIR}/lib/state.sh"
# shellcheck source=lib/expiration.sh
source "${AUTOSSL_INSTALL_DIR}/lib/expiration.sh"
# shellcheck source=lib/renewal.sh
source "${AUTOSSL_INSTALL_DIR}/lib/renewal.sh"

COMMAND="issue"
BACKEND_FORCE="auto"
CHALLENGE_MODE="http"
TARGET_DOMAIN=""
WARN_DAYS=30

usage() {
    cat <<EOF
AutoSSL v${AUTOSSL_VERSION} — Let's Encrypt certificate automation

Usage:
  autossl [options] [command]

Commands:
  issue              Issue a new certificate (interactive, default)
  renew              Renew tracked certificate(s)
  check              Check certificate expiration

Options:
  -h, --help         Show this help
  -V, --version      Show version
  -v, --verbose      Enable debug logging
  -n, --dry-run      Simulate without making changes
  -f, --force        Force renewal/overwrite without prompt
  --backend NAME     Force issuer: certbot | acme.sh
  --dns              Use DNS challenge (Cloudflare API — for wildcard)
  -d, --domain NAME  Target domain (renew/check)

Examples:
  autossl
  autossl issue
  autossl --dry-run issue
  autossl renew -d example.com
  autossl check --warn-days 14
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    usage; exit 0 ;;
            -V|--version) echo "autossl ${AUTOSSL_VERSION}"; exit 0 ;;
            -v|--verbose) VERBOSE=1; shift ;;
            -n|--dry-run) DRY_RUN=1; shift ;;
            -f|--force)   FORCE=1; shift ;;
            --backend)    BACKEND_FORCE="$2"; shift 2 ;;
            --dns)        CHALLENGE_MODE="dns"; shift ;;
            -d|--domain)  TARGET_DOMAIN="$2"; shift 2 ;;
            --warn-days)  WARN_DAYS="$2"; shift 2 ;;
            issue|renew|check)
                COMMAND="$1"; shift ;;
            issue-advanced)
                COMMAND="issue"; shift ;;
            *)
                die "Unknown argument: $1 (use --help)" ;;
        esac
    done
}

cmd_issue() {
    local primary rc domains_str

    print_banner
    is_linux || die "AutoSSL must be run on Linux."

    progress 1 4 "Domain input & validation"
    prompt_domains
    if [[ ${#DOMAINS[@]} -eq 0 ]]; then die "No domains provided."; fi
    validate_domains || exit 1

    primary="$(primary_domain)"
    log INFO "Domains: $(domains_to_string)"
    log INFO "Primary domain (folder name): ${primary}"

    if has_wildcard; then
        CHALLENGE_MODE="dns"
        log INFO "Wildcard — DNS challenge required (Cloudflare API token needed)."
    else
        log INFO "HTTP challenge (default) — no API key needed, port 80 must be free."
    fi

    progress 2 4 "Issuing certificate"
    detect_issuer "$BACKEND_FORCE"
    issue_certificate
    log INFO "Certificate issued successfully via ${ISSUER_BACKEND}."

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log INFO "Dry-run complete. No certificates deployed."
        return 0
    fi

    progress 3 4 "Panel selection & deployment"
    select_panel "$primary"

    set +e
    deploy_certificates "$SRC_FULLCHAIN" "$SRC_PRIVKEY" "$SRC_CERT" "$SRC_CHAIN" \
        "$PANEL_TARGET" 1
    rc=$?
    set -e

    if [[ "$rc" -eq 2 ]]; then
        log WARN "Existing certificates found in ${PANEL_TARGET}"
        if confirm "Overwrite existing certificates? (backup will be created)" "n"; then
            deploy_certificates "$SRC_FULLCHAIN" "$SRC_PRIVKEY" "$SRC_CERT" "$SRC_CHAIN" \
                "$PANEL_TARGET" 0 || die "Deployment failed."
        else
            log INFO "Deployment cancelled by user."
            exit 0
        fi
    elif [[ "$rc" -ne 0 ]]; then
        die "Deployment failed."
    fi

    progress 4 4 "Done"
    domains_str="$(domains_to_string)"
    check_expiration "${PANEL_TARGET}/fullchain.pem" 30
    save_cert_state "$primary" "$domains_str" "$PANEL_NAME" "$PANEL_TARGET" "$ISSUER_BACKEND"

    echo ""
    echo "============================================================"
    echo "  Certificate installation complete!"
    echo "============================================================"
    echo "  Domain:     ${primary}"
    echo "  Panel:      ${PANEL_NAME}"
    echo "  Path:       ${PANEL_TARGET}"
    echo "  fullchain:  ${PANEL_TARGET}/fullchain.pem"
    echo "  privkey:    ${PANEL_TARGET}/privkey.pem"
    echo "  cert:       ${PANEL_TARGET}/cert.pem"
    echo "  chain:      ${PANEL_TARGET}/chain.pem"
    echo "============================================================"
    echo ""
}

cmd_renew() {
    print_banner
    if [[ -n "$TARGET_DOMAIN" ]]; then
        renew_one "$TARGET_DOMAIN" || exit 1
    else
        renew_all || exit 1
    fi
}

cmd_check() {
    local primary
    print_banner
    if [[ -n "$TARGET_DOMAIN" ]]; then
        load_cert_state "$TARGET_DOMAIN" || die "Not tracked: ${TARGET_DOMAIN}"
        echo "${TARGET_DOMAIN}:"
        check_expiration "${deploy_path}/fullchain.pem" "$WARN_DAYS"
        return
    fi

    local found=0
    while IFS= read -r primary; do
        [[ -z "$primary" ]] && continue
        found=1
        load_cert_state "$primary"
        echo "${primary}:"
        check_expiration "${deploy_path}/fullchain.pem" "$WARN_DAYS"
    done < <(list_tracked_domains)

    if [[ "$found" -eq 0 ]]; then die "No tracked certificates."; fi
}

main() {
    parse_args "$@"
    init_autossl

    case "$COMMAND" in
        issue) cmd_issue ;;
        renew) cmd_renew ;;
        check) cmd_check ;;
        *)     cmd_issue ;;
    esac
}

main "$@"
