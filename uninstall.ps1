<#
.SYNOPSIS
    Uninstall ClaudeCode / CodexCli / CopilotCli / GeminiCli / OpenCode context menu entries
    (including WSL variants and submenu layout).
.DESCRIPTION
    Removes registry entries and icon files installed by install.ps1.
#>

# --- Self-elevate if not running as Administrator ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptPath = $MyInvocation.MyCommand.Definition
    Start-Process pwsh.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    exit
}

$ErrorActionPreference = "Continue"

$IconDir   = "$env:USERPROFILE\.context-menu-icons"
$MenuNames = @("ClaudeCodePWSH", "CodexCliPWSH", "CopilotCliPWSH", "GeminiCliPWSH", "OpenCodePWSH")
$Roots     = @(
    "HKCU:\Software\Classes\Directory\Background\shell",
    "HKCU:\Software\Classes\Directory\shell"
)

# --- Read config if available ---
$MenuLayout = "Flat"
$SubmenuKeyName = "CodingLauncher"
$configPath = Join-Path $IconDir "config.json"

if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $MenuLayout = $config.MenuLayout
        if ($config.SubmenuKeyName) { $SubmenuKeyName = $config.SubmenuKeyName }
    } catch {
        Write-Host "Warning: Could not read config.json, using defaults." -ForegroundColor Yellow
    }
}

Write-Host "Removing registry entries..." -ForegroundColor Cyan

foreach ($root in $Roots) {
    foreach ($name in $MenuNames) {
        $keyPath = Join-Path $root $name
        if (Test-Path $keyPath) {
            try {
                Remove-Item $keyPath -Recurse -Force
                Write-Host "  Removed: $keyPath" -ForegroundColor Yellow
            } catch {
                Write-Host "  Failed to remove: $keyPath - $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "  Not found: $keyPath" -ForegroundColor DarkGray
        }
    }
}

# --- Remove CommandStore entries (used by submenu mode) ---
$CommandStoreRoot = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell"
Write-Host "Removing CommandStore entries..." -ForegroundColor Cyan
foreach ($name in $MenuNames) {
    $keyPath = Join-Path $CommandStoreRoot $name
    if (Test-Path $keyPath) {
        try {
            Remove-Item $keyPath -Recurse -Force
            Write-Host "  Removed: $keyPath" -ForegroundColor Yellow
        } catch {
            Write-Host "  Failed to remove: $keyPath - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
# Also remove WSL entries from CommandStore
if (Test-Path $CommandStoreRoot) {
    Get-ChildItem $CommandStoreRoot -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match 'WSL' } |
        ForEach-Object {
            try {
                Remove-Item $_.PSPath -Recurse -Force
                Write-Host "  Removed: $($_.PSPath)" -ForegroundColor Yellow
            } catch {
                Write-Host "  Failed to remove: $($_.PSPath) - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
}

Write-Host "Removing WSL registry entries..." -ForegroundColor Cyan

foreach ($root in $Roots) {
    Get-ChildItem $root -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match 'WSL' } |
        ForEach-Object {
            try {
                Remove-Item $_.PSPath -Recurse -Force
                Write-Host "  Removed: $($_.PSPath)" -ForegroundColor Yellow
            } catch {
                Write-Host "  Failed to remove: $($_.PSPath) - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
}

# --- Remove submenu parent key if exists ---
Write-Host "Removing submenu parent entries..." -ForegroundColor Cyan
foreach ($root in $Roots) {
    $keyPath = Join-Path $root $SubmenuKeyName
    if (Test-Path $keyPath) {
        try {
            Remove-Item $keyPath -Recurse -Force
            Write-Host "  Removed: $keyPath" -ForegroundColor Yellow
        } catch {
            Write-Host "  Failed to remove: $keyPath - $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  Not found: $keyPath" -ForegroundColor DarkGray
    }
}

if (Test-Path $IconDir) {
    try {
        Remove-Item $IconDir -Recurse -Force
        Write-Host "Removed icon directory: $IconDir" -ForegroundColor Yellow
    } catch {
        Write-Host "Failed to remove icon directory: $IconDir - $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "Icon directory not found: $IconDir" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Uninstallation complete!" -ForegroundColor Green
