# Eigene IP für die Phishing-Infrastruktur

## Problem

Laufen die Landing-Pages und der SMTP-Versand auf demselben Server wie die
echten Produkte, teilen sich Köder-Domains und Produkt-Domains eine IP. Ein
Reverse-Lookup auf diese IP listet dann die komplette Firmen-Flotte neben den
Köder-Domains. Das verknüpft die Firma öffentlich mit der Phishing-Infrastruktur.

Blocklisten und Filter bewerten Domains, die eine IP teilen, gemeinsam. Wird eine
Köder-Domain gesperrt, trifft die Sperre über die geteilte IP auch die Produkte.

## Lösung

Phishing-Stack auf einen eigenen, kleinen Server mit eigener IP legen. Dort läuft
nur GoPhish plus der Postfix-Versand. Nichts von der Firma zeigt auf diese IP.

- Eigener Hetzner-/Cloud-Server, getrennt vom App-Cluster.
- Eigene IP, eigenes PTR (Reverse-DNS) passend zum SMTP-Hostnamen.
- Köder-Domains und Admin-Hostname zeigen nur auf diese IP.
- Kein Wildcard-Record der Firmen-Domain auf diese IP.

## Umzug ohne Datenverlust

Die SQLite-Datenbank und die DKIM-Schlüssel liegen in Docker-Volumes
(`gophish-data`, `smtp-dkim`). Für den Umzug die Volumes sichern und auf dem
neuen Server einspielen. Ergebnisse und Schlüssel bleiben erhalten.

## Wichtig: nicht während einer laufenden Kampagne

Ein Wechsel der IP oder der Köder-Domain bricht bereits versendete Links. Umzug
nur zwischen Kampagnen planen.
