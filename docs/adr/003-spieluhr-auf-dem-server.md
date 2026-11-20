# ADR-003 Spieluhr auf dem Server

- Status: angenommen
- Datum: 20.11.2026

## Kontext

Ticker, Co-Trainer und Zuschauer sollen dieselbe Spielzeit sehen, auch nach Neuladen ([U4](../user-stories.md#u4)). Der Ticker startet, stoppt und korrigiert die Uhr ([U1](../user-stories.md#u1), [U2](../user-stories.md#u2)), bei Auszeit und Halbzeitende hält sie von selbst an ([U3](../user-stories.md#u3)). Jedes Ereignis braucht die Spielzeit, zu der es passiert ist.

## Entscheidung

Die Uhr gehört zum Spiel auf dem Server. So gibt es nur eine Wahrheit: Alle sehen dieselbe Zeit, und kein Ereignis kommt mit einer falschen Zeit vom Browser an.

Der Server speichert nur drei Werte: `läuft` (ja/nein), `gestartetUm` (echte Uhrzeit beim letzten Start) und `vorherGelaufen` (Spielzeit bis zum letzten Start oder Stopp). Die Spielzeit wird daraus berechnet: `vorherGelaufen + (jetzt − gestartetUm)`, höchstens bis zum Halbzeitende. Korrigieren geht nur bei stehender Uhr und überschreibt `vorherGelaufen`. Die Fachlogik holt „jetzt“ nie selbst, sie bekommt es übergeben.

## Verworfene Alternativen

- **Uhr im Browser des Tickers:** Nach Neuladen ist die Uhr weg, Zuschauer sehen keine laufende Zeit, der Server müsste der Zeit vom Browser glauben.
- **Jeder Browser zählt selbst:** Die Anzeigen laufen auseinander, nach Neuladen beginnt die Uhr bei null.

## Konsequenzen

- Der Server stempelt jedes Ereignis selbst mit der Spielzeit. Spätere Korrekturen der Uhr ändern diese Zeit nicht ([U2.1](../user-stories.md#u2-1)).
- Die laufende Uhr ändert die Versionsnummer nicht ([ADR-002](002-polling-statt-websocket.md)).
- Jede Antwort enthält die fertig berechnete Spielzeit. Der Client zählt nur bis zur nächsten Antwort weiter, so stört eine falsch gestellte Handy-Uhr nicht.
- Tests nutzen eine feste Uhr, z. B. „jetzt ist 10:32:14“ → 23:14.
