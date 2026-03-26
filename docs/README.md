# GoPhish Knowledge Base

Operational runbooks for phishing awareness campaigns.

## Guides

| Document | When to use |
|----------|-------------|
| [New Domain Setup](new-domain-setup.md) | Onboarding a new client or campaign domain |
| [DKIM Key Extraction](dkim-extraction.md) | After adding a domain, extract public key for DNS |
| [Sending Profile Setup](sending-profile-setup.md) | Configuring GoPhish to send via the SMTP sidecar |
| [IP Warming](ip-warming.md) | Before first campaign on a new or cold IP |
| [Pre-Campaign Checklist](pre-campaign-checklist.md) | Before launching any campaign |
| [Troubleshooting](troubleshooting.md) | Emails not delivering, landing in spam, bounces, etc. |

## Quick Reference

| Resource | Address |
|----------|---------|
| GoPhish Admin UI | `https://{admin-domain}:3333` |
| Landing Pages | `https://{phish-domain}:8080` |
| SMTP (internal) | `smtp:587` (no auth, container-to-container) |
| SMTP (outbound) | Port 25 direct to internet |

## Architecture

See [plans/2026-03-26-gophish-stack-design.md](plans/2026-03-26-gophish-stack-design.md) for the full design document.
