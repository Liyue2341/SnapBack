<h1 align="center">
  <br>
  SnapBack
  <br>
</h1>

<h4 align="center">Save & restore your entire Windows session with one command.</h4>

<p align="center">
  Because life's too short to reopen 20 windows after every reboot.
</p>

<p align="center">
  <a href="README_CN.md">🇨🇳 中文</a> &nbsp;|&nbsp; 🇬🇧 English
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-Windows%2010%2F11-0078D4?style=flat-square&logo=windows&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell&logoColor=white" alt="PowerShell">
  <img src="https://img.shields.io/github/license/Liyue2341/SnapBack?style=flat-square" alt="License">
  <img src="https://img.shields.io/github/stars/Liyue2341/SnapBack?style=flat-square" alt="Stars">
</p>

---

## The Problem

You know the drill:

> 4 terminals running servers. 3 Claude Code sessions across different projects. WeChat open. A dozen browser tabs. File Explorer windows everywhere.
>
> Then Windows says: **"Restart to finish installing updates."**

You restart. **Everything's gone.** Now you spend 15 minutes rebuilding your workspace from memory. _Every. Single. Time._

## The Solution

```powershell
snapback save        # before reboot - takes 3 seconds
# ... reboot ...
snapback restore     # after reboot - everything comes back
```

That's it. Seriously.

---

## What Gets Saved

| Category | What's Captured |
|:---------|:---------------|
| 🖥️ **GUI Apps** | WeChat, browsers, MarkView, etc. |
| ⌨️ **Terminal Processes** | Python servers, Node.js, SSH sessions, ngrok tunnels |
| 🤖 **Claude Code** | Every instance, in the correct project directory, supports multiple instances per folder |
| 📁 **File Explorer** | All open folder windows |
| 📂 **Working Directories** | Real CWD via Windows PEB API + parent shell walking |

> Auto-start programs (PowerToys, OneDrive, Notion...) are automatically excluded - they restart on their own.

---

## Demo

**`snapback save`** — snapshot your workspace:
```
PS C:\> snapback save

  SnapBack - Save & Restore your Windows session

  Capturing running processes...
  Capturing Explorer windows...

  Snapshot saved: 2026-03-28_143022
  Processes captured: 14
  Explorer folders:  4
```

**`snapback restore`** — bring everything back:
```
PS C:\> snapback restore

  Programs to restore:
    - Weixin       @ C:\Program Files (x86)\Tencent\Weixin
    - claude       @ D:\Projects\my-app
    - claude (x2)  @ D:\Projects\backend
    - python       @ D:\Projects\backend
    - ssh          @ D:\Projects\server
    - markview     @ D:\Research\paper

  Restore these programs? [Y/n] Y

  [OK]   Weixin
  [OK]   claude @ D:\Projects\my-app
  [OK]   claude @ D:\Projects\backend (1/2)
  [OK]   claude @ D:\Projects\backend (2/2)
  [OK]   python @ D:\Projects\backend
  [OK]   ssh @ D:\Projects\server
  [OK]   markview @ D:\Research\paper

  Restoring Explorer folders...
  [OK]   D:\Projects\my-app
  [OK]   D:\Projects\backend

  Restore complete:
    Restored: 8
    Folders:  2
    Skipped:  0
    Failed:   0
```

**`snapback list`** — manage your snapshots:
```
PS C:\> snapback list

  Available Snapshots:
  ------------------------------------------------------------
  [1] work_env     |  2026-03-28 14:30:22  |  14 processes (latest)
  [2] before_update|  2026-03-27 09:15:03  |  11 processes
```

---

## Installation

```powershell
git clone https://github.com/Liyue2341/SnapBack.git
cd SnapBack
.\install.ps1       # adds 'snapback' to your PATH
```

Restart your terminal. Done. Use `snapback` from anywhere.

> **Requirements:** Windows 10/11 + PowerShell 5.1+ (pre-installed on all modern Windows)

---

## All Commands

| Command | Description |
|:--------|:------------|
| `snapback save` | Save current session |
| `snapback restore` | Restore latest snapshot |
| `snapback list` | List all snapshots |
| `snapback show` | Show snapshot details |
| `snapback save -Name work` | Save with custom name |
| `snapback restore -Name work` | Restore specific snapshot |
| `snapback delete -Name work` | Delete a snapshot |
| `snapback help` | Show help |

---

## How It Works

### Save
1. Queries all running processes via WMI/CIM
2. Filters out system processes, child processes (renderers, GPU, crashpad), and auto-start apps
3. Detects **real working directories** by walking up the process tree to the parent shell and reading its CWD via the Windows PEB API (`NtQueryInformationProcess`)
4. Captures open File Explorer windows via COM `Shell.Application`
5. Saves everything as a JSON snapshot

### Restore
1. Pre-fetches all running processes for fast matching
2. **GUI apps** (browser, WeChat): skips if any instance is already running
3. **CLI tools** (claude, python, node): matches by exact command-line, supports multi-instance restore
4. Relaunches each process with original arguments and working directory
5. Reopens all Explorer folder windows

### Architecture
```
SnapBack/
├── snapback.ps1          # CLI entry point
├── config.json           # Exclude lists & settings
├── install.ps1           # One-click global installer
└── lib/
    ├── Snapshot.ps1      # Process capture, CWD detection, Explorer capture
    └── Restore.ps1       # Smart restore with duplicate detection
```

---

## Configuration

Edit `config.json` to customize:

```jsonc
{
  "excludeProcesses": [...],       // System processes to always ignore
  "autoStartProcesses": [...],     // Apps that restart on their own
  "excludeArgPatterns": [...],     // Filter by command-line patterns
  "excludePathPatterns": [...],    // Filter by executable path
  "maxSnapshots": 20,              // Auto-cleanup old snapshots
  "restoreDelayMs": 500,           // Delay between launches (ms)
  "confirmBeforeRestore": true     // Prompt before restoring
}
```

---

## Known Limitations

- Terminal **scrollback / command history** is not preserved — only running processes
- **Window positions and sizes** are not restored (yet)
- **Windows Terminal tabs** restore as individual processes, not grouped tabs
- SSH sessions requiring interactive auth will prompt for credentials again

PRs and ideas welcome!

---

## Support the Project

If SnapBack saved you from the _"15-minute workspace rebuild ritual,"_ consider supporting the project:

<p align="center">
  <a href="https://buymeacoffee.com/liyue2341" target="_blank">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me Some Tokens" height="60">
  </a>
</p>

<p align="center">
  <sub>Every token helps fuel more open-source tools. Thank you! 🪙</sub>
</p>

---

## License

[MIT](LICENSE) — use it, fork it, improve it.

<p align="center">
  <sub>Built with frustration and PowerShell.<br>⭐ Star this repo if you've been there too.</sub>
</p>
