# ADR-001 Kursvorlage als Basis

- Status: angenommen
- Datum: 20.11.2026

## Kontext

Die App braucht einen Web-Client, einen Server und eine Schnittstelle dazwischen. Client und Server müssen sich über das Format jeder Nachricht einig sein, z. B. dass ein Tor als `{ "type": "goal", "player": 7 }` ankommt. Die Kursvorlage `pwe_26q4` bringt dafür ein fertiges Gerüst mit.

## Entscheidung

Wir bauen auf der Kursvorlage auf: Flutter Web als Client (`flutter_application`), ein Dart-Server mit shelf (`server_application`) und die REST-Schnittstelle als OpenAPI-Beschreibung in `api.yaml`. Der OpenAPI-Generator erzeugt daraus die Klassen für Client und Server, sodass beide Seiten garantiert dasselbe Nachrichtenformat benutzen.

Die Vorlage liefert schon einen laufenden Server mit Router, eine Web-App, die den Server erreicht, CORS, Logging, Provider und Beispieltests mit Mockito. Die Ordnernamen der Vorlage bleiben, damit die Struktur wiedererkennbar ist. Den ChatGPT-Teil der Vorlage haben wir entfernt, weil die App keine KI braucht.

## Verworfene Alternativen

- **Eigenes Dart-Gerüst ohne OpenAPI:** Request- und Response-Klassen müssten auf beiden Seiten von Hand gleich gehalten werden, die Schnittstelle wäre nirgends zentral beschrieben.
- **Python-Server (z. B. Flask) mit Flutter-Client:** zwei Sprachen, und die Nachrichtenklassen müssten ebenfalls doppelt gepflegt werden.

## Konsequenzen

- Client und Server sind komplett in Dart geschrieben.
- Jede Änderung an der Schnittstelle beginnt in `api.yaml`, danach wird `generate_code` ausgeführt.
- Der Generator braucht Java (ab Version 17). Der Ordner `openapi/` wird erzeugt und nicht ins Repo eingecheckt, deshalb führt auch die CI `generate_code` aus.
