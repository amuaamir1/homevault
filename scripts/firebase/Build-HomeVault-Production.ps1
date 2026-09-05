param(
    [Parameter(Mandatory = $true)]
    [string]$ProductionProjectId,
    [string]$ProjectRoot = 'C:\Projects\homeVaultApp',
    [string]$ConfigRoot = 'C:\Projects\HomeVault-Firebase-Config\production',
    [ValidateSet('appbundle', 'apk')]
    [string]$Artifact = 'appbundle',
    [string]$BuildName = '',
    [string]$BuildNumber = ''
)

$ErrorActionPreference = 'Stop'
$DevelopmentProjectId = 'homevault-aamir-india-1701'
$PrivacyPolicyUrl = 'https://homevault-prod-in-2026-a1.web.app/privacy'
$TermsOfServiceUrl = 'https://homevault-prod-in-2026-a1.web.app/terms'
$AccountDeletionUrl = 'https://homevault-prod-in-2026-a1.web.app/delete-account'
$SupportEmail = 'support.homevault1@gmail.com'

function Assert-HomeVaultProductionLegalUrl {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name is required for a production release."
    }

    try {
        $uri = [System.Uri]$Value
    } catch {
        throw "$Name is not a valid URL: $Value"
    }

    $uriHost = $uri.Host.Trim().ToLowerInvariant()
    if ($uri.Scheme -ne 'https' -or [string]::IsNullOrWhiteSpace($uriHost)) {
        throw "$Name must be a public HTTPS URL."
    }
    if ($uriHost -in @('localhost', '127.0.0.1', '0.0.0.0') -or $uriHost.EndsWith('.local')) {
        throw "$Name cannot use a local/development host."
    }
    if ($Value -match '(?i)placeholder|example\.(com|org|net)') {
        throw "$Name still contains a placeholder/example value."
    }
}

Assert-HomeVaultProductionLegalUrl -Name 'Privacy Policy URL' -Value $PrivacyPolicyUrl
Assert-HomeVaultProductionLegalUrl -Name 'Terms of Service URL' -Value $TermsOfServiceUrl
Assert-HomeVaultProductionLegalUrl -Name 'Account deletion URL' -Value $AccountDeletionUrl
if ($SupportEmail -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$' -or
    $SupportEmail -match '(?i)placeholder|example\.(com|org|net)') {
    throw 'HOMEVAULT_SUPPORT_EMAIL must be a real public support email address.'
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$ConfigRoot = [System.IO.Path]::GetFullPath($ConfigRoot)

if ($ProductionProjectId.Trim() -eq $DevelopmentProjectId) {
    throw 'ProductionProjectId cannot be the HomeVault development Firebase project.'
}
if ([string]::IsNullOrWhiteSpace($ProductionProjectId)) {
    throw 'ProductionProjectId is required.'
}
if (-not (Test-Path (Join-Path $ProjectRoot 'pubspec.yaml'))) {
    throw "HomeVault project not found: $ProjectRoot"
}

$prodDart = Join-Path $ConfigRoot 'firebase_options.dart'
$prodAndroid = Join-Path $ConfigRoot 'google-services.json'
$validator = Join-Path $ProjectRoot 'scripts\firebase\Test-HomeVault-Firebase-Environment.ps1'

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator `
    -Environment production `
    -ExpectedProjectId $ProductionProjectId `
    -FirebaseOptionsPath $prodDart `
    -GoogleServicesPath $prodAndroid `
    -ProjectRoot $ProjectRoot
if ($LASTEXITCODE -ne 0) {
    throw 'Production Firebase configuration validation failed.'
}

$activeDart = Join-Path $ProjectRoot 'lib\firebase_options.dart'
$activeAndroid = Join-Path $ProjectRoot 'android\app\google-services.json'
$tempRoot = Join-Path $env:TEMP "homevault-production-build-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$dartBackup = Join-Path $tempRoot 'firebase_options.dart'
$androidBackup = Join-Path $tempRoot 'google-services.json'
$hadDart = Test-Path $activeDart
$hadAndroid = Test-Path $activeAndroid

if ($hadDart) { Copy-Item $activeDart $dartBackup -Force }
if ($hadAndroid) { Copy-Item $activeAndroid $androidBackup -Force }

$previousExpected = $env:HOMEVAULT_FIREBASE_PROJECT_ID
$previousAllow = $env:HOMEVAULT_ALLOW_NON_PROD_RELEASE
$previousPrivacyPolicyUrl = $env:HOMEVAULT_PRIVACY_POLICY_URL
$previousTermsOfServiceUrl = $env:HOMEVAULT_TERMS_OF_SERVICE_URL
$previousAccountDeletionUrl = $env:HOMEVAULT_ACCOUNT_DELETION_URL
$previousSupportEmail = $env:HOMEVAULT_SUPPORT_EMAIL

try {
    Copy-Item $prodDart $activeDart -Force
    Copy-Item $prodAndroid $activeAndroid -Force

    $env:HOMEVAULT_FIREBASE_PROJECT_ID = $ProductionProjectId
    $env:HOMEVAULT_PRIVACY_POLICY_URL = $PrivacyPolicyUrl
    $env:HOMEVAULT_TERMS_OF_SERVICE_URL = $TermsOfServiceUrl
    $env:HOMEVAULT_ACCOUNT_DELETION_URL = $AccountDeletionUrl
    $env:HOMEVAULT_SUPPORT_EMAIL = $SupportEmail
    Remove-Item Env:HOMEVAULT_ALLOW_NON_PROD_RELEASE -ErrorAction SilentlyContinue

    $arguments = @(
        'build', $Artifact,
        '--release',
        '--dart-define=HOMEVAULT_ENV=production',
        "--dart-define=HOMEVAULT_FIREBASE_PROJECT_ID=$ProductionProjectId",
        "--dart-define=HOMEVAULT_PRIVACY_POLICY_URL=$PrivacyPolicyUrl",
        "--dart-define=HOMEVAULT_TERMS_OF_SERVICE_URL=$TermsOfServiceUrl",
        "--dart-define=HOMEVAULT_ACCOUNT_DELETION_URL=$AccountDeletionUrl",
        "--dart-define=HOMEVAULT_SUPPORT_EMAIL=$SupportEmail"
    )
    if ($BuildName) { $arguments += "--build-name=$BuildName" }
    if ($BuildNumber) { $arguments += "--build-number=$BuildNumber" }

    $flutterCommand = Get-Command flutter.bat -ErrorAction SilentlyContinue
    if ($null -eq $flutterCommand) {
        $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    }
    if ($null -eq $flutterCommand) {
        throw 'Flutter is not installed or not available in PATH.'
    }

    Push-Location $ProjectRoot
    try {
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & $flutterCommand.Source @arguments
            $flutterExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousPreference
        }

        if ($flutterExitCode -ne 0) {
            throw "Flutter production build failed with exit code $flutterExitCode."
        }
    } finally {
        Pop-Location
    }
} finally {
    if ($hadDart) {
        Copy-Item $dartBackup $activeDart -Force
    } else {
        Remove-Item $activeDart -Force -ErrorAction SilentlyContinue
    }

    if ($hadAndroid) {
        Copy-Item $androidBackup $activeAndroid -Force
    } else {
        Remove-Item $activeAndroid -Force -ErrorAction SilentlyContinue
    }

    if ($null -eq $previousExpected) {
        Remove-Item Env:HOMEVAULT_FIREBASE_PROJECT_ID -ErrorAction SilentlyContinue
    } else {
        $env:HOMEVAULT_FIREBASE_PROJECT_ID = $previousExpected
    }
    if ($null -eq $previousAllow) {
        Remove-Item Env:HOMEVAULT_ALLOW_NON_PROD_RELEASE -ErrorAction SilentlyContinue
    } else {
        $env:HOMEVAULT_ALLOW_NON_PROD_RELEASE = $previousAllow
    }

    $legalEnvironment = @{
        HOMEVAULT_PRIVACY_POLICY_URL = $previousPrivacyPolicyUrl
        HOMEVAULT_TERMS_OF_SERVICE_URL = $previousTermsOfServiceUrl
        HOMEVAULT_ACCOUNT_DELETION_URL = $previousAccountDeletionUrl
        HOMEVAULT_SUPPORT_EMAIL = $previousSupportEmail
    }
    foreach ($entry in $legalEnvironment.GetEnumerator()) {
        if ($null -eq $entry.Value) {
            Remove-Item "Env:$($entry.Key)" -ErrorAction SilentlyContinue
        } else {
            Set-Item "Env:$($entry.Key)" $entry.Value
        }
    }

    Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'Production Firebase configuration was restored to its external location only.'
Write-Host 'Local development Firebase files were restored after the build.'

