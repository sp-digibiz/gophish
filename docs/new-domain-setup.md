# New Domain Setup

Run this checklist every time a new client or campaign domain is onboarded.

## 1. Domain Registration

- [ ] Register the campaign domain (e.g., `{client}-portal.de`)
- [ ] Configure nameservers to point to your DNS provider
- [ ] Verify domain resolves: `dig NS {domain}`

## 2. Reverse DNS (PTR)

The PTR record on the sending IP **must** match `${SMTP_HOSTNAME}`.

- [ ] Set PTR record at your hosting provider (Hetzner Robot for dedicated servers — this is **not** configured in the DNS zone, it is set in the hosting provider's server management panel)
- [ ] Verify PTR:

```bash
dig -x {SERVER_IP} +short
# Expected: {SMTP_HOSTNAME}.
```

## 3. SPF

- [ ] Add TXT record to the domain's DNS zone:

```
{domain}.    IN    TXT    "v=spf1 ip4:{SERVER_IP} -all"
```

- [ ] Verify:

```bash
dig TXT {domain} +short
# Expected: "v=spf1 ip4:{SERVER_IP} -all"
```

## 4. DKIM

- [ ] Add the domain to `SMTP_DOMAINS` in `.env` (comma-separated, no spaces):

```
SMTP_DOMAINS=existing-domain.de,{domain}
```

- [ ] Restart the smtp container:

```bash
docker compose restart smtp
```

- [ ] Extract the DKIM public key — see [dkim-extraction.md](dkim-extraction.md)
- [ ] Add DNS TXT record at `default._domainkey.{domain}`:

```
default._domainkey.{domain}.    IN    TXT    "v=DKIM1; k=rsa; p={PUBLIC_KEY}"
```

- [ ] Verify:

```bash
dig TXT default._domainkey.{domain} +short
```

## 5. DMARC

Start with `p=none` to monitor without rejecting. Move to `p=quarantine` after verifying all emails pass alignment.

- [ ] Add TXT record at `_dmarc.{domain}`:

```
_dmarc.{domain}.    IN    TXT    "v=DMARC1; p=none; rua=mailto:dmarc-reports@{domain}"
```

- [ ] Verify:

```bash
dig TXT _dmarc.{domain} +short
```

## 6. Verification

- [ ] Send a test email to [mail-tester.com](https://www.mail-tester.com) — target score **>= 8/10**
- [ ] Send a test email to a Gmail account — check headers for:
  - `spf=pass`
  - `dkim=pass`
  - `dmarc=pass`
- [ ] Send a test email to an M365 mailbox — check `Authentication-Results` header for SPF/DKIM/DMARC PASS
- [ ] Confirm email lands in inbox (not spam/junk)

## 7. GoPhish Sending Profile

- [ ] Create sending profile in GoPhish Admin UI — see [sending-profile-setup.md](sending-profile-setup.md)
  - SMTP server: `smtp:587`
  - From address: `Sender Name <sender@{domain}>`
- [ ] Send test email from GoPhish and verify delivery
