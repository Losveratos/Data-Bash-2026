# Live-Demo dwg cli · Data Bash 2026 (27.11.2026)

**Aussage:** Eine kleine App-Spec (JSON) wird zur Fabric-App-Seite und zum selben Power-BI-Bericht (PBIP). Dieselben
Original-Visuals (ChartKitchen byDatenWG, P&L Statement byDatenWG), dieselben Felder, dasselbe Layout, und ein Test,
der beide Seiten gegeneinander prüft.

Alles läuft **lokal und ohne Fabric**: Mini-DAX rechnet die erzeugten Abfragen auf synthetischen Demodaten
(Brauerei-Datensatz des Showcase-Modells), ein Browser-Test rendert den echten erzeugten App-Code. Es wird nichts
deployt und nichts gepusht. Die Darstellung ist an IBCS angelehnt (inspiriert, nicht zertifiziert).

## Vorher prüfen (am Vorabend und 30 Minuten vor dem Slot)

| Was | Wo | Erwartet |
| --- | --- | --- |
| dwg-Arbeitskopie | `%USERPROFILE%\Desktop\PnL Demo\dwg-cli-databash` | eigener Worktree, losgelöst auf `origin/main` 6dca187 (ChartKitchen 1.58.0.0, P&L 1.8.4.0), `npm ci` gelaufen. Nicht löschen, nicht `git worktree prune` |
| Generalprobe | `powershell -ExecutionPolicy Bypass -File demo.ps1 -NoLive` | am Ende grüne Zeile „GRÜN: alle Befehle ok“, rund 28 s |
| Port 8765 frei | `Get-NetTCPConnection -LocalPort 8765 -State Listen` | keine Ausgabe |
| Schrift im Terminal | Windows Terminal oder PowerShell-Fenster mit Cascadia/Consolas | Umlaute und Δ lesbar |

Die Hauptkopie `PnL Demo\dwg-cli` gehört anderen Sitzungen und bleibt unberührt.

## Ablauf auf der Bühne

Das Skript `demo.ps1` hat einen Block je Schritt. Entweder ganz laufen lassen mit Pause nach jedem Schritt:

```powershell
cd "%USERPROFILE%\Desktop\Data Bash 2026\demo"
powershell -ExecutionPolicy Bypass -File .\demo.ps1 -Pause
```

oder die Blöcke einzeln in ein PowerShell-Fenster einfügen: **zuerst Schritt 0**, dann 1 bis 6 in Reihenfolge.
Schritt 0 legt die Pfade fest, leert `demo\out` und definiert die Hilfsfunktion `run`, die jeden Befehl in Cyan
anzeigt und dann ausführt. Ein Lauf als Skript mit `-Record` schreibt die Fallback-Dateien nach `shots\` neu.

Gemessene Laufzeiten (26.11.2026, Demo-Laptop, zwei Läufe als Skript):

| Schritt | Inhalt | Laufzeit |
| --- | --- | --- |
| 0 | Vorbereitung, Rahmen der App kopieren | unter 1 s |
| 1 | Templates | 0,7 s |
| 2 | drei Kacheln mit `tile add`, Feinschliff | 1,8 s |
| 3 | `lint` und `check` | 0,5 bis 0,6 s |
| 4 | App-Seite erzeugen und im Browser-Test rendern | 9,0 bis 9,1 s |
| 4b | dieselbe Seite live im Browser | rund 3 s |
| 5 | PBIP erzeugen und zweifach prüfen | 5,6 bis 5,7 s |
| 6 | Paritätstest Power BI gegen App | 9,4 bis 9,9 s |
| | **gesamt ohne 4b** | **27,0 bis 27,7 s** |

### Schritt 1 · Welche Templates gibt es?

```powershell
node dwg.mjs templates --visual chartkitchen
node dwg.mjs templates C03
```

Zeigt die 24 ChartKitchen-Templates nach Zweck mit ihren Pflichtrollen, dann C03 im Detail: Rollen (Pflicht,
empfohlen, optional) und was das Template im Visual einstellt. Insgesamt gibt es 47 Templates (`node dwg.mjs templates`
ohne Filter listet auch die 23 P&L-Templates). Botschaft: Ein Template ist eine bewährte Aussage, nicht nur ein
Diagrammtyp.

### Schritt 2 · Drei Kacheln auf die Seite „Überblick“

Ausgangspunkt ist `spec\rahmen.json`: Name der App, Slicer Jahr (Vorgabe 2026) und Kanal, Fußtext, noch keine Seite.

```powershell
node dwg.mjs tile add --spec $Spec --new-page 'Überblick' --template C03 --model $Model --measure Umsatz --rect '327,123,774,438' --title 'Nettoumsatz in EUR' --description '…'
node dwg.mjs tile add --spec $Spec --page 'Überblick' --template C13 --model $Model --measure Umsatz --rect '327,579,774,438'
node dwg.mjs tile add --spec $Spec --page 'Überblick' --template C13 --model $Model --measure Umsatz --rect '327,579,774,438' --category Kalender.Monatsname --multiples Kunde.Kanal --forecast 'Fakten.Umsatz FC' --title 'Nettoumsatz in EUR je Kanal'
node dwg.mjs tile add --spec $Spec --page 'Überblick' --template T04B --model $Model --rect '1119,123,774,894'
node "$Demo\tools\feinschliff.mjs" $Spec
```

- **C03** Säulen mit ΔPY und ΔPY %, Forecast-Monate schraffiert. `tile add` zeigt je Rolle das gewählte Feld, die
  Quelle („Vorschlag“ aus dem Modell oder „angegeben“) und die Alternativen.
- **C13** Small Multiples je Kanal. Der erste Aufruf **bricht absichtlich ab** (Exit-Code 1): Kategorie und
  Small-Multiples-Feld sind nicht eindeutig, dwg nennt Kandidaten statt zu raten. Der zweite Aufruf gibt sie an.
- **T04B** GuV mit Plan-Wasserfall. dwg nimmt von selbst „GuV PL bis Ist“: Ist YTD gegen Plan Gesamtjahr zeigte sonst
  rund −30 % auf jeder Zeile.
- **Feinschliff** (`tools\feinschliff.mjs`) steht für das, was man sonst im Editor in der JSON macht: GuV in Mio. EUR
  (`numbers.scaling`), Titelzeile mit Zeitraum, Kanäle in der Reihenfolge des Modells. `objects` in der Spec sind
  genau die Einstellungen des Power-BI-Formatbereichs. Spec zeigen: `code $Spec`.

Layout im Full-HD-Pixelraster (Inhalt x 327 bis 1893, y 123 bis 1017, Abstand 18): links oben C03, links unten C13,
rechts über die ganze Höhe T04B.

### Schritt 3 · Prüfen, bevor etwas erzeugt wird

```powershell
node dwg.mjs lint --spec $Spec
node dwg.mjs check --spec $Spec --model $Model
```

`lint` prüft Pixelraster und Barrierefreiheit, `check` Aufbau, Rollen und Felder gegen das Modell (TMDL).
Erwartet: lint 0 Fehler und 1 Warnung (Kontrast der Akzentfarbe 4,4:1 statt 4,5:1, gilt für alle Apps, bekannt),
check „1 Seiten, 3 Kacheln, 0 Probleme, 0 Hinweise“.

### Schritt 4 · Fabric-App-Seite erzeugen und rendern

```powershell
# Minimal-App: rayfin\rayfin.yml mit Konnektor "showcase", leere Hook-Datei (macht der Block selbst)
node dwg.mjs app page --app $App --spec $Spec --connector showcase --model $Model
Get-Content "$App\packages\frontend\src\dwg\pages\uberblick.dax" -Encoding UTF8 -TotalCount 26
node app\test\showcase-e2e.mjs --spec $Spec --out "$Out\harness"
```

`app page` schreibt Adapter, `DwgShell`, die Seite und je Seite eine `.dax`-Datei mit allen Abfragen (zum Zeigen: so
sieht die DAX aus, die die App an das Semantikmodell schickt, prüfbar in der DAX-Abfrageansicht). Dazu `fabscan.json`
für den Governance-Scanner. Der Browser-Test bündelt den erzeugten Code mit einem Konnektor-Ersatz (Mini-DAX), rendert
die Seite in Chromium mit 1920 × 1200 und prüft: alle Kacheln gerendert, keine Konsolenfehler, Erklärtext da, Δ in
derselben Skala wie die Basis. Erwartet: `ok   Überblick · 3 Kacheln …` und „1/1 Seiten ohne Befund“.
Bild: `Invoke-Item "$Out\harness\01-Überblick.png"`.

### Schritt 4b · Dieselbe Seite live im Browser

Startet `python -m http.server 8765` auf 127.0.0.1 im Bündel aus Schritt 4 und öffnet `http://127.0.0.1:8765/index.html`
im Standardbrowser. Zum Zeigen: Kanal im Filter-Panel wählen, auf eine Säule klicken (Querfilter, neue Abfrage mit
TREATAS), Hell / Dunkel umschalten, HD und Fließend. Danach Server beenden: `Stop-Process $Srv`.
Beim Skriptlauf mit `-NoLive` entfällt der Schritt.

### Schritt 5 · Derselbe Bericht als PBIP

```powershell
Copy-Item $Model $Pbip -Recurse -Force
node dwg.mjs pbip new --out $Report --name 'Data Bash' --model "$Pbip\ZlatyLev Showcase.SemanticModel" --template 'examples\showcase\ZlatyLev Showcase.Report'
node dwg.mjs pbip register --report $Report --pbiviz visuals\pbiviz\chartKitchenByDatenWG.1.58.0.0.pbiviz --pbiviz visuals\pbiviz\pnlByDatenWG.1.8.4.0.pbiviz
node dwg.mjs pbip pages --report $Report --spec $Spec
node dwg.mjs validate $Report
pbir validate $Report --fields
```

Das Modell (TMDL, 97 KB) wird neben den Bericht kopiert, damit der PBIP-Ordner so aussieht wie im Git-Repo
(Bericht + Modell, `definition.pbir` zeigt per `byPath` auf `../ZlatyLev Showcase.SemanticModel`). `register` trägt
die Custom Visuals direkt aus der `.pbiviz` ein, ohne Desktop. `pages` schreibt Seite, Kacheln und die zwei Slicer
aus derselben Spec. Erwartet: `ok   Data Bash.Report: 13 Dateien gegen Schema, 1 Seiten, 7 Visuals` (3 Kacheln,
2 Slicer, Kopf und Fuß) und von pbir „Fields: 30 (model loaded)“, „Valid (2 info)“.

In Power BI Desktop öffnen geht in dieser Demo nicht: das Showcase-Modell ist Direct Lake und braucht Fabric. Darum
gibt es kein Desktop-Bild; der Paritätstest in Schritt 6 zeigt stattdessen die Kacheln so, wie Power BI sie dem
Visual übergibt.

### Schritt 6 · Paritätstest Power BI gegen App

```powershell
node pbip\test\parity.mjs --report $Report --spec $Spec
node pbip\test\parity.mjs --app --report $Report --spec $Spec
```

Der erste Lauf liest das erzeugte PBIP und rendert jede Kachel so, wie Power BI sie übergibt (aktive Projektionen,
Anzeigenamen, Formatstrings aus dem TMDL, Viewport abzüglich Container-Innenabstand). Der zweite rendert dieselben
Kacheln unter App-Bedingungen aus der Spec. Geprüft werden die Fehlerbilder, die es im Dienst gab. Erwartet zweimal
„ok  keine Befunde“. Bild: `Invoke-Item "$Dwg\pbip\test\out\parity\alle.png"`.

## Ausblick: der Schritt nach Fabric (nur mit Freigabe)

> **Nur mit Freigabe, nicht auf der Bühne ausführen.** Deploy macht ein Mensch mit Fabric-Anmeldung. Im Skript stehen
> diese Zeilen nur als Kommentar.

- **App:** `node dwg.mjs app page --app <echte Rayfin-App> --spec <Spec> --connector <Konnektor> --model <Modell>`,
  Seite in `App.tsx` einbinden (`<DwgShell app={app} connection="<Konnektor>" />`), in der App `npm run build`, dann
  `npx rayfin up`. Der Konnektor vom Typ `fabric-semanticmodel` muss auf das Modell im Workspace zeigen.
- **Bericht:** Ordner `out\pbip` (Modell + Bericht) in ein Repo, das per Fabric-Git-Integration mit dem Workspace
  verbunden ist, oder per Fabric CLI:
  `fab import "<Workspace>.Workspace/ZlatyLev Showcase.SemanticModel" -i "<abs. Pfad>\ZlatyLev Showcase.SemanticModel" -f`,
  danach `fab import "<Workspace>.Workspace/Data Bash.Report" -i "<abs. Pfad>\Data Bash.Report" -f`.
  Private Custom Visuals brauchen im Tenant die Einstellung für SDK- bzw. Organisations-Visuals.

## Wenn ein Schritt scheitert

| Symptom | Was tun |
| --- | --- |
| `--rect „327“: erwartet x,y,Breite,Höhe` | In PowerShell `--rect` immer in Anführungszeichen: `'327,123,774,438'`. Ohne macht PowerShell aus den Kommas ein Array |
| `Seite „Überblick“ fehlt in der Spec` | Der erste `tile add` ist gescheitert. Schritt 0 neu, dann Schritt 2 neu. Oder die geprobte Spec nehmen: `Copy-Item "$Demo\spec\databash.json" $Spec -Force` und mit Schritt 3 weiter |
| Rote Zeile „Spec hat n statt 3 Kacheln“ | wie oben: geprobte Spec kopieren, weiter mit Schritt 3 |
| Umlaute kaputt („Ãœberblick“) | Schritt 0 nicht gelaufen (`[Console]::OutputEncoding`) oder Skript ohne BOM gespeichert. Schritt 0 erneut einfügen |
| C13 bricht ab mit „Pflichtrolle … ohne Feld“ | beim ersten C13-Aufruf **gewollt**; der zweite Aufruf mit `--category` und `--multiples` schreibt die Kachel |
| Browser-Test hängt („Timeout 45000ms“) | Spec ohne Kacheln oder Chromium fehlt. Spec prüfen (Schritt 3), sonst `npx playwright install chromium` im dwg-Ordner (braucht Netz, also am Vorabend). Fallback: `shots\04-app-page.png` |
| Paritätstest läuft minutenlang | passiert bei einem Bericht ohne Kacheln (Schritt 2 oder 5 gescheitert). Strg+C, Schritt 5 neu. Fallback: `shots\06-parity.txt` und `.png` |
| Port 8765 belegt (Schritt 4b) | alten Server beenden: `Get-NetTCPConnection -LocalPort 8765 -State Listen \| % { Stop-Process -Id $_.OwningProcess }` |
| `pbir` nicht gefunden oder meldet ein Update | Update-Hinweis ignorieren; ohne pbir überspringt das Skript die zweite Prüfung, `dwg validate` reicht |
| Irgendetwas anderes | Bilder und Texte aus `shots\` zeigen (gleiche Reihenfolge wie die Schritte) |

## Wo was liegt

| Was | Pfad |
| --- | --- |
| Bühnenskript | `demo\demo.ps1` (UTF-8 mit BOM, PowerShell 5.1) |
| Rahmen der App (Start) | `demo\spec\rahmen.json` |
| Geprobte Spec (Ergebnis von Schritt 2, versioniert) | `demo\spec\databash.json` |
| Feinschliff | `demo\tools\feinschliff.mjs` |
| Erzeugte Spec beim Lauf | `demo\out\databash.json` |
| Minimal-App mit erzeugter Seite | `demo\out\app\packages\frontend\src\dwg\` (Seite `pages\uberblick.ts`, Abfragen `pages\uberblick.dax`, Rahmen `apps\data-bash-2026.ts`), `demo\out\app\fabscan.json` |
| Browser-Test (Bündel, Screenshot) | `demo\out\harness\harness\` (für 4b), `demo\out\harness\01-Überblick.png` |
| PBIP | `demo\out\pbip\Data Bash.Report` und `demo\out\pbip\ZlatyLev Showcase.SemanticModel` |
| Paritätstest-Bild | `PnL Demo\dwg-cli-databash\pbip\test\out\parity\alle.png` |
| Fallback | `demo\shots\` (siehe unten) |

`demo\out\` wird bei jedem Lauf neu erzeugt und ist per `demo\.gitignore` ausgenommen.

### Fallback-Dateien in `shots\`

| Datei | Inhalt |
| --- | --- |
| `01-templates.txt` | Ausgabe Schritt 1 |
| `02-tile-add.txt` | Ausgabe Schritt 2 mit dem gewollten C13-Abbruch und dem Feinschliff |
| `03-lint-check.txt` | Ausgabe Schritt 3 |
| `04-app-page.txt` | `app page`, Auszug der `.dax`-Datei, Browser-Test |
| `04-app-page.png` | gerenderte App-Seite, 1920 × 1200, hell |
| `04-app-page-dunkel.png` | dieselbe Seite im Dunkelmodus |
| `05-pbip.txt` | PBIP erzeugen, `dwg validate`, `pbir validate --fields` |
| `06-parity.txt` | beide Paritätsläufe |
| `06-parity.png` | die drei Kacheln so, wie Power BI sie übergibt |

Pfade in den Textdateien sind gekürzt (`<demo>`, `<dwg>`). Alle Zahlen sind synthetische Demodaten.
