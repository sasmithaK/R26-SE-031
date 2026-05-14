# PowerShell script to force clean Flutter project artifacts
# Useful when 'flutter clean' fails due to file locks

$ErrorActionPreference = "Continue"

Write-Host "🚀 Starting Force Clean..." -ForegroundColor Cyan

# 1. Kill any stray Dart/Flutter processes that might lock files
Write-Host "🛑 Stopping Dart/Flutter processes..." -ForegroundColor Yellow
Get-Process -Name "dart", "flutter" -ErrorAction SilentlyContinue | Stop-Process -Force

# 2. Define items to delete
$targets = @(
    "build",
    ".dart_tool",
    ".flutter-plugins",
    ".flutter-plugins-dependencies",
    ".packages",
    "pubspec.lock",
    "windows/flutter/ephemeral",
    "linux/flutter/ephemeral",
    "macos/Flutter/ephemeral"
)

foreach ($item in $targets) {
    if (Test-Path $item) {
        Write-Host "🗑️ Deleting $item..." -ForegroundColor Gray
        try {
            Remove-Item -Path $item -Recurse -Force -ErrorAction Stop
            Write-Host "✅ Deleted $item" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to delete $item. It might be locked by another process." -ForegroundColor Red
        }
    }
}

Write-Host "✨ Clean complete! Run 'flutter pub get' to restore dependencies." -ForegroundColor Cyan
