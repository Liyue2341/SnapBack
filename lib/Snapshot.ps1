function Get-SnapBackConfig {
    param(
        [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config.json")
    )
    $raw = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $raw.snapshotDir = [Environment]::ExpandEnvironmentVariables($raw.snapshotDir)
    return $raw
}

# --- CWD Detection via Windows API ---
function Initialize-CwdReader {
    <#
    .SYNOPSIS
        Loads native Windows API functions to read the current working directory
        of another process via its PEB (Process Environment Block).
    #>
    if (-not ([System.Management.Automation.PSTypeName]'SnapBack.ProcessCwd').Type) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace SnapBack {
    public class ProcessCwd {
        [DllImport("ntdll.dll")]
        static extern int NtQueryInformationProcess(
            IntPtr processHandle, int processInformationClass,
            ref PROCESS_BASIC_INFORMATION pbi, int processInformationLength, ref int returnLength);

        [DllImport("kernel32.dll")]
        static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

        [DllImport("kernel32.dll")]
        static extern bool ReadProcessMemory(
            IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, int dwSize, ref int lpNumberOfBytesRead);

        [DllImport("kernel32.dll")]
        static extern bool CloseHandle(IntPtr hObject);

        [DllImport("kernel32.dll")]
        static extern bool IsWow64Process(IntPtr hProcess, out bool wow64Process);

        [StructLayout(LayoutKind.Sequential)]
        struct PROCESS_BASIC_INFORMATION {
            public IntPtr Reserved1;
            public IntPtr PebBaseAddress;
            public IntPtr Reserved2_0;
            public IntPtr Reserved2_1;
            public IntPtr UniqueProcessId;
            public IntPtr Reserved3;
        }

        const uint PROCESS_QUERY_INFORMATION = 0x0400;
        const uint PROCESS_VM_READ = 0x0010;

        public static string GetCwd(int pid) {
            try {
                IntPtr hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, false, pid);
                if (hProcess == IntPtr.Zero) return null;

                try {
                    // Check if target is 32-bit on 64-bit OS
                    bool isWow64 = false;
                    IsWow64Process(hProcess, out isWow64);
                    if (isWow64) return null; // Skip 32-bit processes for safety

                    // Get PEB address
                    PROCESS_BASIC_INFORMATION pbi = new PROCESS_BASIC_INFORMATION();
                    int returnLength = 0;
                    int status = NtQueryInformationProcess(hProcess, 0, ref pbi, Marshal.SizeOf(pbi), ref returnLength);
                    if (status != 0) return null;

                    // Read ProcessParameters pointer from PEB (offset 0x20 on x64)
                    byte[] buffer = new byte[8];
                    int bytesRead = 0;
                    IntPtr paramAddr = IntPtr.Add(pbi.PebBaseAddress, 0x20);
                    if (!ReadProcessMemory(hProcess, paramAddr, buffer, 8, ref bytesRead)) return null;
                    IntPtr processParams = (IntPtr)BitConverter.ToInt64(buffer, 0);

                    // Read CurrentDirectory.DosPath UNICODE_STRING (offset 0x38 on x64)
                    // UNICODE_STRING: ushort Length, ushort MaxLength, padding, IntPtr Buffer
                    byte[] uniStr = new byte[16];
                    IntPtr cwdAddr = IntPtr.Add(processParams, 0x38);
                    if (!ReadProcessMemory(hProcess, cwdAddr, uniStr, 16, ref bytesRead)) return null;

                    ushort length = BitConverter.ToUInt16(uniStr, 0);
                    IntPtr cwdBuffer = (IntPtr)BitConverter.ToInt64(uniStr, 8);

                    if (length == 0 || cwdBuffer == IntPtr.Zero) return null;

                    // Read the actual path string
                    byte[] pathBytes = new byte[length];
                    if (!ReadProcessMemory(hProcess, cwdBuffer, pathBytes, length, ref bytesRead)) return null;

                    string path = Encoding.Unicode.GetString(pathBytes).TrimEnd('\\');
                    return path;
                }
                finally {
                    CloseHandle(hProcess);
                }
            }
            catch {
                return null;
            }
        }
    }
}
"@
    }
}

function Get-ProcessCwd {
    param([int]$ProcessId)
    try {
        $cwd = [SnapBack.ProcessCwd]::GetCwd($ProcessId)
        if ($cwd -and (Test-Path $cwd)) { return $cwd }
    }
    catch { }
    return $null
}

function Get-ShellCwd {
    <#
    .SYNOPSIS
        Walks up the process tree to find the parent shell (powershell, cmd, bash)
        and returns its CWD. This gives us the directory the user cd'd to,
        not the exe's own directory.
    #>
    param(
        [int]$ProcessId,
        [hashtable]$ProcessMap
    )

    $shellNames = @('powershell.exe', 'pwsh.exe', 'cmd.exe', 'bash.exe')
    $visited = @{}
    $currentPid = $ProcessId

    # Walk up parent chain (max 10 levels to avoid infinite loops)
    for ($i = 0; $i -lt 10; $i++) {
        if ($visited.ContainsKey($currentPid)) { break }
        $visited[$currentPid] = $true

        if (-not $ProcessMap.ContainsKey($currentPid)) { break }
        $parentPid = $ProcessMap[$currentPid]
        if ($parentPid -eq 0 -or $parentPid -eq $currentPid) { break }

        # Check if parent is a shell
        $parentProc = Get-CimInstance Win32_Process -Filter "ProcessId = $parentPid" -ErrorAction SilentlyContinue
        if ($parentProc -and $parentProc.Name -in $shellNames) {
            $cwd = Get-ProcessCwd -ProcessId $parentPid
            if ($cwd) { return $cwd }
        }

        $currentPid = $parentPid
    }

    return $null
}

function Get-RunningUserProcesses {
    <#
    .SYNOPSIS
        Captures user-launched, main processes only.
        Filters out child/sub-processes, auto-start services, and system noise.
    #>
    param(
        [object]$Config
    )

    $excludeNames = $Config.excludeProcesses | ForEach-Object { $_.ToLower() }
    $excludePaths = $Config.excludePaths
    $autoStartNames = $Config.autoStartProcesses | ForEach-Object { $_.ToLower() }
    $excludeArgPatterns = if ($Config.excludeArgPatterns) { $Config.excludeArgPatterns } else { @() }

    # Built-in patterns that indicate a child/sub-process
    $childProcessArgs = @(
        '--type=renderer',
        '--type=gpu-process',
        '--type=crashpad-handler',
        '--type=utility',
        '--type=broker',
        '--type=zygote',
        '--type=ppapi',
        '/prefetch:',
        '--monitor-self-annotation=ptype=crashpad-handler'
    )

    # Initialize CWD reader
    Initialize-CwdReader

    # CLI process names that should inherit CWD from parent shell
    $cliProcessNames = @('python', 'node', 'ngrok', 'ssh', 'claude', 'npm', 'npx', 'cargo', 'go', 'ruby', 'java')

    # Use CIM to get process details including CommandLine
    $allCimProcs = Get-CimInstance Win32_Process
    # Build PID -> ParentPID map for tree walking
    $parentMap = @{}
    foreach ($p in $allCimProcs) {
        $parentMap[$p.ProcessId] = $p.ParentProcessId
    }

    $processes = $allCimProcs | Where-Object {
        $_.ExecutablePath
    } | Where-Object {
        $owner = Invoke-CimMethod -InputObject $_ -MethodName GetOwner -ErrorAction SilentlyContinue
        $owner -and $owner.User -eq $env:USERNAME
    }

    $result = @()

    foreach ($proc in $processes) {
        $name = $proc.Name -replace '\.exe$', ''
        $nameLower = $name.ToLower()
        $cmdLine = if ($proc.CommandLine) { $proc.CommandLine } else { "" }

        # --- Filter 1: Excluded process names ---
        if ($nameLower -in $excludeNames) { continue }

        # --- Filter 2: Excluded paths ---
        $skipPath = $false
        foreach ($pattern in $excludePaths) {
            $expandedPattern = [Environment]::ExpandEnvironmentVariables($pattern)
            if ($proc.ExecutablePath -like $expandedPattern) {
                $skipPath = $true
                break
            }
        }
        if ($skipPath) { continue }

        # --- Filter 3: Child/sub-processes (renderers, GPU, crashpad, etc.) ---
        $isChild = $false
        foreach ($pattern in $childProcessArgs) {
            if ($cmdLine -like "*$pattern*") {
                $isChild = $true
                break
            }
        }
        if ($isChild) { continue }

        # --- Filter 4: Auto-start programs (they restart on their own) ---
        if ($nameLower -in $autoStartNames) { continue }

        # --- Filter 5: Exclude by executable path patterns ---
        $matchedPathPattern = $false
        $excludePathPatterns = if ($Config.excludePathPatterns) { $Config.excludePathPatterns } else { @() }
        foreach ($pattern in $excludePathPatterns) {
            if ($proc.ExecutablePath -like $pattern) {
                $matchedPathPattern = $true
                break
            }
        }
        if ($matchedPathPattern) { continue }

        # --- Filter 6: Custom argument patterns from config ---
        $matchedArgPattern = $false
        foreach ($pattern in $excludeArgPatterns) {
            if ($cmdLine -like "*$pattern*") {
                $matchedArgPattern = $true
                break
            }
        }
        if ($matchedArgPattern) { continue }

        # Extract arguments from CommandLine
        $arguments = ""
        if ($cmdLine) {
            if ($cmdLine.StartsWith('"')) {
                $endQuote = $cmdLine.IndexOf('"', 1)
                if ($endQuote -gt 0 -and $endQuote + 1 -lt $cmdLine.Length) {
                    $arguments = $cmdLine.Substring($endQuote + 1).TrimStart()
                }
            }
            else {
                $spaceIdx = $cmdLine.IndexOf(' ')
                if ($spaceIdx -gt 0) {
                    $arguments = $cmdLine.Substring($spaceIdx + 1).TrimStart()
                }
            }
        }

        # Working directory detection:
        # For CLI tools (python, node, etc.), the process's own CWD is often
        # the exe directory (e.g. .venv\Scripts), not where the user ran the command.
        # So we walk up to the parent shell (powershell/cmd/bash) and use ITS CWD.
        $workingDir = $null
        if ($nameLower -in $cliProcessNames) {
            $workingDir = Get-ShellCwd -ProcessId $proc.ProcessId -ProcessMap $parentMap
        }
        # Fallback: process's own CWD
        if (-not $workingDir) {
            $workingDir = Get-ProcessCwd -ProcessId $proc.ProcessId
        }
        # Final fallback: exe directory
        if (-not $workingDir) {
            $workingDir = Split-Path $proc.ExecutablePath -Parent
        }

        # Window title
        $windowTitle = ""
        try {
            $liveProc = Get-Process -Id $proc.ProcessId -ErrorAction SilentlyContinue
            if ($liveProc.MainWindowTitle) {
                $windowTitle = $liveProc.MainWindowTitle
            }
        }
        catch { }

        $entry = [PSCustomObject]@{
            Name            = $name
            ProcessName     = $proc.Name
            ProcessId       = $proc.ProcessId
            ExecutablePath  = $proc.ExecutablePath
            CommandLine     = $cmdLine
            Arguments       = $arguments
            WorkingDir      = $workingDir
            MainWindowTitle = $windowTitle
        }

        $result += $entry
    }

    # --- Post-processing: collapse GUI app process trees ---
    $mainApps = @{}
    $nonAppProcesses = @()

    # GUI apps: only keep main process. CLI tools: keep every instance.
    $guiApps = @('msedge', 'weixin', 'notion', 'slack', 'discord', 'spotify', 'code', 'chrome', 'firefox')

    foreach ($entry in $result) {
        $nameLower = $entry.Name.ToLower()
        if ($nameLower -in $guiApps) {
            if (-not $mainApps.ContainsKey($nameLower)) {
                $mainApps[$nameLower] = @()
            }
            $mainApps[$nameLower] += $entry
        }
        else {
            $nonAppProcesses += $entry
        }
    }

    # For each GUI app, pick only the main process
    $mainEntries = @()
    foreach ($appName in $mainApps.Keys) {
        $instances = $mainApps[$appName]
        $withTitle = $instances | Where-Object { $_.MainWindowTitle }
        if ($withTitle) {
            $mainEntries += ($withTitle | Select-Object -First 1)
        }
        else {
            $mainEntries += ($instances | Sort-Object { $_.Arguments.Length } | Select-Object -First 1)
        }
    }

    $combined = $mainEntries + $nonAppProcesses

    # Deduplicate by Name + Arguments + WorkingDir (so same command in different dirs survives)
    $grouped = $combined | Group-Object { "$($_.Name)|$($_.Arguments)|$($_.WorkingDir)" }
    $deduped = @($grouped | ForEach-Object {
        $item = $_.Group[0]
        $item | Add-Member -NotePropertyName "InstanceCount" -NotePropertyValue $_.Count -Force
        # Remove ProcessId from final output (not useful for restore)
        $item.PSObject.Properties.Remove('ProcessId')
        $item
    })

    return $deduped
}

function Get-OpenExplorerWindows {
    <#
    .SYNOPSIS
        Gets all open File Explorer windows and their folder paths.
    #>
    $folders = @()
    try {
        $shell = New-Object -ComObject Shell.Application
        $shell.Windows() | ForEach-Object {
            $url = $_.LocationURL
            if ($url) {
                # Convert file:///C:/path to C:\path
                $path = [Uri]::UnescapeDataString($url) -replace '^file:///', '' -replace '/', '\'
                if ($path -and (Test-Path $path)) {
                    $folders += $path
                }
            }
        }
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
    }
    catch { }
    return $folders
}

function Save-Snapshot {
    <#
    .SYNOPSIS
        Takes a snapshot of the current session and saves it as JSON.
    #>
    param(
        [string]$Name,
        [object]$Config
    )

    if (-not $Config) { $Config = Get-SnapBackConfig }

    # Create snapshot directory if needed
    $snapshotDir = $Config.snapshotDir
    if (-not (Test-Path $snapshotDir)) {
        New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
    }

    # Generate snapshot name
    if (-not $Name) {
        $Name = Get-Date -Format "yyyy-MM-dd_HHmmss"
    }

    Write-Host "  Capturing running processes..." -ForegroundColor Cyan
    $processes = Get-RunningUserProcesses -Config $Config

    Write-Host "  Capturing Explorer windows..." -ForegroundColor Cyan
    $explorerFolders = @(Get-OpenExplorerWindows)

    $snapshot = [PSCustomObject]@{
        name            = $Name
        timestamp       = (Get-Date).ToString("o")
        computer        = $env:COMPUTERNAME
        user            = $env:USERNAME
        processes       = $processes
        explorerFolders = $explorerFolders
    }

    $filePath = Join-Path $snapshotDir "$Name.json"
    $snapshot | ConvertTo-Json -Depth 5 | Set-Content $filePath -Encoding UTF8

    # Enforce maxSnapshots limit
    $allSnapshots = Get-ChildItem $snapshotDir -Filter "*.json" | Sort-Object LastWriteTime
    $excess = $allSnapshots.Count - $Config.maxSnapshots
    if ($excess -gt 0) {
        $allSnapshots | Select-Object -First $excess | ForEach-Object {
            Remove-Item $_.FullName -Force
            Write-Host "  Removed old snapshot: $($_.BaseName)" -ForegroundColor DarkGray
        }
    }

    $processCount = if ($processes -is [array]) { $processes.Count } else { 1 }
    $folderCount = $explorerFolders.Count
    Write-Host ""
    Write-Host "  Snapshot saved: $Name" -ForegroundColor Green
    Write-Host "  Processes captured: $processCount" -ForegroundColor Green
    Write-Host "  Explorer folders:  $folderCount" -ForegroundColor Green
    Write-Host "  Location: $filePath" -ForegroundColor DarkGray

    return $filePath
}
