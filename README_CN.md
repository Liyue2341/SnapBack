<h1 align="center">
  <br>
  SnapBack
  <br>
</h1>

<h4 align="center">一条命令保存，一条命令恢复，你的整个 Windows 工作环境。</h4>

<p align="center">
  人生苦短，不要每次重启都花 15 分钟重新打开 20 个窗口。
</p>

<p align="center">
  🇨🇳 中文 &nbsp;|&nbsp; <a href="README.md">🇬🇧 English</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/平台-Windows%2010%2F11-0078D4?style=flat-square&logo=windows&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell&logoColor=white" alt="PowerShell">
  <img src="https://img.shields.io/github/license/Liyue2341/SnapBack?style=flat-square" alt="License">
  <img src="https://img.shields.io/github/stars/Liyue2341/SnapBack?style=flat-square" alt="Stars">
</p>

---

## 痛点

Windows 用户都经历过这种场景：

> 开了 4 个终端跑服务，3 个 Claude Code 分布在不同项目里，微信开着，浏览器十几个标签页，文件夹窗口散落一地...
>
> 然后 Windows 弹窗：**"需要重启以完成更新。"**

重启完，**全没了**。你开始凭记忆一个个打开，回忆刚才在哪个目录跑了什么... _每次都要浪费 15 分钟。_

## 解决方案

```powershell
snapback save        # 关机前 - 3 秒搞定
# ... 重启 ...
snapback restore     # 重启后 - 一切回来
```

就这么简单。真的。

---

## 能恢复什么？

| 类别 | 说明 |
|:-----|:-----|
| 🖥️ **桌面应用** | 微信、浏览器、MarkView 等 |
| ⌨️ **终端进程** | Python 服务、Node.js、SSH 连接、ngrok 隧道 |
| 🤖 **Claude Code** | 每个实例在正确的项目目录下恢复，同目录多实例也支持 |
| 📁 **文件资源管理器** | 所有打开的文件夹窗口 |
| 📂 **工作目录** | 通过 Windows PEB API 读取真实工作目录，不是 exe 目录 |

> 自启动程序（PowerToys、OneDrive、Notion 等）会自动排除，不会重复启动。

---

## 演示

**`snapback save`** — 快照你的工作环境：
```
PS C:\> snapback save

  SnapBack - Save & Restore your Windows session

  Capturing running processes...
  Capturing Explorer windows...

  Snapshot saved: 2026-03-28_143022
  Processes captured: 14
  Explorer folders:  4
```

**`snapback restore`** — 一键恢复：
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

**`snapback list`** — 管理快照：
```
PS C:\> snapback list

  Available Snapshots:
  ------------------------------------------------------------
  [1] work_env     |  2026-03-28 14:30:22  |  14 processes (latest)
  [2] before_update|  2026-03-27 09:15:03  |  11 processes
```

---

## 安装

```powershell
git clone https://github.com/Liyue2341/SnapBack.git
cd SnapBack
.\install.ps1       # 安装到全局 PATH
```

重启终端，然后在任意位置使用 `snapback`。

> **系统要求：** Windows 10/11 + PowerShell 5.1+（所有现代 Windows 自带）

---

## 所有命令

| 命令 | 说明 |
|:-----|:-----|
| `snapback save` | 保存当前会话 |
| `snapback restore` | 恢复最近的快照 |
| `snapback list` | 查看所有快照 |
| `snapback show` | 查看快照详情 |
| `snapback save -Name work` | 用自定义名字保存 |
| `snapback restore -Name work` | 恢复指定快照 |
| `snapback delete -Name work` | 删除快照 |
| `snapback help` | 帮助 |

---

## 技术实现

### 保存（Save）
1. 通过 WMI/CIM 枚举所有运行中的进程
2. 智能过滤：排除系统进程、子进程（renderer、GPU、crashpad）、自启动应用
3. **真实工作目录检测**：向上遍历进程树，找到父 Shell（PowerShell/cmd/bash），通过 Windows PEB API（`NtQueryInformationProcess`）读取它的当前工作目录
4. 通过 COM `Shell.Application` 接口捕获文件资源管理器窗口
5. 保存为 JSON 快照文件

### 恢复（Restore）
1. 一次性获取所有运行中的进程（避免反复查询）
2. **GUI 应用**（浏览器、微信）：如果已经在运行则跳过
3. **CLI 工具**（claude、python、node）：按命令行参数精确匹配，支持多实例恢复
4. 用原始参数和工作目录重新启动每个进程
5. 重新打开所有文件夹窗口

### 项目结构
```
SnapBack/
├── snapback.ps1          # 命令行入口
├── config.json           # 排除列表和配置
├── install.ps1           # 一键全局安装
└── lib/
    ├── Snapshot.ps1      # 进程捕获、CWD 检测、Explorer 窗口
    └── Restore.ps1       # 智能恢复、重复检测
```

---

## 配置

编辑 `config.json` 自定义行为：

```jsonc
{
  "excludeProcesses": [...],       // 始终排除的系统进程
  "autoStartProcesses": [...],     // 会自动重启的应用
  "excludeArgPatterns": [...],     // 按命令行参数过滤
  "excludePathPatterns": [...],    // 按程序路径过滤
  "maxSnapshots": 20,              // 自动清理旧快照
  "restoreDelayMs": 500,           // 启动间隔（毫秒）
  "confirmBeforeRestore": true     // 恢复前确认
}
```

---

## 已知限制

- 终端的**滚动历史和命令记录**不会保留 —— 只保留运行中的进程
- **窗口位置和大小**暂不恢复（计划中）
- **Windows Terminal 标签页**会作为独立进程恢复，而非同一窗口内的标签
- 需要交互式认证的 SSH 会话需要重新输入密码

欢迎提 PR 和建议！

---

## 支持项目

如果 SnapBack 帮你告别了 _"每次重启重建 15 分钟"_ 的痛苦，欢迎支持一下：

<p align="center">
  <a href="https://buymeacoffee.com/liyue2341" target="_blank">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me Some Tokens" height="60">
  </a>
</p>

<p align="center">
  <sub>每一份支持都是开源的动力。感谢！🪙</sub>
</p>

---

## 开源协议

[MIT](LICENSE) — 随便用，随便改，随便叉。

<p align="center">
  <sub>用 PowerShell 和不爽写成的工具。<br>⭐ 如果你也经历过这种痛苦，请给个 Star。</sub>
</p>
