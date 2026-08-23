param(
    [ValidateSet('development', 'production')]
    [string]$Environment = 'development',
    [string]$ExpectedProjectId = '',
    [string]$FirebaseOptionsPath = 'lib\firebase_options.dart',
    [string]$GoogleServicesPath = 'android\app\google-services.json',
    [string]$ProjectRoot = 'C:\Projects\homeVaultApp'
)

$ErrorActionPreference = 'Stop'
$DevelopmentProjectId = 'homevault-aamir-india-1701'
$ExpectedPackageName = 'com.amuaamir.homevault'

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
if (-not [System.IO.Path]::IsPathRooted($FirebaseOptionsPath)) {
    $FirebaseOptionsPath = Join-Path $ProjectRoot $FirebaseOptionsPath
}
if (-not [System.IO.Path]::IsPathRooted($GoogleServicesPath)) {
    $GoogleServicesPath = Join-Path $ProjectRoot $GoogleServicesPath
}

foreach ($path in @($FirebaseOptionsPath, $GoogleServicesPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Firebase configuration file not found: $path"
    }
}

$google = Get-Content -Raw -LiteralPath $GoogleServicesPath | ConvertFrom-Json
$googleProjectId = "$($google.project_info.project_id)".Trim()
$packageNames = @(
    $google.client |
        ForEach-Object { $_.client_info.android_client_info.package_name } |
        Where-Object { -not [string]::IsNullOrWhiteSpace("$_") }
)

$dart = Get-Content -Raw -LiteralPath $FirebaseOptionsPath
$dartProjectIds = @(
    [regex]::Matches($dart, 'projectId\s*:\s*[''"]([^''"]+)[''"]') |
        ForEach-Object { $_.Groups[1].Value.Trim() } |
        Sort-Object -Unique
)

if ([string]::IsNullOrWhiteSpace($googleProjectId)) {
    throw 'google-services.json does not contain project_info.project_id.'
}
if ($dartProjectIds.Count -eq 0) {
    throw 'firebase_options.dart does not contain a Firebase projectId.'
}
if ($dartProjectIds -notcontains $googleProjectId) {
    throw 'Firebase Dart and Android configuration files target different projects.'
}
if ($packageNames -notcontains $ExpectedPackageName) {
    throw "google-services.json is not registered for $ExpectedPackageName."
}

if ($Environment -eq 'development') {
    if ($googleProjectId -ne $DevelopmentProjectId) {
        throw "Development configuration must target $DevelopmentProjectId."
    }
    if ($ExpectedProjectId -and $ExpectedProjectId -ne $DevelopmentProjectId) {
        throw 'ExpectedProjectId conflicts with the HomeVault development project.'
    }
} else {
    if ([string]::IsNullOrWhiteSpace($ExpectedProjectId)) {
        throw 'Production validation requires -ExpectedProjectId.'
    }
    if ($ExpectedProjectId -eq $DevelopmentProjectId) {
        throw 'Production cannot use the HomeVault development Firebase project.'
    }
    if ($googleProjectId -ne $ExpectedProjectId) {
        throw 'Production Firebase configuration does not match ExpectedProjectId.'
    }
}

Write-Host "PASS  Firebase environment: $Environment"
Write-Host "PASS  Firebase project ID: $googleProjectId"
Write-Host "PASS  Android package: $ExpectedPackageName"
exit 0
