[CmdletBinding()]
param(
    [switch]$SkipIntegration
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path 'pubspec.yaml')) {
    throw 'Run this script from the Flutter project root.'
}

Write-Host 'Running validation before release build...' -ForegroundColor Cyan
& "$PSScriptRoot\validate-app.ps1" -SkipIntegration:$SkipIntegration
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`n=== flutter build appbundle --release ===" -ForegroundColor Cyan
flutter build appbundle --release
if ($LASTEXITCODE -ne 0) {
    throw "Release AAB build failed with exit code $LASTEXITCODE"
}

$aab = Join-Path (Get-Location) 'build\app\outputs\bundle\release\app-release.aab'
if (Test-Path $aab) {
    Write-Host "`nAAB READY: $aab" -ForegroundColor Green
} else {
    Write-Warning 'Build completed but the default AAB path was not found. Check Flutter build output for the artifact path.'
}

Write-Host 'No Google Play upload or production publication was performed.' -ForegroundColor Yellow
