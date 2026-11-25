# Handball-Live-Statistik

Die Handball-Live-Statistik ist eine Web-App für Amateur-Handballmannschaften. Am Spielfeldrand erfasst ein Ticker im Browser Tore, Paraden, Strafen und Auszeiten, Teams und Fans sehen Spielstand und Statistik live. Ein Beispiel: Max (Nr. 7, TV Mettmann) wirft in der 23. Minute das 12:11 gegen die HSG Hilden, eine Sekunde später zeigen alle Zuschauer-Seiten den neuen Stand und Max' Wurfquote. Gebaut ist sie mit Flutter Web, einem Dart-Server mit shelf und einer REST-API nach OpenAPI.

KI-Einsatz bei der Entwicklung: [AI Engineering Journal](docs/ai-engineering-journal.md).

## Ziel und Motivation

Amateurmannschaften haben meist nicht die Mittel, ihre Spiele professionell zu begleiten. Liveticker wie der von nuLiga (dem Portal, über das die Handballverbände Spielpläne und Ergebnisse veröffentlichen) gibt es nicht für jedes Spiel, oder sie fallen wegen technischer Probleme aus. Eine Statistik pro Spieler fehlt fast immer. Die App soll Amateurmannschaften eine moderne Darstellung ihrer Spiele und Statistiken bieten, für die Teams selbst und für interessierte Fans.

Mein persönliches Ziel war, ein Projekt strukturiert in Phasen umzusetzen: erst die Anforderungen, dann eine durchdachte Architektur und danach die technische Umsetzung Schritt für Schritt.

## Vorgehen

Das Projekt lief bewusst in Phasen mit Feedbackschleifen. Erst wenn eine Phase klar war, ging es an die nächste.

1. **Einrichtung:** Repository aus der Kursvorlage, CI in GitHub Actions.
2. **Anforderungen:** User Stories mit Akzeptanzkriterien, aufgeteilt in Muss und Kann.
3. **Architektur:** sechs Entscheidungen als ADRs, jeweils mit verworfenen Alternativen.
4. **Prototyp:** Entwurf der Oberfläche als klickbarer Prototyp, bevor die Flutter-Seiten entstanden.
5. **Umsetzung Story für Story:** Pseudocode für die Fachlogik, danach Dart-Code mit Unit-Tests, dann REST-API und Oberfläche, zuletzt Akzeptanztests.
6. **Dokumentation:** README, AI Engineering Journal und Referat.

## Handball in Kürze

Für das Verständnis der Anforderungen reichen wenige Begriffe:

- Ein Spiel dauert 2 × 30 Minuten, pro Team stehen 6 Feldspieler und 1 Torwart auf dem Feld.
- **Parade:** Der Torwart hält einen Wurf.
- **Zeitstrafe (2 Minuten):** Der Spieler muss vom Feld, sein Team spielt 2 Minuten mit einem Spieler weniger (Unterzahl). Nach der dritten Zeitstrafe ist er disqualifiziert (Rote Karte).
- **Auszeit:** Ein Team hält das Spiel für eine Minute an, höchstens dreimal pro Spiel.
- **Spielbericht:** Liste der bis zu 16 Spieler, die in diesem Spiel eingesetzt werden dürfen.

## Anforderungen

Die Anforderungen stehen als User Stories mit Akzeptanzkriterien in [docs/user-stories.md](docs/user-stories.md). Jede Story hat eine Kennung, jedes Kriterium eine Unterkennung (z. B. `E1.2`). Sie sind in **Muss** (Kern der App) und **Kann** (Erweiterungen) geteilt.

| Block | Inhalt |
|---|---|
| T – Teams und Kader | Team mit Kader vorab anlegen, geheimer Team-Link |
| S – Spiel anlegen | Gegner, Spielbericht (max. 16 Spieler), Ticker- und Zuschauer-Link |
| E – Ereignisse erfassen | Tor, Parade, Fehlwurf, Strafen, Auszeit, Wechsel; jedes Ereignis gehört zu einem Spieler |
| U – Spieluhr | Start, Stopp, Korrektur, Halbzeit, Spielende wie an einer Hallenuhr |
| L – Live ansehen | Spielstand, Uhr, Verlauf und Spielerstatistik ohne Neuladen |
| R – Handballregeln | z. B. höchstens drei Auszeiten (R1), Rote Karte nach der dritten Zeitstrafe (R3) |

Es gibt bewusst keinen Login: Wer den passenden geheimen Link hat, darf die zugehörige Aktion ausführen ([ADR-005](docs/adr/005-geheime-links-statt-login.md)).

## Technische Mittel

| Bereich | Technik |
|---|---|
| Client | Flutter Web (Dart), go_router für Adressen wie `/spiel/17/live`, provider |
| Server | Dart mit shelf und shelf_router |
| Schnittstelle | REST, beschrieben in [api.yaml](api.yaml) (OpenAPI 3); Client- und Server-Modelle erzeugt der OpenAPI Generator |
| Speicherung | JSON-Dateien für Teams und laufende Spiele (`data/teams.json`, `data/games/<id>.json`), beendete Spiele in SQLite (`data/archive.db`), Vereinslogos als Dateien (`data/logos/`) ([ADR-004](docs/adr/004-json-dateien-und-sqlite-archiv.md)) |
| Tests | package:test (Server), flutter_test und mockito (Client) |
| CI/CD | GitHub Actions, Demo auf GitHub Pages |

Grundlage ist die Kursvorlage des Moduls ([ADR-001](docs/adr/001-kursvorlage-als-basis.md)). Der ChatGPT-Teil der Vorlage ist entfernt, die App nutzt keine KI.

## Architektur

```
Browser (Flutter Web)  ──HTTP/JSON──>  Dart-Server (shelf)
  Ticker-Seite                          api/      Handler, prüfen Links, übersetzen JSON
  Live-Seite (fragt jede Sekunde)       domain/   Fachlogik und Handballregeln
                                        storage/  JSON-Dateien, SQLite-Archiv, Logos
```

Die Architekturentscheidungen stehen als ADRs in [docs/adr/](docs/adr/):

| ADR | Entscheidung |
|---|---|
| [001](docs/adr/001-kursvorlage-als-basis.md) | Kursvorlage als Basis |
| [002](docs/adr/002-polling-statt-websocket.md) | Polling jede Sekunde statt WebSocket |
| [003](docs/adr/003-spieluhr-auf-dem-server.md) | Spieluhr läuft auf dem Server |
| [004](docs/adr/004-json-dateien-und-sqlite-archiv.md) | JSON-Datei pro Spiel, beendete Spiele in SQLite |
| [005](docs/adr/005-geheime-links-statt-login.md) | Geheime Links statt Login |
| [006](docs/adr/006-spielstand-aus-ereignissen-berechnen.md) | Spielstand und Statistik aus den Ereignissen berechnen |

**Schichten im Server.** Die Fachlogik in `server_application/lib/domain/` kennt weder HTTP noch Dateien noch die Systemzeit. Die aktuelle Zeit wird übergeben, damit Tests eine feste Uhr nutzen können. Die Objekte sind unveränderlich: Jede Aktion liefert ein neues Spiel. Verstößt eine Aktion gegen eine Regel, wirft die Fachlogik eine `RuleViolation` mit deutscher Meldung, die der Server als HTTP 409 zurückgibt, z. B. „Nur 2 Auszeiten pro Halbzeit.“

**Ereignisse statt Zähler.** Gespeichert wird nur die Liste der Ereignisse. Spielstand, Aufstellung, Zeitstrafen und Statistik werden daraus berechnet. Löscht der Ticker ein falsch erfasstes Tor, stimmen Stand und Statistik dadurch sofort wieder.

**Uhr auf dem Server.** Gespeichert werden nur „läuft“, „gestartet um“ und „vorher gelaufen“. Die Spielzeit wird bei jeder Anfrage berechnet, so zeigen alle Browser dieselbe Zeit, auch nach einem Neustart des Servers.

## Qualitätssicherung

Die Fachlogik entstand zuerst als Pseudocode. So war die Hürde, den Code zu verstehen, nicht mehr da, und die KI bekam einen klaren Rahmen, was zu tun ist. Jeden Pseudocode habe ich gelesen, verstanden und Rückfragen gestellt, bevor daraus Dart-Code und Tests wurden.

| Maßnahme | Umsetzung |
|---|---|
| Unit-Tests | `server_application/test/domain/`, je Regel und Kriterium, mit Test-Buildern und fester Uhr |
| API- und Speichertests | `test/api/`, `test/storage/` |
| Akzeptanztests | `test/acceptance/` starten den echten Server als eigenen Prozess und sprechen nur über HTTP mit ihm; geschrieben nach jeder Story, eng am Beispiel im Kriterium |
| Widget-Tests | `flutter_application/test/` |
| Statische Analyse | `dart analyze --fatal-infos` (Server), `flutter analyze` (Client) |
| CI | GitHub Actions bei jedem Push: Code erzeugen, analysieren, alle Tests |
| Kriterienzähler | `server_application/tool/criteria_coverage.dart` meldet in der CI, welche Muss-Kriterien noch keinen Akzeptanztest haben (Stand 25.11.2026: alle 48 haben einen) |
| Continuous Deployment | Bei jedem Push auf `main` baut GitHub Actions die App im Demo-Modus und stellt sie auf GitHub Pages bereit |

Tests tragen die Kennung des Kriteriums im Namen und folgen dem Aufbau Vorbereiten / Ausführen / Prüfen, z. B.:

```dart
test('R1_2 rejects a third timeout in the first half', () { ... });
```

## Lokal starten

Voraussetzungen: Flutter 3.50 (enthält Dart), Java 17 oder neuer (nur für den Code-Generator), Git.

### Windows (PowerShell)

```powershell
git clone https://github.com/eamaadacho/handball-live-statistik.git
cd handball-live-statistik
.\generate_code.bat

# Fenster 1: Server
cd server_application
dart run bin/server.dart

# Fenster 2: Client
cd flutter_application
flutter run -d chrome --dart-define=SERVER_URL=http://127.0.0.1:8080
```

### macOS / Linux

```bash
git clone https://github.com/eamaadacho/handball-live-statistik.git
cd handball-live-statistik
chmod +x generate_code.sh && ./generate_code.sh

# Terminal 1: Server
cd server_application
dart run bin/server.dart

# Terminal 2: Client
cd flutter_application
flutter run -d chrome --dart-define=SERVER_URL=http://127.0.0.1:8080
```

Der Server läuft auf Port 8080 und meldet unter http://localhost:8080/health `{"status":"ok"}`. Der Client öffnet sich in Chrome und spricht mit diesem Server. Ohne `--dart-define=SERVER_URL=…` startet er im Demo-Modus mit Beispieldaten, so läuft auch die Demo auf GitHub Pages: https://eamaadacho.github.io/handball-live-statistik/. Daten liegen in `server_application/data/` und sind nicht im Repository.

Tests ausführen: `dart test` in `server_application`, `flutter test` in `flutter_application`.

## Aufbau des Repositorys

| Ordner | Inhalt |
|---|---|
| `api.yaml` | REST-Schnittstelle (OpenAPI) |
| `server_application/lib/domain/` | Fachlogik und Handballregeln |
| `server_application/lib/api/` | HTTP-Handler |
| `server_application/lib/storage/` | Speicherung in JSON-Dateien, SQLite-Archiv und Logo-Dateien |
| `server_application/test/` | Unit-, API-, Speicher- und Akzeptanztests |
| `server_application/tool/` | Kriterienzähler für die CI |
| `flutter_application/` | Client: Ticker- und Live-Seite |
| `docs/` | User Stories, ADRs, AI Engineering Journal |
| `generate_code.sh` / `.bat` | Code aus `api.yaml` erzeugen |
| `.github/workflows/` | CI (`ci.yml`) und Demo auf GitHub Pages (`pages.yml`) |

## Stand und Ausblick

Alle Muss-Stories sind umgesetzt, jedes der 48 Muss-Kriterien hat einen Akzeptanztest (Stand 25.11.2026). Die Kann-Stories in [docs/user-stories.md](docs/user-stories.md) waren nur vorgesehen, wenn Zeit bleibt. Login mit Passwort (T3) und eine Saisonstatistik über alle Spiele (T5) gehören zum Beispiel nicht zum aktuellen Stand.

> **[PLATZHALTER Elias: Was würdest du als Nächstes bauen, wenn das Projekt weiterginge, und warum? 2–4 Sätze.]**
