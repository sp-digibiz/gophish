# DKIM Key Extraction

The boky/postfix container auto-generates DKIM keys for each domain listed in `SMTP_DOMAINS`. After adding a new domain and restarting the container, extract the public key and add it to DNS.

## Steps

1. **Restart the SMTP container** (if not already restarted after adding the domain):

```bash
docker compose restart smtp
```

2. **List generated keys** to confirm the domain's key exists:

```bash
docker compose exec smtp ls /etc/opendkim/keys/
```

You should see a directory for each domain in `SMTP_DOMAINS`.

3. **Extract the public key** for the target domain:

```bash
docker compose exec smtp cat /etc/opendkim/keys/{domain}/default.txt
```

4. **Interpret the output**. It will look like:

```
default._domainkey	IN	TXT	( "v=DKIM1; h=sha256; k=rsa; "
	  "p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..." )
```

The value you need for DNS is everything inside the quotes, concatenated into one string:

```
v=DKIM1; h=sha256; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
```

5. **Create a DNS TXT record** at `default._domainkey.{domain}`:

```
default._domainkey.{domain}.    IN    TXT    "v=DKIM1; h=sha256; k=rsa; p={PUBLIC_KEY}"
```

Note: Some DNS providers have a character limit per TXT record. If the key is too long, split it into multiple quoted strings (most providers handle this automatically).

6. **Verify the DNS record** has propagated:

```bash
dig TXT default._domainkey.{domain} +short
```

The output should show the DKIM record with the public key.

7. **Verify DKIM signing** by sending a test email and checking the received email headers:
   - Look for a `DKIM-Signature` header in the raw email
   - Check that the `d=` value matches your domain
   - Check that `Authentication-Results` shows `dkim=pass`
