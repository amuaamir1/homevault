[CmdletBinding()]
param(
    [switch]$SkipPubGet,
    [switch]$SkipIntegration
)

$ErrorActionPreference = 'Stop'

function Run-Step([string]$Name, [scriptblock]$Command) {
    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
}

if (-not (Test-Path 'pubspec.yaml')) {
    throw 'Run this script from the Flutter project root.'
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'flutter is not available on PATH.'
}

if (-not $SkipPubGet) {
    Run-Step 'flutter pub get' { flutter pub get }
}

$formatTargets = @()
foreach ($d in @('lib','test','integration_test')) {
    if (Test-Path $d) { $formatTargets += $d }
}
if ($formatTargets.Count -gt 0) {
    Run-Step 'dart format check' { dart format --output=none --set-exit-if-changed @formatTargets }
}

Run-Step 'flutter analyze' { flutter analyze }
Run-Step 'flutter test' { flutter test }

if ((Test-Path 'integration_test') -and -not $SkipIntegration) {
    Run-Step 'flutter integration tests' { flutter test integration_test }
}

Write-Host "`nOVERALL PASS" -ForegroundColor Green
