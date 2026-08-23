param(
    [Parameter(Mandatory = $true)]
    [string]$ProductionProjectId,
    [string]$ProjectPath = 'C:\Projects\homeVaultApp',
    [string]$ConfigRoot = 'C:\Projects\HomeVault-Firebase-Config\production'
)

$ErrorActionPreference = 'Stop'
$DevelopmentProjectId = 'homevault-aamir-india-1701'

if ($ProductionProjectId -eq $DevelopmentProjectId) {
    throw 'ProductionProjectId cannot be the HomeVault development Firebase project.'
}

foreach ($command in @('gh', 'git')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command '$command' was not found."
    }
}

$ProjectPath = [System.IO.Path]::GetFullPath($ProjectPath)
$ConfigRoot = [System.IO.Path]::GetFullPath($ConfigRoot)
$firebaseOptions = Join-Path $ConfigRoot 'firebase_options.dart'
$googleServices = Join-Path $ConfigRoot 'google-services.json'
$validator = Join-Path $ProjectPath 'scripts\firebase\Test-HomeVault-Firebase-Environment.ps1'

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator `
    -Environment production `
    -ExpectedProjectId $ProductionProjectId `
    -FirebaseOptionsPath $firebaseOptions `
    -GoogleServicesPath $googleServices `
    -ProjectRoot $ProjectPath
if ($LASTEXITCODE -ne 0) {
    throw 'Production Firebase configuration validation failed.'
}

Set-Location $ProjectPath
& gh auth status
if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI is not authenticated.' }

function Set-Base64Secret([string]$Name, [string]$Path) {
    $base64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path))
    $base64 | & gh secret set $Name
    if ($LASTEXITCODE -ne 0) { throw "Could not set GitHub secret $Name." }
}

Set-Base64Secret -Name 'PROD_FIREBASE_OPTIONS_DART_BASE64' -Path $firebaseOptions
Set-Base64Secret -Name 'PROD_GOOGLE_SERVICES_JSON_BASE64' -Path $googleServices
$ProductionProjectId | & gh variable set PRODUCTION_FIREBASE_PROJECT_ID
if ($LASTEXITCODE -ne 0) {
    throw 'Could not set GitHub variable PRODUCTION_FIREBASE_PROJECT_ID.'
}

Write-Host 'Production Firebase GitHub configuration is installed.'
Write-Host 'No Firebase client configuration content was printed.'
