# User Stories

**Kern der App:** Ein Betreuer tickert ein Spiel, und alle sehen Spielstand, Uhr und Statistik live – mit geprüften Handballregeln.

Kennungen wie im Projektsteckbrief. Jede Story hat Akzeptanzkriterien (z. B. `E1.2`), Tests tragen die Kennung im Namen (z. B. `R1_2 rejects a third timeout in the first half`).
**Muss** wird bis zum Referat umgesetzt, **Kann** nur, wenn Zeit bleibt (in der Reihenfolge am Ende).

Beispiel für alle Stories: TV Mettmann (Heim) gegen HSG Hilden. Im Kader des TV Mettmann stehen Max Mustermann (Nr. 7), Lisa Mustermann (Nr. 12), Tom Neumann (Nr. 9) und Torwart Nora Neumann (Nr. 1).

## Beteiligte

| Rolle | Zugang | darf |
|---|---|---|
| Teamverantwortliche | geheimer Team-Link | Team und Kader pflegen, Spiele anlegen |
| Ticker | Ticker-Link pro Spiel | Uhr bedienen, Ereignisse erfassen und löschen |
| Zuschauer | öffentlicher Zuschauer-Link | Spiel live ansehen |
| Spieler und Teamangehörige (Kann) | Team-Ansicht, nur lesen | Kader, Spiele, Saisonstatistik ansehen |

## T – Teams und Kader

- **T1 (Muss)** Als Teamverantwortliche lege ich mein Team einmal an und bekomme einen geheimen Team-Link für die Teamverwaltung.
  - T1.1 Ein Teamname kommt in der App nur einmal vor. „TV Mettmann“ ein zweites Mal wird abgelehnt.
  - T1.2 Der Team-Link enthält einen zufälligen, nicht erratbaren Code. Ohne ihn antwortet der Server mit 403.
- **T2 (Muss)** Als Teamverantwortliche pflege ich den Kader: Spieler mit Trikotnummer, Name und Position (Feldspieler oder Torwart) hinzufügen, ändern und entfernen.
  - T2.1 Trikotnummern sind im Team eindeutig und liegen zwischen 1 und 99.
- **T6 (Muss)** Als Teamverantwortliche lade ich das Vereinslogo hoch. Es erscheint auf dem Spielfeld (E5), in der Live-Ansicht (L1) und in der Teamverwaltung.
  - T6.1 Erlaubt sind PNG und JPG bis 500 KB, sonst lehnt der Server mit verständlicher Meldung ab.
  - T6.2 Ohne Logo (auch beim nicht registrierten Gegner) steht das Kürzel des Teams im Kreis, z. B. „TVM“.
- **T3 (Kann)** Statt des Team-Links melde ich mich mit Teamname und Passwort an.
  - T3.1 Der Server speichert das Passwort nur als Hash, nie im Klartext.
  - T3.2 Bei falschem Passwort antwortet der Server mit 401.
- **T4 (Kann)** Als Spieler sehe ich über die Team-Ansicht (nur lesen) Kader und Spiele meines Teams. Den Link dazu finde ich in der Teamverwaltung. Ein laufendes Spiel öffnet die Live-Ansicht.
- **T5 (Kann)** Als Spieler sehe ich meine Saisonstatistik über alle Spiele meines Teams.
  - T5.1 Max trifft in Spiel 1 fünf Mal aus 6 Würfen und in Spiel 2 drei Mal aus 4 Würfen → Saison: 8 Tore aus 10 Würfen (80 %).

## S – Spiel anlegen

- **S1 (Muss)** Als Teamverantwortliche lege ich ein Spiel an: Gegner (Name), Datum, Halbzeitlänge (Standard 30 Min., z. B. 25 Min. für die B-Jugend).
  - S1.1 Für einen nicht registrierten Gegner pflege ich einen Spielkader mit Nummer und Name (Pflicht, mindestens 7 Spieler, davon 1 Torwart), z. B. „5 Jan Becker“. Das geht beim Anlegen oder im Ticker vor dem Anpfiff. Der Spielkader gilt nur für dieses Spiel.
  - S1.2 Nach dem Anlegen bekomme ich einen Ticker-Link und einen öffentlichen Zuschauer-Link.
  - S1.3 In der Teamverwaltung sehe ich alle Spiele mit Status (geplant, läuft, beendet) und finde die Links dort wieder.
- **S2 (Kann)** Ist der Gegner ein registriertes Team, wähle ich es aus und sein Kader wird übernommen.
  - S2.1 Gegen einen registrierten Gegner legt nur das Heimteam das Spiel an.
  - S2.2 Der Gegner bestätigt das Spiel in seiner Teamverwaltung. Erst dann zählt es für seine Saisonstatistik (T5). Ohne Bestätigung läuft der Ticker ganz normal.

## E – Ereignisse erfassen

- **E1 (Muss)** Als Ticker erfasse ich Ereignisse für beide Teams mit wenigen Klicks auf dem Spielfeld (E5): erst den Spieler antippen, dann die Aktion. Jedes Ereignis bekommt automatisch die aktuelle Spielzeit.
  Ereignisse: Tor, Fehlwurf, Parade, 7-Meter Tor, 7-Meter verworfen, 2 Minuten, Gelb, Rot, Technischer Fehler, Auszeit (gehört zum Team).
  - E1.1 Der Spielstand wird nie eingetippt, sondern aus den Toren berechnet: Tor von Max bei 11:10 → 12:10.
  - E1.2 Aktiver Torwart ist der Torwart, der gerade auf dem Feld steht (E5). Jedes Gegentor und jede Parade speichert den Torwart, der in dem Moment auf dem Feld war.
  - E1.3 Ein Tor von Hilden ist ein einziges Ereignis: Es zählt für den Werfer und als Gegentor für den aktiven Torwart von Mettmann. Genauso ist eine Parade von Nora der Fehlwurf eines Hilden-Spielers.
  - E1.4 Spieler stehen mit Nummer und Name im Ticker („7 Max Mustermann“).
- **E2 (Muss)** Als Ticker lösche ich ein beliebiges Ereignis aus dem Verlauf, wenn ich mich vertippt habe.
  - E2.1 Spielstand und Statistik werden neu berechnet: Lösche ich das Tor von Max bei 12:11, steht es 11:11.
  - E2.2 Lösche ich die dritte Zeitstrafe von Max, fällt die automatische Rote Karte (R2) mit weg.
- **E3 (Muss)** Nur wer den Ticker-Link hat, kann Ereignisse erfassen oder löschen (sonst 403). Der Ticker sieht den Kader, kann ihn aber nicht ändern.
- **E5 (Muss)** Als Ticker sehe ich ein Handballfeld: Heimteam immer links, Gastteam immer rechts. Auf dem Feld steht die aktuelle Aufstellung, daneben die Bank.
  - E5.1 Vor dem Anpfiff stelle ich je Team 7 Spieler auf (6 Feldspieler, 1 Torwart), z. B. Nora im Tor, Max und Lisa im Feld.
  - E5.2 Ich wechsle wie in einem Fußball-Videospiel: Spieler auf dem Feld antippen, dann einen von der Bank, die beiden tauschen (Max raus, Tom rein). Gewechselt werden darf jederzeit.
  - E5.3 Jeder Wechsel wird mit Spielzeit gespeichert, aber nicht im Verlauf der Zuschauer angezeigt.
  - E5.4 Ein Spieler mit laufender Zeitstrafe steht neben dem Feld; das Team hat so lange einen Platz weniger.
  - E5.5 Aufstellen und Wechseln funktioniert für beide Teams gleich, auch für den Gegner mit Spielkader (S1.1).
- **E4 (Kann)** Weitere Ereignisse: Assist (Tor Max, Vorlage Lisa), Block, Ballgewinn, 7-Meter herausgeholt, Fehlpass und Schrittfehler einzeln statt „Technischer Fehler“.

## U – Spieluhr

- **U1 (Muss)** Als Ticker bediene ich die Uhr wie eine Hallenuhr: Start, Stopp, Halbzeit, Spielende.
  - U1.1 Ich kann die Uhr jederzeit von Hand anhalten und weiterlaufen lassen, z. B. beim 7-Meter oder bei einer Verletzung.
- **U2 (Muss)** Solange die Uhr steht, korrigiere ich die Zeit ein paar Sekunden vor oder zurück (23:14 → 23:05).
  - U2.1 Schon erfasste Ereignisse behalten ihre Zeit.
- **U3 (Muss)** Die Uhr hält von selbst an:
  - U3.1 bei einer Auszeit,
  - U3.2 am Ende der Halbzeit (bei 30 Min. Halbzeitlänge also bei 30:00 bzw. 60:00).
- **U4 (Muss)** Alle Clients zeigen dieselbe Spielzeit, auch nach Neuladen (die Uhr läuft auf dem Server).

## L – Live ansehen

- **L1 (Muss)** Als Zuschauer sehe ich über den Zuschauer-Link oben Spielstand und Spielzeit, darunter die Reiter „Verlauf“ (neuestes Ereignis oben) und „Statistik“, ohne neu zu laden (Aktualisierung alle 2 Sekunden).
- **L2 (Muss)** Im Reiter „Statistik“ sehe ich den Halbzeitstand und je Spieler: Tore, Würfe, Wurfquote, 7-Meter-Quote, technische Fehler, Strafen; je Torwart Paraden, Gegentore und Paradenquote.
  - L2.1 Max trifft 4 von 5 Siebenmetern → 7-Meter-Quote 80 %.
  - L2.2 Nora hält 12 von 30 Würfen aufs Tor (12 Paraden, 18 Gegentore) → Paradenquote 40 %.
- **L3 (Muss)** Laufende Zeitstrafen stehen mit Restzeit unter dem Spielstand („Nr. 7 Max 1:23“), dazu „TV Mettmann in Unterzahl“.
  - L3.1 Die Restzeit läuft mit der Spieluhr: Max bekommt bei 23:00 zwei Minuten, bei 24:37 steht 0:23. Steht die Uhr, steht auch die Restzeit.
  - L3.2 Eine Zeitstrafe läuft über die Halbzeitpause hinweg weiter.
  - L3.3 Eine Rote Karte (auch nach R2) bedeutet für das Team 2 Minuten Unterzahl.
- **L4 (Kann)** Nach Abpfiff teile ich das Ergebnis per Knopf als Text, z. B. für WhatsApp: „TV Mettmann – HSG Hilden 28:25. Tore: Max 8, Lisa 6 …“

## R – Handballregeln (in der Fachlogik geprüft)

Verstöße lehnt der Server mit einer verständlichen Meldung ab (HTTP 409).

- **R1 (Muss)** Auszeiten
  - R1.1 Jedes Team hat höchstens 3 Auszeiten pro Spiel.
  - R1.2 Höchstens 2 Auszeiten pro Halbzeit.
  - R1.3 In den letzten 5 Minuten des Spiels höchstens eine Auszeit pro Team.
- **R2 (Muss)** Die dritte Zeitstrafe eines Spielers führt automatisch zur Disqualifikation (Rot).
- **R3 (Muss)** Ein disqualifizierter Spieler kann keine Ereignisse mehr bekommen.
- **R4 (Muss)** Ereignisse nur während des Spiels
  - R4.1 Vor dem Anpfiff werden keine Ereignisse angenommen.
  - R4.2 Nach Spielende werden keine Ereignisse mehr angenommen oder gelöscht.
- **R5 (Muss)** Paraden und Gegentore kann nur ein Torwart haben. „Parade – Nr. 7 Max“ wird abgelehnt.
- **R7 (Muss)** Auf dem Feld stehen höchstens 7 Spieler eines Teams, während einer Zeitstrafe oder nach Rot entsprechend weniger. Nur Spieler auf dem Feld können Ereignisse bekommen.
- **R6 (Kann)** Hinweis bei Gelb: Hat Max schon Gelb oder hat Mettmann schon 3 Gelbe, zeigt der Ticker „Laut Regel sollte jetzt eine Zeitstrafe folgen“. Das ist nur ein Hinweis, keine Ablehnung, weil die Regel ein „sollte“ ist.

Regelquellen: IHF-Regeln Hallenhandball (R2: Regel 16:5/16:6; R6: Kommentar zu Regel 16:1; L3.3: Regel 16:8). R1 mit 3 Auszeiten ist eine Durchführungsbestimmung der Verbände (DHB), nicht der IHF-Grundtext.

## Reihenfolge der Kann-Stories

1. T3 Login mit Passwort
2. T4 Team-Ansicht
3. T5 Saisonstatistik
4. S2 Registrierter Gegner mit Bestätigung
5. E4 Weitere Ereignisse
6. R6 Gelb-Hinweis
7. L4 Ergebnis teilen
8. L5 Einsatzzeit und Plus/Minus je Spieler (die Daten liefern die Wechsel aus E5.3)

## Erweiterungen (außerhalb dieses Projekts)

Liga mit Spielplan und Tabelle (wie nuLiga) · persönliche Konten · WebSocket statt Polling · CSV-Export · Wurfposition
