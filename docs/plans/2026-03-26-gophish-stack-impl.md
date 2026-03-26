# GoPhish Stack Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace CISA fork scaffolding with a clean GoPhish + SMTP stack and operational knowledge base.

**Architecture:** Multi-stage Docker build of GoPhish from source with anti-fingerprinting mods, boky/postfix sidecar for direct sending with auto-DKIM, deployed via Coolify with Traefik TLS termination.

**Tech Stack:** Docker multi-stage (Node 20 + Go 1.22 + Debian slim), boky/postfix, GoPhish source, Markdown knowledge base.

**Design doc:** `docs/plans/2026-03-26-gophish-stack-design.md`

---

### Task 1: Clean up CISA files

**Files:**
- Delete: `compose.yml`, `Dockerfile`, `bin/`, `src/`, `tests/`, `setup-env`, `bump-version`, `tag.sh`, `trivy.yml`, `pytest.ini`, `requirements.txt`, `requirements-dev.txt`, `requirements-test.txt`, `CONTRIBUTING.md`, `.ansible-lint`, `.bandit.yml`, `.flake8`, `.isort.cfg`, `.pre-commit-config.yaml`, `.mdl_config.yaml`, `.yamllint`, `.prettierignore`, `docker-compose.yml` (the placeholder from earlier)
- Keep: `LICENSE`, `.git/`, `.github/`, `.gitignore`, `docs/`, `README.md` (will be overwritten in task 7)

**Step 1: Delete all CISA-specific files**

```bash
cd /tmp/gophish
rm -f compose.yml Dockerfile docker-compose.yml bump-version tag.sh setup-env trivy.yml pytest.ini
rm -f requirements.txt requirements-dev.txt requirements-test.txt CONTRIBUTING.md
rm -f .ansible-lint .bandit.yml .flake8 .isort.cfg .pre-commit-config.yaml .mdl_config.yaml .yamllint .prettierignore
rm -rf bin/ src/ tests/
```

**Step 2: Update .gitignore**

Replace contents with:

```
.env
*.db
```

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove CISA fork scaffolding, start clean"
```

---

### Task 2: Create config files

**Files:**
- Create: `config/config.json`
- Create: `config/404.html`
- Create: `.env.example`

**Step 1: Create config/config.json**

```json
{
  "admin_server": {
    "listen_url": "0.0.0.0:3333",
    "use_tls": false
  },
  "phish_server": {
    "listen_url": "0.0.0.0:8080",
    "use_tls": false
  },
  "db_name": "sqlite3",
  "db_path": "/opt/gophish/data/gophish.db",
  "migrations_prefix": "db/db_",
  "contact_address": ""
}
```

**Step 2: Create config/404.html**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>404 - Page Not Found</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; background: #f5f5f5; color: #333; }
        .container { text-align: center; }
        h1 { font-size: 72px; margin: 0; color: #999; }
        p { font-size: 18px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <h1>404</h1>
        <p>The page you requested could not be found.</p>
    </div>
</body>
</html>
```

**Step 3: Create .env.example**

```env
# GoPhish Admin
GOPHISH_ADMIN_PASSWORD=ChangeMe123!

# SMTP - Direct Sending
SMTP_HOSTNAME=mail.example.com
SMTP_DOMAINS=client1-portal.de,client2-secure.com

# Build overrides (optional)
# GOPHISH_VERSION=master
# TRACKING_PARAM=cid
```

**Step 4: Commit**

```bash
git add config/ .env.example
git commit -m "feat: add GoPhish config, custom 404, and env template"
```

---

### Task 3: Create Dockerfile

**Files:**
- Create: `Dockerfile`

**Step 1: Write the Dockerfile**

```dockerfile
# Stage 1: Minify client-side assets
FROM node:20-slim AS build-js

ARG GOPHISH_VERSION=master

RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git clone --depth 1 --branch ${GOPHISH_VERSION} https://github.com/gophish/gophish.git . \
    || (git clone https://github.com/gophish/gophish.git . && git checkout ${GOPHISH_VERSION})

RUN npm install --only=dev && npx gulp


# Stage 2: Build Go binary with anti-fingerprinting mods
FROM golang:1.22 AS build-go

ARG TRACKING_PARAM=cid

WORKDIR /go/src/github.com/gophish/gophish
COPY --from=build-js /build/ ./

# Anti-fingerprinting: strip GoPhish email headers
RUN sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request_test.go \
    && sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog.go \
    && sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog_test.go \
    && sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request.go

# Anti-fingerprinting: strip GoPhish webhook signature header
RUN sed -i 's/X-Gophish-Signature/X-Signature/g' webhook/webhook.go

# Anti-fingerprinting: change server name from "gophish" to "IGNORE"
RUN sed -i 's/const ServerName = "gophish"/const ServerName = "IGNORE"/' config/config.go

# Anti-fingerprinting: rename tracking parameter from "rid" to custom value
RUN sed -i "s/const RecipientParameter = \"rid\"/const RecipientParameter = \"${TRACKING_PARAM}\"/g" models/campaign.go

# Custom 404 page (overwrite default)
COPY config/404.html templates/404.html

RUN go build -v -o gophish


# Stage 3: Minimal runtime
FROM debian:bookworm-slim

ARG UID=1000
ARG GID=1000

RUN groupadd -g ${GID} gophish \
    && useradd -m -d /opt/gophish -s /bin/bash -u ${UID} -g ${GID} gophish

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libsqlite3-0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/gophish

# Copy binary and assets from build stages
COPY --from=build-go --chown=gophish:gophish /go/src/github.com/gophish/gophish/gophish ./
COPY --from=build-go --chown=gophish:gophish /go/src/github.com/gophish/gophish/db/ ./db/
COPY --from=build-js --chown=gophish:gophish /build/static/js/dist/ ./static/js/dist/
COPY --from=build-js --chown=gophish:gophish /build/static/css/dist/ ./static/css/dist/
COPY --from=build-go --chown=gophish:gophish /go/src/github.com/gophish/gophish/static/images/ ./static/images/
COPY --from=build-go --chown=gophish:gophish /go/src/github.com/gophish/gophish/static/font/ ./static/font/
COPY --from=build-go --chown=gophish:gophish /go/src/github.com/gophish/gophish/static/favicon.ico ./static/favicon.ico
COPY --from=build-go --chown=gophish:gophish /go/src/github.com/gophish/gophish/templates/ ./templates/

# Copy config
COPY --chown=gophish:gophish config/config.json ./config.json

# Persistent data directory for SQLite
RUN mkdir -p /opt/gophish/data && chown gophish:gophish /opt/gophish/data
VOLUME /opt/gophish/data

USER gophish

EXPOSE 3333 8080

ENTRYPOINT ["./gophish"]
```

**Step 2: Verify Dockerfile syntax**

```bash
docker build --check . 2>&1 || echo "No --check support, will validate on build"
```

**Step 3: Commit**

```bash
git add Dockerfile
git commit -m "feat: multi-stage Dockerfile with anti-fingerprinting mods"
```

---

### Task 4: Create docker-compose.yml

**Files:**
- Create: `docker-compose.yml`

**Step 1: Write docker-compose.yml**

```yaml
services:
  gophish:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        - GOPHISH_VERSION=${GOPHISH_VERSION:-master}
        - TRACKING_PARAM=${TRACKING_PARAM:-cid}
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

**Step 2: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: docker-compose with GoPhish + postfix SMTP sidecar"
```

---

### Task 5: Write knowledge base docs

**Files:**
- Create: `docs/README.md`
- Create: `docs/new-domain-setup.md`
- Create: `docs/pre-campaign-checklist.md`
- Create: `docs/ip-warming.md`
- Create: `docs/sending-profile-setup.md`
- Create: `docs/dkim-extraction.md`
- Create: `docs/troubleshooting.md`

**Step 1: Write docs/README.md**

```markdown
# GoPhish Knowledge Base

Operational runbooks for phishing awareness campaigns.

## Guides

| Document | When to use |
|----------|-------------|
| [New Domain Setup](new-domain-setup.md) | Onboarding a new client or campaign domain |
| [DKIM Key Extraction](dkim-extraction.md) | After adding a domain, extract public key for DNS |
| [Sending Profile Setup](sending-profile-setup.md) | Configuring GoPhish to send via the SMTP sidecar |
| [IP Warming](ip-warming.md) | Before first campaign on a new IP |
| [Pre-Campaign Checklist](pre-campaign-checklist.md) | Before launching any campaign |
| [Troubleshooting](troubleshooting.md) | Emails not delivering, landing in spam, etc. |

## Architecture

See [plans/2026-03-26-gophish-stack-design.md](plans/2026-03-26-gophish-stack-design.md) for the full design document.

## Quick Reference

- **GoPhish Admin UI:** https://{admin-domain}:3333
- **Landing Pages:** https://{phish-domain}:8080
- **SMTP (internal):** `smtp:587` (no auth, container-to-container)
- **SMTP (outbound):** Port 25 direct to internet
```

**Step 2: Write docs/new-domain-setup.md**

Content: step-by-step checklist with DNS record templates for PTR, SPF (`v=spf1 ip4:{IP} -all`), DKIM (link to extraction doc), DMARC (`v=DMARC1; p=none; rua=mailto:...`), verification steps (mail-tester.com, header checks), and GoPhish sending profile creation. Each step is a `- [ ]` checkbox.

**Step 3: Write docs/pre-campaign-checklist.md**

Content: pre-launch checklist covering infrastructure (DNS passes, IP warmed, SMTP healthy), campaign config (sending profile tested, landing page accessible via HTTPS, tracking links working, email template reviewed), and operational (client sign-off, target list imported, schedule confirmed, reporting contact set).

**Step 4: Write docs/ip-warming.md**

Content: day-by-day schedule table (Day 1: 50, Day 2: 100, Day 3: 200, Day 4: 350, Day 5: 500, Day 8: 750, Day 10: 1000, Day 14: 2000, Day 18+: full volume). Monitoring guidance: watch bounce rate (<5%), spam complaints (<0.1%), check blacklists. When to pause: bounce rate >10%, blacklisted, complaint spike.

**Step 5: Write docs/sending-profile-setup.md**

Content: GoPhish sending profile walkthrough — SMTP server: `smtp:587`, no auth, from address per client domain, envelope sender config, test email procedure.

**Step 6: Write docs/dkim-extraction.md**

Content: how to exec into smtp container or read from volume, find the auto-generated key per domain at `/etc/opendkim/keys/{domain}/default.txt`, format for DNS TXT record `default._domainkey.{domain}`, verify with `dig TXT default._domainkey.{domain}`.

**Step 7: Write docs/troubleshooting.md**

Content: table of symptoms → likely cause → fix. Covers: emails in spam (check SPF/DKIM/DMARC alignment), emails bouncing (check PTR, check recipient MX), emails not sending (check postfix logs, check SMTP_DOMAINS), landing page not loading (check Traefik routing, check port 8080), GoPhish fingerprinted (check X-Gophish headers stripped, check rid param changed, check 404 page).

**Step 8: Commit**

```bash
git add docs/
git commit -m "docs: add operational knowledge base (7 runbooks)"
```

---

### Task 6: Write root README.md

**Files:**
- Overwrite: `README.md`

**Step 1: Write README.md**

Content:
- One-line description: "Self-hosted phishing simulation stack — GoPhish with anti-fingerprinting + direct SMTP sending"
- Quick start: clone, copy `.env.example` to `.env`, fill in values, `docker compose up -d --build`
- Architecture diagram (ASCII from design doc)
- Link to `docs/` knowledge base
- Link to `docs/new-domain-setup.md` as first step after deploy
- Anti-fingerprinting section listing what's modified
- Credits/license

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with quick start and architecture overview"
```

---

### Task 7: Push to sp-digibiz/gophish

**Step 1: Push develop branch**

```bash
git push origin develop
```

**Step 2: Verify on GitHub**

```bash
gh repo view sp-digibiz/gophish --web
```
