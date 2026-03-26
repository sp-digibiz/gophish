# GoPhish Stack Design — sp-digibiz/gophish

**Date:** 2026-03-26
**Status:** Approved
**Repo:** https://github.com/sp-digibiz/gophish

## Context

We run phishing awareness campaigns internally and as a service for clients. The existing Coolify setup had a stopped `gophish/gophish:latest` container with separate SMTP/Mailhog services. This redesign encapsulates everything into a single deployable stack with a knowledge base for repeatable multi-client operations.

### Requirements

- Self-hosted on Coolify (single server, Traefik reverse proxy)
- Direct email sending via port 25 (Spamhaus whitelisted, port open)
- Multi-tenant: one GoPhish installation, multiple client domains
- Anti-fingerprinting: strip GoPhish indicators from emails and HTTP responses
- Knowledge base: repeatable runbooks for domain setup, campaign launch, troubleshooting

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │           Coolify / Traefik          │
                    │         (TLS termination)            │
                    └──────┬──────────────┬───────────────┘
                           │              │
                     :3333 admin    :8080 landing pages
                           │              │
                    ┌──────┴──────────────┴───────────────┐
                    │            GoPhish                    │
                    │  (built from source, anti-fingerprint)│
                    │  SQLite DB in /opt/gophish/data       │
                    └──────────────┬───────────────────────┘
                                   │ smtp:587 (internal)
                    ┌──────────────┴───────────────────────┐
                    │         boky/postfix                   │
                    │  Direct sending, auto-DKIM per domain  │
                    │  Host port 25 → container 587          │
                    └──────────────────────────────────────┘
                                   │
                              Port 25 → Internet
```

## Dockerfile

Multi-stage build from GoPhish source with anti-fingerprinting mods.

### Stage 1: Node (JS minification)
- Clone `gophish/gophish` at `${GOPHISH_VERSION}` (default: `master`)
- Install npm deps, run gulp to minify JS/CSS

### Stage 2: Go (compile with mods)
- Copy minified assets from stage 1
- Apply anti-fingerprinting via `sed`:
  - `X-Gophish-Contact` → `X-Contact`
  - `X-Gophish-Signature` → `X-Signature`
  - `ServerName "gophish"` → `"IGNORE"`
  - `RecipientParameter "rid"` → `"${TRACKING_PARAM}"` (default: `cid`)
- Copy custom `404.html` into templates
- `go build`

### Stage 3: Runtime (debian-slim)
- Unprivileged user
- Copy binary + static assets + config
- Expose 3333 (admin) + 8080 (phish)
- Volume mount point at `/opt/gophish/data` for SQLite persistence

### Build args
| Arg | Default | Purpose |
|-----|---------|---------|
| `GOPHISH_VERSION` | `master` | GoPhish git ref to build |
| `TRACKING_PARAM` | `cid` | URL tracking parameter name |

## Docker Compose

```yaml
services:
  gophish:
    build: .
    volumes:
      - gophish-data:/opt/gophish/data
    ports:
      - '3333:3333'
      - '8080:8080'
    depends_on:
      - smtp
    restart: unless-stopped

  smtp:
    image: boky/postfix:latest
    ports:
      - '25:587'
    volumes:
      - smtp-dkim:/etc/opendkim/keys
      - smtp-spool:/var/spool/postfix
    environment:
      - ALLOWED_SENDER_DOMAINS=${SMTP_DOMAINS}
      - HOSTNAME=${SMTP_HOSTNAME}
      - DKIM_AUTOGENERATE=1
      - POSTFIX_myhostname=${SMTP_HOSTNAME}
      - POSTFIX_message_size_limit=20480000
      - POSTFIX_smtp_tls_security_level=may
      - POSTFIX_smtp_tls_note_starttls_offer=yes
    restart: unless-stopped

volumes:
  gophish-data:
  smtp-dkim:
  smtp-spool:
```

### Key decisions
- **No SMTP relay** — direct sending, we own the IP and have Spamhaus whitelist
- **DKIM auto-generated** per domain in `SMTP_DOMAINS`
- **GoPhish Sending Profile** → `smtp:587` on internal Docker network (no auth needed)
- **Traefik** handles TLS for admin UI and landing pages
- **Single postfix, multiple domains** — GoPhish switches via sending profiles per client

## Config Files

### `config/config.json`
- No TLS (Traefik terminates)
- SQLite at `/opt/gophish/data/gophish.db`
- Listen on `0.0.0.0` for both admin (3333) and phish (8080)

### `config/404.html`
- Generic "404 Page Not Found" — no GoPhish fingerprint
- Intentionally bland; customize per engagement if needed

### `.env.example`
- `GOPHISH_ADMIN_PASSWORD` — initial admin password
- `SMTP_HOSTNAME` — must match PTR record
- `SMTP_DOMAINS` — comma-separated list of all sending domains

## Knowledge Base (`docs/`)

| File | Purpose |
|------|---------|
| `docs/README.md` | Index with links to all docs |
| `docs/new-domain-setup.md` | Per-client runbook: domain → DNS (PTR/SPF/DKIM/DMARC) → verify → GoPhish profile. Copyable checklist format. |
| `docs/pre-campaign-checklist.md` | Launch checklist: DNS verified, IP warmed, sending profile tested, landing page working, tracking tested, client sign-off |
| `docs/ip-warming.md` | Day-by-day volume ramp schedule (50→100→250→500→1000+), monitoring, when to pause |
| `docs/sending-profile-setup.md` | GoPhish SMTP config: creating profiles, per-domain from-address, envelope sender |
| `docs/dkim-extraction.md` | Extracting auto-generated DKIM public keys from smtp-dkim volume, DNS TXT record format |
| `docs/troubleshooting.md` | Common issues: spam folder (SPF/DKIM/DMARC), bounces (PTR), blocked (Spamhaus), fingerprinting detected |

### Core runbook: `new-domain-setup.md`

Template with checkbox format covering:
1. Domain registration
2. Reverse DNS (PTR) — must match `SMTP_HOSTNAME`
3. SPF — `v=spf1 ip4:{SERVER_IP} -all`
4. DKIM — add domain to env, restart, extract key, add DNS record, verify
5. DMARC — `v=DMARC1; p=none; rua=mailto:dmarc@{domain}`
6. Verification — mail-tester.com score ≥ 8/10, check Gmail/M365 headers
7. GoPhish — create sending profile, send test email

## Repo Structure (final)

```
sp-digibiz/gophish/
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── config/
│   ├── config.json
│   └── 404.html
├── docs/
│   ├── README.md
│   ├── new-domain-setup.md
│   ├── pre-campaign-checklist.md
│   ├── ip-warming.md
│   ├── sending-profile-setup.md
│   ├── dkim-extraction.md
│   └── troubleshooting.md
├── docs/plans/
│   └── 2026-03-26-gophish-stack-design.md  (this file)
├── LICENSE
└── README.md
```

## What gets deleted from CISA fork

All CISA-specific files: `compose.yml` (their version), original `Dockerfile`, `bin/`, `src/`, `tests/`, `setup-env`, `bump-version`, `tag.sh`, `trivy.yml`, `pytest.ini`, `requirements*.txt`, `CONTRIBUTING.md`, Python/Ansible lint configs (`.ansible-lint`, `.bandit.yml`, `.flake8`, `.isort.cfg`), `.pre-commit-config.yaml`, `.mdl_config.yaml`, `.yamllint`, `.prettierignore`.

Keep: `LICENSE`, `.git` (fork history), `.github/` (clean up later).
