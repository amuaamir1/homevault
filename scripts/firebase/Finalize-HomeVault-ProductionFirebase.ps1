param(
    [string]$ProductionProjectId = '',
    [string]$ProjectRoot = 'C:\Projects\homeVaultApp',
    [string]$ConfigRoot = 'C:\Projects\HomeVault-Firebase-Config\production',
    [string]$FirestoreLocation = 'asia-south1',
    [string]$ReleaseSha1 = '',
    [string]$FirebaseNodeExe = 'C:\Tools\Node22\node.exe',
    [string]$FirebaseCliJs = '',
    [switch]$ConfirmProjectMarkedProduction,
    [switch]$ConfirmBlazeAndStorage,
    [switch]$ConfirmAuthConfigured,
    [switch]$ConfirmProductionRules,
    [switch]$RunLiveSmoke,
    [switch]$BuildProductionApk
)

$ErrorActionPreference = 'Stop'
$DevelopmentProjectId = 'homevault-aamir-india-1701'
$PackageName = 'com.amuaamir.homevault'

function Write-Section([string]$Text) {
    Write-Host ''
    Write-Host ('=' * 78)
    Write-Host $Text
    Write-Host ('=' * 78)
}

function Normalize-Sha1([string]$Value) {
    return (($Value -replace '[^0-9A-Fa-f]', '').ToUpperInvariant())
}

function Resolve-FirebaseRunner {
    if ([string]::IsNullOrWhiteSpace($script:FirebaseNodeExe)) {
        $script:FirebaseNodeExe = 'C:\Tools\Node22\node.exe'
    }
    if ([string]::IsNullOrWhiteSpace($script:FirebaseCliJs)) {
        if ([string]::IsNullOrWhiteSpace($env:APPDATA)) {
            throw 'APPDATA is unavailable, so the Firebase CLI JavaScript path cannot be resolved.'
        }
        $script:FirebaseCliJs = Join-Path $env:APPDATA 'npm\node_modules\firebase-tools\lib\bin\firebase.js'
    }

    $script:FirebaseNodeExe = [System.IO.Path]::GetFullPath($script:FirebaseNodeExe)
    $script:FirebaseCliJs = [System.IO.Path]::GetFullPath($script:FirebaseCliJs)

    if (-not (Test-Path -LiteralPath $script:FirebaseNodeExe -PathType Leaf)) {
        throw @"
HomeVault P16 requires the stable Node 22 Firebase runner.

Expected Node executable:
  $script:FirebaseNodeExe

Install/download Node 22 there, or pass -FirebaseNodeExe explicitly.
The global Node/Firebase runner is intentionally not used for Production
provisioning because Node 24 was observed crashing in Firebase SHA commands.
"@
    }
    if (-not (Test-Path -LiteralPath $script:FirebaseCliJs -PathType Leaf)) {
        throw @"
Firebase CLI JavaScript entry point was not found:
  $script:FirebaseCliJs

Install firebase-tools for the current user, or pass -FirebaseCliJs explicitly.
"@
    }

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $nodeVersionOutput = & $script:FirebaseNodeExe --version 2>&1
        $nodeVersionExitCode = $LASTEXITCODE
        $firebaseVersionOutput = & $script:FirebaseNodeExe $script:FirebaseCliJs --version 2>&1
        $firebaseVersionExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }

    $nodeVersion = (@($nodeVersionOutput | ForEach-Object { "$_" }) -join "`n").Trim()
    $firebaseVersion = (@($firebaseVersionOutput | ForEach-Object { "$_" }) -join "`n").Trim()

    if ($nodeVersionExitCode -ne 0 -or $nodeVersion -notmatch '^v22\.') {
        throw "HomeVault P16 Firebase operations require Node 22. Resolved runner reported '$nodeVersion'."
    }
    if ($firebaseVersionExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($firebaseVersion)) {
        throw 'Firebase CLI could not be started through the stable Node 22 runner.'
    }

    Write-Host "Firebase Node runner: $script:FirebaseNodeExe ($nodeVersion)"
    Write-Host "Firebase CLI entry: $script:FirebaseCliJs ($firebaseVersion)"
}

function Invoke-Firebase {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$AllowFailure,
        [switch]$Quiet
    )

    if (-not $Quiet) {
        Write-Host "firebase $($Arguments -join ' ')"
    }

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $script:FirebaseNodeExe $script:FirebaseCliJs @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }

    if (-not $Quiet) {
        $output | ForEach-Object { Write-Host "$_" }
    }

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "Firebase CLI command failed with exit code $exitCode."
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = @($output)
        Text = (@($output | ForEach-Object { "$_" }) -join "`n")
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$ConfigRoot = [System.IO.Path]::GetFullPath($ConfigRoot)
$statePath = Join-Path $ConfigRoot 'production-onboarding.json'

if ([string]::IsNullOrWhiteSpace($ProductionProjectId) -and (Test-Path $statePath)) {
    $state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
    $ProductionProjectId = "$($state.projectId)".Trim()
    if ([string]::IsNullOrWhiteSpace($ReleaseSha1)) {
        $ReleaseSha1 = "$($state.releaseSha1)".Trim()
    }
    if ("$($state.firestoreLocation)".Trim()) {
        $FirestoreLocation = "$($state.firestoreLocation)".Trim()
    }
}

if ([string]::IsNullOrWhiteSpace($ProductionProjectId)) {
    throw 'ProductionProjectId is required or must exist in production-onboarding.json.'
}
if ($ProductionProjectId -eq $DevelopmentProjectId) {
    throw 'Production finalization cannot target the Development Firebase project.'
}

foreach ($gate in @(
    @{ Name = 'Project marked Production'; Confirmed = $ConfirmProjectMarkedProduction },
    @{ Name = 'Blaze plan and default Storage bucket'; Confirmed = $ConfirmBlazeAndStorage },
    @{ Name = 'Email/Password and Google Authentication'; Confirmed = $ConfirmAuthConfigured },
    @{ Name = 'Production Security Rules deployment'; Confirmed = $ConfirmProductionRules }
)) {
    if (-not $gate.Confirmed) {
        throw "Finalization requires explicit confirmation: $($gate.Name)."
    }
}

$script:FirebaseNodeExe = $FirebaseNodeExe
$script:FirebaseCliJs = $FirebaseCliJs
Resolve-FirebaseRunner

Write-Section 'Refresh Production Android Firebase configuration'
$googleServicesPath = Join-Path $ConfigRoot 'google-services.json'
$optionsPath = Join-Path $ConfigRoot 'firebase_options.dart'

$existingGoogle = $null
if (Test-Path $googleServicesPath) {
    $existingGoogle = Get-Content -Raw -LiteralPath $googleServicesPath | ConvertFrom-Json
}
$appId = @(
    $existingGoogle.client |
        Where-Object {
            "$($_.client_info.android_client_info.package_name)" -eq $PackageName
        } |
        ForEach-Object { "$($_.client_info.mobilesdk_app_id)".Trim() }
) | Where-Object { $_ } | Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($appId)) {
    throw 'Production Android Firebase App ID is missing. Re-run the provisioning script first.'
}

$sdkConfig = Invoke-Firebase -Arguments @(
    'apps:sdkconfig',
    'android',
    $appId,
    '--project', $ProductionProjectId,
    '--out', $googleServicesPath,
    '--non-interactive'
)
if ($sdkConfig.ExitCode -ne 0) {
    throw 'Could not refresh Production google-services.json.'
}

$google = Get-Content -Raw -LiteralPath $googleServicesPath | ConvertFrom-Json
if ("$($google.project_info.project_id)" -ne $ProductionProjectId) {
    throw 'Refreshed Production google-services.json targets the wrong project.'
}

$storageBucket = "$($google.project_info.storage_bucket)".Trim()
if ([string]::IsNullOrWhiteSpace($storageBucket)) {
    throw 'Production Cloud Storage default bucket is not present in google-services.json. Provision Storage in Firebase Console, then run finalization again.'
}
if ($storageBucket -notmatch '\.firebasestorage\.app$|\.appspot\.com$') {
    throw "Unexpected Production Storage bucket name: $storageBucket"
}
Write-Host "PASS  Production Storage bucket: $storageBucket"

$client = @(
    $google.client |
        Where-Object {
            "$($_.client_info.android_client_info.package_name)" -eq $PackageName
        }
) | Select-Object -First 1

$webOauthClients = @(
    $client.oauth_client |
        Where-Object { "$($_.client_type)" -eq '3' }
)
if ($webOauthClients.Count -eq 0) {
    throw 'Production google-services.json has no web OAuth client. Enable Google sign-in and refresh the Android config.'
}
Write-Host 'PASS  Google sign-in OAuth client is present in Production Android config'

Write-Section 'Release SHA-1 verification'
if ([string]::IsNullOrWhiteSpace($ReleaseSha1)) {
    $shaHelper = Join-Path $ProjectRoot 'scripts\firebase\Get-HomeVault-ReleaseSha1.ps1'
    $ReleaseSha1 = (
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $shaHelper -ProjectRoot $ProjectRoot
    ).Trim()
}

$normalizedSha1 = Normalize-Sha1 $ReleaseSha1
if ($normalizedSha1.Length -ne 40) {
    throw 'Could not determine a valid release SHA-1 fingerprint.'
}

$shaListResult = Invoke-Firebase -Arguments @(
    'apps:android:sha:list',
    $appId,
    '--project', $ProductionProjectId
)
$shaList = $shaListResult.Text

if ((Normalize-Sha1 $shaList) -notmatch [regex]::Escape($normalizedSha1)) {
    throw 'Production Firebase Android app does not contain the HomeVault release SHA-1.'
}
Write-Host 'PASS  Production Android release SHA-1'

Write-Section 'Production Firestore verification'
$firestoreResult = Invoke-Firebase -Arguments @(
    'firestore:databases:get',
    '(default)',
    '--project', $ProductionProjectId
)
$firestoreText = $firestoreResult.Text
if ($firestoreText -notmatch [regex]::Escape($FirestoreLocation)) {
    Write-Warning "Firestore exists, but its CLI output did not confirm expected location '$FirestoreLocation'. Review this before launch."
} else {
    Write-Host "PASS  Production Firestore location: $FirestoreLocation"
}

Write-Section 'Regenerate external Production firebase_options.dart'
$generator = Join-Path $ProjectRoot 'scripts\firebase\New-HomeVault-ProductionFirebaseOptions.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $generator `
    -ExpectedProjectId $ProductionProjectId `
    -GoogleServicesPath $googleServicesPath `
    -OutputPath $optionsPath
if ($LASTEXITCODE -ne 0) {
    throw 'Production firebase_options.dart generation failed.'
}

$environmentValidator = Join-Path $ProjectRoot 'scripts\firebase\Test-HomeVault-Firebase-Environment.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $environmentValidator `
    -Environment production `
    -ExpectedProjectId $ProductionProjectId `
    -FirebaseOptionsPath $optionsPath `
    -GoogleServicesPath $googleServicesPath `
    -ProjectRoot $ProjectRoot
if ($LASTEXITCODE -ne 0) {
    throw 'Production Firebase environment configuration validation failed.'
}

Write-Section 'Deploy validated P13 Firebase Security Rules to Production'
$deployRules = Join-Path $ProjectRoot 'scripts\firebase\Deploy-HomeVault-Firebase-Rules.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $deployRules `
    -Environment production `
    -ProjectId $ProductionProjectId `
    -ProjectRoot $ProjectRoot `
    -FirebaseNodeExe $script:FirebaseNodeExe `
    -FirebaseCliJs $script:FirebaseCliJs `
    -ConfirmProduction
if ($LASTEXITCODE -ne 0) {
    throw 'Production Firebase Security Rules deployment failed.'
}

if ($RunLiveSmoke) {
    Write-Section 'Production Auth and Firestore live smoke'
    $smoke = Join-Path $ProjectRoot 'scripts\firebase\Test-HomeVault-ProductionFirebase-Live.ps1'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $smoke `
        -ProductionProjectId $ProductionProjectId `
        -ConfigRoot $ConfigRoot
    if ($LASTEXITCODE -ne 0) {
        throw 'Production Firebase live smoke failed.'
    }
}

if ($BuildProductionApk) {
    Write-Section 'Production APK build'
    $build = Join-Path $ProjectRoot 'scripts\firebase\Build-HomeVault-Production.ps1'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $build `
        -ProductionProjectId $ProductionProjectId `
        -ProjectRoot $ProjectRoot `
        -ConfigRoot $ConfigRoot `
        -Artifact apk
    if ($LASTEXITCODE -ne 0) {
        throw 'Production APK build failed.'
    }
}

$state = [ordered]@{
    schemaVersion = 1
    environment = 'production'
    projectId = $ProductionProjectId
    androidPackageName = $PackageName
    androidAppId = $appId
    firestoreLocation = $FirestoreLocation
    releaseSha1 = $ReleaseSha1
    storageBucket = $storageBucket
    authenticationProviders = @('password', 'google.com')
    projectMarkedProductionConfirmed = $true
    blazeAndStorageConfirmed = $true
    authConfiguredConfirmed = $true
    productionRulesDeployed = $true
    liveSmokePassed = [bool]$RunLiveSmoke
    productionApkBuilt = [bool]$BuildProductionApk
    finalizedAt = (Get-Date).ToString('o')
}

$state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath -Encoding utf8

Write-Host ''
Write-Host 'P16 Phase 2 Production Firebase finalization completed.'
Write-Host "Production project: $ProductionProjectId"
Write-Host "Storage bucket: $storageBucket"
Write-Host "External config: $ConfigRoot"
if (-not $RunLiveSmoke) {
    Write-Warning 'Run finalization again with -RunLiveSmoke before marking P16 Phase 2 complete.'
}
if (-not $BuildProductionApk) {
    Write-Warning 'A real Production APK has not yet been built by this run.'
}
