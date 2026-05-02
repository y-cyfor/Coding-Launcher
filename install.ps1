<#
.SYNOPSIS
    安装 ClaudeCode 和 OpenCode 右键菜单 / Install ClaudeCode and OpenCode context menu entries.
.DESCRIPTION
    将图标文件复制到固定位置并注册文件夹右键菜单项。
    Copies icon files to a permanent location and registers right-click context menu
    entries for both Directory Background and Directory shell.

    支持选择彩色或黑白 Claude 图标。
    Supports choosing between a color or monochrome Claude icon.
.NOTES
    需要与 claude.ico（或 claude-color.ico）和 opencode.ico 放在同一目录。
    Run from the same directory as claude.ico (or claude-color.ico) and opencode.ico.
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

# --- Claude icon choice ---
$ClaudeMono  = Join-Path $ScriptDir "claude.ico"
$ClaudeColor = Join-Path $ScriptDir "claude-color.ico"

if ((Test-Path $ClaudeMono) -and (Test-Path $ClaudeColor)) {
    Write-Host ""
    Write-Host "选择 Claude 图标样式 / Select Claude icon style:" -ForegroundColor Cyan
    Write-Host "  [1] 黑白 / Monochrome (claude.ico)"       -ForegroundColor White
    Write-Host "  [2] 彩色 / Color      (claude-color.ico)" -ForegroundColor White
    Write-Host ""

    do {
        $choice = Read-Host "请选择 (1/2) [默认 1] / Select (1/2) [default 1]"
    } while ($choice -ne "" -and $choice -ne "1" -and $choice -ne "2")

    if ($choice -eq "2") {
        $ClaudeIcon = $ClaudeColor
        $ClaudeIconName = "claude-color.ico"
        Write-Host "已选择彩色图标 / Using color icon." -ForegroundColor Green
    } else {
        $ClaudeIcon = $ClaudeMono
        $ClaudeIconName = "claude.ico"
        Write-Host "已选择黑白图标 / Using monochrome icon." -ForegroundColor Green
    }
} elseif (Test-Path $ClaudeColor) {
    $ClaudeIcon = $ClaudeColor
    $ClaudeIconName = "claude-color.ico"
    Write-Host "仅找到彩色图标，使用它 / Only claude-color.ico found, using it." -ForegroundColor Yellow
} elseif (Test-Path $ClaudeMono) {
    $ClaudeIcon = $ClaudeMono
    $ClaudeIconName = "claude.ico"
    Write-Host "仅找到黑白图标，使用它 / Only claude.ico found, using it." -ForegroundColor Yellow
} else {
    Write-Error "未找到 claude.ico 或 claude-color.ico / No claude.ico or claude-color.ico found in $ScriptDir"
    exit 1
}

$OpencodeIcon = Join-Path $ScriptDir "opencode.ico"
if (-not (Test-Path $OpencodeIcon)) {
    Write-Error "未找到 opencode.ico / opencode.ico not found at: $OpencodeIcon"
    exit 1
}

# --- Locate executables ---
$ClaudeCmd = (Get-Command "claude.cmd"    -ErrorAction SilentlyContinue).Source
if (-not $ClaudeCmd -or -not (Test-Path $ClaudeCmd)) {
    $ClaudeCmd = "$env:APPDATA\npm\claude.cmd"
}

$OpencodeCmd = (Get-Command "opencode.cmd" -ErrorAction SilentlyContinue).Source
if (-not $OpencodeCmd -or -not (Test-Path $OpencodeCmd)) {
    $OpencodeCmd = (Get-Command "opencode.exe" -ErrorAction SilentlyContinue).Source
}
if (-not $OpencodeCmd -or -not (Test-Path $OpencodeCmd)) {
    $OpencodeCmd = "$env:APPDATA\npm\opencode.cmd"
}

Write-Host "claude.cmd:   $ClaudeCmd"   -ForegroundColor DarkGray
Write-Host "opencode:     $OpencodeCmd" -ForegroundColor DarkGray
Write-Host "图标目录:     $IconDir"     -ForegroundColor DarkGray

# --- Copy icons to permanent location ---
if (-not (Test-Path $IconDir)) { New-Item -ItemType Directory -Path $IconDir -Force | Out-Null }

# Copy both color and mono to the destination, so re-running the script can switch
$ClaMonoDest   = Join-Path $IconDir "claude.ico"
$ClaColorDest  = Join-Path $IconDir "claude-color.ico"
$OpeIconDest   = Join-Path $IconDir "opencode.ico"

Copy-Item $ClaudeMono  $ClaMonoDest  -Force
if (Test-Path $ClaudeColor) {
    Copy-Item $ClaudeColor $ClaColorDest -Force
}
Copy-Item $OpencodeIcon $OpeIconDest -Force

# Point to the chosen icon
$ClaIconDest = Join-Path $IconDir $ClaudeIconName

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

# --- Build command lines ---
$BgPlaceholder  = "%V"   # Directory Background
$DirPlaceholder = "%1"   # Directory

$ClaBG  = "pwsh.exe -NoExit -NoProfile -Command `"cd \`"$BgPlaceholder\`"; & \`"$ClaudeCmd\`"`""
$ClaDir = "pwsh.exe -NoExit -NoProfile -Command `"cd \`"$DirPlaceholder\`"; & \`"$ClaudeCmd\`"`""

$OpeBG  = "pwsh.exe -NoExit -NoProfile -Command `"cd \`"$BgPlaceholder\`"; & \`"$OpencodeCmd\`"`""
$OpeDir = "pwsh.exe -NoExit -NoProfile -Command `"cd \`"$DirPlaceholder\`"; & \`"$OpencodeCmd\`"`""

# --- Register entries ---
$BgRoot  = "HKCU:\Software\Classes\Directory\Background\shell"
$DirRoot = "HKCU:\Software\Classes\Directory\shell"

Write-Host ""
Write-Host "正在注册右键菜单 / Registering context menu..." -ForegroundColor Cyan

# Background (right-click in folder empty space)
Write-RegContextMenu -Root $BgRoot -Name "ClaudeCodePWSH" -Display "ClaudeCode PWSH" -Icon $ClaIconDest -Command $ClaBG
Write-RegContextMenu -Root $BgRoot -Name "OpenCodePWSH"   -Display "OpenCode PWSH"   -Icon $OpeIconDest -Command $OpeBG

# Directory (right-click on folder itself)
Write-RegContextMenu -Root $DirRoot -Name "ClaudeCodePWSH" -Display "ClaudeCode PWSH" -Icon $ClaIconDest -Command $ClaDir
Write-RegContextMenu -Root $DirRoot -Name "OpenCodePWSH"   -Display "OpenCode PWSH"   -Icon $OpeIconDest -Command $OpeDir

Write-Host "  ClaudeCode PWSH  (背景 / background + 文件夹 / folder)" -ForegroundColor Cyan
Write-Host "  OpenCode PWSH    (背景 / background + 文件夹 / folder)" -ForegroundColor Cyan

Write-Host ""
Write-Host "安装完成 / Installation complete!" -ForegroundColor Green
Write-Host "如果菜单项未立即出现，请重启资源管理器或注销后重新登录。" -ForegroundColor Yellow
Write-Host "If menu items don't appear immediately, restart Explorer or log out and back in." -ForegroundColor Yellow
