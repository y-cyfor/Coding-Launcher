<#
.SYNOPSIS
    Uninstall ClaudeCode and OpenCode context menu entries.
.DESCRIPTION
    Removes registry entries and icon files installed by install.ps1.
#>

# --- Self-elevate if not running as Administrator ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptPath = $MyInvocation.MyCommand.Definition
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    exit
}

$ErrorActionPreference = "Stop"

$IconDir   = "$env:USERPROFILE\.context-menu-icons"
$MenuNames = @("ClaudeCodePWSH", "CodexCliPWSH", "CopilotCliPWSH", "GeminiCliPWSH", "OpenCodePWSH")
$Roots     = @(
    "HKCU:\Software\Classes\Directory\Background\shell",
    "HKCU:\Software\Classes\Directory\shell"
)

Write-Host "Removing registry entries..." -ForegroundColor Cyan

foreach ($root in $Roots) {
    foreach ($name in $MenuNames) {
        $keyPath = Join-Path $root $name
        if (Test-Path $keyPath) {
            Remove-Item $keyPath -Recurse -Force
            Write-Host "  Removed: $keyPath" -ForegroundColor Yellow
        } else {
            Write-Host "  Not found: $keyPath" -ForegroundColor DarkGray
        }
    }
}

if (Test-Path $IconDir) {
    Remove-Item $IconDir -Recurse -Force
    Write-Host "Removed icon directory: $IconDir" -ForegroundColor Yellow
} else {
    Write-Host "Icon directory not found: $IconDir" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Uninstallation complete!" -ForegroundColor Green
