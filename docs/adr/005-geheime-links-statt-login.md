# ADR-005 Geheime Links statt Login

- Status: angenommen
- Datum: 20.11.2026

## Kontext

Nur die Teamverantwortliche darf ihr Team pflegen, nur der Ticker darf Ereignisse erfassen, zuschauen darf jeder (T1, E3, L1). HTTP ist zustandslos, deshalb muss jeder einzelne Request zeigen, dass er etwas darf.

## Entscheidung

Rechte hängen an geheimen Links statt an Konten. Beim Anlegen eines Teams entsteht ein Team-Link, beim Anlegen eines Spiels ein Ticker-Link und ein Zuschauer-Link. Team- und Ticker-Link enthalten einen zufälligen Code (`Random.secure`, 16 Zeichen), den der Server beim Team bzw. Spiel speichert. Ändernde Requests (`POST`, `PUT`, `DELETE`) ohne passenden Code beantwortet der Server mit 403, lesen darf jeder.

So braucht niemand ein Konto oder Passwort: Die Teamverantwortliche schickt den Ticker-Link einfach an den Co-Trainer weiter.

Geht ein Team-Link verloren, gibt es keinen Admin, der ihn neu vergibt, weil das bei vielen Vereinen nicht skaliert. Stattdessen fordert das Team über seine hinterlegte E-Mail-Adresse einen neuen Team-Link an (T7, Kann). Der alte Link wird dabei ungültig.

## Verworfene Alternativen

- **Login mit Teamname und Passwort:** sicherer, aber mit Hash, Token und Login-Seite deutlich aufwendiger; bleibt als Kann-Story T3.
- **Ein Admin vergibt verlorene Links neu:** skaliert nicht.
- **Kein Schutz:** Jeder Zuschauer könnte Tore eintragen oder löschen.

## Konsequenzen

- Wer einen Link hat, hat die Rechte. Wird er weitergeleitet, gilt das auch für den Empfänger.
- Die Antwort auf „Team-Link vergessen?“ ist immer gleich, damit niemand herausfinden kann, welche Adressen angemeldet sind.
- Die E-Mail-Adresse wird nur für die Wiederherstellung gespeichert.
- Mails schreibt der Server zunächst in die Konsole; ein echter Mail-Dienst lässt sich später anschließen, ohne die Fachlogik zu ändern. Zugangsdaten dafür kommen nie ins Repo.
