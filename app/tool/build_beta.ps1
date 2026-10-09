# Builds the beta APKs (task 5.8, docs/beta-release.md), pointed at the
# deployed server. Run from app/:
#   .\tool\build_beta.ps1 -ApiUrl https://mizan-api.onrender.com
# Bump `version:` in pubspec.yaml and `appVersion` in lib/app/app_version.dart
# first (a test checks they match), so an update installs over the old APK.
param(
    [Parameter(Mandatory = $true)]
    [string]$ApiUrl
)

$ErrorActionPreference = 'Stop'

# Release builds block plain http, so a LAN or emulator URL would build an
# APK that can never sign in.
if ($ApiUrl -notmatch '^https://[^/]+$') {
    throw "Give the server's https:// address with no path, e.g. https://mizan-api.onrender.com"
}

$health = Invoke-RestMethod -Uri "$ApiUrl/health" -TimeoutSec 90
if ($health.status -ne 'ok') {
    throw "The server answered /health with: $($health | ConvertTo-Json -Compress)"
}

flutter build apk --release --split-per-abi --dart-define=MIZAN_API_URL=$ApiUrl
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Get-ChildItem build\app\outputs\flutter-apk\*-release.apk |
    Select-Object Name, @{ Name = 'MB'; Expression = { [math]::Round($_.Length / 1MB, 1) } }
