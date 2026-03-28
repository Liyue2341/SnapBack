<#
.SYNOPSIS
    SnapBack - Save and restore your Windows session.

.DESCRIPTION
    Takes a snapshot of running programs before reboot,
    then restores them with a single command.

.EXAMPLE
    .\snapback.ps1 save
    .\snapback.ps1 restore
    .\snapback.ps1 list
    .\snapback.ps1 delete -Name "2024-01-15_143022"
    .\snapback.ps1 show -Name "2024-01-15_143022"
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("save", "restore", "list", "delete", "show", "help")]
    [string]$Command = "help",

    [Parameter()]
    [string]$Name,

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Load modules
. (Join-Path $PSScriptRoot "lib\Snapshot.ps1")
. (Join-Path $PSScriptRoot "lib\Restore.ps1")

# Load config
$Config = Get-SnapBackConfig -ConfigPath (Join-Path $PSScriptRoot "config.json")

# Banner
function Show-Banner {
    Write-Host ""
    Write-Host "  SnapBack" -ForegroundColor Cyan -NoNewline
    Write-Host " - Save & Restore your Windows session" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-Help {
    Show-Banner
    Write-Host "  Usage: snapback <command> [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "  Commands:" -ForegroundColor Cyan
    Write-Host "    save    [--Name <name>]    Save current session snapshot"
    Write-Host "    restore [--Name <name>]    Restore from snapshot (latest if no name)"
    Write-Host "    list                       List all saved snapshots"
    Write-Host "    show    [--Name <name>]    Show details of a snapshot"
    Write-Host "    delete  --Name <name>      Delete a snapshot"
    Write-Host "    help                       Show this help message"
    Write-Host ""
    Write-Host "  Examples:" -ForegroundColor Cyan
    Write-Host "    .\snapback.ps1 save                     # Quick save before reboot"
    Write-Host "    .\snapback.ps1 restore                  # Restore latest snapshot"
    Write-Host "    .\snapback.ps1 restore -Name my_setup   # Restore specific snapshot"
    Write-Host "    .\snapback.ps1 save -Name work_env      # Save with custom name"
    Write-Host ""
}

# Dispatch
Show-Banner

switch ($Command) {
    "save" {
        Save-Snapshot -Name $Name -Config $Config
    }
    "restore" {
        Restore-Snapshot -Name $Name -Config $Config -Force:$Force
    }
    "list" {
        Show-SnapshotList -Config $Config
    }
    "show" {
        if (-not $Name) {
            $snapshots = @(Get-SnapshotList -Config $Config)
            if ($snapshots.Count -gt 0) { $Name = $snapshots[0].Name }
        }
        if ($Name) {
            $filePath = Join-Path $Config.snapshotDir "$Name.json"
            if (Test-Path $filePath) {
                $data = Get-Content $filePath -Raw | ConvertFrom-Json
                Write-Host "  Snapshot: $Name" -ForegroundColor Cyan
                Write-Host "  Created:  $($data.timestamp)" -ForegroundColor DarkGray
                Write-Host "  Computer: $($data.computer)" -ForegroundColor DarkGray
                Write-Host ""
                Write-Host "  Processes:" -ForegroundColor Cyan
                foreach ($proc in $data.processes) {
                    $display = "    - $($proc.Name)"
                    if ($proc.InstanceCount -gt 1) { $display += " (x$($proc.InstanceCount))" }
                    if ($proc.MainWindowTitle) { $display += " [$($proc.MainWindowTitle)]" }
                    Write-Host $display -ForegroundColor White
                    if ($proc.WorkingDir) {
                        Write-Host "      dir: $($proc.WorkingDir)" -ForegroundColor DarkGray
                    }
                    if ($proc.Arguments) {
                        $argsDisplay = if ($proc.Arguments.Length -gt 80) { $proc.Arguments.Substring(0, 80) + "..." } else { $proc.Arguments }
                        Write-Host "      args: $argsDisplay" -ForegroundColor DarkGray
                    }
                }
                if ($data.explorerFolders -and $data.explorerFolders.Count -gt 0) {
                    Write-Host ""
                    Write-Host "  Explorer Folders:" -ForegroundColor Cyan
                    foreach ($folder in $data.explorerFolders) {
                        Write-Host "    - $folder" -ForegroundColor White
                    }
                }
                Write-Host ""
            }
            else {
                Write-Host "  Snapshot not found: $Name" -ForegroundColor Red
            }
        }
    }
    "delete" {
        Remove-Snapshot -Name $Name -Config $Config
    }
    "help" {
        Show-Help
    }
}
