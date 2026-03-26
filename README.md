# GoPhish -- Self-Hosted Phishing Simulation Stack

Self-hosted GoPhish with anti-fingerprinting mods + direct SMTP sending via postfix.

## Quick Start

```bash
git clone https://github.com/sp-digibiz/gophish.git
cd gophish
cp .env.example .env
# Edit .env with your values
docker compose up -d --build
```

Open the admin UI at `https://{your-domain}:3333`. The initial admin password is printed to the GoPhish container logs on first run -- retrieve it with `docker compose logs gophish | grep password`.

## Architecture

```
                Coolify / Traefik (TLS)
                    |              |
              :3333 admin    :8080 landing pages
                    |              |
                +---+--------------+---+
                |       GoPhish        |
                |  (anti-fingerprint)  |
                +----------+-----------+
                           | smtp:587
                +----------+-----------+
                |    boky/postfix      |
                |  auto-DKIM, port 25  |
                +----------------------+
```

- **GoPhish** is built from source with anti-fingerprinting patches applied at build time.
- **boky/postfix** handles outbound SMTP on port 25 with automatic DKIM key generation per domain.
- **Traefik** (via Coolify) terminates TLS for both the admin UI and landing pages.
- Container-to-container SMTP uses `smtp:587` (no auth required).

## Anti-Fingerprinting

Modifications applied during the Docker build:

- `X-Gophish-Contact` header renamed to `X-Contact`
- `X-Gophish-Signature` header renamed to `X-Signature`
- Server name `"gophish"` replaced with `"IGNORE"`
- Tracking parameter `rid` renamed to `cid` (configurable via `TRACKING_PARAM` build arg)
- Custom 404 page with no GoPhish fingerprint

## Configuration

Environment variables in `.env` (see `.env.example`):

| Variable | Description | Default |
|----------|-------------|---------|
| `GOPHISH_ADMIN_PASSWORD` | Initial admin password | -- (required) |
| `SMTP_HOSTNAME` | FQDN for the postfix container (used in HELO/EHLO and reverse DNS) | -- (required) |
| `SMTP_DOMAINS` | Comma-separated list of domains allowed to send (triggers DKIM key generation) | -- (required) |
| `GOPHISH_VERSION` | Git branch/tag to build GoPhish from | `master` |
| `TRACKING_PARAM` | URL parameter name for recipient tracking | `cid` |

## Data Persistence

SQLite database and DKIM keys are stored in Docker volumes:

| Volume | Purpose |
|--------|---------|
| `gophish-data` | GoPhish SQLite database |
| `smtp-dkim` | Auto-generated DKIM keys |
| `smtp-spool` | Postfix mail spool |

## Knowledge Base

See the [Knowledge Base](docs/README.md) for domain setup, campaign checklists, IP warming, and troubleshooting.

## First Campaign

Start with [New Domain Setup](docs/new-domain-setup.md) to onboard your first sending domain.

## License

See [LICENSE](LICENSE).
