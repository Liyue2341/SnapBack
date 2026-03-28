# SnapBack

Save and restore your Windows desktop session with one command.

SnapBack takes a snapshot of your running programs, terminal windows, and working directories before a reboot, then restores everything with a single command afterward.

## Features

- **Snapshot** current running processes (paths, arguments, working directories)
- **Restore** all programs from a saved snapshot
- **List** and manage multiple snapshots
- **Exclude** system processes automatically (configurable)
- **Windows Terminal** tab/pane awareness (planned)

## Requirements

- Windows 10/11
- PowerShell 5.1+ (pre-installed on Windows)

## Quick Start

```powershell
# Save current session before reboot
.\snapback.ps1 save

# After reboot, restore everything
.\snapback.ps1 restore

# List saved snapshots
.\snapback.ps1 list

# Restore a specific snapshot
.\snapback.ps1 restore -Name "2024-01-15_143022"

# Delete a snapshot
.\snapback.ps1 delete -Name "2024-01-15_143022"
```

## Installation

```powershell
git clone https://github.com/YOUR_USERNAME/SnapBack.git
cd SnapBack

# Optional: add to PATH for global access
.\install.ps1
```

## Configuration

Edit `config.json` to customize behavior:

```json
{
  "snapshotDir": "~/.snapback/snapshots",
  "excludeProcesses": ["svchost", "csrss", "System", ...],
  "excludePaths": ["C:\\Windows\\*"],
  "maxSnapshots": 10
}
```

## How It Works

1. **Save**: Enumerates all user-visible processes, captures their executable path, command-line arguments, and working directory, then writes a JSON snapshot file.
2. **Restore**: Reads the snapshot and re-launches each process with its original arguments and working directory.

## License

MIT License - see [LICENSE](LICENSE) for details.
