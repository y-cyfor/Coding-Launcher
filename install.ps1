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

    支持平铺模式或子菜单模式。
    Supports flat menu or submenu layout.
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
    Start-Process pwsh.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    exit
}

$ErrorActionPreference = "Stop"

try {

# --- Input helper (avoids Read-Host empty-input hang) ---
function Read-Key {
    param([bool]$AllowEsc = $false)

    $buffer = ""
    while ($true) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::Enter) {
            Write-Host ""
            if ($AllowEsc) {
                return @{ Save = $true; Value = $buffer }
            } else {
                return $buffer
            }
        } elseif ($AllowEsc -and $key.Key -eq [ConsoleKey]::Escape) {
            Write-Host ""
            return @{ Save = $false; Value = "" }
        } elseif ($key.Key -eq [ConsoleKey]::Backspace) {
            if ($buffer.Length -gt 0) {
                $buffer = $buffer.Substring(0, $buffer.Length - 1)
                Write-Host "`b `b" -NoNewline
            }
        } else {
            $char = $key.KeyChar
            if ($char -ne 0 -and $char -ne 13 -and $char -ne 10 -and $char -ne 27) {
                $buffer += $char
                Write-Host $char -NoNewline
            }
        }
    }
}

function Read-Line {
    return Read-Key -AllowEsc $false
}

function Read-LineWithEsc {
    return Read-Key -AllowEsc $true
}

# --- Configuration ---
$IconDir   = "$env:USERPROFILE\.context-menu-icons"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$IconSrc   = Join-Path $ScriptDir "ico"

# ============================================================
#  菜单布局选择 / Menu layout selection
# ============================================================

Write-Host ""
Write-Host "选择菜单布局 / Select menu layout:" -ForegroundColor Cyan
Write-Host "  [1] 平铺 / Flat (直接显示在右键菜单)" -ForegroundColor White
Write-Host "  [2] 子菜单 / Submenu (归类到子菜单)" -ForegroundColor White
Write-Host ""

do {
    Write-Host "请选择 (1/2) [默认 1] / Select (1/2) [default 1]:" -NoNewline
    $layoutChoice = Read-Line
} while ($layoutChoice -ne "" -and $layoutChoice -ne "1" -and $layoutChoice -ne "2")

$MenuLayout = "Flat"
$SubMenuName = "Coding Launcher"

if ($layoutChoice -eq "2") {
    $MenuLayout = "Submenu"
    Write-Host "请输入子菜单名称 [默认 Coding Launcher]" -ForegroundColor Cyan
    Write-Host "Enter submenu name [default Coding Launcher]:" -ForegroundColor Cyan
    $customName = Read-Line
    if ($customName.Trim() -ne "") { $SubMenuName = $customName.Trim() }
    Write-Host "子菜单模式 / Submenu mode: $SubMenuName" -ForegroundColor Green
} else {
    Write-Host "平铺模式 / Flat mode" -ForegroundColor Green
}

# ============================================================
#  版本获取 / Version detection
# ============================================================

function Get-ToolVersion {
    param([string]$Path)
    try {
        if ($Path -and (Test-Path $Path)) {
            $ver = & $Path --version 2>&1 | Select-Object -First 1
            if ($ver -match '(\d+\.\d+[\.\d]*\w*)') { return "v$($Matches[1])" }
        }
    } catch {}
    return ""
}

# ============================================================
#  Windows 工具检测 / Windows tool detection
# ============================================================

$Tools = @(
    @{ Name = "ClaudeCode"; Icon = "claude";  Cmd = "claude.cmd";  Fallback = "$env:APPDATA\npm\claude.cmd";  CustomArgs = "" }
    @{ Name = "CodexCli";   Icon = "codex";   Cmd = "codex.cmd";   Fallback = "$env:APPDATA\npm\codex.cmd";   CustomArgs = "" }
    @{ Name = "CopilotCli"; Icon = "copilot"; Cmd = "github-copilot-cli.cmd"; Fallback = "$env:APPDATA\npm\github-copilot-cli.cmd"; CustomArgs = "" }
    @{ Name = "GeminiCli";  Icon = "gemini";  Cmd = "gemini.cmd";  Fallback = "$env:APPDATA\npm\gemini.cmd";  CustomArgs = "" }
    @{ Name = "OpenCode";   Icon = "opencode";Cmd = "opencode.cmd"; Fallback = "$env:APPDATA\npm\opencode.cmd"; CustomArgs = "" }
)

foreach ($t in $Tools) {
    $found = (Get-Command $t.Cmd -ErrorAction SilentlyContinue).Source
    if (-not $found -or -not (Test-Path $found)) { $found = $t.Fallback }
    $t.Found = $found -and (Test-Path $found)
    $t.Path  = $found
    if ($t.Found) { $t.Version = Get-ToolVersion -Path $found }
}

$Installed    = $Tools | Where-Object { $_.Found }
$NotInstalled = $Tools | Where-Object { -not $_.Found }

Write-Host ""
if ($Installed) {
    $inStr = ($Installed | ForEach-Object {
        $v = if ($_.Version) { " ($($_.Version))" } else { "" }
        "$($_.Name)$v"
    }) -join "、"
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
                    $verRaw = wsl -d $dist -- $linuxCmd --version 2>&1 | Select-Object -First 1
                    $version = if ($verRaw -match '(\d+\.\d+[\.\d]*\w*)') { "v$($Matches[1])" } else { "" }
                    $distInstalled += $t.Name
                    $WslTools += @{ Distro = $dist; Tool = $t; LinuxCmd = $linuxCmd; CustomArgs = ""; Version = $version }
                } else {
                    $distNotInstalled += $t.Name
                }
            }

            if ($distInstalled.Count -gt 0) {
                $distVerStr = ($WslTools | Where-Object { $_.Distro -eq $dist } | ForEach-Object {
                    $v = if ($_.Version) { " ($($_.Version))" } else { "" }
                    "$($_.Tool.Name)$v"
                }) -join "、"
                Write-Host "  $dist 已安装 / installed: $distVerStr" -ForegroundColor Green
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
    return
}

# ============================================================
#  选择菜单 / Selection menu
# ============================================================

# --- Build unified list ---
$AllItems = @()
$idx = 1

foreach ($t in $Tools) {
    if ($t.Found) {
        $v = if ($t.Version) { " $($t.Version)" } else { "" }
        $AllItems += @{ Index = $idx; Display = "$($t.Name)$v        (Windows)"; Type = "Win"; Data = $t }
        $idx++
    }
}
foreach ($wt in $WslTools) {
    $v = if ($wt.Version) { " $($wt.Version)" } else { "" }
    $AllItems += @{ Index = $idx; Display = "$($wt.Tool.Name)$v WSL    ($($wt.Distro))"; Type = "WSL"; Data = $wt }
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
    Write-Host "请输入要添加的编号 (如 1,3,5 或 1-3)，输入 all 全选 [默认 all]" -ForegroundColor Cyan
    Write-Host "Select items (e.g. 1,3,5 or 1-3), or 'all' [default all]:" -ForegroundColor Cyan
    $userInput = Read-Line
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

# ============================================================
#  自定义启动参数 / Custom launch parameters
# ============================================================

Write-Host ""
Write-Host "是否需要添加自定义启动参数？(y/n) [默认 n]" -ForegroundColor Cyan
Write-Host "Do you want to add custom launch parameters? (y/n) [default n]:" -ForegroundColor Cyan
$customArgsChoice = Read-Line

if ($customArgsChoice -eq "y") {
    # Build configurable items list (only selected items)
    $ConfigurableItems = @()
    $cIdx = 1
    foreach ($item in $SelectedItems) {
        if ($item.Type -eq "Win") {
            $displayName = "$($item.Data.Name)        (Windows)"
        } else {
            $displayName = "$($item.Data.Tool.Name) WSL    ($($item.Data.Distro))"
        }
        $ConfigurableItems += @{ Index = $cIdx; Display = $displayName; Item = $item }
        $cIdx++
    }

    $exitCustomArgs = $false
    while (-not $exitCustomArgs) {
        Write-Host ""
        Write-Host "可配置的工具 / Configurable tools:" -ForegroundColor Cyan
        foreach ($ci in $ConfigurableItems) {
            $currentArgs = $ci.Item.Data.CustomArgs
            $argsDisplay = if ($currentArgs) { "  当前参数: $currentArgs" } else { "" }
            Write-Host "  [$($ci.Index)] $($ci.Display)$argsDisplay" -ForegroundColor White
        }

        Write-Host ""
        Write-Host "输入编号选择工具，完成后直接回车 / Enter number to select, press Enter when done:" -NoNewline
        $toolChoice = Read-Line

        if ($toolChoice.Trim() -eq "") {
            $exitCustomArgs = $true
            continue
        }

        if ($toolChoice -match '^\d+$') {
            $chosenIdx = [int]$toolChoice
            $chosenItem = $ConfigurableItems | Where-Object { $_.Index -eq $chosenIdx }

            if ($chosenItem) {
                if ($chosenItem.Item.Type -eq "Win") {
                    $toolName = $chosenItem.Item.Data.Name
                } else {
                    $toolName = "$($chosenItem.Item.Data.Tool.Name) WSL ($($chosenItem.Item.Data.Distro))"
                }
                $currentArgs = $chosenItem.Item.Data.CustomArgs

                $argsDisplay = if ($currentArgs) { $currentArgs } else { "(无 / none)" }
                Write-Host ""
                Write-Host "$toolName 当前参数 / Current args: $argsDisplay" -ForegroundColor Yellow
                Write-Host "请输入自定义参数 (Enter 保存 / Esc 返回)" -ForegroundColor Cyan
                Write-Host "Enter custom args (Enter to save / Esc to go back):" -ForegroundColor Cyan

                $result = Read-LineWithEsc

                if ($result.Save) {
                    $chosenItem.Item.Data.CustomArgs = $result.Value

                    if ($result.Value) {
                        Write-Host "已保存 / Saved: $toolName → $($result.Value)" -ForegroundColor Green
                    } else {
                        Write-Host "已清除 / Cleared: $toolName" -ForegroundColor Green
                    }
                } else {
                    Write-Host "已取消 / Cancelled" -ForegroundColor Yellow
                }
            } else {
                Write-Host "无效编号，请重新输入。" -ForegroundColor Yellow
            }
        } else {
            Write-Host "无效输入，请输入编号或直接回车完成。" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "自定义参数配置完成 / Custom parameters configuration complete." -ForegroundColor Green
}

# ============================================================
#  图标样式选择 / Icon style selection
# ============================================================

$Suffix = ""

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
        Write-Host "请选择 (1/2) [默认 1] / Select (1/2) [default 1]:" -NoNewline
        $choice = Read-Line
    } while ($choice -ne "" -and $choice -ne "1" -and $choice -ne "2")

    if ($choice -eq "2") { $Suffix = "-color"; Write-Host "使用彩色图标 / Using color icons." -ForegroundColor Green }
    else { Write-Host "使用黑白图标 / Using monochrome icons." -ForegroundColor Green }
}

foreach ($t in $Tools) { Write-Host "$($t.Name): $($t.Path)" -ForegroundColor DarkGray }
Write-Host "图标目录 / Icon dir: $IconDir" -ForegroundColor DarkGray

# ============================================================
#  复制图标 / Copy icons
# ============================================================

if (-not (Test-Path $IconDir)) { New-Item -ItemType Directory -Path $IconDir -Force | Out-Null }

$IconBases = @("claude", "codex", "copilot", "gemini", "opencode", "coding")
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

function Get-MenuKeyName {
    param(
        [string]$Type,
        [object]$Data
    )

    if ($Type -eq "Win") {
        return "$($Data.Name)PWSH"
    } else {
        return "$($Data.Tool.Name)WSL_$($Data.Distro)"
    }
}

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
#  子菜单父级创建 / Submenu parent creation
# ============================================================

$BgPlaceholder  = "%V"
$DirPlaceholder = "%1"

if ($MenuLayout -eq "Submenu") {
    $SubmenuKeyName = "CodingLauncher"
    $CommandStoreRoot = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell"

    # Parent icon: coding launcher icon (follows global color choice)
    $parentIcon = Join-Path $IconDir "coding.ico"
    if (-not (Test-Path $parentIcon)) {
        # Fallback to first available tool icon
        $fallbackIcon = $null
        foreach ($item in $SelectedItems) {
            if ($item.Type -eq "Win") {
                $testIcon = Join-Path $IconDir "$($item.Data.Icon).ico"
            } else {
                $testIcon = Join-Path $IconDir "$($item.Data.Tool.Icon).ico"
            }
            if (Test-Path $testIcon) { $fallbackIcon = $testIcon; break }
        }
        if ($fallbackIcon) { $parentIcon = $fallbackIcon }
    }

    # Build SubCommands list
    $subCommands = @()
    foreach ($item in $SelectedItems) {
        $subCommands += Get-MenuKeyName -Type $item.Type -Data $item.Data
    }

    # Create parent keys under HKCU shell
    foreach ($parentPath in @(
        "HKCU:\Software\Classes\Directory\Background\shell\$SubmenuKeyName",
        "HKCU:\Software\Classes\Directory\shell\$SubmenuKeyName"
    )) {
        if (Test-Path $parentPath) { Remove-Item $parentPath -Recurse -Force }
        New-Item -Path $parentPath -Force | Out-Null
        Set-ItemProperty -Path $parentPath -Name "MUIVerb" -Value $SubMenuName
        Set-ItemProperty -Path $parentPath -Name "Icon" -Value $parentIcon
        Set-ItemProperty -Path $parentPath -Name "SubCommands" -Value ($subCommands -join ";")
    }

    # Clean up old CommandStore entries from previous installs
    foreach ($cmdName in $subCommands) {
        $oldPath = Join-Path $CommandStoreRoot $cmdName
        if (Test-Path $oldPath) { Remove-Item $oldPath -Recurse -Force }
    }

    # Child commands go into CommandStore (shared by both Background and Directory)
    $BgRoot  = $CommandStoreRoot
    $DirRoot = $CommandStoreRoot

    Write-Host ""
    Write-Host "子菜单父级已创建 / Submenu parent created: $SubMenuName" -ForegroundColor Cyan
} else {
    $SubmenuKeyName = ""
    $BgRoot  = "HKCU:\Software\Classes\Directory\Background\shell"
    $DirRoot = "HKCU:\Software\Classes\Directory\shell"
}

# ============================================================
#  注册选中项 / Register selected items
# ============================================================

Write-Host ""
Write-Host "正在注册右键菜单 / Registering context menu..." -ForegroundColor Cyan

foreach ($item in $SelectedItems) {
    $menuName = Get-MenuKeyName -Type $item.Type -Data $item.Data

    if ($item.Type -eq "Win") {
        $t = $item.Data
        $iconPath = Join-Path $IconDir "$($t.Icon).ico"
        $customArgs = if ($t.CustomArgs) { " $($t.CustomArgs)" } else { "" }

        $bgCmd = "pwsh.exe -NoExit -NoProfile -Command `"cd '$BgPlaceholder'; & '$($t.Path)'$customArgs`""

        if ($MenuLayout -eq "Submenu") {
            Write-RegContextMenu -Root $BgRoot -Name $menuName -Display "$($t.Name) PWSH" -Icon $iconPath -Command $bgCmd
        } else {
            $dirCmd = "pwsh.exe -NoExit -NoProfile -Command `"cd '$DirPlaceholder'; & '$($t.Path)'$customArgs`""
            Write-RegContextMenu -Root $BgRoot -Name $menuName -Display "$($t.Name) PWSH" -Icon $iconPath -Command $bgCmd
            Write-RegContextMenu -Root $DirRoot -Name $menuName -Display "$($t.Name) PWSH" -Icon $iconPath -Command $dirCmd
        }

        $argsInfo = if ($t.CustomArgs) { "  参数: $($t.CustomArgs)" } else { "" }
        Write-Host "  $($t.Name) PWSH  (背景 / background + 文件夹 / folder)$argsInfo" -ForegroundColor Cyan
    }
    elseif ($item.Type -eq "WSL") {
        $wt = $item.Data
        $iconPath = Join-Path $IconDir "$($wt.Tool.Icon).ico"
        $display  = "$($wt.Tool.Name) WSL ($($wt.Distro))"
        $customArgs = if ($wt.CustomArgs) { " $($wt.CustomArgs)" } else { "" }

        $bgCmd = "wsl.exe -d {0} --cd `"{1}`" -- {2}{3}" -f $wt.Distro, $BgPlaceholder, $wt.LinuxCmd, $customArgs

        if ($MenuLayout -eq "Submenu") {
            Write-RegContextMenu -Root $BgRoot  -Name $menuName -Display $display -Icon $iconPath -Command $bgCmd
        } else {
            $dirCmd = "wsl.exe -d {0} --cd `"{1}`" -- {2}{3}" -f $wt.Distro, $DirPlaceholder, $wt.LinuxCmd, $customArgs
            Write-RegContextMenu -Root $BgRoot  -Name $menuName -Display $display -Icon $iconPath -Command $bgCmd
            Write-RegContextMenu -Root $DirRoot -Name $menuName -Display $display -Icon $iconPath -Command $dirCmd
        }

        $argsInfo = if ($wt.CustomArgs) { "  参数: $($wt.CustomArgs)" } else { "" }
        Write-Host "  $display  (背景 / background + 文件夹 / folder)$argsInfo" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "安装完成 / Installation complete!" -ForegroundColor Green

# Save config for uninstall
$config = @{
    MenuLayout = $MenuLayout
    SubmenuKeyName = $SubmenuKeyName
}
$config | ConvertTo-Json | Set-Content -Path (Join-Path $IconDir "config.json") -Encoding UTF8

Write-Host "如果菜单项未立即出现，请重启资源管理器或注销后重新登录。" -ForegroundColor Yellow
Write-Host "If menu items don't appear immediately, restart Explorer or log out and back in." -ForegroundColor Yellow

} catch {
    Write-Host ""
    Write-Host "发生错误 / Error occurred:" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    if ($_.InvocationInfo.ScriptLineNumber) {
        Write-Host "  位置 / At: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor DarkRed
    }
} finally {
    Write-Host ""
    Write-Host "按任意键退出 / Press any key to exit ..." -ForegroundColor White
    try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { Start-Sleep -Seconds 15 }
}
