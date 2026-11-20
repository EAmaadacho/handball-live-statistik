# ADR-006 Spielstand und Statistik aus den Ereignissen berechnen

- Status: angenommen
- Datum: 20.11.2026

## Kontext

Der Ticker erfasst Ereignisse und kann jedes davon wieder löschen (E1, E2). Spielstand, Halbzeitstand, Spielerstatistik, laufende Zeitstrafen und automatische Rote Karten (R2) hängen alle von diesen Ereignissen ab.

## Entscheidung

Gespeichert wird nur die Liste der Ereignisse eines Spiels, auch Wechsel (E5.3). Der Spielstand wird nie eingetippt oder als Zahl gespeichert, sondern immer aus den Ereignissen berechnet, genauso die Statistik, die aktuelle Aufstellung und die Folgen der Regeln.

Löscht der Ticker das Tor von Max bei 12:11, wird nur dieses Ereignis entfernt und alles neu berechnet: Es steht 11:11, und Max hat ein Tor weniger. Löscht er die dritte Zeitstrafe von Max, findet R2 nur noch zwei, und die automatische Rote Karte fällt weg (E2.2).

## Verworfene Alternativen

- **Zähler speichern und bei jedem Ereignis ändern:** Jede Aktion bräuchte eine Rückwärts-Aktion fürs Löschen, und Zähler können mit der Ereignisliste auseinanderlaufen.
- **Ereignisliste und Zähler zusammen:** zwei Wahrheiten, die synchron bleiben müssen, ohne spürbaren Geschwindigkeitsvorteil.

## Konsequenzen

- Es gibt nur eine Wahrheit, die Ereignisliste; Spielstand und Statistik können ihr nie widersprechen.
- Die Berechnung ist eine reine Funktion (Ereignisse rein, Statistik raus) und lässt sich ohne Server testen.
- Bei jeder Anfrage wird neu gerechnet. Bei etwa 150 Ereignissen pro Spiel dauert das Mikrosekunden.
- Das Archiv (ADR-004) speichert genau diese Liste in der Tabelle `events`.
- Das Muster ist eine vereinfachte Form von Event Sourcing.
