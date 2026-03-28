<p align="center">
  <h1 align="center">SnapBack</h1>
  <p align="center">
    <strong>Save & restore your entire Windows session with one command.</strong><br>
    Because life's too short to reopen 20 windows after every reboot.
  </p>
  <p align="center">
    <a href="#installation">Install</a> &bull;
    <a href="#quick-start">Quick Start</a> &bull;
    <a href="#how-it-works">How It Works</a> &bull;
    <a href="#%E4%B8%AD%E6%96%87%E8%AF%B4%E6%98%8E">中文说明</a>
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/platform-Windows%2010%2F11-blue?logo=windows" alt="Platform">
    <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white" alt="PowerShell">
    <img src="https://img.shields.io/github/license/Liyue2341/SnapBack" alt="License">
    <img src="https://img.shields.io/github/stars/Liyue2341/SnapBack?style=social" alt="Stars">
  </p>
</p>

---

## The Problem

You know the drill. You're deep in work: 4 terminals running servers, 3 Claude Code sessions in different projects, WeChat open, a dozen browser tabs, File Explorer windows everywhere...

Then Windows says: **"Restart to finish installing updates."**

You restart. Everything's gone. Now you spend 15 minutes rebuilding your workspace from memory. _Every. Single. Time._

**SnapBack fixes this.** Two commands. That's it.

```
snapback save      # before reboot
snapback restore   # after reboot
```

## What Gets Saved

| Category | Details |
|----------|---------|
| **GUI Apps** | WeChat, browsers, MarkView, etc. |
| **Terminal Processes** | Python servers, Node.js, SSH sessions, ngrok tunnels |
| **Claude Code** | Every instance, in the correct project directory |
| **File Explorer** | All open folder windows |
| **Working Directories** | Detected via Windows PEB API + parent shell walking |

Auto-start programs (PowerToys, OneDrive, Notion, etc.) are automatically excluded - they'll restart on their own.

## Quick Start

**Before reboot:**
```powershell
PS C:\Users\you> snapback save

  SnapBack - Save & Restore your Windows session

  Capturing running processes...
  Capturing Explorer windows...

  Snapshot saved: 2026-03-28_143022
  Processes captured: 14
  Explorer folders:  4
```

**After reboot:**
```powershell
PS C:\Users\you> snapback restore

  SnapBack - Save & Restore your Windows session

  Snapshot: 2026-03-28_143022
  Processes: 14

  Programs to restore:
    - Weixin       @ C:\Program Files (x86)\Tencent\Weixin
    - claude       @ D:\Projects\my-app
    - claude (x2)  @ D:\Projects\backend
    - python       @ D:\Projects\backend
    - ssh          @ D:\Projects\server
    ...

  Restore these programs? [Y/n] Y

  [OK]   Weixin
  [OK]   claude @ D:\Projects\my-app
  [OK]   claude @ D:\Projects\backend (1/2)
  [OK]   claude @ D:\Projects\backend (2/2)
  [OK]   python @ D:\Projects\backend
  [OK]   ssh @ D:\Projects\server

  Restoring Explorer folders...
  [OK]   D:\Projects\my-app
  [OK]   D:\Projects\backend

  Restore complete:
    Restored: 8
    Folders:  2
    Skipped:  0
    Failed:   0
```

**Manage snapshots:**
```powershell
snapback list                    # List all saved snapshots
snapback show                    # Show details of latest snapshot
snapback save -Name work         # Save with a custom name
snapback restore -Name work      # Restore a specific snapshot
snapback delete -Name work       # Delete a snapshot
```

## Installation

```powershell
git clone https://github.com/Liyue2341/SnapBack.git
cd SnapBack

# Install globally (adds 'snapback' to your PATH)
.\install.ps1

# Restart your terminal, then use from anywhere:
snapback save
```

**Requirements:** Windows 10/11, PowerShell 5.1+ (pre-installed)

## How It Works

### Save (`snapback save`)
1. Queries all running processes via WMI/CIM
2. Filters out system processes, child processes (renderers, GPU, crashpad), and auto-start apps
3. Detects the **real working directory** by:
   - Walking up the process tree to find the parent shell (PowerShell/cmd/bash)
   - Reading the shell's CWD via the Windows PEB (Process Environment Block) API
   - This gives you the directory you `cd`'d to, not where the `.exe` lives
4. Captures open File Explorer windows via COM `Shell.Application`
5. Saves everything as a JSON snapshot

### Restore (`snapback restore`)
1. Reads the snapshot file
2. For each process:
   - **GUI apps** (browser, WeChat): skips if already running
   - **CLI tools** (claude, python, node): matches by command-line arguments, supports multiple instances
3. Restarts each process with its original arguments and working directory
4. Reopens all Explorer folder windows

### Architecture
```
SnapBack/
├── snapback.ps1          # Main entry point (save/restore/list/show/delete)
├── config.json           # Exclude lists, auto-start apps, settings
├── install.ps1           # One-click PATH installer
└── lib/
    ├── Snapshot.ps1      # Process capture, CWD detection, Explorer windows
    └── Restore.ps1       # Process restore, duplicate detection
```

## Configuration

Edit `config.json` to customize:

```jsonc
{
  "excludeProcesses": ["svchost", "csrss", ...],  // System processes to ignore
  "autoStartProcesses": ["PowerToys", "OneDrive", ...],  // Apps that restart on their own
  "excludeArgPatterns": ["--type=wx*", ...],  // Filter by command-line patterns
  "excludePathPatterns": ["*\\AnthropicClaude\\app-*"],  // Filter by exe path
  "maxSnapshots": 20,  // Auto-cleanup old snapshots
  "restoreDelayMs": 500,  // Delay between launching processes
  "confirmBeforeRestore": true  // Ask before restoring
}
```

## Limitations & Roadmap

- **Terminal session content** (command history, scrollback) is not preserved - only the running processes
- **Window positions** are not restored (yet)
- **Windows Terminal tabs** are restored as individual processes, not as tabs in a single window
- SSH sessions that require interactive authentication will need you to re-enter credentials

PRs welcome!

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Support

If SnapBack saved you from "the 15-minute rebuild ritual," consider buying me some API tokens:

<a href="https://buymeacoffee.com/liyue2341" target="_blank">
  <img src="https://img.shields.io/badge/Buy%20Me%20Some%20Tokens-%F0%9F%AA%99-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me Some Tokens" height="40">
</a>

---

## 中文说明

### 这工具解决什么问题？

Windows 用户的经典痛苦：开了一堆终端跑服务、好几个 Claude Code 窗口、微信、浏览器、文件夹... 然后系统提示要重启更新。

重启完，全没了。一个个重新打开，回忆刚才开了什么、在哪个目录... 每次浪费 15 分钟。

**SnapBack 两条命令搞定：**

```
snapback save      # 关机前
snapback restore   # 重启后
```

### 能恢复什么？

- **应用程序**：微信、浏览器、MarkView 等
- **终端进程**：Python 服务、Node.js、SSH 连接、ngrok 隧道
- **Claude Code**：每个实例都会在正确的项目目录下恢复，支持同目录多实例
- **文件资源管理器**：所有打开的文件夹窗口
- **工作目录**：通过 Windows PEB API 读取父 Shell 的真实工作目录

自启动程序（PowerToys、OneDrive、Notion 等）会自动排除，不会重复启动。

### 安装

```powershell
git clone https://github.com/Liyue2341/SnapBack.git
cd SnapBack
.\install.ps1    # 安装到全局 PATH

# 重启终端后，任意位置使用：
snapback save
snapback restore
```

### 所有命令

```powershell
snapback save                    # 保存当前会话
snapback restore                 # 恢复最近的快照
snapback list                    # 查看所有快照
snapback show                    # 查看最新快照详情
snapback save -Name work         # 自定义快照名字
snapback restore -Name work      # 恢复指定快照
snapback delete -Name work       # 删除快照
snapback help                    # 帮助
```

### 技术实现

- 通过 WMI/CIM 枚举进程，智能过滤系统进程和子进程
- 通过 Windows PEB API（NtQueryInformationProcess）读取进程的真实工作目录
- 对 CLI 进程（python、node、claude 等）会向上查找父 Shell 进程的 CWD
- 通过 COM Shell.Application 接口捕获文件资源管理器窗口
- 恢复时按命令行参数精确匹配，避免重复启动

---

<p align="center">
  <sub>Built with frustration and PowerShell. Star if you've been there too.</sub>
</p>
