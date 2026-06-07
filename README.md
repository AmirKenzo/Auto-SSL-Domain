# AutoSSL

Production-ready **pure Bash** Let's Encrypt certificate automation with **Marzban**, **Pasarguard**, and manual deployment.

> No Python required — works on any Linux server with Bash.

## Features

- **Certificate issuance** via `certbot` or `acme.sh` (auto-detected)
- **Single domain**, **SAN (multiple domains)**, and **wildcard** (`*.example.com`)
- **DNS challenge** for wildcards with pluggable DNS providers (Cloudflare first)
- **Panel integration**: Marzban, Pasarguard, or manual/custom path
- **Interactive CLI** with numeric panel selection (1/2/3)
- **Manual renewal** via `autossl renew` (no background service)
- **Expiration checker**, logging, dry-run mode
- **Backup** existing certificates before overwrite

## Quick Install

```bash
# One-liner
bash <(curl -Ls https://raw.githubusercontent.com/AmirKenzo/Auto-SSL-Domain/main/scripts/install.sh)

# Or clone and install
git clone https://github.com/AmirKenzo/Auto-SSL-Domain.git
cd Auto-SSL-Domain
sudo bash scripts/install.sh
```

## Usage Examples

### Interactive issuance (default)

```bash
sudo autossl
sudo autossl issue
```

### Single domain

```bash
sudo autossl issue
# Enter: example.com
# Choice [1-3]: 1   (Marzban)
```

### Multiple domains (SAN)

```bash
sudo autossl issue
# Enter: example.com www.example.com api.example.com
```

### Wildcard (DNS — Cloudflare)

```bash
export CF_Token="your_cloudflare_api_token"
sudo autossl issue
# Enter: *.example.com example.com
```

### Dry-run

```bash
sudo autossl --dry-run issue
```

### Force backend

```bash
sudo autossl --backend certbot issue
sudo autossl --backend acme.sh issue
```

### Renew & check

```bash
sudo autossl renew
sudo autossl renew -d example.com
sudo autossl check
sudo autossl check -d example.com --warn-days 14
```

## Deployment Paths

| Panel       | Path                                      |
|-------------|-------------------------------------------|
| Marzban     | `/var/lib/marzban/certs/<domain>/`        |
| Pasarguard  | `/var/lib/pasarguard/certs/<domain>/`     |
| None        | `/etc/autossl/certs/<domain>/` or custom  |

Each domain folder:

```
fullchain.pem
privkey.pem
cert.pem
chain.pem
```

## Cloudflare DNS Setup

```bash
sudo cp config/cloudflare.ini.example /etc/autossl/cloudflare.ini
sudo chmod 600 /etc/autossl/cloudflare.ini
sudo nano /etc/autossl/cloudflare.ini
```

Or:

```bash
export CF_Token="your_api_token"
```

## Manual Renewal

```bash
sudo autossl renew
sudo autossl renew -d example.com
```

## Project Structure

```
autossl.sh
lib/
├── common.sh
├── domain.sh
├── dns.sh
├── issuer.sh
├── deploy.sh
├── backup.sh
├── panels.sh
├── state.sh
├── expiration.sh
└── renewal.sh
scripts/install.sh
```

## Adding a DNS Provider

1. Add `detect_dns_yourprovider()` in `lib/dns.sh`
2. Call it from `detect_dns_provider()`

## Logs & State

| Path | Purpose |
|------|---------|
| `/var/log/autossl/autossl.log` | Main log |
| `/etc/autossl/state/<domain>.conf` | Per-domain state |

## Requirements

- Linux (Debian/Ubuntu, RHEL, Arch, …)
- **Bash 4+** (pre-installed on all Linux servers)
- `certbot` or `acme.sh`
- `openssl`, `curl`, `socat`, `dig`
- Root/sudo access

## License

MIT
