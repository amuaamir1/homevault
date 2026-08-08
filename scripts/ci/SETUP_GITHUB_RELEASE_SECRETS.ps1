param(
    [string]$ProjectPath = "C:\Projects\homeVaultApp"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Require-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found."
    }
}

function Read-KeyProperties {
    param([Parameter(Mandatory = $true)][string]$Path)

    $values = @{}

    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()

        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $values[$parts[0].Trim()] = $parts[1].Trim()
        }
    }

    return $values
}

function Resolve-ConfiguredFile {
    param(
        [Parameter(Mandatory = $true)][string]$AndroidFolder,
        [Parameter(Mandatory = $true)][string]$ConfiguredPath
    )

    $candidate = $ConfiguredPath.Trim().Trim('"')

    if ([System.IO.Path]::IsPathRooted($candidate)) {
        return [System.IO.Path]::GetFullPath($candidate)
    }

    return [System.IO.Path]::GetFullPath(
        (Join-Path $AndroidFolder $candidate)
    )
}

function Set-SecretText {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Secret '$Name' is empty."
    }

    $Value | & gh secret set $Name
    if ($LASTEXITCODE -ne 0) {
        throw "Could not set GitHub secret '$Name'."
    }
}

function Set-SecretFileBase64 {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path $Path -PathType Leaf)) {
        throw "Required file not found: $Path"
    }

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $base64 = [Convert]::ToBase64String($bytes)

    if ([Text.Encoding]::UTF8.GetByteCount($base64) -gt 48000) {
        throw "$Path is too large to store directly as a GitHub Actions secret."
    }

    Set-SecretText -Name $Name -Value $base64
}

Require-Command "gh"
Require-Command "git"
Require-Command "flutter"

$ProjectPath = [System.IO.Path]::GetFullPath($ProjectPath)
$AndroidFolder = Join-Path $ProjectPath "android"
$KeyPropertiesPath = Join-Path $AndroidFolder "key.properties"
$FirebaseOptionsPath = Join-Path $ProjectPath "lib\firebase_options.dart"
$GoogleServicesPath = Join-Path $ProjectPath "android\app\google-services.json"

if (-not (Test-Path $KeyPropertiesPath -PathType Leaf)) {
    throw "android\key.properties was not found."
}

Set-Location $ProjectPath

Write-Host "Checking GitHub CLI authentication..." -ForegroundColor Cyan
& gh auth status
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated. Run: gh auth login"
}

$repo = (& gh repo view --json nameWithOwner --jq ".nameWithOwner").Trim()
if ([string]::IsNullOrWhiteSpace($repo)) {
    throw "Could not determine the current GitHub repository."
}

Write-Host "Repository: $repo" -ForegroundColor Green

$keyProperties = Read-KeyProperties -Path $KeyPropertiesPath

foreach ($name in @("storeFile", "storePassword", "keyAlias", "keyPassword")) {
    if (-not $keyProperties.ContainsKey($name)) {
        throw "'$name' is missing from android\key.properties."
    }
}

$KeystorePath = Resolve-ConfiguredFile `
    -AndroidFolder $AndroidFolder `
    -ConfiguredPath $keyProperties["storeFile"]

Write-Host "Setting encrypted GitHub Actions secrets..." -ForegroundColor Cyan

Set-SecretFileBase64 `
    -Name "ANDROID_KEYSTORE_BASE64" `
    -Path $KeystorePath

Set-SecretText `
    -Name "ANDROID_STORE_PASSWORD" `
    -Value $keyProperties["storePassword"]

Set-SecretText `
    -Name "ANDROID_KEY_PASSWORD" `
    -Value $keyProperties["keyPassword"]

Set-SecretText `
    -Name "ANDROID_KEY_ALIAS" `
    -Value $keyProperties["keyAlias"]

Set-SecretFileBase64 `
    -Name "GOOGLE_SERVICES_JSON_BASE64" `
    -Path $GoogleServicesPath

Set-SecretFileBase64 `
    -Name "FIREBASE_OPTIONS_DART_BASE64" `
    -Path $FirebaseOptionsPath

Write-Host "Detecting local Flutter version..." -ForegroundColor Cyan
$flutterInfo = (& flutter --version --machine | ConvertFrom-Json)
$flutterVersion = "$($flutterInfo.frameworkVersion)".Trim()

if ([string]::IsNullOrWhiteSpace($flutterVersion)) {
    throw "Could not determine the local Flutter version."
}

$flutterVersion | & gh variable set FLUTTER_VERSION
if ($LASTEXITCODE -ne 0) {
    throw "Could not set repository variable FLUTTER_VERSION."
}

Write-Host ""
Write-Host "GitHub Actions CI/CD secrets are configured." -ForegroundColor Green
Write-Host "Repository:      $repo"
Write-Host "Flutter version: $flutterVersion"
Write-Host ""
Write-Host "No passwords or keystore data were printed."
