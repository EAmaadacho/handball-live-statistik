# AI Engineering Journal

Dieses Journal beschreibt, wofür ich bei der Entwicklung der Handball-Live-Statistik KI eingesetzt habe. Die App selbst nutzt keine KI. Eingesetzt habe ich durchgehend Claude Opus 5.5 (Anthropic).

Für alle Phasen galt dieselbe Arbeitsweise: Die KI erklärt das Thema und schlägt Optionen vor, ich entscheide, erst danach entsteht Text oder Code. Jede Änderung kam erst nach meinem OK ins Repository.

## Überblick

| Phase | Wofür ich KI eingesetzt habe |
|---|---|
| Ideenfindung | Vorgaben zusammenfassen, Themen sammeln und bewerten, Kursvorlage auswerten |
| Einrichtung | Installationsplan für Flutter, Java, Git und VS Code ohne Administratorrechte, Repository aus der Kursvorlage, CI |
| Anforderungen | User Stories mit Akzeptanzkriterien über Auswahlkarten schärfen, Lücken suchen, Handballregeln prüfen |
| Architektur | Grundlagen erklären (Polling, Zustandslosigkeit, Speicherung), Optionen vergleichen, ADRs formulieren |
| Implementierung und Tests | Pseudocode für die Fachlogik, nach meiner Prüfung Dart-Code für Fachlogik, REST-API und Oberfläche, Unit- und Akzeptanztests |
| Dokumentation | README, dieses Journal und Referat gemeinsam ausformulieren; die Inhalte stammen von mir |

## Beispiel 1 – User Stories schärfen

**Kontext.** Phase Anforderungen, 17.11.2026. Im Projektsteckbrief stand nur ein grober Entwurf für einen Live-Ticker. Als Handballer kenne ich den Liveticker von nuLiga, dem Portal, über das die Handballverbände Spielpläne und Ergebnisse veröffentlichen. Ich wusste also, wie man so etwas aufbaut, und wollte ihn erweitern, weil er zu rudimentär und nicht aufschlussreich ist.

**Interaktion.** Ich wollte die User Stories gemeinsam mit der KI schärfen, über Auswahlkarten mit zwei bis vier Optionen und eigenen Ideen. Eigene Ideen waren zum Beispiel, Teams und Kader vorab zu speichern, statt sie vor jedem Spiel einzutippen. Ein unabhängiger Review-Durchgang prüfte am Ende Regeln und Umfang.

**Reflexion.** An den Auswahlkarten konnte ich erkennen, ob die KI das Zielbild erkennt. Falsch war: Die KI schlug „höchstens 3 Gelbe Karten pro Team“ als harte Grenze vor, laut Regelkommentar ist das nur eine Empfehlung. Die Regel „drei Auszeiten pro Spiel“ gab sie als internationale Regel aus, sie stammt aber von den deutschen Verbänden. Außerdem plante sie doppelte Ereignisse wie „Gegentor“ und „Tor des Gegners“. Der Umfang wuchs auf etwa das Doppelte und wurde danach in Muss und Kann geteilt. Daraus habe ich gelernt: Im Vorfeld hat man nicht direkt das fertige Produkt, man muss flexibel bleiben, weil beim Entwickeln neue Dinge dazukommen.

## Beispiel 2 – Feldspieler ins Tor

**Kontext.** Phase Implementierung, 23.11.2026. Die Fachlogik entstand Schritt für Schritt: Die KI schreibt Pseudocode, ich prüfe ihn, dann folgen Dart-Code und Tests. Im Schritt „Aufstellung und Wechsel“ durfte nur ein Spieler mit der Position „Torwart“ ins Tor. Im Handball darf aber jeder Feldspieler mit Torwarttrikot ins Tor, zum Beispiel wenn die Torhüterin verletzt ist. Aufgefallen ist mir das beim Oberflächen-Entwurf eher zufällig: Ich hatte Spielszenen im Kopf und merkte, dass so ein Fall im Spiel eine andere Bedeutung hat.

**Interaktion.** Ich bat die KI, die Handballregel zu prüfen und zu zeigen, wie wir es lösen. Sie bestätigte die Regel und legte Pseudocode für eine neue Aktion „Ins Tor“ vor. Nach meinem OK entstanden der Code, 13 Tests und ein neues Akzeptanzkriterium (E5.7).

**Reflexion.** Ich sehe das nicht als Fehler der KI, sondern als etwas, das nicht im Scope war: Die KI hat nicht alle Eventualitäten eines Handballspiels im Kontext. Solche Fälle findet, wer den Sport kennt. Geprüft habe ich das Ergebnis über die Tests in der CI.

## Beispiel 3 – Max bekommt dreimal 2 Minuten

**Kontext.** Phase Tests, 22. und 23.11.2026. Für die Regel „nach der dritten Zeitstrafe disqualifiziert“ (R2) schrieb die KI Tests, in denen Max dreimal hintereinander 2 Minuten bekam und dabei auf dem Feld blieb. Im echten Spiel geht das nicht: Wer 2 Minuten hat, sitzt draußen. Die Tests waren grün, weil eine Zeitstrafe den Spieler damals noch nicht vom Feld nahm.

**Interaktion.** Im nächsten Schritt bestätigte ich den Pseudocode „Zeitstrafe nimmt den Spieler vom Feld“. Danach schlugen die alten Tests fehl, zu Recht, denn die Testdaten waren falsch. Die KI passte sie an: Max sitzt seine Strafe ab und wird wieder eingewechselt, bevor er die nächste bekommt.

**Reflexion.** Ohne die roten Tests hätte ich den Fehler nicht bemerkt. Die Tests prüften eine Situation, die es im Spiel nicht gibt, und sahen trotzdem richtig aus. Daraus nehme ich mit: Man muss testen, um das Verhalten des Codes zu sehen.

## Gesamtreflexion

**Was würde ich künftig an KI delegieren?** Die technische Übersetzung von Anforderungen und Architektur in Code. Das funktioniert, wenn Anforderungen und Architektur klar definiert sind und der Pseudocode mir das Gefühl gibt: Ja, das passt.

**Was mache ich bewusst selbst?** Das Zielbild aufmalen und der KI Feedback geben, damit klar ist, was ich will.

**Welche Fehler hätte ich ohne eigene Fachkenntnisse oder Tests nicht entdeckt?** Vor allem unübliche Fälle, bei denen das Verhalten andere Mechanismen braucht. Die Torwart-Lücke habe ich nur gefunden, weil ich Handball spiele; den Fehler mit Max' drei Zeitstrafen nur, weil die Tests rot wurden.

**Wie hat sich meine Art verändert, Aufgaben zu formulieren und Ergebnisse zu prüfen?** Waren meine Aufträge zu allgemein, hat die KI Dinge nicht berücksichtigt. Heute plane ich erst mit der KI und baue Prototypen. Wenn alles klar ist, geht es an die Umsetzung. Ich arbeite also bewusst in Phasen und mit Feedbackschleifen.

**Wichtigste Erkenntnis für zukünftige Softwareprojekte?** Immer sicherstellen, dass die KI mich verstanden hat und ich verstehe, was die KI machen will.
