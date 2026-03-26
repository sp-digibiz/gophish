# Troubleshooting

Common issues and how to fix them.

## Quick Diagnosis

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Emails land in spam | SPF/DKIM/DMARC not aligned or failing | Check all three records with `dig`. Send to [mail-tester.com](https://www.mail-tester.com) — target score >= 8/10. Fix any failing records per [new-domain-setup.md](new-domain-setup.md). |
| Emails bounce (5xx) | PTR record does not match `SMTP_HOSTNAME`, or recipient MX does not exist | Verify PTR: `dig -x {SERVER_IP} +short` must return `{SMTP_HOSTNAME}`. Verify recipient domain has MX: `dig MX recipient-domain.com`. |
| Emails not sending | SMTP container down, or sender domain not in `SMTP_DOMAINS` | Check logs: `docker compose logs smtp --tail 100`. Verify `SMTP_DOMAINS` in `.env` includes the sender domain. Restart: `docker compose restart smtp`. |
| Landing page not loading | Traefik routing misconfigured, or port 8080 not exposed | Check Coolify service config — verify the phish server domain routes to port 8080. Check `docker compose ps` to confirm the gophish container is running and port 8080 is mapped. |
| GoPhish detected/blocked | Default GoPhish fingerprints not stripped | Check email headers for `X-Gophish-Contact` or `X-Gophish-Signature` — if present, the Dockerfile anti-fingerprinting mods were not applied (rebuild). Check tracking URLs for `rid=` parameter — should be `cid=` or your custom `TRACKING_PARAM`. Visit a non-existent path on the phish server — should show the custom 404, not the default GoPhish page. |
| DKIM failing | Key mismatch between container and DNS, or DNS not propagated | Re-extract the key from the container (see [dkim-extraction.md](dkim-extraction.md)) and compare with the DNS record. Wait for propagation and verify: `dig TXT default._domainkey.{domain} +short`. |
| High bounce rate | IP not warmed, sending too fast, or bad recipient list | Follow the [ip-warming.md](ip-warming.md) schedule. Clean the recipient list — remove invalid/inactive addresses. Use GoPhish's send-by-date to throttle delivery. |
| IP blacklisted | Sending too fast, high bounce/complaint rate | Check [mxtoolbox.com/blacklists](https://mxtoolbox.com/blacklists.aspx). Request delisting from the specific blacklist. Pause all sending. Review and fix the root cause (warming, list quality, content). Resume at reduced volume per [ip-warming.md](ip-warming.md). |

## Useful Commands

**Check SMTP container logs:**
```bash
docker compose logs smtp --tail 100
```

**Check GoPhish container logs:**
```bash
docker compose logs gophish --tail 100
```

**Verify all DNS records for a domain:**
```bash
dig TXT {domain} +short                         # SPF
dig TXT default._domainkey.{domain} +short      # DKIM
dig TXT _dmarc.{domain} +short                  # DMARC
dig -x {SERVER_IP} +short                        # PTR
```

**Check if a port is reachable:**
```bash
nc -zv {SERVER_IP} 25     # SMTP outbound
nc -zv {SERVER_IP} 8080   # Landing pages
nc -zv {SERVER_IP} 3333   # Admin UI
```

**Restart the full stack:**
```bash
docker compose restart
```

**Rebuild GoPhish (after Dockerfile changes):**
```bash
docker compose up -d --build gophish
```
