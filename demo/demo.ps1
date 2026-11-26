# =====================================================================================================
#  Data Bash 2026 · Live-Demo dwg cli
#  "Eine kleine App-Spec wird zur Fabric-App-Seite und zum selben Power-BI-Bericht (PBIP)."
#
#  Alles lokal, ohne Fabric, ohne Netz. Nichts wird deployt, nichts gepusht.
#  Windows PowerShell 5.1. Datei ist UTF-8 mit BOM (Umlaute).
#
#  Ganz laufen lassen:      powershell -ExecutionPolicy Bypass -File demo.ps1
#    -Pause                 nach jedem Schritt auf Enter warten (Bühne)
#    -NoLive                Schritt 4b (App live im Browser) auslassen
#    -Record                Ausgaben als Fallback nach shots\ schreiben (Texte und PNG)
#  Oder Block für Block einfügen: zuerst Schritt 0, dann 1 bis 6 in Reihenfolge.
#
#  Laufzeiten gemessen am 26.11.2026 auf dem Demo-Laptop (warm, zweiter Lauf), siehe je Schritt.
# =====================================================================================================
param([switch]$Record, [switch]$Pause, [switch]$NoLive)


# -----------------------------------------------------------------------------------------------------
#  Schritt 0 · Vorbereitung (Pfade, Ausgabe-Kodierung, Hilfsfunktion)                      ca. 0,5 s
#  Leert demo\out und startet mit dem Rahmen der App (Name, Slicer Jahr und Kanal, Fußtext).
# -----------------------------------------------------------------------------------------------------
# dwg-cli-Klon auf origin/main: per Umgebungsvariable DWG_CLI setzen, sonst Standardpfad
$Dwg    = if ($env:DWG_CLI) { $env:DWG_CLI } else { Join-Path $env:USERPROFILE 'Desktop\PnL Demo\dwg-cli-databash' }
$Demo   = if ($PSScriptRoot) { $PSScriptRoot } else { Join-Path $env:USERPROFILE 'Desktop\Data Bash 2026\demo' }
$Out    = Join-Path $Demo 'out'
$Shots  = Join-Path $Demo 'shots'
$Spec   = Join-Path $Out 'databash.json'
$Model  = Join-Path $Dwg 'examples\showcase\ZlatyLev Showcase.SemanticModel'
$App    = Join-Path $Out 'app'
$Pbip   = Join-Path $Out 'pbip'
$Report = Join-Path $Pbip 'Data Bash.Report'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = 'utf-8'
if (-not $env:SWC_NATIVE_BINDING_CACHE) { $env:SWC_NATIVE_BINDING_CACHE = Join-Path $env:USERPROFILE 'Desktop\fabric-apps\swc-cache' }
Set-Location $Dwg
$Log = @(); $Exits = 0; $Times = [ordered]@{}

# run <exe> <args…>: zeigt den Befehl, führt ihn aus, merkt sich die Ausgabe für shots\ (ohne param-Block,
# damit PowerShell keine Schalter wie -h abfängt)
function run {
    $exe, $rest = $args
    $shown = (@($exe) + @($rest | ForEach-Object { if ("$_" -match '\s') { '"' + $_ + '"' } else { "$_" } })) -join ' '
    $shown = $shown.Replace($Dwg + '\', '').Replace($Demo, '<demo>')
    Write-Host ''
    Write-Host "PS> $shown" -ForegroundColor Cyan
    & $exe @rest | Tee-Object -Variable o | Out-Host
    if ($LASTEXITCODE -ne 0) { Write-Host "    (Exit-Code $LASTEXITCODE)" -ForegroundColor Yellow; $script:Exits++ }
    $script:Log += @("PS> $shown") + @($o) + @('')
}
# Ausgabe eines Schritts als Textdatei nach shots\ (nur mit -Record), Pfade gekürzt
function Save-Shot($Name) {
    if (-not $Record) { $script:Log = @(); return }
    $enc = New-Object System.Text.UTF8Encoding $false
    $text = ($script:Log -join "`r`n").Replace($Dwg, '<dwg>').Replace($Dwg.Replace('\', '/'), '<dwg>')
    $text = $text.Replace($Demo, '<demo>').Replace($Demo.Replace('\', '/'), '<demo>').Replace($env:USERPROFILE, '~')
    [System.IO.File]::WriteAllText((Join-Path $Shots $Name), $text + "`r`n", $enc)
    $script:Log = @()
}
function Stop-Step($Nr, $Sw) {
    $s = $Sw.Elapsed.TotalSeconds; $script:Times["$Nr"] = $s
    Write-Host ('--- Schritt {0} fertig in {1:N1} s' -f $Nr, $s) -ForegroundColor Green
    if ($Pause) { Read-Host 'Weiter mit Enter' | Out-Null }
}

if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Force $Out, $Shots | Out-Null
Copy-Item (Join-Path $Demo 'spec\rahmen.json') $Spec
Write-Host "Bereit: dwg in $Dwg, Spec $Spec" -ForegroundColor Green


# -----------------------------------------------------------------------------------------------------
#  Schritt 1 · Welche Templates gibt es?                                                   ca. 1 s
#  47 Templates: 24 ChartKitchen (C01 bis C25), 23 P&L (T01A bis 12H, 11A), je mit Pflichtrollen.
#  Erzählen: "Ein Template ist eine bewährte Aussage, nicht nur ein Diagrammtyp."
# -----------------------------------------------------------------------------------------------------
$sw = [Diagnostics.Stopwatch]::StartNew()
run node dwg.mjs templates --visual chartkitchen
run node dwg.mjs templates C03
Save-Shot '01-templates.txt'
Stop-Step 1 $sw


# -----------------------------------------------------------------------------------------------------
#  Schritt 2 · Drei Kacheln auf die Seite "Überblick"                                      ca. 2 s
#  C03 Säulen mit ΔPY, C13 Small Multiples je Kanal, T04B GuV mit Plan-Wasserfall.
#  tile add erklärt je Rolle: welches Feld, woher (Vorschlag oder angegeben), welche Alternativen.
#  Moment fürs Publikum: C13 ohne Angaben bricht ab und nennt Kandidaten, dwg rät nicht (Exit 1 ist gewollt).
#  T04B nimmt von selbst "GuV PL bis Ist": Ist YTD gegen Plan Gesamtjahr zeigte sonst −30 % auf jeder Zeile.
# -----------------------------------------------------------------------------------------------------
$sw = [Diagnostics.Stopwatch]::StartNew()
run node dwg.mjs tile add --spec $Spec --new-page 'Überblick' --template C03 --model $Model --measure Umsatz --rect '327,123,774,438' --title 'Nettoumsatz in EUR' --description 'Wie läuft der Umsatz gegen das Vorjahr, welcher Kanal trägt ihn, und wie wird aus dem Plan das Ist-Ergebnis? Drei Kacheln aus drei Templates, eine Spec für App und Power BI.'
run node dwg.mjs tile add --spec $Spec --page 'Überblick' --template C13 --model $Model --measure Umsatz --rect '327,579,774,438'
run node dwg.mjs tile add --spec $Spec --page 'Überblick' --template C13 --model $Model --measure Umsatz --rect '327,579,774,438' --category Kalender.Monatsname --multiples Kunde.Kanal --forecast 'Fakten.Umsatz FC' --title 'Nettoumsatz in EUR je Kanal'
run node dwg.mjs tile add --spec $Spec --page 'Überblick' --template T04B --model $Model --rect '1119,123,774,894'
# Feinschliff wie im Editor: GuV in Mio. EUR mit Zeitraum, Kanäle in Modell-Reihenfolge (objects = Formatbereich)
run node (Join-Path $Demo 'tools\feinschliff.mjs') $Spec
# Sicherung: ohne drei Kacheln nicht weitermachen, sondern die geprobte Spec nehmen
$n = @((Get-Content $Spec -Raw -Encoding UTF8 | ConvertFrom-Json).pages | ForEach-Object { $_.tiles }).Count
if ($n -ne 3) { Write-Host "Spec hat $n statt 3 Kacheln. Fallback: Copy-Item (Join-Path `$Demo 'spec\databash.json') `$Spec -Force" -ForegroundColor Red }
Save-Shot '02-tile-add.txt'
Stop-Step 2 $sw
# Spec zeigen (VS Code oder Notepad):   code $Spec


# -----------------------------------------------------------------------------------------------------
#  Schritt 3 · Prüfen, bevor etwas erzeugt wird                                            ca. 1 s
#  lint: Pixelraster und Barrierefreiheit. check: Aufbau, Rollen, Felder gegen das Modell (TMDL).
#  Erwartet: lint 0 Fehler, 1 Warnung (Kontrast Akzentfarbe 4,4:1, gilt für alle Apps), check 0 Probleme.
# -----------------------------------------------------------------------------------------------------
$sw = [Diagnostics.Stopwatch]::StartNew()
run node dwg.mjs lint --spec $Spec
run node dwg.mjs check --spec $Spec --model $Model
Save-Shot '03-lint-check.txt'
Stop-Step 3 $sw


# -----------------------------------------------------------------------------------------------------
#  Schritt 4 · Fabric-App-Seite erzeugen und im Browser rendern (Mini-DAX statt Fabric)     ca. 15 s
#  a) Minimal-App: so viel Rayfin-Gerüst, wie dwg braucht (rayfin.yml mit Konnektor, Hook-Datei).
#  b) dwg app page schreibt Adapter, DwgShell, Seite und die DAX-Abfragen (.dax) in die App.
#  c) Browser-Test: echter erzeugter Code, Original-Visuals, Mini-DAX auf den Demodaten, Screenshot 1920 breit.
# -----------------------------------------------------------------------------------------------------
$sw = [Diagnostics.Stopwatch]::StartNew()
$utf8 = New-Object System.Text.UTF8Encoding $false
New-Item -ItemType Directory -Force (Join-Path $App 'rayfin'), (Join-Path $App 'packages\frontend\src\hooks') | Out-Null
[System.IO.File]::WriteAllText((Join-Path $App 'rayfin\rayfin.yml'), "connectors:`n  - name: showcase`n    type: fabric-semanticmodel`n", $utf8)
[System.IO.File]::WriteAllText((Join-Path $App 'packages\frontend\src\hooks\use-semantic-model-query.ts'), '', $utf8)
run node dwg.mjs app page --app $App --spec $Spec --connector showcase --model $Model
# Die erzeugten DAX-Abfragen (zum Prüfen in der DAX-Abfrageansicht)
Get-Content (Join-Path $App 'packages\frontend\src\dwg\pages\uberblick.dax') -Encoding UTF8 -TotalCount 26 | Tee-Object -Variable dax | Out-Host
$Log += @('PS> Get-Content <demo>\out\app\packages\frontend\src\dwg\pages\uberblick.dax -TotalCount 26') + $dax + @('')
run node app\test\showcase-e2e.mjs --spec $Spec --out (Join-Path $Out 'harness')
Save-Shot '04-app-page.txt'
if ($Record) { Copy-Item (Join-Path $Out 'harness\01-Überblick.png') (Join-Path $Shots '04-app-page.png') -Force }
Stop-Step 4 $sw
# Screenshot ansehen:   Invoke-Item (Join-Path $Out 'harness\01-Überblick.png')


# -----------------------------------------------------------------------------------------------------
#  Schritt 4b · Dieselbe Seite live im Browser (lokaler Webserver, Klick filtert)           ca. 3 s
#  Python-Webserver auf 127.0.0.1:8765 liefert das Bündel aus Schritt 4. Klick auf eine Säule oder einen
#  Kanal filtert die anderen Kacheln (neue DAX-Abfrage mit TREATAS). Ende: Stop-Process $Srv
# -----------------------------------------------------------------------------------------------------
if (-not $NoLive) {
    $Srv = Start-Process python -ArgumentList @('-m', 'http.server', '8765', '--bind', '127.0.0.1', '--directory', ('"' + (Join-Path $Out 'harness\harness') + '"')) -PassThru -WindowStyle Minimized
    Start-Sleep -Seconds 2
    Start-Process 'http://127.0.0.1:8765/index.html'
}


# -----------------------------------------------------------------------------------------------------
#  Schritt 5 · Derselbe Bericht als Power-BI-Projekt (PBIP/PBIR)                           ca. 8 s
#  Modell (TMDL) neben den Bericht kopieren: ein PBIP-Ordner wie im Git-Repo (Bericht + Modell).
#  pbip new: Bericht mit Theme aus dem Showcase. register: Custom Visuals direkt aus der .pbiviz.
#  pbip pages: Seite, Visuals, Slicer aus derselben Spec. validate: gegen die offiziellen PBIR-Schemas.
#  pbir validate --fields: zweite, unabhängige Prüfung (alle Felder im Modell vorhanden).
# -----------------------------------------------------------------------------------------------------
$sw = [Diagnostics.Stopwatch]::StartNew()
New-Item -ItemType Directory -Force $Pbip | Out-Null
Copy-Item $Model $Pbip -Recurse -Force
$PbipModel = Join-Path $Pbip 'ZlatyLev Showcase.SemanticModel'
run node dwg.mjs pbip new --out $Report --name 'Data Bash' --model $PbipModel --template 'examples\showcase\ZlatyLev Showcase.Report'
run node dwg.mjs pbip register --report $Report --pbiviz visuals\pbiviz\chartKitchenByDatenWG.1.58.0.0.pbiviz --pbiviz visuals\pbiviz\pnlByDatenWG.1.8.4.0.pbiviz
run node dwg.mjs pbip pages --report $Report --spec $Spec
run node dwg.mjs validate $Report
if (Get-Command pbir -ErrorAction SilentlyContinue) { run pbir validate $Report --fields }
else { Write-Host 'pbir nicht gefunden, zweite Prüfung entfällt.' -ForegroundColor Yellow }
Save-Shot '05-pbip.txt'
Stop-Step 5 $sw
# Ordner zeigen:   explorer $Pbip


# -----------------------------------------------------------------------------------------------------
#  Schritt 6 · Paritätstest: Power BI gegen App                                            ca. 10 s
#  Rendert jede Kachel so, wie Power BI sie dem Visual übergibt (aus dem PBIP), und so, wie die App es tut
#  (aus der Spec), und prüft die Fehlerbilder, die es im Dienst gab. Erwartet zweimal "ok keine Befunde".
# -----------------------------------------------------------------------------------------------------
$sw = [Diagnostics.Stopwatch]::StartNew()
run node pbip\test\parity.mjs --report $Report --spec $Spec
run node pbip\test\parity.mjs --app --report $Report --spec $Spec
Save-Shot '06-parity.txt'
if ($Record) { Copy-Item (Join-Path $Dwg 'pbip\test\out\parity\alle.png') (Join-Path $Shots '06-parity.png') -Force }
Stop-Step 6 $sw
# Kacheln in Power-BI-Form ansehen:   Invoke-Item (Join-Path $Dwg 'pbip\test\out\parity\alle.png')


# -----------------------------------------------------------------------------------------------------
#  Ausblick · Der Schritt nach Fabric. NUR MIT FREIGABE, NICHT AUF DER BÜHNE AUSFÜHREN.
#  Bleibt bewusst auskommentiert: Deploy macht ein Mensch mit Fabric-Anmeldung.
# -----------------------------------------------------------------------------------------------------
# App:      node dwg.mjs app page --app <echte Rayfin-App> --spec $Spec --connector <Konnektor> --model $Model
#           cd <echte Rayfin-App>; npm run build; npx rayfin up
# Bericht:  Modell und Bericht per Fabric-Git-Integration (Ordner $Pbip ins verbundene Repo) oder
#           fab import "<Workspace>.Workspace/ZlatyLev Showcase.SemanticModel" -i "<abs. Pfad>\ZlatyLev Showcase.SemanticModel" -f
#           fab import "<Workspace>.Workspace/Data Bash.Report" -i "<abs. Pfad>\Data Bash.Report" -f


# -----------------------------------------------------------------------------------------------------
#  Zusammenfassung (nur beim Lauf als Skript sinnvoll)
# -----------------------------------------------------------------------------------------------------
Write-Host ''
foreach ($k in $Times.Keys) { Write-Host ('Schritt {0}: {1,5:N1} s' -f $k, $Times[$k]) }
Write-Host ('Gesamt:    {0,5:N1} s' -f (($Times.Values | Measure-Object -Sum).Sum))
if ($Exits -eq 1) { Write-Host 'GRÜN: alle Befehle ok (der eine Abbruch ist der gewollte C13 ohne Felder).' -ForegroundColor Green }
else { Write-Host "ACHTUNG: $Exits Befehle mit Exit-Code ungleich 0 (erwartet 1, der gewollte C13-Abbruch)." -ForegroundColor Red }
