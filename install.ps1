<#
.SYNOPSIS
    安装 ClaudeCode / CodexCli / CopilotCli / GeminiCli / OpenCode 右键菜单
.DESCRIPTION
    将图标文件复制到固定位置并注册文件夹右键菜单项。
    Copies icon files to a permanent location and registers right-click context menu
    entries for both Directory Background and Directory shell.

    支持全局选择彩色或黑白图标。
    Supports global choice between color or monochrome icons for all tools.
.NOTES
    需要与 *.ico 图标文件放在同一目录。
    Run from the same directory as the *.ico files.
    需要 pwsh.exe (PowerShell 7)。
    Requires pwsh.exe (PowerShell 7) to be installed.
    脚本会自动请求管理员权限。
    Script will auto-elevate to Administrator if not already running as such.
#>

# --- Self-elevate if not running as Administrator ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptPath = $MyInvocation.MyCommand.Definition
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    exit
}

$ErrorActionPreference = "Stop"

# --- Configuration ---
$IconDir   = "$env:USERPROFILE\.context-menu-icons"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- Global icon style choice (color or monochrome) ---
$Suffix = ""  # "" = monochrome, "-color" = color

# Check if any tool has both color and mono icons available
$HasChoice = $false
foreach ($base in @("claude", "codex", "copilot", "gemini")) {
    if ((Test-Path (Join-Path $ScriptDir "${base}.ico")) -and (Test-Path (Join-Path $ScriptDir "${base}-color.ico"))) {
        $HasChoice = $true; break
    }
}

if ($HasChoice) {
    Write-Host ""
    Write-Host "选择全局图标样式 / Select global icon style:" -ForegroundColor Cyan
    Write-Host "  [1] 黑白 / Monochrome" -ForegroundColor White
    Write-Host "  [2] 彩色 / Color"      -ForegroundColor White
    Write-Host ""

    do {
        $choice = Read-Host "请选择 (1/2) [默认 1] / Select (1/2) [default 1]"
    } while ($choice -ne "" -and $choice -ne "1" -and $choice -ne "2")

    if ($choice -eq "2") { $Suffix = "-color"; Write-Host "使用彩色图标 / Using color icons." -ForegroundColor Green }
    else { Write-Host "使用黑白图标 / Using monochrome icons." -ForegroundColor Green }
}

# --- Locate executables ---
$Tools = @(
    @{ Name = "ClaudeCode"; Icon = "claude";  Cmd = "claude.cmd";  Fallback = "$env:APPDATA\npm\claude.cmd" }
    @{ Name = "CodexCli";   Icon = "codex";   Cmd = "codex.cmd";   Fallback = "$env:APPDATA\npm\codex.cmd" }
    @{ Name = "CopilotCli"; Icon = "copilot"; Cmd = "github-copilot-cli.cmd"; Fallback = "$env:APPDATA\npm\github-copilot-cli.cmd" }
    @{ Name = "GeminiCli";  Icon = "gemini";  Cmd = "gemini.cmd";  Fallback = "$env:APPDATA\npm\gemini.cmd" }
    @{ Name = "OpenCode";   Icon = "opencode";Cmd = "opencode.cmd"; Fallback = "$env:APPDATA\npm\opencode.cmd" }
)

foreach ($t in $Tools) {
    $found = (Get-Command $t.Cmd -ErrorAction SilentlyContinue).Source
    if (-not $found -or -not (Test-Path $found)) { $found = $t.Fallback }
    $t.Found = $found -and (Test-Path $found)
    $t.Path  = $found
}

$Installed   = $Tools | Where-Object { $_.Found }
$NotInstalled = $Tools | Where-Object { -not $_.Found }

Write-Host ""
if ($NotInstalled) {
    $inStr  = ($Installed   | ForEach-Object { $_.Name }) -join "、"
    $notStr = ($NotInstalled | ForEach-Object { $_.Name }) -join "、"
    Write-Host "检查到本地已安装: $inStr" -ForegroundColor Green
    Write-Host "未检测到: $notStr" -ForegroundColor Yellow
    Write-Host "脚本将只为已安装的工具添加右键菜单。后续安装相应工具后可再次运行本脚本。" -ForegroundColor White
    Write-Host ""
    Write-Host "已安装: Installed: $inStr" -ForegroundColor Green
    Write-Host "未安装: Not installed: $notStr" -ForegroundColor Yellow
    Write-Host "Only installed tools will be registered. Re-run this script after installing missing tools." -ForegroundColor White
} else {
    $inStr = ($Installed | ForEach-Object { $_.Name }) -join "、"
    Write-Host "检查到本地已安装: $inStr" -ForegroundColor Green
    Write-Host ""
    Write-Host "已安装: Installed: $inStr" -ForegroundColor Green
}
Write-Host ""
Write-Host "按任意键继续，取消请按 Ctrl+C ..." -ForegroundColor White
Write-Host "Press any key to continue, or Ctrl+C to cancel ..." -ForegroundColor White
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host ""

foreach ($t in $Tools) { Write-Host "$($t.Name): $($t.Path)" -ForegroundColor DarkGray }
Write-Host "图标目录:  $IconDir" -ForegroundColor DarkGray

# --- Copy icons to permanent location ---
if (-not (Test-Path $IconDir)) { New-Item -ItemType Directory -Path $IconDir -Force | Out-Null }

$IconBases = @("claude", "codex", "copilot", "gemini", "opencode")
foreach ($base in $IconBases) {
    # Try preferred style first, then fallback to the other
    $preferred = Join-Path $ScriptDir "${base}${Suffix}.ico"
    $altSuffix = if ($Suffix -eq "-color") { "" } else { "-color" }
    $alt = Join-Path $ScriptDir "${base}${altSuffix}.ico"

    if (Test-Path $preferred) { $src = $preferred }
    elseif (Test-Path $alt) { $src = $alt }
    else { continue }

    $dest = Join-Path $IconDir "${base}.ico"
    Copy-Item $src $dest -Force
}
Write-Host "图标已复制到 $IconDir" -ForegroundColor Green

# --- Helper: write a single context menu entry ---
function Write-RegContextMenu {
    param(
        [string]$Root,       # e.g. "HKCU:\Software\Classes\Directory\Background\shell"
        [string]$Name,       # unique key name
        [string]$Display,    # text shown in menu
        [string]$Icon,       # full path to .ico
        [string]$Command     # full command line (may contain %V or %1)
    )

    $keyPath = Join-Path $Root $Name
    $cmdPath = Join-Path $keyPath "command"

    if (Test-Path $keyPath) { Remove-Item $keyPath -Recurse -Force }
    New-Item -Path $keyPath -Force | Out-Null
    New-Item -Path $cmdPath -Force | Out-Null

    Set-ItemProperty -Path $keyPath -Name "(Default)" -Value $Display
    Set-ItemProperty -Path $keyPath -Name "Icon"       -Value "`"$Icon`""
    Set-ItemProperty -Path $cmdPath -Name "(Default)"  -Value $Command
}

# --- Build command lines and register entries ---
$BgPlaceholder  = "%V"   # Directory Background
$DirPlaceholder = "%1"   # Directory

$BgRoot  = "HKCU:\Software\Classes\Directory\Background\shell"
$DirRoot = "HKCU:\Software\Classes\Directory\shell"

Write-Host ""
Write-Host "正在注册右键菜单 / Registering context menu..." -ForegroundColor Cyan

foreach ($t in $Tools) {
    if (-not $t.Found) { continue }

    $menuName = "$($t.Name)PWSH"
    $iconPath = Join-Path $IconDir "$($t.Icon).ico"

    $bgCmd  = "pwsh.exe -NoExit -NoProfile -Command `"cd \`"$BgPlaceholder\`"; & \`"$($t.Path)\`"`""
    $dirCmd = "pwsh.exe -NoExit -NoProfile -Command `"cd \`"$DirPlaceholder\`"; & \`"$($t.Path)\`"`""

    Write-RegContextMenu -Root $BgRoot -Name $menuName -Display "$($t.Name) PWSH" -Icon $iconPath -Command $bgCmd
    Write-RegContextMenu -Root $DirRoot -Name $menuName -Display "$($t.Name) PWSH" -Icon $iconPath -Command $dirCmd

    Write-Host "  $($t.Name) PWSH  (背景 / background + 文件夹 / folder)" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "安装完成 / Installation complete!" -ForegroundColor Green
Write-Host "如果菜单项未立即出现，请重启资源管理器或注销后重新登录。" -ForegroundColor Yellow
Write-Host "If menu items don't appear immediately, restart Explorer or log out and back in." -ForegroundColor Yellow
