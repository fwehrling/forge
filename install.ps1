#Requires -Version 5.1
# FORGE Installer for Windows
# Detects WSL, offers to install it if missing, then runs install.sh inside WSL.
#
# Usage (PowerShell):
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\install.ps1
#
# Usage (CMD):
#   powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

function Write-Step { param($n, $msg) Write-Host "  [$n] $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg)     Write-Host "  ok  $msg" -ForegroundColor Green }
function Write-Warn { param($msg)     Write-Host "  !   $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg)     Write-Host "  x   $msg" -ForegroundColor Red }
function Write-Info { param($msg)     Write-Host "  --> $msg" -ForegroundColor Blue }

Write-Host ""
Write-Host "  FORGE -- Windows Installer" -ForegroundColor Cyan
Write-Host "  Framework for Orchestrated Resilient Generative Engineering"
Write-Host ""

# ── [1/3] Check Windows version ───────────────────────────────────────────────

Write-Step "1/3" "Checking Windows version..."

$winBuild = [System.Environment]::OSVersion.Version.Build
if ($winBuild -lt 19041) {
    Write-Err "Windows 10 version 2004 (build 19041+) required for WSL."
    Write-Err "Current build: $winBuild -- Please update Windows and retry."
    exit 1
}
Write-Ok "Windows build $winBuild -- OK"

# ── [2/3] Detect WSL and installed distributions ──────────────────────────────

Write-Step "2/3" "Checking WSL..."

$wslCmd      = Get-Command wsl -ErrorAction SilentlyContinue
$wslPresent  = $null -ne $wslCmd
$hasDistro   = $false

if ($wslPresent) {
    try {
        # wsl --list --quiet output can contain Unicode null bytes on some versions
        $raw = wsl --list --quiet 2>&1
        $hasDistro = ($raw | Where-Object { $_ -match '\w' }) .Count -gt 0
    } catch {
        $hasDistro = $false
    }
}

# ── [3/3] Install WSL if needed, then run FORGE ───────────────────────────────

if (-not $wslPresent -or -not $hasDistro) {

    if (-not $wslPresent) {
        Write-Warn "WSL is not installed."
    } else {
        Write-Warn "WSL is installed but no Linux distribution is configured."
    }

    Write-Host ""
    Write-Info "FORGE requires WSL to run on Windows."
    Write-Info "This will install WSL with Ubuntu (default)."
    Write-Info "A reboot will be required to complete WSL setup."
    Write-Host ""

    $answer = Read-Host "  Install WSL now? [Y/N]"
    if ($answer -notmatch '^[Yy]') {
        Write-Info "Cancelled. Install WSL manually:"
        Write-Info "  https://learn.microsoft.com/en-us/windows/wsl/install"
        exit 0
    }

    # Need admin rights to enable WSL feature
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if (-not $isAdmin) {
        Write-Warn "Administrator rights required. Relaunching as Administrator..."
        $scriptPath = $MyInvocation.MyCommand.Path
        if (-not $scriptPath) {
            Write-Err "Cannot determine script path. Run this script as Administrator manually."
            exit 1
        }
        Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`""
        exit 0
    }

    Write-Info "Running: wsl --install ..."
    wsl --install

    Write-Host ""
    Write-Ok "WSL installation started."
    Write-Host ""
    Write-Info "Next steps:"
    Write-Info "  1. Reboot your machine"
    Write-Info "  2. Ubuntu will open automatically -- set your Linux username and password"
    Write-Info "  3. Run this script again: .\install.ps1"
    Write-Host ""

    $reboot = Read-Host "  Reboot now? [Y/N]"
    if ($reboot -match '^[Yy]') {
        Restart-Computer -Force
    }
    exit 0
}

Write-Ok "WSL ready"
Write-Host ""
Write-Step "3/3" "Launching FORGE installer inside WSL..."
Write-Host ""

# Run install.sh from GitHub inside WSL
# Using a temp path accessible from WSL (/tmp)
$installScript = @'
set -e
FORGE_TMP="/tmp/forge-windows-install"
rm -rf "$FORGE_TMP"
git clone --depth 1 https://github.com/fwehrling/forge.git "$FORGE_TMP"
bash "$FORGE_TMP/install.sh"
rm -rf "$FORGE_TMP"
'@

wsl bash -c $installScript

Write-Host ""
Write-Ok "FORGE installation complete!"
Write-Info "Open a WSL terminal (search 'Ubuntu' in Start menu) to use FORGE in your projects."
Write-Host ""
