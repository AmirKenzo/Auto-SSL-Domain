#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/autossl}"
REPO_URL="${REPO_URL:-https://github.com/AmirKenzo/Auto-SSL-Domain.git}"
BIN_PATH="/usr/local/bin/autossl"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${GREEN}[+]${NC} $*"; }
err() { echo -e "${RED}[x]${NC} $*"; exit 1; }

[[ "$(id -u)" -eq 0 ]] || err "Run as root: sudo bash scripts/install.sh"
[[ -f /etc/os-release ]] || err "Linux required."

install_pkg() {
    command -v apt-get &>/dev/null && apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$1" && return
    command -v dnf &>/dev/null && dnf install -y "$1" && return
    command -v yum &>/dev/null && yum install -y "$1" && return
    command -v pacman &>/dev/null && pacman -Sy --noconfirm "$1" && return
}

log "Installing dependencies..."
for pkg in curl openssl socat dnsutils; do install_pkg "$pkg" 2>/dev/null || true; done

if ! command -v certbot &>/dev/null; then
    install_pkg certbot 2>/dev/null || true
    install_pkg python3-certbot-dns-cloudflare 2>/dev/null || true
fi

if ! command -v certbot &>/dev/null && [[ ! -f "${HOME}/.acme.sh/acme.sh" ]]; then
    curl -fsSL https://get.acme.sh | sh -s email="${AUTOSSL_EMAIL:-admin@localhost}"
    "${HOME}/.acme.sh/acme.sh" --set-default-ca --server letsencrypt 2>/dev/null || true
fi

log "Installing to ${INSTALL_DIR}..."
if [[ -f "$(dirname "$0")/../autossl.sh" ]]; then
    SRC="$(cd "$(dirname "$0")/.." && pwd)"
    mkdir -p "$INSTALL_DIR"
    cp -a "$SRC/autossl.sh" "$SRC/lib" "$INSTALL_DIR/"
    cp -a "$SRC/config" "$INSTALL_DIR/" 2>/dev/null || true
else
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi

mkdir -p /etc/autossl/{certs,state} /var/log/autossl
chmod 700 /etc/autossl

[[ -f /etc/autossl/cloudflare.ini ]] || {
    cp "${INSTALL_DIR}/config/cloudflare.ini.example" /etc/autossl/cloudflare.ini 2>/dev/null || \
    echo "# dns_cloudflare_api_token = TOKEN" > /etc/autossl/cloudflare.ini
    chmod 600 /etc/autossl/cloudflare.ini
}

cat > "$BIN_PATH" <<EOF
#!/usr/bin/env bash
export AUTOSSL_INSTALL_DIR="${INSTALL_DIR}"
exec bash "${INSTALL_DIR}/autossl.sh" "\$@"
EOF
chmod +x "$BIN_PATH" "${INSTALL_DIR}/autossl.sh"

echo ""
log "Done. Run: autossl"
echo ""
