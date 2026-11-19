# Admin-Interface härten

Der GoPhish-Admin (Port 3333) steuert Kampagnen und zeigt Ergebnisse. Er gehört
nicht offen ins Internet. Diese Schritte laufen über Coolify (Traefik), nicht im
Repo. Sie sind unabhängig von den Landing-Pages und können getrennt gesetzt werden.

## 1. HTTPS erzwingen

Der Admin darf nicht über reines HTTP erreichbar sein. Login und CSRF-Cookie
gehen sonst im Klartext über die Leitung.

In Coolify beim Service unter **Domains** die Admin-Domain von `http://…` auf
`https://…` setzen. Coolify legt dann ein Let's-Encrypt-Zertifikat an und leitet
HTTP auf HTTPS um.

**Wichtig: HTTPS schaltet den CSRF-Referer-Check scharf.** Hinter Traefik sieht
GoPhish den Header `X-Forwarded-Proto: https` und prüft bei jedem Login die
Herkunft. Fehlt der Admin-Host in `trusted_origins`, lehnt GoPhish jeden Login ab
mit `Forbidden - referer invalid`. Dann kommt niemand mehr rein.

Darum in `config/config.json` unter `admin_server` den Admin-Host eintragen:

```json
"trusted_origins": ["mgmt-1ogbol.app.spdigi.biz"]
```

Nur der Hostname, ohne Scheme und ohne Port. Ändert sich der Admin-Host, diesen
Eintrag mitändern, sonst ist der Login wieder tot.

## 2. Zugang auf bekannte IPs beschränken

Der Admin wird nur aus dem Büro oder per VPN bedient. Sperre alles andere mit
einer Traefik-IP-Allowlist. In Coolify als Custom-Label am Service:

```
traefik.http.middlewares.admin-allow.ipallowlist.sourcerange=<BÜRO-IP>/32
```

und die Middleware am Admin-Router anhängen (`…middlewares=admin-allow`).

Mehrere IPs mit Komma trennen. Steht Traefik hinter einem weiteren Proxy, statt
`sourcerange` die Variante mit `ipstrategy.depth` nutzen, sonst filtert die
Allowlist gegen die Proxy-IP.

## 3. Zusätzlich Basic-Auth

Als zweite Schicht neben der IP-Sperre. In Coolify beim Service unter
**Basic Auth** Benutzer und Passwort setzen (`is_http_basic_auth_enabled`).

## 4. Admin-Hostname ohne Produktname

Kein `gophish` im Hostnamen und möglichst nicht auf der Firmen-Domain, über die
auch die Produkte laufen. Ein geratener Name wie `gophish-admin.<firma>` verrät
Zweck und Betreiber. Ein neutraler, zufälliger Name reicht gegen Enumeration.

Besser noch: Admin gar nicht per DNS veröffentlichen, sondern nur per SSH-Tunnel
oder internem Netz erreichen.

## 5. Default-Favicon ersetzen

Das mitgelieferte GoPhish-Favicon ist ein Wiedererkennungsmerkmal. Hinter
IP-Sperre und Auth zweitrangig, bei öffentlichem Admin aber ein klares Signal.
`static/images/favicon.ico` durch ein neutrales Icon ersetzen.
