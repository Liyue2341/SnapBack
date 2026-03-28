<#
.SYNOPSIS
    Installs SnapBack by adding it to the user's PATH and creating a global alias.
#>

$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$snapbackPath = Join-Path $scriptDir "snapback.ps1"

if (-not (Test-Path $snapbackPath)) {
    Write-Host "Error: snapback.ps1 not found in $scriptDir" -ForegroundColor Red
    exit 1
}

# Create a wrapper batch file in a PATH-accessible location
$binDir = Join-Path $env:USERPROFILE ".snapback\bin"
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
}

# Create snapback.cmd wrapper
$cmdWrapper = @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "$snapbackPath" %*
"@
Set-Content (Join-Path $binDir "snapback.cmd") $cmdWrapper -Encoding ASCII

# Add to user PATH if not already there
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
    Write-Host ""
    Write-Host "  SnapBack installed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Added to PATH: $binDir" -ForegroundColor DarkGray
    Write-Host "  Please restart your terminal for PATH changes to take effect." -ForegroundColor Yellow
    Write-Host ""
}
else {
    Write-Host ""
    Write-Host "  SnapBack is already installed." -ForegroundColor Green
    Write-Host "  Wrapper updated at: $binDir\snapback.cmd" -ForegroundColor DarkGray
    Write-Host ""
}

Write-Host "  Usage:" -ForegroundColor Cyan
Write-Host "    snapback save       # Save current session"
Write-Host "    snapback restore    # Restore after reboot"
Write-Host "    snapback list       # List snapshots"
Write-Host ""
