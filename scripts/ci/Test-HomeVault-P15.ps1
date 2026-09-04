[CmdletBinding()]
param(
    [switch]$RunFlutterTests
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Push-Location $repo
try {
    Write-Host '=== HomeVault P15 local audit ===' -ForegroundColor Cyan
    foreach ($path in @(
        '.\pubspec.yaml',
        '.\pubspec.lock',
        '.\lib\core\app_build_info.dart',
        '.\.github\workflows\development-validation.yml',
        '.\.github\workflows\developer-release.yml',
        '.\.github\workflows\manual-release.yml',
        '.\scripts\ci\homevault_ci.py',
        '.\test\p15_ci_release_contract_test.dart'
    )) {
        if (-not (Test-Path $path)) { throw "Missing required P15 file: $path" }
    }

    $pubspec = Get-Content '.\pubspec.yaml' -Raw
    $versionMatch = [regex]::Match($pubspec, '(?m)^version:\s*([^+\s]+)\+(\d+)\s*$')
    if (-not $versionMatch.Success) { throw 'pubspec.yaml must contain version: x.y.z+N.' }
    $version = $versionMatch.Groups[1].Value
    $build = $versionMatch.Groups[2].Value
    if ($version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$') {
        throw "Invalid HomeVault semantic version: $version"
    }
    if ([int]$build -le 0) { throw 'Build number must be positive.' }

    $buildInfo = Get-Content '.\lib\core\app_build_info.dart' -Raw
    $appVersion = [regex]::Match($buildInfo, "static const String version = '([^']*)';").Groups[1].Value
    $appBuild = [regex]::Match($buildInfo, "static const String buildNumber = '([^']*)';").Groups[1].Value
    $release = [regex]::Match($buildInfo, "static const String releaseNumber = '(R\d+)';").Groups[1].Value
    if ($appVersion -ne $version) { throw "AppBuildInfo.version ($appVersion) != pubspec version ($version)." }
    if ($appBuild -ne $build) { throw "AppBuildInfo.buildNumber ($appBuild) != pubspec build ($build)." }
    if (-not $release) { throw 'AppBuildInfo.releaseNumber must use RNN format.' }
    Write-Host "Release metadata: PASS (v$version+$build $release)" -ForegroundColor Green

    & git ls-files --error-unmatch pubspec.lock *> $null
    if ($LASTEXITCODE -ne 0) { throw 'pubspec.lock must be tracked by Git.' }
    $lockDiff = (& git diff -- pubspec.lock) -join "`n"
    $lockStaged = (& git diff --cached -- pubspec.lock) -join "`n"
    if ($lockDiff -or $lockStaged) { throw 'pubspec.lock has uncommitted changes.' }
    Write-Host 'Lockfile reproducibility: PASS' -ForegroundColor Green

    $tracked = & git ls-files
    $sensitivePatterns = @(
        '(^|/)android/key\.properties$',
        '\.(jks|keystore|p12|pfx)$',
        '(^|/)lib/firebase_options\.dart$',
        '(^|/)android/app/google-services\.json$',
        '(service[-_]?account|firebase-admin|adminsdk).*\.json$'
    )
    $offenders = @()
    foreach ($file in $tracked) {
        $normalized = $file -replace '\\','/'
        foreach ($pattern in $sensitivePatterns) {
            if ($normalized -match $pattern) { $offenders += $normalized; break }
        }
    }
    if ($offenders.Count -gt 0) { throw "Sensitive/generated files are tracked: $($offenders -join ', ')" }
    Write-Host 'Tracked source secret hygiene: PASS' -ForegroundColor Green

    $workflowText = (Get-Content '.\.github\workflows\development-validation.yml' -Raw) + "`n" +
                    (Get-Content '.\.github\workflows\developer-release.yml' -Raw) + "`n" +
                    (Get-Content '.\.github\workflows\manual-release.yml' -Raw)
    foreach ($token in @('FINAL RELEASE GATE','SHA256SUMS.txt','release-manifest.json','verify-artifact','validate-lock','P15 failure diagnostics')) {
        if ($workflowText -notmatch [regex]::Escape($token)) { throw "P15 workflow contract missing: $token" }
    }
    if ($workflowText -match 'flutter-version:\s*(stable|latest)') { throw 'CI must use an exact repository FLUTTER_VERSION, not stable/latest.' }
    Write-Host 'Static workflow hardening contract: PASS' -ForegroundColor Green

    if ($RunFlutterTests) {
        & dart format --output=none --set-exit-if-changed lib test
        if ($LASTEXITCODE -ne 0) { throw 'dart format failed.' }
        & flutter analyze
        if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed.' }
        & flutter test test/p15_ci_release_contract_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'P15 contract tests failed.' }
        & flutter test
        if ($LASTEXITCODE -ne 0) { throw 'Full Flutter test suite failed.' }
    }

    Write-Host '=== P15 LOCAL AUDIT PASS ===' -ForegroundColor Green
}
finally {
    Pop-Location
}
