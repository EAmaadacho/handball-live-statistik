# ADR-004 Laufende Spiele als JSON-Datei, beendete Spiele in SQLite

- Status: angenommen
- Datum: 20.11.2026

## Kontext

Teams, Kader, Spiele und Ereignisse müssen einen Neustart des Servers überleben. Laufende Spiele ändern sich alle paar Sekunden, beendete Spiele gar nicht mehr, sollen aber auch später noch abrufbar sein. Die App soll sich ohne Installation einer Datenbank starten lassen.

## Entscheidung

Wir trennen Live-Daten vom Archiv. Laufende Spiele liegen als Dart-Objekte im Arbeitsspeicher und werden nach jeder Änderung als eigene JSON-Datei zwischengespeichert. Ist ein Spiel beendet, wird es in eine SQLite-Datenbank geschrieben, damit man es später wieder öffnen und auswerten kann.

| Pfad | Inhalt |
|---|---|
| `data/teams.json` | Teams mit Kader und Logo-Dateiname |
| `data/games/<id>.json` | laufendes Spiel mit Kader-Kopie, Uhr und Ereignissen |
| `data/logos/` | Logos als PNG oder JPG ([T6](../user-stories.md#t6)) |
| `data/archive.db` | beendete Spiele (Tabellen `games`, `players`, `events`) |

Beim Spielende schreibt der Server das Spiel in einer Transaktion in die Datenbank und löscht erst danach die JSON-Datei. Findet er beim Start ein beendetes Spiel als Datei, holt er diesen Schritt nach. JSON-Dateien werden über `<name>.tmp` und Umbenennen geschrieben, damit nie eine halbe Datei entsteht. Die Repositories in `storage/` übernehmen das, die Fachlogik weiß davon nichts.

## Verworfene Alternativen

- **Nur Arbeitsspeicher:** Nach jedem Neustart wären alle Daten weg.
- **Eine einzige JSON-Datei für alles:** wird mit jedem Spiel größer und bei jeder Änderung komplett neu geschrieben.
- **Alles in JSON-Dateien:** Alte Spiele lassen sich nur mit Schleifen über alle Dateien auswerten, nicht per SQL.
- **Alles in SQLite:** Jede Änderung im laufenden Spiel ginge direkt in die Datenbank, der schnelle Zwischenspeicher fehlt.
- **PostgreSQL/MongoDB:** müssten installiert und gestartet werden.

## Konsequenzen

- Das Paket `sqlite3` bringt SQLite selbst mit, es ist nichts zu installieren.
- Zwei Speicherarten, also zwei Repositories mit eigenen Tests.
- Alte Spiele liegen nicht im Arbeitsspeicher, sondern werden bei Bedarf aus der Datenbank gelesen.
- Saisonstatistiken ([T5](../user-stories.md#t5)) lassen sich per SQL abfragen.
- Es darf nur ein Server gleichzeitig laufen.
- `data/` kommt in `.gitignore`, damit keine Testdaten ins Repo geraten.
