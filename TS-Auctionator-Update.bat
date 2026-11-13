@echo off
rem TS Auctionator Updater - laedt die neueste Version von https://ts-auctionator.github.io
rem und ersetzt den Add-on-Ordner. Einstellungen (Ordner WTF) bleiben erhalten.
title TS Auctionator Updater
powershell -NoProfile -ExecutionPolicy Bypass -Command "$c=[IO.File]::ReadAllText('%~f0'); $i=$c.IndexOf('#'+'POWERSHELL'); Invoke-Expression $c.Substring($i)"
echo.
pause
exit /b

#POWERSHELL
$ErrorActionPreference = 'Stop'
$url = 'https://github.com/TS-Auctionator/ts-auctionator.github.io/releases/latest/download/TSAuctionator.zip'
$ue = [char]0xFC; $ae = [char]0xE4
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

function Write-Step($t) { Write-Host "  $t" }
function Is-Forever($p) { $p -and (Test-Path -LiteralPath (Join-Path $p 'Interface\AddOns')) }
function Version-Of($folder) {
  $toc = Join-Path $folder 'TSAuctionator.toc'
  if (-not (Test-Path -LiteralPath $toc)) { return $null }
  $m = Select-String -LiteralPath $toc -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1
  if ($m) { return $m.Matches[0].Groups[1].Value.Trim() } else { return $null }
}

Write-Host ''
Write-Host '  TS Auctionator Updater' -ForegroundColor Yellow
Write-Host '  ======================' -ForegroundColor Yellow
Write-Host ''

try {
  # 1. WoW-Forever-Ordner finden (wird gemerkt)
  $cfgDir = Join-Path $env:APPDATA 'TS-Auctionator'
  $cfg = Join-Path $cfgDir 'wow-ordner.txt'
  $wow = $null
  if (Test-Path -LiteralPath $cfg) {
    $saved = (Get-Content -LiteralPath $cfg -Raw).Trim()
    if (Is-Forever $saved) { $wow = $saved }
  }
  if (-not $wow) {
    $cands = New-Object System.Collections.ArrayList
    foreach ($key in 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft', 'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft') {
      try {
        $ip = (Get-ItemProperty -LiteralPath $key -ErrorAction Stop).InstallPath
        if ($ip) {
          $ip = $ip.TrimEnd('\')
          [void]$cands.Add((Join-Path $ip '_forever_'))
          [void]$cands.Add((Join-Path (Split-Path $ip -Parent) '_forever_'))
        }
      } catch {}
    }
    foreach ($d in (Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root })) {
      foreach ($sub in 'World of Warcraft', 'Spiele\World of Warcraft', 'Games\World of Warcraft', 'Program Files (x86)\World of Warcraft', 'Program Files\World of Warcraft', 'Blizzard\World of Warcraft') {
        [void]$cands.Add((Join-Path (Join-Path $d $sub) '_forever_'))
      }
    }
    foreach ($c in $cands) { if (Is-Forever $c) { $wow = $c; break } }
  }
  if (-not $wow) {
    Write-Step "WoW-Ordner nicht gefunden. Bitte im Fenster den Ordner _forever_ ausw${ae}hlen."
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Ordner _forever_ in deinem World-of-Warcraft-Ordner ausw${ae}hlen"
    if ($dlg.ShowDialog() -ne 'OK') { throw 'Abgebrochen.' }
    $pick = $dlg.SelectedPath
    if (-not (Is-Forever $pick) -and (Is-Forever (Join-Path $pick '_forever_'))) { $pick = Join-Path $pick '_forever_' }
    if (-not (Is-Forever $pick)) {
      if (Test-Path -LiteralPath (Join-Path $pick 'Interface')) { New-Item -ItemType Directory -Force (Join-Path $pick 'Interface\AddOns') | Out-Null }
      else { throw "In diesem Ordner gibt es kein Interface\AddOns. Bitte den Ordner _forever_ w${ae}hlen." }
    }
    $wow = $pick
  }
  New-Item -ItemType Directory -Force $cfgDir | Out-Null
  Set-Content -LiteralPath $cfg -Value $wow -Encoding UTF8
  $target = Join-Path $wow 'Interface\AddOns\TSAuctionator'
  Write-Step "WoW-Ordner: $wow"

  # 2. Neueste Version laden
  Write-Step 'Lade neueste Version ...'
  $tmp = Join-Path $env:TEMP ('TSAuctionator-Update-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force $tmp | Out-Null
  $zip = Join-Path $tmp 'TSAuctionator.zip'
  Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
  Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
  $src = Join-Path $tmp 'TSAuctionator'
  if (-not (Test-Path -LiteralPath (Join-Path $src 'TSAuctionator.toc'))) { throw 'Die heruntergeladene Datei ist unvollst' + $ae + 'ndig.' }

  $old = Version-Of $target
  $new = Version-Of $src
  if ($old -and $old -eq $new) {
    Write-Host ''
    Write-Host "  Du hast schon die neueste Version ($new). Nichts zu tun." -ForegroundColor Green
  } else {
    # 3. Ersetzen (nur der Add-on-Ordner, Einstellungen liegen in WTF und bleiben)
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    Copy-Item -LiteralPath $src -Destination $target -Recurse
    Write-Host ''
    if ($old) { Write-Host "  Fertig: Version $old -> $new" -ForegroundColor Green }
    else { Write-Host "  Fertig: Version $new installiert" -ForegroundColor Green }
    Write-Step "L${ae}uft WoW gerade, im Chat /reload eingeben. Sonst einfach WoW starten."
  }
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
} catch {
  Write-Host ''
  Write-Host ("  Fehler: " + $_.Exception.Message) -ForegroundColor Red
  Write-Step "Notfalls die ZIP von https://ts-auctionator.github.io laden und von Hand entpacken."
}
