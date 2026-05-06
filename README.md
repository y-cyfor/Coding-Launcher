# <p align="center"> Coding Launcher —— Context Menu Launcher for AI Coding CLI Tools </p>

<p align="center">
  <a href="README.md">English</a> |
  <a href="README_CN.md">简体中文</a> |
</p>

Add "ClaudeCode PWSH", "CodexCli PWSH", "CopilotCli PWSH", "GeminiCli PWSH" and "OpenCode PWSH" entries to your Windows right-click context menu. Open any tool directly from any folder — no terminal, no `cd`, no manual commands.

Supports launching tools from **Windows** or **WSL** (Windows Subsystem for Linux).

<center>

![截图](./img/右键截图.png)

</center>

## Goal

Eliminate the tedious workflow of:
1. Opening a terminal
2. `cd` into the project directory
3. Typing `claude`, `codex`, `copilot-cli`, `gemini` or `opencode`

Instead, simply **right-click any folder (or inside it) → select the tool you want** → done.

## Supported Tools

| Tool | Install Command |
|---|---|
| **ClaudeCode** | `npm i -g @anthropic-ai/claude-code` |
| **Codex CLI** | `npm i -g @openai/codex` |
| **GitHub Copilot CLI** | `npm i -g github-copilot-cli` |
| **Gemini CLI** | `npm i -g @anthropic/gemini-cli` |
| **OpenCode** | `winget install SST.opencode` |

All tools support both **Windows** and **WSL** environments.

## Requirements

- Windows 10/11
- PowerShell 7 (`pwsh.exe`) installed
- WSL (optional) — for opening tools in Linux environment

## Installation

1. Download all files from this repository to a local folder:
   - `install.ps1`
   - `uninstall.ps1`
   - `ico/` folder (all icon files)

   **Or download and extract the latest release archive: [Releases](https://github.com/y-cyfor/Coding-Launcher/releases)**

2. Right-click `install.ps1` → **"Run with PowerShell"**

3. When prompted, choose your preferred global icon style:
   - `[1]` Monochrome (default)
   - `[2]` Color

4. The script will scan your system for installed tools (Windows + WSL) and display versions:
   ```
   Windows 已安装: ClaudeCode (v1.2.3)、OpenCode (v0.5.1)
   Windows 未安装: CodexCli、CopilotCli、GeminiCli

   检测到 WSL 发行版: Ubuntu
     Ubuntu 已安装: ClaudeCode (v1.2.0)、CodexCli (v0.3.0)
     Ubuntu 未安装: CopilotCli、GeminiCli、OpenCode
   ```

5. A selection menu will appear. Choose which items to add:
   ```
   ══════════════════════════════════════════════════════
     可用菜单项 / Available menu items:
   ══════════════════════════════════════════════════════
     [1] ClaudeCode v1.2.3        (Windows)
     [2] OpenCode v0.5.1          (Windows)
     [3] ClaudeCode v1.2.0 WSL    (Ubuntu)
     [4] CodexCli v0.3.0 WSL      (Ubuntu)
   ══════════════════════════════════════════════════════
   ```

   Enter numbers like `1,3,5` or ranges like `1-3`, or type `all` to select all (default).

6. If a UAC prompt appears, click **Yes** to grant administrator privileges.

## What Gets Installed

- Icon files copied to `%USERPROFILE%\.context-menu-icons\` (persistent location)
- Registry entries under `HKCU\Software\Classes\Directory\Background\shell\` and `HKCU\Software\Classes\Directory\shell\`

Both the **folder background** (right-click in empty space) and the **folder itself** (right-click on the folder icon) will show the menu entries.

WSL menu entries will automatically convert Windows paths to WSL paths using `wslpath`.

## Uninstall

Right-click `uninstall.ps1` → **"Run with PowerShell"** → confirm UAC prompt. This removes all registry entries (including WSL variants) and the icon directory.

## Notes

- If menu items don't appear immediately, restart Windows Explorer or log out and back in.
- You can re-run `install.ps1` anytime to switch between monochrome and color icons, or to register newly installed tools.
- In submenu mode, the parent menu uses a dedicated "Coding Launcher" icon that follows the global monochrome/color choice.
- The `ico/` folder must remain in the same directory as the scripts during installation. After installation, it can be safely deleted (icons are copied to a persistent location).

## Tools

**ClaudeCode**

**XiaoMi MiMo-V2.5-Pro**

## ICON
by Ecommerce Website Design on <a href="https://icon-icons.com/zh/authors/364-ecommerce-website-design">Icon-Icons.com</a>