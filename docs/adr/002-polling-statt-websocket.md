# ADR-002 Polling statt WebSocket

- Status: angenommen
- Datum: 20.11.2026

## Kontext

Zuschauer wie Lisa sollen Spielstand, Uhr und Verlauf live sehen, ohne die Seite neu zu laden (L1). HTTP ist zustandslos: Der Server antwortet nur, wenn der Browser fragt, und kann von sich aus nichts schicken.

## Entscheidung

Wir wollen immer alles auf dem aktuellsten Stand haben, ohne dass Lisa manuell etwas machen muss. Deshalb fragt die Live-Ansicht jede Sekunde `GET /games/{id}?version=N`. Hat sich seit Version N nichts geändert, antwortet der Server nur kurz, sonst mit dem kompletten Spielstand.

Polling ist leichter umzusetzen als ein WebSocket. Außerdem ist der Kommunikationsfluss gut nachvollziehbar: Jede Aktualisierung ist ein einzelner Request mit einer Response, die man in der `api.yaml` beschreiben und testen kann.

## Verworfene Alternativen

- **WebSocket:** offene Verbindung, Änderungen kommen sofort. Nicht in der Kursvorlage und nicht mit OpenAPI beschreibbar, Abbrüche müssten wir selbst behandeln.
- **Long Polling:** Der Server hält die Antwort zurück, bis sich etwas ändert. Schneller, aber schwerer zu bauen und zu testen.
- **Server-Sent Events:** nur Server → Browser, kaum OpenAPI-Unterstützung.

## Konsequenzen

- Ein Tor erscheint bei Lisa nach höchstens etwa 1 Sekunde.
- 30 Zuschauer erzeugen 30 Anfragen pro Sekunde, für den Server kein Problem.
- Jede Änderung am Spiel erhöht die Versionsnummer. Die laufende Uhr ändert sie nicht, weil die Spielzeit berechnet wird (ADR-003).
- Die Schnittstelle bleibt reines REST in `api.yaml`.
