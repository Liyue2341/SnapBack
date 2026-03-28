function Get-SnapshotList {
    <#
    .SYNOPSIS
        Lists all available snapshots.
    #>
    param(
        [object]$Config
    )

    if (-not $Config) { $Config = Get-SnapBackConfig }

    $snapshotDir = $Config.snapshotDir
    if (-not (Test-Path $snapshotDir)) {
        Write-Host "  No snapshots found. Run 'snapback save' first." -ForegroundColor Yellow
        return @()
    }

    $files = @(Get-ChildItem $snapshotDir -Filter "*.json" | Sort-Object LastWriteTime -Descending)
    if ($files.Count -eq 0) {
        Write-Host "  No snapshots found." -ForegroundColor Yellow
        return @()
    }

    $snapshots = @()
    foreach ($file in $files) {
        $data = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $processCount = if ($data.processes -is [array]) { $data.processes.Count } else { 1 }
        $snapshots += [PSCustomObject]@{
            Name      = $file.BaseName
            Timestamp = $data.timestamp
            Processes = $processCount
            File      = $file.FullName
        }
    }

    return $snapshots
}

function Show-SnapshotList {
    param(
        [object]$Config
    )

    $snapshots = Get-SnapshotList -Config $Config
    if ($snapshots.Count -eq 0) { return }

    Write-Host ""
    Write-Host "  Available Snapshots:" -ForegroundColor Cyan
    Write-Host "  $('-' * 60)" -ForegroundColor DarkGray

    $i = 1
    foreach ($snap in $snapshots) {
        $ts = [DateTime]::Parse($snap.Timestamp).ToString("yyyy-MM-dd HH:mm:ss")
        $marker = if ($i -eq 1) { " (latest)" } else { "" }
        Write-Host "  [$i] $($snap.Name)  |  $ts  |  $($snap.Processes) processes$marker" -ForegroundColor White
        $i++
    }
    Write-Host ""
}

function Restore-Snapshot {
    <#
    .SYNOPSIS
        Restores processes from a saved snapshot.
    #>
    param(
        [string]$Name,
        [object]$Config,
        [switch]$Force
    )

    if (-not $Config) { $Config = Get-SnapBackConfig }

    $snapshotDir = $Config.snapshotDir

    # If no name given, use the latest snapshot
    if (-not $Name) {
        $latest = Get-ChildItem $snapshotDir -Filter "*.json" |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1
        if (-not $latest) {
            Write-Host "  No snapshots found. Run 'snapback save' first." -ForegroundColor Red
            return
        }
        $Name = $latest.BaseName
    }

    $filePath = Join-Path $snapshotDir "$Name.json"
    if (-not (Test-Path $filePath)) {
        Write-Host "  Snapshot not found: $Name" -ForegroundColor Red
        Write-Host "  Use 'snapback list' to see available snapshots." -ForegroundColor Yellow
        return
    }

    $snapshot = Get-Content $filePath -Raw | ConvertFrom-Json
    $processes = $snapshot.processes

    $processCount = if ($processes -is [array]) { $processes.Count } else { 1 }
    Write-Host ""
    Write-Host "  Snapshot: $Name" -ForegroundColor Cyan
    Write-Host "  Created:  $($snapshot.timestamp)" -ForegroundColor DarkGray
    Write-Host "  Processes: $processCount" -ForegroundColor DarkGray
    Write-Host ""

    # GUI apps: skip if any instance is running (they manage their own state)
    # CLI tools: compare instance count, restore missing ones
    $guiApps = @('msedge', 'weixin', 'chrome', 'firefox', 'slack', 'discord', 'spotify', 'notion')

    # Show what will be restored
    Write-Host "  Programs to restore:" -ForegroundColor Cyan
    foreach ($proc in $processes) {
        $display = "    - $($proc.Name)"
        if ($proc.MainWindowTitle) { $display += " [$($proc.MainWindowTitle)]" }
        if ($proc.WorkingDir) { $display += "  @ $($proc.WorkingDir)" }
        Write-Host $display -ForegroundColor White
    }
    Write-Host ""

    # Confirm unless forced
    if ($Config.confirmBeforeRestore -and -not $Force) {
        $confirm = Read-Host "  Restore these programs? [Y/n]"
        if ($confirm -and $confirm.ToLower() -ne 'y') {
            Write-Host "  Restore cancelled." -ForegroundColor Yellow
            return
        }
    }

    # Pre-fetch all running processes once (avoid repeated CIM queries)
    Write-Host "  Checking running processes..." -ForegroundColor DarkGray
    $liveProcesses = @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath } |
        Select-Object Name, ProcessId, CommandLine, ExecutablePath)

    # Restore each process
    $restored = 0
    $failed = 0
    $skipped = 0

    foreach ($proc in $processes) {
        $exePath = $proc.ExecutablePath
        $nameLower = $proc.Name.ToLower()
        $displayName = $proc.Name
        if ($proc.WorkingDir) { $displayName += " @ $($proc.WorkingDir)" }

        # Check if executable still exists
        if (-not (Test-Path $exePath)) {
            Write-Host "  [SKIP] $displayName - executable not found" -ForegroundColor Yellow
            $skipped++
            continue
        }

        # For GUI apps: skip if any instance is running (by process name)
        if ($nameLower -in $guiApps) {
            $running = $liveProcesses | Where-Object { ($_.Name -replace '\.exe$','').ToLower() -eq $nameLower }
            if ($running) {
                Write-Host "  [SKIP] $displayName - already running" -ForegroundColor DarkGray
                $skipped++
                continue
            }
        }

        # For CLI tools: match by arguments appearing in any live process's CommandLine
        if ($nameLower -notin $guiApps) {
            $snapshotArgs = if ($proc.Arguments) { $proc.Arguments.Trim() } else { "" }
            $snapCmdLine = if ($proc.CommandLine) { $proc.CommandLine.Trim() } else { "" }

            $running = $liveProcesses | Where-Object {
                $_.Name -eq $proc.ProcessName
            } | Where-Object {
                $liveCmdLine = if ($_.CommandLine) { $_.CommandLine.Trim() } else { "" }
                # Match by: exact cmdline, OR args substring, OR same exe path + same args
                if ($snapCmdLine -and $liveCmdLine -eq $snapCmdLine) { return $true }
                if ($snapshotArgs -and $liveCmdLine.Contains($snapshotArgs)) { return $true }
                return $false
            }
            if ($running) {
                Write-Host "  [SKIP] $displayName - already running" -ForegroundColor DarkGray
                $skipped++
                continue
            }
        }

        try {
            $startParams = @{
                FilePath = $exePath
            }

            # Pass Arguments as a single string (not array) so it's forwarded as-is
            if ($proc.Arguments) {
                $startParams["ArgumentList"] = @($proc.Arguments)
            }

            if ($proc.WorkingDir -and (Test-Path $proc.WorkingDir)) {
                $startParams["WorkingDirectory"] = $proc.WorkingDir
            }

            $count = if ($proc.InstanceCount -and $proc.InstanceCount -gt 1) { $proc.InstanceCount } else { 1 }
            for ($i = 0; $i -lt $count; $i++) {
                Start-Process @startParams
                if ($count -gt 1) {
                    Write-Host "  [OK]   $displayName ($($i+1)/$count)" -ForegroundColor Green
                }
                else {
                    Write-Host "  [OK]   $displayName" -ForegroundColor Green
                }
                $restored++

                # Delay between launches to avoid overwhelming the system
                if ($Config.restoreDelayMs -gt 0) {
                    Start-Sleep -Milliseconds $Config.restoreDelayMs
                }
            }
        }
        catch {
            Write-Host "  [FAIL] $displayName - $($_.Exception.Message)" -ForegroundColor Red
            $failed++
        }
    }

    # Restore Explorer folders
    $folderRestored = 0
    if ($snapshot.explorerFolders) {
        Write-Host ""
        Write-Host "  Restoring Explorer folders..." -ForegroundColor Cyan
        foreach ($folder in $snapshot.explorerFolders) {
            if (Test-Path $folder) {
                Start-Process explorer.exe -ArgumentList "`"$folder`""
                Write-Host "  [OK]   $folder" -ForegroundColor Green
                $folderRestored++
                Start-Sleep -Milliseconds 300
            }
            else {
                Write-Host "  [SKIP] $folder - folder not found" -ForegroundColor Yellow
            }
        }
    }

    Write-Host ""
    Write-Host "  Restore complete:" -ForegroundColor Cyan
    Write-Host "    Restored: $restored" -ForegroundColor Green
    if ($folderRestored -gt 0) {
        Write-Host "    Folders:  $folderRestored" -ForegroundColor Green
    }
    Write-Host "    Skipped:  $skipped" -ForegroundColor Yellow
    Write-Host "    Failed:   $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "DarkGray" })
}

function Remove-Snapshot {
    <#
    .SYNOPSIS
        Deletes a saved snapshot.
    #>
    param(
        [string]$Name,
        [object]$Config
    )

    if (-not $Config) { $Config = Get-SnapBackConfig }

    if (-not $Name) {
        Write-Host "  Please specify a snapshot name. Use 'snapback list' to see available snapshots." -ForegroundColor Yellow
        return
    }

    $filePath = Join-Path $Config.snapshotDir "$Name.json"
    if (-not (Test-Path $filePath)) {
        Write-Host "  Snapshot not found: $Name" -ForegroundColor Red
        return
    }

    Remove-Item $filePath -Force
    Write-Host "  Deleted snapshot: $Name" -ForegroundColor Green
}
