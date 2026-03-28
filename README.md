<h1 align="center">SnapBack</h1>

<p align="center">
  <strong>Save & restore your entire Windows session with one command.</strong><br>
  <sub>Because life's too short to reopen 20 windows after every reboot.</sub>
</p>

<p align="center">
  <a href="README_CN.md">🇨🇳 中文</a> &nbsp;|&nbsp; 🇬🇧 English
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Windows%2010%2F11-0078D4?style=flat-square&logo=windows&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/PowerShell%205.1%2B-5391FE?style=flat-square&logo=powershell&logoColor=white" alt="PowerShell">
  <img src="https://img.shields.io/github/license/Liyue2341/SnapBack?style=flat-square" alt="License">
  <img src="https://img.shields.io/github/stars/Liyue2341/SnapBack?style=flat-square" alt="Stars">
</p>

---

## Quick Start

```powershell
# Install (one-time)
git clone https://github.com/Liyue2341/SnapBack.git
cd SnapBack && .\install.ps1

# Use (every time)
snapback save        # before reboot
snapback restore     # after reboot - everything comes back
```

That's it. Restart your terminal after install. Works from anywhere.

---

## What It Restores

🖥️ GUI apps (WeChat, browsers, etc.) &bull; ⌨️ Terminal processes (Python, Node, SSH, ngrok) &bull; 🤖 Claude Code (every instance, correct directory, multi-instance support) &bull; 📁 All open File Explorer windows

> Auto-start apps (PowerToys, OneDrive, Notion...) are automatically excluded.

---

## Demo

```
PS> snapback save

  Capturing running processes...
  Capturing Explorer windows...

  Snapshot saved: 2026-03-28_143022
  Processes captured: 14
  Explorer folders:  4
```

```
PS> snapback restore

  [OK]   Weixin
  [OK]   claude @ D:\Projects\my-app
  [OK]   claude @ D:\Projects\backend (1/2)
  [OK]   claude @ D:\Projects\backend (2/2)
  [OK]   python @ D:\Projects\backend
  [OK]   ssh @ D:\Projects\server

  Restoring Explorer folders...
  [OK]   D:\Projects\my-app
  [OK]   D:\Projects\backend

  Restore complete: Restored 8, Folders 2
```

---

## All Commands

| Command | What it does |
|:--------|:-------------|
| `snapback save` | Save current session |
| `snapback restore` | Restore latest snapshot |
| `snapback list` | List all snapshots |
| `snapback show` | Show snapshot details |
| `snapback save -Name dev` | Save with a custom name |
| `snapback restore -Name dev` | Restore a specific snapshot |
| `snapback delete -Name dev` | Delete a snapshot |

---

<details>
<summary><strong>How It Works (click to expand)</strong></summary>

### Save
1. Queries running processes via WMI/CIM, filters out system/child/auto-start processes
2. Detects **real working directories** by walking up the process tree to the parent shell and reading its CWD via the Windows PEB API (`NtQueryInformationProcess`)
3. Captures open File Explorer windows via COM `Shell.Application`
4. Saves everything as JSON

### Restore
1. GUI apps (browser, WeChat): skips if already running
2. CLI tools (claude, python, node): matches by command-line arguments, supports multi-instance
3. Relaunches each process with original arguments and working directory
4. Reopens all Explorer folder windows

### Architecture
```
SnapBack/
├── snapback.ps1       # CLI entry point
├── config.json        # Exclude lists & settings
├── install.ps1        # One-click global installer
└── lib/
    ├── Snapshot.ps1    # Process capture, CWD detection
    └── Restore.ps1    # Smart restore with duplicate detection
```
</details>

<details>
<summary><strong>Configuration (click to expand)</strong></summary>

Edit `config.json` to customize:

```jsonc
{
  "excludeProcesses": [...],       // System processes to ignore
  "autoStartProcesses": [...],     // Apps that restart on their own
  "excludeArgPatterns": [...],     // Filter by command-line patterns
  "maxSnapshots": 20,              // Auto-cleanup old snapshots
  "restoreDelayMs": 500,           // Delay between launches (ms)
  "confirmBeforeRestore": true     // Prompt before restoring
}
```
</details>

<details>
<summary><strong>Known Limitations</strong></summary>

- Terminal scrollback / command history is not preserved — only running processes
- Window positions and sizes are not restored (yet)
- Windows Terminal tabs restore as individual processes, not grouped tabs
- SSH sessions requiring interactive auth will prompt for credentials again

PRs and ideas welcome!
</details>

---

## Support

If SnapBack saved you from the _"15-minute workspace rebuild ritual"_:

<p align="center">
  <a href="https://buymeacoffee.com/liyue2341" target="_blank">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me Some Tokens" height="50">
  </a>
</p>

---

<p align="center">
  <a href="LICENSE">MIT License</a> &bull; Built with frustration and PowerShell<br>
  ⭐ Star if you've been there too
</p>
