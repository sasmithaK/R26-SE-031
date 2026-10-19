param(
    [string]$LanIp = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $projectRoot

if (-not $LanIp) {
    $LanIp = Get-NetIPConfiguration |
        Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq "Up" } |
        ForEach-Object { $_.IPv4Address.IPAddress } |
        Where-Object { $_ -match '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' } |
        Select-Object -First 1
}

if (-not $LanIp) {
    throw "No private Wi-Fi/LAN IPv4 address was found. Pass it explicitly: .\start_local_network.ps1 -LanIp 192.168.x.x"
}

$required = @("MONGODB_URL", "JWT_SECRET_KEY")
$missing = $required | Where-Object { -not [Environment]::GetEnvironmentVariable($_, "Process") }
if ($missing.Count -gt 0 -and -not (Test-Path -LiteralPath "$projectRoot\app\backend\api\.env")) {
    throw "Set these environment variables in this PowerShell window first: $($missing -join ', ')"
}

Write-Host "Local services will listen on all interfaces. Phone host: $LanIp"
Write-Host "Use the same MongoDB database and exact JWT_SECRET_KEY as the Render authentication service."
Write-Host "In another terminal run:"
Write-Host "  cd app\frontend"
Write-Host "  flutter run --dart-define=API_HOST=$LanIp"
Write-Host "If Windows asks about Python network access, allow Private networks."

& "$projectRoot\venv\Scripts\python.exe" "$projectRoot\start_services.py"
