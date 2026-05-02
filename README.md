# Coding Quick Start —— Context Menu Launcher for ClaudeCode & OpenCode

Add "ClaudeCode PWSH" and "OpenCode PWSH" entries to your Windows right-click context menu. Open either tool directly from any folder — no terminal, no `cd`, no manual commands.

## Goal

Eliminate the tedious workflow of:
1. Opening a terminal
2. `cd` into the project directory
3. Typing `claude` or `opencode`

Instead, simply **right-click any folder (or inside it) → select "ClaudeCode PWSH" or "OpenCode PWSH"** → done.

## Requirements

- Windows 10/11
- PowerShell 7 (`pwsh.exe`) installed
- `claude` command available (via npm: `npm i -g @anthropic-ai/claude-code`)
- `opencode` command available (via [winget](https://github.com/nicholasgasior/opencode) or npm)

## Installation

1. Download all files from this repository to a local folder:
   - `install.ps1`
   - `uninstall.ps1`
   - `claude.ico`
   - `claude-color.ico`
   - `opencode.ico`

2. Right-click `install.ps1` → **"Run with PowerShell"**

3. When prompted, choose your preferred Claude icon style:
   - `[1]` Monochrome (default)
   - `[2]` Color

4. If a UAC prompt appears, click **Yes** to grant administrator privileges.

## What Gets Installed

- Icon files copied to `%USERPROFILE%\.context-menu-icons\` (persistent location)
- Registry entries under `HKCU\Software\Classes\Directory\Background\shell\` and `HKCU\Software\Classes\Directory\shell\`

Both the **folder background** (right-click in empty space) and the **folder itself** (right-click on the folder icon) will show the menu entries.

## Uninstall

Right-click `uninstall.ps1` → **"Run with PowerShell"** → confirm UAC prompt. This removes all registry entries and the icon directory.

## Notes

- If menu items don't appear immediately, restart Windows Explorer or log out and back in.
- You can re-run `install.ps1` anytime to switch between monochrome and color icons.
- The icon files must remain in the same directory as the scripts during installation. After installation, they can be safely deleted (icons are copied to a persistent location).

## Tools


**ClaudeCode**

**XiaoMi MiMo-V2.5-Pro**