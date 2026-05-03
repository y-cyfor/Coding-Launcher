<#
.SYNOPSIS
    安装 ClaudeCode / CodexCli / CopilotCli / GeminiCli / OpenCode 右键菜单
.DESCRIPTION
    将图标文件复制到固定位置并注册文件夹右键菜单项。
    Copies icon files to a permanent location and registers right-click context menu
    entries for both Directory Background and Directory shell.

    支持全局选择彩色或黑白图标。
    Supports global choice between color or monochrome icons for all tools.

    支持 WSL 中已安装的工具。
    Supports tools installed in WSL distros.
.NOTES
    需要与 ico/ 文件夹放在同一目录。
    Run from the same directory as the ico/ folder.
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
$IconSrc   = Join-Path $ScriptDir "ico"

# --- Global icon style choice (color or monochrome) ---
$Suffix = ""  # "" = monochrome, "-color" = color

# Check if any tool has both color and mono icons available
$HasChoice = $false
foreach ($base in @("claude", "codex", "copilot", "gemini")) {
    if ((Test-Path (Join-Path $IconSrc "${base}.ico")) -and (Test-Path (Join-Path $IconSrc "${base}-color.ico"))) {
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

# ============================================================
#  Windows 工具检测 / Windows tool detection
# ============================================================

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

$Installed    = $Tools | Where-Object { $_.Found }
$NotInstalled = $Tools | Where-Object { -not $_.Found }

Write-Host ""
if ($Installed) {
    $inStr = ($Installed | ForEach-Object { $_.Name }) -join "、"
    Write-Host "Windows 已安装: $inStr" -ForegroundColor Green
}
if ($NotInstalled) {
    $notStr = ($NotInstalled | ForEach-Object { $_.Name }) -join "、"
    Write-Host "Windows 未安装: $notStr" -ForegroundColor Yellow
}

# ============================================================
#  WSL 检测 / WSL detection
# ============================================================

$WslAvailable = Get-Command wsl.exe -ErrorAction SilentlyContinue
$WslDistros   = @()
$WslTools     = @()

Write-Host ""
if (-not $WslAvailable) {
    Write-Host "未检测到 WSL，跳过 WSL 检测。" -ForegroundColor Yellow
    Write-Host "WSL not detected. Skipping WSL detection." -ForegroundColor Yellow
} else {
    $wslOutput = wsl -l -q 2>$null
    $WslDistros = $wslOutput |
        ForEach-Object { $_ -replace '[\x00\xFEFF]', '' } |
        Where-Object { $_.Trim() -ne '' } |
        ForEach-Object { $_.Trim() }

    if ($WslDistros.Count -eq 0) {
        Write-Host "WSL 已安装但未检测到发行版。" -ForegroundColor Yellow
        Write-Host "WSL installed but no distros found." -ForegroundColor Yellow
    } else {
        Write-Host "检测到 WSL 发行版 / WSL distros: $($WslDistros -join '、')" -ForegroundColor Cyan

        foreach ($dist in $WslDistros) {
            $distInstalled    = @()
            $distNotInstalled = @()

            foreach ($t in $Tools) {
                $linuxCmd = $t.Cmd -replace '\.cmd$', ''
                $null = wsl -d $dist -- which $linuxCmd 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $distInstalled += $t.Name
                    $WslTools += @{ Distro = $dist; Tool = $t; LinuxCmd = $linuxCmd }
                } else {
                    $distNotInstalled += $t.Name
                }
            }

            if ($distInstalled.Count -gt 0) {
                Write-Host "  $dist 已安装 / installed: $($distInstalled -join '、')" -ForegroundColor Green
            }
            if ($distNotInstalled.Count -gt 0) {
                Write-Host "  $dist 未安装 / not installed: $($distNotInstalled -join '、')" -ForegroundColor Yellow
            }
        }
    }
}

# ============================================================
#  无工具退出 / Exit if nothing found
# ============================================================

if (-not $Installed -and $WslTools.Count -eq 0) {
    Write-Host ""
    Write-Host "未检测到任何已安装的工具，无需注册右键菜单。" -ForegroundColor Red
    Write-Host "No installed tools detected. Nothing to register." -ForegroundColor Red
    Write-Host ""
    Write-Host "请先安装至少一个工具后重新运行本脚本。" -ForegroundColor Yellow
    Write-Host "Please install at least one tool and re-run this script." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "按任意键退出 / Press any key to exit ..." -ForegroundColor White
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# ============================================================
#  选择菜单 / Selection menu
# ============================================================

# --- Build unified list ---
$AllItems = @()
$idx = 1

foreach ($t in $Tools) {
    if ($t.Found) {
        $AllItems += @{ Index = $idx; Display = "$($t.Name)        (Windows)"; Type = "Win"; Data = $t }
        $idx++
    }
}
foreach ($wt in $WslTools) {
    $AllItems += @{ Index = $idx; Display = "$($wt.Tool.Name) WSL    ($($wt.Distro))"; Type = "WSL"; Data = $wt }
    $idx++
}

# --- Parse selection input ---
function Parse-Selection {
    param(
        [string]$InputStr,
        [int]$MaxIndex
    )

    if ($InputStr -eq '' -or $InputStr -eq 'all') {
        return 1..$MaxIndex
    }

    $result = @()
    $parts = $InputStr -split ','

    foreach ($part in $parts) {
        $part = $part.Trim()
        if ($part -match '^(\d+)\s*-\s*(\d+)$') {
            $start = [int]$Matches[1]
            $end   = [int]$Matches[2]
            if ($start -le $end) { $result += $start..$end }
        } elseif ($part -match '^\d+$') {
            $result += [int]$part
        }
    }

    return ($result | Where-Object { $_ -ge 1 -and $_ -le $MaxIndex } | Sort-Object -Unique)
}

# --- Display selection menu ---
Write-Host ""
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  可用菜单项 / Available menu items:" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan
foreach ($item in $AllItems) {
    Write-Host "  [$($item.Index)] $($item.Display)" -ForegroundColor White
}
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan

# --- Get user selection ---
$SelectedIndices = @()
do {
    Write-Host ""
    $userInput = Read-Host "请输入要添加的编号 (如 1,3,5 或 1-3)，输入 all 全选 [默认 all]`nSelect items (e.g. 1,3,5 or 1-3), or 'all' [default all]"
    $SelectedIndices = @(Parse-Selection -InputStr $userInput -MaxIndex $AllItems.Count)
    if ($SelectedIndices.Count -eq 0) {
        Write-Host "未选择任何有效项，请重新输入。" -ForegroundColor Yellow
        Write-Host "No valid items selected. Please try again." -ForegroundColor Yellow
    }
} while ($SelectedIndices.Count -eq 0)

$SelectedItems = $AllItems | Where-Object { $SelectedIndices -contains $_.Index }

Write-Host ""
Write-Host "已选择 / Selected:" -ForegroundColor Green
foreach ($item in $SelectedItems) {
    Write-Host "  [$($item.Index)] $($item.Display)" -ForegroundColor Green
}

foreach ($t in $Tools) { Write-Host "$($t.Name): $($t.Path)" -ForegroundColor DarkGray }
Write-Host "图标目录 / Icon dir: $IconDir" -ForegroundColor DarkGray

# ============================================================
#  复制图标 / Copy icons
# ============================================================

if (-not (Test-Path $IconDir)) { New-Item -ItemType Directory -Path $IconDir -Force | Out-Null }

$IconBases = @("claude", "codex", "copilot", "gemini", "opencode")
foreach ($base in $IconBases) {
    $preferred = Join-Path $IconSrc "${base}${Suffix}.ico"
    $altSuffix = if ($Suffix -eq "-color") { "" } else { "-color" }
    $alt = Join-Path $IconSrc "${base}${altSuffix}.ico"

    if (Test-Path $preferred) { $src = $preferred }
    elseif (Test-Path $alt) { $src = $alt }
    else { continue }

    $dest = Join-Path $IconDir "${base}.ico"
    Copy-Item $src $dest -Force
}
Write-Host "图标已复制到 $IconDir" -ForegroundColor Green

# ============================================================
#  注册表写入函数 / Registry helper
# ============================================================

function Write-RegContextMenu {
    param(
        [string]$Root,
        [string]$Name,
        [string]$Display,
        [string]$Icon,
        [string]$Command
    )

    $keyPath = Join-Path $Root $Name
    $cmdPath = Join-Path $keyPath "command"

    if (Test-Path $keyPath) { Remove-Item $keyPath -Recurse -Force }
    New-Item -Path $keyPath -Force | Out-Null
    New-Item -Path $cmdPath -Force | Out-Null

    Set-ItemProperty -Path $keyPath -Name "(Default)" -Value $Display
    Set-ItemProperty -Path $keyPath -Name "Icon"       -Value $Icon
    Set-ItemProperty -Path $cmdPath -Name "(Default)"  -Value $Command
}

# ============================================================
#  注册选中项 / Register selected items
# ============================================================

$BgPlaceholder  = "%V"
$DirPlaceholder = "%1"

$BgRoot  = "HKCU:\Software\Classes\Directory\Background\shell"
$DirRoot = "HKCU:\Software\Classes\Directory\shell"

Write-Host ""
Write-Host "正在注册右键菜单 / Registering context menu..." -ForegroundColor Cyan

foreach ($item in $SelectedItems) {
    if ($item.Type -eq "Win") {
        $t = $item.Data
        $menuName = "$($t.Name)PWSH"
        $iconPath = Join-Path $IconDir "$($t.Icon).ico"

        $bgCmd  = "pwsh.exe -NoExit -NoProfile -Command `"cd `"$BgPlaceholder`"; & `"$($t.Path)`"`""
        $dirCmd = "pwsh.exe -NoExit -NoProfile -Command `"cd `"$DirPlaceholder`"; & `"$($t.Path)`"`""

        Write-RegContextMenu -Root $BgRoot -Name $menuName -Display "$($t.Name) PWSH" -Icon $iconPath -Command $bgCmd
        Write-RegContextMenu -Root $DirRoot -Name $menuName -Display "$($t.Name) PWSH" -Icon $iconPath -Command $dirCmd

        Write-Host "  $($t.Name) PWSH  (背景 / background + 文件夹 / folder)" -ForegroundColor Cyan
    }
    elseif ($item.Type -eq "WSL") {
        $wt = $item.Data
        $menuName = "$($wt.Tool.Name)WSL_$($wt.Distro)"
        $iconPath = Join-Path $IconDir "$($wt.Tool.Icon).ico"
        $display  = "$($wt.Tool.Name) WSL ($($wt.Distro))"

        $bgCmd  = 'wsl.exe -d {0} -- bash -c "cd \"$(wslpath ''{1}'')\" && {2}"' -f $wt.Distro, $BgPlaceholder, $wt.LinuxCmd
        $dirCmd = 'wsl.exe -d {0} -- bash -c "cd \"$(wslpath ''{1}'')\" && {2}"' -f $wt.Distro, $DirPlaceholder, $wt.LinuxCmd

        Write-RegContextMenu -Root $BgRoot  -Name $menuName -Display $display -Icon $iconPath -Command $bgCmd
        Write-RegContextMenu -Root $DirRoot -Name $menuName -Display $display -Icon $iconPath -Command $dirCmd

        Write-Host "  $display  (背景 / background + 文件夹 / folder)" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "安装完成 / Installation complete!" -ForegroundColor Green
Write-Host "如果菜单项未立即出现，请重启资源管理器或注销后重新登录。" -ForegroundColor Yellow
Write-Host "If menu items don't appear immediately, restart Explorer or log out and back in." -ForegroundColor Yellow
