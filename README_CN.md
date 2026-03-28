<h1 align="center">SnapBack</h1>

<p align="center">
  <strong>一条命令保存，一条命令恢复，你的整个 Windows 工作环境。</strong><br>
  <sub>人生苦短，不要每次重启都花 15 分钟重新开窗口。</sub>
</p>

<p align="center">
  🇨🇳 中文 &nbsp;|&nbsp; <a href="README.md">🇬🇧 English</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Windows%2010%2F11-0078D4?style=flat-square&logo=windows&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/PowerShell%205.1%2B-5391FE?style=flat-square&logo=powershell&logoColor=white" alt="PowerShell">
  <img src="https://img.shields.io/github/license/Liyue2341/SnapBack?style=flat-square" alt="License">
  <img src="https://img.shields.io/github/stars/Liyue2341/SnapBack?style=flat-square" alt="Stars">
</p>

---

## 快速开始

```powershell
# 安装（一次性）
git clone https://github.com/Liyue2341/SnapBack.git
cd SnapBack && .\install.ps1

# 使用（每次重启）
snapback save        # 关机前
snapback restore     # 重启后 - 一切回来
```

安装后重启终端，即可在任意位置使用。

---

## 能恢复什么？

🖥️ 桌面应用（微信、浏览器等） &bull; ⌨️ 终端进程（Python、Node、SSH、ngrok） &bull; 🤖 Claude Code（每个实例在正确目录恢复，支持同目录多实例） &bull; 📁 所有打开的文件资源管理器窗口

> 自启动程序（PowerToys、OneDrive、Notion 等）自动排除，不会重复启动。

---

## 演示

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

## 所有命令

| 命令 | 说明 |
|:-----|:-----|
| `snapback save` | 保存当前会话 |
| `snapback restore` | 恢复最近的快照 |
| `snapback list` | 查看所有快照 |
| `snapback show` | 查看快照详情 |
| `snapback save -Name dev` | 用自定义名字保存 |
| `snapback restore -Name dev` | 恢复指定快照 |
| `snapback delete -Name dev` | 删除快照 |

---

<details>
<summary><strong>技术实现（点击展开）</strong></summary>

### 保存
1. 通过 WMI/CIM 枚举进程，智能过滤系统进程、子进程、自启动应用
2. 通过 Windows PEB API（`NtQueryInformationProcess`）向上查找父 Shell，读取**真实工作目录**
3. 通过 COM `Shell.Application` 捕获文件资源管理器窗口
4. 保存为 JSON 快照

### 恢复
1. GUI 应用（浏览器、微信）：已运行则跳过
2. CLI 工具（claude、python、node）：按命令行精确匹配，支持多实例
3. 用原始参数和工作目录重启每个进程
4. 重新打开所有文件夹窗口

### 项目结构
```
SnapBack/
├── snapback.ps1       # 命令行入口
├── config.json        # 排除列表和配置
├── install.ps1        # 一键全局安装
└── lib/
    ├── Snapshot.ps1    # 进程捕获、CWD 检测
    └── Restore.ps1    # 智能恢复、重复检测
```
</details>

<details>
<summary><strong>配置（点击展开）</strong></summary>

编辑 `config.json` 自定义：

```jsonc
{
  "excludeProcesses": [...],       // 排除的系统进程
  "autoStartProcesses": [...],     // 自动重启的应用
  "excludeArgPatterns": [...],     // 按命令行参数过滤
  "maxSnapshots": 20,              // 自动清理旧快照
  "restoreDelayMs": 500,           // 启动间隔（毫秒）
  "confirmBeforeRestore": true     // 恢复前确认
}
```
</details>

<details>
<summary><strong>已知限制</strong></summary>

- 终端滚动历史和命令记录不会保留 —— 只保留运行中的进程
- 窗口位置和大小暂不恢复（计划中）
- Windows Terminal 标签页会作为独立进程恢复，而非同窗口标签
- 需要交互认证的 SSH 会话需要重新输入密码

欢迎提 PR 和建议！
</details>

---

## 支持项目

如果 SnapBack 帮你告别了 _"重启后重建 15 分钟"_ 的痛苦：

<p align="center">
  <a href="https://buymeacoffee.com/liyue2341" target="_blank">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me Some Tokens" height="50">
  </a>
</p>

---

<p align="center">
  <a href="LICENSE">MIT 协议</a> &bull; 用 PowerShell 和不爽写成<br>
  ⭐ 如果你也经历过，请给个 Star
</p>
