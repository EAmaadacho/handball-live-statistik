# User Stories

**Kern der App:** Ein Betreuer tickert ein Spiel, und alle sehen Spielstand, Uhr und Statistik live – mit geprüften Handballregeln.

Jede Story hat Akzeptanzkriterien (z. B. `E1.2`), Tests tragen die Kennung im Namen (z. B. `R1_2 rejects a third timeout in the first half`).
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

- <a id="t1"></a>**T1 (Muss)** Als Teamverantwortliche lege ich mein Team einmal an und bekomme einen geheimen Team-Link für die Teamverwaltung.
  - <a id="t1-1"></a>T1.1 Ein Teamname kommt in der App nur einmal vor. „TV Mettmann“ ein zweites Mal wird abgelehnt.
  - <a id="t1-2"></a>T1.2 Der Team-Link enthält einen zufälligen, nicht erratbaren Code. Ohne ihn antwortet der Server mit 403.
- <a id="t2"></a>**T2 (Muss)** Als Teamverantwortliche pflege ich den Kader: Spieler mit Trikotnummer, Name und Position (Feldspieler oder Torwart) hinzufügen, ändern und entfernen.
  - <a id="t2-1"></a>T2.1 Trikotnummern sind im Team eindeutig und liegen zwischen 1 und 99.
- <a id="t6"></a>**T6 (Muss)** Als Teamverantwortliche lade ich das Vereinslogo hoch. Es erscheint auf dem Spielfeld ([E5](#e5)), in der Live-Ansicht ([L1](#l1)) und in der Teamverwaltung.
  - <a id="t6-1"></a>T6.1 Erlaubt sind PNG und JPG bis 500 KB, sonst lehnt der Server mit verständlicher Meldung ab.
  - <a id="t6-2"></a>T6.2 Ohne Logo (auch beim nicht registrierten Gegner) steht das Kürzel des Teams im Kreis, z. B. „TVM“.
- <a id="t3"></a>**T3 (Kann)** Statt des Team-Links melde ich mich mit Teamname und Passwort an.
  - <a id="t3-1"></a>T3.1 Der Server speichert das Passwort nur als Hash, nie im Klartext.
  - <a id="t3-2"></a>T3.2 Bei falschem Passwort antwortet der Server mit 401.
- <a id="t4"></a>**T4 (Kann)** Als Spieler sehe ich über die Team-Ansicht (nur lesen) Kader und Spiele meines Teams. Den Link dazu finde ich in der Teamverwaltung. Ein laufendes Spiel öffnet die Live-Ansicht.
- <a id="t5"></a>**T5 (Kann)** Als Spieler sehe ich meine Saisonstatistik über alle Spiele meines Teams.
  - <a id="t5-1"></a>T5.1 Max trifft in Spiel 1 fünf Mal aus 6 Würfen und in Spiel 2 drei Mal aus 4 Würfen → Saison: 8 Tore aus 10 Würfen (80 %).
- <a id="t7"></a>**T7 (Kann)** Als Teamverantwortliche fordere ich auf der Startseite über „Team-Link vergessen?“ einen neuen Team-Link an.
  - <a id="t7-1"></a>T7.1 Beim Anlegen des Teams ([T1](#t1)) gebe ich eine E-Mail-Adresse an.
  - <a id="t7-2"></a>T7.2 Der neue Link wird an diese Adresse geschickt (zunächst in der Server-Konsole ausgegeben), der alte Link wird ungültig.
  - <a id="t7-3"></a>T7.3 Die Antwort ist für bekannte und unbekannte Adressen gleich.

## S – Spiel anlegen

- <a id="s1"></a>**S1 (Muss)** Als Teamverantwortliche lege ich ein Spiel an: Gegner (Name), Datum, Halbzeitlänge (Standard 30 Min., z. B. 25 Min. für die B-Jugend).
  - <a id="s1-1"></a>S1.1 Für einen nicht registrierten Gegner pflege ich einen Spielkader mit Nummer und Name (Pflicht, mindestens 7 Spieler, davon 1 Torwart), z. B. „5 Jan Becker“. Das geht beim Anlegen oder im Ticker vor dem Anpfiff. Der Spielkader gilt nur für dieses Spiel.
  - <a id="s1-2"></a>S1.2 Nach dem Anlegen bekomme ich einen Ticker-Link und einen öffentlichen Zuschauer-Link.
  - <a id="s1-3"></a>S1.3 In der Teamverwaltung sehe ich alle Spiele mit Status (geplant, läuft, beendet) und finde die Links dort wieder.
- <a id="s2"></a>**S2 (Kann)** Ist der Gegner ein registriertes Team, wähle ich es aus und sein Kader wird übernommen.
  - <a id="s2-1"></a>S2.1 Gegen einen registrierten Gegner legt nur das Heimteam das Spiel an.
  - <a id="s2-2"></a>S2.2 Der Gegner bestätigt das Spiel in seiner Teamverwaltung. Erst dann zählt es für seine Saisonstatistik ([T5](#t5)). Ohne Bestätigung läuft der Ticker ganz normal.

## E – Ereignisse erfassen

- <a id="e1"></a>**E1 (Muss)** Als Ticker erfasse ich Ereignisse für beide Teams mit wenigen Klicks auf dem Spielfeld ([E5](#e5)): erst den Spieler antippen, dann die Aktion. Jedes Ereignis bekommt automatisch die aktuelle Spielzeit.
  Ereignisse: Tor, Fehlwurf, Parade, 7-Meter Tor, 7-Meter verworfen, 2 Minuten, Gelb, Rot, Technischer Fehler, Auszeit (gehört zum Team).
  - <a id="e1-1"></a>E1.1 Der Spielstand wird nie eingetippt, sondern aus den Toren berechnet: Tor von Max bei 11:10 → 12:10.
  - <a id="e1-2"></a>E1.2 Aktiver Torwart ist der Torwart, der gerade auf dem Feld steht ([E5](#e5)). Jedes Gegentor und jede Parade speichert den Torwart, der in dem Moment auf dem Feld war.
  - <a id="e1-3"></a>E1.3 Ein Tor von Hilden ist ein einziges Ereignis: Es zählt für den Werfer und als Gegentor für den aktiven Torwart von Mettmann. Genauso ist eine Parade von Nora der Fehlwurf eines Hilden-Spielers.
  - <a id="e1-4"></a>E1.4 Spieler stehen mit Nummer und Name im Ticker („7 Max Mustermann“).
- <a id="e2"></a>**E2 (Muss)** Als Ticker lösche ich ein beliebiges Ereignis aus dem Verlauf, wenn ich mich vertippt habe.
  - <a id="e2-1"></a>E2.1 Spielstand und Statistik werden neu berechnet: Lösche ich das Tor von Max bei 12:11, steht es 11:11.
  - <a id="e2-2"></a>E2.2 Lösche ich die dritte Zeitstrafe von Max, fällt die automatische Rote Karte ([R2](#r2)) mit weg.
- <a id="e3"></a>**E3 (Muss)** Nur wer den Ticker-Link hat, kann Ereignisse erfassen oder löschen (sonst 403). Der Ticker sieht den Kader, kann ihn aber nicht ändern.
- <a id="e5"></a>**E5 (Muss)** Als Ticker sehe ich ein Handballfeld: Heimteam immer links, Gastteam immer rechts. Auf dem Feld steht die aktuelle Aufstellung, daneben die Bank.
  - <a id="e5-1"></a>E5.1 Vor dem Anpfiff stelle ich je Team 7 Spieler auf (6 Feldspieler, 1 Torwart), z. B. Nora im Tor, Max und Lisa im Feld.
  - <a id="e5-2"></a>E5.2 Ich wechsle wie in einem Fußball-Videospiel: Spieler auf dem Feld antippen, dann einen von der Bank, die beiden tauschen (Max raus, Tom rein). Gewechselt werden darf jederzeit.
  - <a id="e5-3"></a>E5.3 Jeder Wechsel wird mit Spielzeit gespeichert, aber nicht im Verlauf der Zuschauer angezeigt.
  - <a id="e5-4"></a>E5.4 Ein Spieler mit laufender Zeitstrafe steht neben dem Feld; das Team hat so lange einen Platz weniger.
  - <a id="e5-5"></a>E5.5 Aufstellen und Wechseln funktioniert für beide Teams gleich, auch für den Gegner mit Spielkader ([S1.1](#s1-1)).
- <a id="e4"></a>**E4 (Kann)** Weitere Ereignisse: Assist (Tor Max, Vorlage Lisa), Block, Ballgewinn, 7-Meter herausgeholt, Fehlpass und Schrittfehler einzeln statt „Technischer Fehler“.

## U – Spieluhr

- <a id="u1"></a>**U1 (Muss)** Als Ticker bediene ich die Uhr wie eine Hallenuhr: Start, Stopp, Halbzeit, Spielende.
  - <a id="u1-1"></a>U1.1 Ich kann die Uhr jederzeit von Hand anhalten und weiterlaufen lassen, z. B. beim 7-Meter oder bei einer Verletzung.
- <a id="u2"></a>**U2 (Muss)** Solange die Uhr steht, korrigiere ich die Zeit ein paar Sekunden vor oder zurück (23:14 → 23:05).
  - <a id="u2-1"></a>U2.1 Schon erfasste Ereignisse behalten ihre Zeit.
- <a id="u3"></a>**U3 (Muss)** Die Uhr hält von selbst an:
  - <a id="u3-1"></a>U3.1 bei einer Auszeit,
  - <a id="u3-2"></a>U3.2 am Ende der Halbzeit (bei 30 Min. Halbzeitlänge also bei 30:00 bzw. 60:00).
- <a id="u4"></a>**U4 (Muss)** Alle Clients zeigen dieselbe Spielzeit, auch nach Neuladen (die Uhr läuft auf dem Server).

## L – Live ansehen

- <a id="l1"></a>**L1 (Muss)** Als Zuschauer sehe ich über den Zuschauer-Link oben Spielstand und Spielzeit, darunter die Reiter „Verlauf“ (neuestes Ereignis oben) und „Statistik“, ohne neu zu laden (Aktualisierung jede Sekunde).
- <a id="l2"></a>**L2 (Muss)** Im Reiter „Statistik“ sehe ich den Halbzeitstand und je Spieler: Tore, Würfe, Wurfquote, 7-Meter-Quote, technische Fehler, Strafen; je Torwart Paraden, Gegentore und Paradenquote.
  - <a id="l2-1"></a>L2.1 Max trifft 4 von 5 Siebenmetern → 7-Meter-Quote 80 %.
  - <a id="l2-2"></a>L2.2 Nora hält 12 von 30 Würfen aufs Tor (12 Paraden, 18 Gegentore) → Paradenquote 40 %.
- <a id="l3"></a>**L3 (Muss)** Laufende Zeitstrafen stehen mit Restzeit unter dem Spielstand („Nr. 7 Max 1:23“), dazu „TV Mettmann in Unterzahl“.
  - <a id="l3-1"></a>L3.1 Die Restzeit läuft mit der Spieluhr: Max bekommt bei 23:00 zwei Minuten, bei 24:37 steht 0:23. Steht die Uhr, steht auch die Restzeit.
  - <a id="l3-2"></a>L3.2 Eine Zeitstrafe läuft über die Halbzeitpause hinweg weiter.
  - <a id="l3-3"></a>L3.3 Eine Rote Karte (auch nach [R2](#r2)) bedeutet für das Team 2 Minuten Unterzahl.
- <a id="l4"></a>**L4 (Kann)** Nach Abpfiff teile ich das Ergebnis per Knopf als Text, z. B. für WhatsApp: „TV Mettmann – HSG Hilden 28:25. Tore: Max 8, Lisa 6 …“
- <a id="l5"></a>**L5 (Kann)** Einsatzzeit und Plus/Minus je Spieler (die Daten liefern die Wechsel aus [E5.3](#e5-3)).

## R – Handballregeln (in der Fachlogik geprüft)

Verstöße lehnt der Server mit einer verständlichen Meldung ab (HTTP 409).

- <a id="r1"></a>**R1 (Muss)** Auszeiten
  - <a id="r1-1"></a>R1.1 Jedes Team hat höchstens 3 Auszeiten pro Spiel.
  - <a id="r1-2"></a>R1.2 Höchstens 2 Auszeiten pro Halbzeit.
  - <a id="r1-3"></a>R1.3 In den letzten 5 Minuten des Spiels höchstens eine Auszeit pro Team.
- <a id="r2"></a>**R2 (Muss)** Die dritte Zeitstrafe eines Spielers führt automatisch zur Disqualifikation (Rot).
- <a id="r3"></a>**R3 (Muss)** Ein disqualifizierter Spieler kann keine Ereignisse mehr bekommen.
- <a id="r4"></a>**R4 (Muss)** Ereignisse nur während des Spiels
  - <a id="r4-1"></a>R4.1 Vor dem Anpfiff werden keine Ereignisse angenommen.
  - <a id="r4-2"></a>R4.2 Nach Spielende werden keine Ereignisse mehr angenommen oder gelöscht.
- <a id="r5"></a>**R5 (Muss)** Paraden und Gegentore kann nur ein Torwart haben. „Parade – Nr. 7 Max“ wird abgelehnt.
- <a id="r7"></a>**R7 (Muss)** Auf dem Feld stehen höchstens 7 Spieler eines Teams, während einer Zeitstrafe oder nach Rot entsprechend weniger. Nur Spieler auf dem Feld können Ereignisse bekommen.
- <a id="r6"></a>**R6 (Kann)** Hinweis bei Gelb: Hat Max schon Gelb oder hat Mettmann schon 3 Gelbe, zeigt der Ticker „Laut Regel sollte jetzt eine Zeitstrafe folgen“. Das ist nur ein Hinweis, keine Ablehnung, weil die Regel ein „sollte“ ist.

Regelquellen: IHF-Regeln Hallenhandball ([R2](#r2): Regel 16:5/16:6; [R6](#r6): Kommentar zu Regel 16:1; [L3.3](#l3-3): Regel 16:8). [R1](#r1) mit 3 Auszeiten ist eine Durchführungsbestimmung der Verbände (DHB), nicht der IHF-Grundtext.

## Reihenfolge der Kann-Stories

1. [T3](#t3) Login mit Passwort
2. [T7](#t7) Neuen Team-Link anfordern
3. [T4](#t4) Team-Ansicht
4. [T5](#t5) Saisonstatistik
5. [S2](#s2) Registrierter Gegner mit Bestätigung
6. [E4](#e4) Weitere Ereignisse
7. [R6](#r6) Gelb-Hinweis
8. [L4](#l4) Ergebnis teilen
9. [L5](#l5) Einsatzzeit und Plus/Minus je Spieler (die Daten liefern die Wechsel aus [E5.3](#e5-3))

## Erweiterungen (außerhalb dieses Projekts)

Liga mit Spielplan und Tabelle (wie nuLiga) · persönliche Konten · WebSocket statt Polling · CSV-Export · Wurfposition
