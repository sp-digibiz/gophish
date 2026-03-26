# IP Warming Schedule

New or cold IPs must be warmed gradually before sending campaign volumes. Sending too many emails too fast from an unknown IP triggers spam filters and blacklists.

## Schedule

| Day | Daily Volume | Cumulative | Notes |
|-----|-------------|------------|-------|
| 1 | 50 | 50 | Monitor bounce rate |
| 2 | 100 | 150 | |
| 3 | 200 | 350 | |
| 4 | 350 | 700 | Check blacklists |
| 5 | 500 | 1,200 | |
| 8 | 750 | 2,700 | |
| 10 | 1,000 | 4,700 | |
| 14 | 2,000 | 12,700 | |
| 18+ | Full volume | — | Warming complete |

## Monitoring

Track these metrics throughout the warming period:

- **Bounce rate** — must stay below 5%. Hard bounces above 5% indicate a list quality problem or IP reputation issue.
- **Spam complaint rate** — must stay below 0.1%. Higher rates risk blacklisting.
- **Blacklist checks** — check [mxtoolbox.com/blacklists](https://mxtoolbox.com/blacklists.aspx) daily during warming. Also check [Spamhaus](https://check.spamhaus.org/).

## When to Pause

Stop sending immediately if any of these occur:

- Bounce rate exceeds 10%
- IP appears on any major blacklist (Spamhaus, Barracuda, Sorbs)
- Spam complaint spike (multiple complaints in a short window)
- Noticeable IP reputation drop (emails consistently landing in spam)

## After a Pause

- Resume at **50% of the last successful daily volume**
- Ramp back up following the schedule from that point
- Investigate and fix the root cause before resuming (bad list, content issues, blacklist)

## Tips

- **Send to engaged recipients first** — during warming, prioritize recipients who are likely to open (e.g., internal test accounts, known-good addresses)
- **Vary content** — sending identical content to many recipients looks like spam
- **Maintain consistent sending times** — pick a window and stick to it (e.g., business hours in the target timezone)
- **Space out emails** — use GoPhish's send-by-date feature to spread delivery over the day rather than blasting all at once
