# Sending Profile Setup

How to create a GoPhish sending profile for a client domain.

## Steps

1. In the GoPhish Admin UI, navigate to **Sending Profiles** and click **New Profile**.

2. **Name**: Use the convention `{client} - {domain}` (e.g., `Acme Corp - acme-portal.de`).

3. **SMTP From**: `Sender Name <sender@{domain}>`
   - The sender name and address should match the campaign pretext.
   - Example: `IT-Abteilung <it-sicherheit@acme-portal.de>`

4. **Host**: `smtp:587`
   - This is the internal Docker network address of the boky/postfix container.

5. **Username**: Leave blank (no authentication needed for container-to-container traffic).

6. **Password**: Leave blank.

7. **Ignore Certificate Errors**: Check this box.
   - Internal traffic between GoPhish and the SMTP sidecar does not need TLS verification.

8. **Send Test Email**: Enter a test recipient address and send. Verify:
   - Email is delivered to inbox (not spam)
   - SPF, DKIM, DMARC all pass (check email headers)
   - From address displays correctly

9. **Custom Headers** (optional): Add headers to blend in with legitimate mail clients. Example:
   ```
   X-Mailer: Microsoft Outlook 16.0
   ```

10. Click **Save Profile**.

## Envelope Sender vs. From Header

For DMARC alignment to pass, the envelope sender (MAIL FROM / Return-Path) and the From header must share the same domain.

- GoPhish uses the **SMTP From** field for both the envelope sender and the From header by default.
- If you set a custom envelope sender that differs from the From header domain, DMARC alignment will fail even if SPF and DKIM individually pass.
- Keep both on the same domain to ensure alignment.

## Multiple Domains

Create a **separate sending profile per domain**. Each campaign selects one sending profile, and the profile's From address determines which domain's SPF/DKIM/DMARC are checked by the recipient's mail server.
