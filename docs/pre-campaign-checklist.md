# Pre-Campaign Checklist

Run through this checklist before **every** campaign launch.

## Infrastructure

- [ ] DNS records pass — verify SPF, DKIM, DMARC with `dig`:
  ```bash
  dig TXT {domain} +short                        # SPF
  dig TXT default._domainkey.{domain} +short     # DKIM
  dig TXT _dmarc.{domain} +short                 # DMARC
  ```
- [ ] IP warmed for target volume — see [ip-warming.md](ip-warming.md)
- [ ] SMTP container healthy:
  ```bash
  docker compose logs smtp --tail 50
  ```
- [ ] Landing page accessible via HTTPS — open in browser, verify content loads
- [ ] No blacklist flags — check [mxtoolbox.com/blacklists](https://mxtoolbox.com/blacklists.aspx) for your sending IP

## Campaign Config

- [ ] Sending profile tested — send test email from GoPhish, confirm delivery to inbox
- [ ] Email template reviewed — no broken links, all images load, correct branding
- [ ] Tracking links working — click a test tracking link, verify GoPhish records the click event
- [ ] Landing page content matches the email pretext (consistent story)
- [ ] Target list imported and deduplicated (no duplicate email addresses)

## Operational

- [ ] Client sign-off obtained (written confirmation — email or ticket)
- [ ] Campaign schedule confirmed (date, time, timezone)
- [ ] Reporting contact identified (who receives results)
- [ ] Escalation plan documented — what to do if a real security incident is triggered during the simulation
