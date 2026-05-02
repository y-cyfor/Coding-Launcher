# Coding Quick Start —— ClaudeCode & OpenCode 右键菜单启动器

在 Windows 右键菜单中添加 "ClaudeCode PWSH" 和 "OpenCode PWSH" 选项，从任意文件夹直接启动工具——无需打开终端、无需 `cd`、无需手动输入命令。

## 脚本目标

省去以下重复操作：
1. 打开终端
2. `cd` 进入项目目录
3. 手动输入 `claude` 或 `opencode` 命令

改为：**右键点击任意文件夹（或文件夹内空白处）→ 选择 "ClaudeCode PWSH" 或 "OpenCode PWSH" → 完成。**

## 环境要求

- Windows 10/11
- 已安装 PowerShell 7（`pwsh.exe`）
- 已安装 `claude`（通过 npm：`npm i -g @anthropic-ai/claude-code`）
- 已安装 `opencode`（通过 [winget](https://github.com/nicholasgasior/opencode) 或 npm）

## 安装方法

1. 将以下所有文件下载到同一个本地文件夹：
   - `install.ps1`
   - `uninstall.ps1`
   - `claude.ico`
   - `claude-color.ico`
   - `opencode.ico`

2. 右键点击 `install.ps1` → **"使用 PowerShell 运行"**

3. 根据提示选择 Claude 图标样式：
   - `[1]` 黑白（默认）
   - `[2]` 彩色

4. 如果弹出 UAC 权限提示，点击 **"是"** 授予管理员权限。

## 安装内容

- 图标文件复制到 `%USERPROFILE%\.context-menu-icons\`（持久化存储）
- 注册表项写入 `HKCU\Software\Classes\Directory\Background\shell\` 和 `HKCU\Software\Classes\Directory\shell\`

**文件夹空白处右键**和**文件夹图标上右键**都会显示对应的菜单项。

## 卸载方法

右键点击 `uninstall.ps1` → **"使用 PowerShell 运行"** → 确认 UAC 提示。这将移除所有注册表项和图标目录。

## 注意事项

- 如果菜单项没有立即出现，请重启资源管理器或注销后重新登录。
- 随时可以重新运行 `install.ps1` 切换黑白/彩色图标。
- 安装期间图标文件必须与脚本放在同一目录。安装完成后，原始图标文件可以安全删除（图标已复制到持久化位置）。

## 工具

**ClaudeCode**

**小米 MiMo-V2.5-Pro**
