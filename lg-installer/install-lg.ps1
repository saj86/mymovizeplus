# MyMoviz Plus - one-click installer for LG webOS TVs (Windows)
# Usage: double-click install-lg.bat
#   or:  powershell -ExecutionPolicy Bypass -File install-lg.ps1 [-Ip 10.0.0.55] [-Passphrase AB12CD] [-Ipk path\to\app.ipk]
#
# What it does:
#   1. Makes sure Node.js (>=20) is available - downloads a private portable copy if not (no admin needed)
#   2. Installs the LG webOS CLI (@webos-tools/cli) into a private folder
#   3. Uses the .ipk that ships next to this script in the installer package
#   4. Asks for the TV IP + Developer Mode passphrase, connects and fetches the SSH key
#   5. Installs and launches the app on the TV

param(
    [string]$Ip = "",
    [string]$Passphrase = "",
    [string]$Ipk = ""
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest is very slow with the progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$IpkName    = "moviz-webos.ipk"
$AppId      = "com.movizplus.moviztv"
$DeviceName = "moviz-tv"
$NodeMajor  = 22                     # @webos-tools/cli needs Node >= 20
$Root       = Join-Path $env:LOCALAPPDATA "MovizLG"
$CliDir     = Join-Path $Root "cli"
$StateFile  = Join-Path $Root "last-ip.txt"

function Step($n, $msg) { Write-Host ""; Write-Host "[$n/5] $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  OK  $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  !!  $msg" -ForegroundColor Yellow }
function Fail($msg) {
    Write-Host ""
    Write-Host "  XX  $msg" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $Root | Out-Null

Write-Host "==============================================" -ForegroundColor Red
Write-Host "   MyMoviz Plus  -  LG webOS TV installer"      -ForegroundColor Red
Write-Host "==============================================" -ForegroundColor Red
Write-Host "Before starting, on the TV: open the 'Developer Mode' app,"
Write-Host "make sure Dev Mode Status is ON and Key Server is ON."

# ---------------------------------------------------------------- 1. Node.js
Step 1 "Checking Node.js"
$Node = $null
$Npm  = $null

$sysNode = Get-Command node.exe -ErrorAction SilentlyContinue
if ($sysNode) {
    $ver = (& $sysNode.Source -v) 2>$null
    if ($ver -match '^v(\d+)\.' -and [int]$Matches[1] -ge 20) {
        $sysNpm = Get-Command npm.cmd -ErrorAction SilentlyContinue
        if ($sysNpm) {
            $Node = $sysNode.Source; $Npm = $sysNpm.Source
            Ok "Using installed Node.js $ver"
        }
    } else {
        Warn "Installed Node.js ($ver) is too old - using a private copy instead"
    }
}

if (-not $Node) {
    $existing = Get-ChildItem -Path $Root -Directory -Filter "node-v$NodeMajor.*-win-*" -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | Select-Object -First 1
    if ($existing -and (Test-Path (Join-Path $existing.FullName "node.exe"))) {
        $nodeDir = $existing.FullName
        Ok "Using private Node.js ($($existing.Name))"
    } else {
        switch ($env:PROCESSOR_ARCHITECTURE) {
            "ARM64" { $arch = "arm64" }
            "x86"   { $arch = "x86" }
            default { $arch = "x64" }
        }
        $nodeVer = "v22.12.0"   # fallback if the index cannot be read
        try {
            $index = Invoke-RestMethod -Uri "https://nodejs.org/dist/index.json" -UseBasicParsing -TimeoutSec 30
            $pick = $index | Where-Object { $_.version -like "v$NodeMajor.*" -and $_.lts } | Select-Object -First 1
            if ($pick) { $nodeVer = $pick.version }
        } catch { Warn "Could not read the Node.js version list, using $nodeVer" }

        $zipName = "node-$nodeVer-win-$arch"
        $zipPath = Join-Path $Root "$zipName.zip"
        Write-Host "  Downloading Node.js $nodeVer ($arch)... (~30 MB)"
        try {
            Invoke-WebRequest -Uri "https://nodejs.org/dist/$nodeVer/$zipName.zip" -OutFile $zipPath -UseBasicParsing -TimeoutSec 600
        } catch {
            Fail "Download of Node.js failed. Check the internet connection and run again. ($($_.Exception.Message))"
        }
        Write-Host "  Extracting..."
        Expand-Archive -Path $zipPath -DestinationPath $Root -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        $nodeDir = Join-Path $Root $zipName
        if (-not (Test-Path (Join-Path $nodeDir "node.exe"))) { Fail "Node.js extraction failed." }
        Ok "Node.js $nodeVer ready"
    }
    $Node = Join-Path $nodeDir "node.exe"
    $Npm  = Join-Path $nodeDir "npm.cmd"
    $env:Path = "$nodeDir;$env:Path"
}

# ---------------------------------------------------------------- 2. webOS CLI
Step 2 "Checking LG webOS CLI"
$CliBin = Join-Path $CliDir "node_modules\@webos-tools\cli\bin"
if (-not (Test-Path (Join-Path $CliBin "ares-install.js"))) {
    Write-Host "  Installing @webos-tools/cli (one time, takes a minute)..."
    New-Item -ItemType Directory -Force -Path $CliDir | Out-Null
    & $Npm install --prefix "$CliDir" "@webos-tools/cli" --no-audit --no-fund --loglevel=error
    if (-not (Test-Path (Join-Path $CliBin "ares-install.js"))) {
        Fail "Could not install @webos-tools/cli. Check the internet connection and run again."
    }
}
Ok "webOS CLI ready"

# Runs an ares-* tool; its output goes to the console (or is hidden with -Quiet),
# only the exit code is returned.
function Ares {
    param([string]$Tool, [string[]]$ArgList, [switch]$Quiet)
    $js = Join-Path $CliBin "$Tool.js"
    if ($Quiet) { & $Node $js @ArgList 2>&1 | Out-Null }
    else        { & $Node $js @ArgList | Out-Host }
    return [int]$LASTEXITCODE
}

# ---------------------------------------------------------------- 3. .ipk file
Step 3 "Finding the app package"
if ($Ipk -and -not (Test-Path $Ipk)) { Fail "File not found: $Ipk" }
# The .ipk ships inside the installer package, next to this script
if (-not $Ipk) {
    $Ipk = Join-Path $PSScriptRoot $IpkName
    if (-not (Test-Path $Ipk)) {
        Fail "$IpkName not found next to this script. Extract the whole zip into one folder and run again."
    }
}
Ok "Package: $Ipk"

# ---------------------------------------------------------------- 4. Connect
Step 4 "Connecting to the TV"

function Test-Port($h, $p) {
    $c = New-Object Net.Sockets.TcpClient
    try {
        $r = $c.BeginConnect($h, $p, $null, $null)
        if ($r.AsyncWaitHandle.WaitOne(3000) -and $c.Connected) { return $true }
        return $false
    } catch { return $false } finally { $c.Close() }
}

$lastIp = ""
if (Test-Path $StateFile) { $lastIp = (Get-Content $StateFile -Raw).Trim() }

while ($true) {
    if (-not $Ip) {
        $prompt = "  TV IP address (shown in the Developer Mode app)"
        if ($lastIp) { $prompt += " [$lastIp]" }
        $Ip = (Read-Host $prompt).Trim()
        if (-not $Ip) { $Ip = $lastIp }
    }
    if ($Ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { Warn "That is not a valid IP (example: 10.0.0.55)"; $Ip = ""; continue }

    Write-Host "  Checking $Ip ..."
    if (-not (Test-Port $Ip 9922)) {
        Warn "TV not reachable on $Ip (port 9922). Same WiFi/LAN? Developer Mode ON? Correct IP?"
        $Ip = ""; continue
    }
    if (-not (Test-Port $Ip 9991)) {
        Warn "Key Server looks OFF. Turn 'Key Server' ON in the Developer Mode app, then press Enter."
        Read-Host | Out-Null
        if (-not (Test-Port $Ip 9991)) { Warn "Key Server still not reachable - trying anyway." }
    }
    break
}
Set-Content -Path $StateFile -Value $Ip
Ok "TV found at $Ip"

$null = Ares "ares-setup-device" @("--remove", $DeviceName) -Quiet
$rc = Ares "ares-setup-device" @("--add", $DeviceName, "-i", "host=$Ip", "-i", "port=9922", "-i", "username=prisoner")
if ($rc -ne 0) { Fail "Could not register the TV in the webOS CLI." }

$connected = $false
for ($try = 1; $try -le 3; $try++) {
    if (-not $Passphrase) {
        $Passphrase = (Read-Host "  Passphrase (6 characters, shown in the Developer Mode app)").Trim()
    }
    if (-not $Passphrase) { continue }
    Write-Host "  Fetching key from the TV..."
    $rc = Ares "ares-novacom" @("--device", $DeviceName, "--getkey", "--passphrase", $Passphrase)
    if ($rc -eq 0) {
        $rc = Ares "ares-device" @("--device", $DeviceName, "--system-info")
        if ($rc -eq 0) { $connected = $true; break }
    }
    Warn "Connection failed. The passphrase may be wrong or expired - check it in the Developer Mode app."
    $Passphrase = ""
}
if (-not $connected) { Fail "Could not connect to the TV after 3 attempts." }
Ok "Connected"

# ---------------------------------------------------------------- 5. Install
Step 5 "Installing the app on the TV"
$rc = Ares "ares-install" @("--device", $DeviceName, $Ipk)
if ($rc -ne 0) { Fail "Install failed (see the message above)." }
Ok "Installed"

$null = Ares "ares-launch" @("--device", $DeviceName, $AppId) -Quiet

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host "  Done! MyMoviz Plus is installed on the TV."   -ForegroundColor Green
Write-Host "  To update later, just run this again."        -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
exit 0
