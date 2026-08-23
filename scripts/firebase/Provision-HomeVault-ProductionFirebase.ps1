param(
    [string]$ProductionProjectId = '',
    [string]$DisplayName = 'HomeVault Production',
    [string]$ProjectRoot = 'C:\Projects\homeVaultApp',
    [string]$ConfigRoot = 'C:\Projects\HomeVault-Firebase-Config\production',
    [string]$FirestoreLocation = 'asia-south1',
    [string]$AndroidAppId = '',
    [string]$ReleaseSha1 = '',
    [string]$FirebaseNodeExe = 'C:\Tools\Node22\node.exe',
    [string]$FirebaseCliJs = '',
    [switch]$ConfirmCreateProject,
    [switch]$ConfirmCreateFirestore
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

    # Windows PowerShell 5.1 can promote native stderr/progress output from
    # npm PowerShell shims into NativeCommandError when the caller uses
    # ErrorActionPreference=Stop. Temporarily allow native stderr, then decide
    # success strictly from the Firebase CLI process exit code.
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
        if ($Quiet -and -not [string]::IsNullOrWhiteSpace((@($output | ForEach-Object { "$_" }) -join "`n"))) {
            Write-Host 'Firebase CLI command output:'
            $output | ForEach-Object { Write-Host "$_" }
        }
        throw "Firebase CLI command failed with exit code $exitCode."
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = @($output)
        Text = (@($output | ForEach-Object { "$_" }) -join "`n")
    }
}

function Normalize-Sha1([string]$Value) {
    return (($Value -replace '[^0-9A-Fa-f]', '').ToUpperInvariant())
}

function Save-OnboardingState {
    param(
        [string]$ProjectId,
        [string]$AppId,
        [string]$Location,
        [string]$GoogleServicesPath,
        [string]$OptionsPath,
        [string]$Sha1
    )

    $state = [ordered]@{
        schemaVersion = 1
        environment = 'production'
        projectId = $ProjectId
        androidPackageName = $PackageName
        androidAppId = $AppId
        firestoreLocation = $Location
        releaseSha1 = $Sha1
        googleServicesPath = $GoogleServicesPath
        firebaseOptionsPath = $OptionsPath
        developmentProjectId = $DevelopmentProjectId
        createdOrUpdatedAt = (Get-Date).ToString('o')
        storageProvisioning = 'manual-console-required'
        authenticationProviders = @('password', 'google.com')
        productionRulesDeployed = $false
    }

    $statePath = Join-Path $ConfigRoot 'production-onboarding.json'
    $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath -Encoding utf8
    return $statePath
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$ConfigRoot = [System.IO.Path]::GetFullPath($ConfigRoot)

Write-Section 'HomeVault P16 Phase 2 - Production Firebase provisioning'

if (-not (Test-Path (Join-Path $ProjectRoot 'pubspec.yaml'))) {
    throw "HomeVault project not found: $ProjectRoot"
}
$script:FirebaseNodeExe = $FirebaseNodeExe
$script:FirebaseCliJs = $FirebaseCliJs
Resolve-FirebaseRunner

if ([string]::IsNullOrWhiteSpace($ProductionProjectId)) {
    $ProductionProjectId = (Read-Host 'Enter the globally unique Production Firebase project ID').Trim()
}

if ($ProductionProjectId -eq $DevelopmentProjectId) {
    throw 'Production Firebase cannot use the HomeVault Development project.'
}
if ($ProductionProjectId -notmatch '^[a-z][a-z0-9-]{4,28}[a-z0-9]$') {
    throw 'ProductionProjectId must be a valid Google Cloud/Firebase project ID: 6-30 lowercase letters, digits, or hyphens, starting with a letter and ending with a letter or digit.'
}

Write-Host "Production Firebase project: $ProductionProjectId"
Write-Host "Firestore location: $FirestoreLocation"
Write-Host "Android package: $PackageName"

Write-Section 'Firebase CLI authentication'
$login = Invoke-Firebase -Arguments @('login:list', '--json') -AllowFailure -Quiet
if ($login.ExitCode -ne 0 -or $login.Text -notmatch '"user"|"email"') {
    Write-Host 'Firebase CLI login is required.'
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $script:FirebaseNodeExe $script:FirebaseCliJs login
        $loginExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($loginExitCode -ne 0) {
        throw 'Firebase CLI login failed.'
    }
}
Write-Host 'PASS  Firebase CLI is authenticated.'

Write-Section 'Production project'

# Prefer a project-specific read-only probe. This avoids relying on the
# combined `projects:list --json` output, which has proven unreliable in this
# Windows Firebase CLI environment.
$projectProbe = Invoke-Firebase -Arguments @(
    'apps:list',
    'android',
    '--project', $ProductionProjectId
) -AllowFailure -Quiet

if ($projectProbe.ExitCode -eq 0) {
    $projectExists = $true
} else {
    # Fall back to plain project listing only to distinguish a genuinely
    # absent project from an access/probe problem. Never create a project when
    # Firebase state is ambiguous.
    $projects = Invoke-Firebase -Arguments @('projects:list') -AllowFailure -Quiet
    if ($projects.ExitCode -ne 0) {
        Write-Host 'Firebase project-specific probe output:'
        Write-Host $projectProbe.Text
        Write-Host 'Firebase projects:list fallback output:'
        Write-Host $projects.Text
        throw 'Could not safely determine whether the Production Firebase project exists. No project was created.'
    }

    $projectPattern = '(?im)(^|[\s|])' + [regex]::Escape($ProductionProjectId) + '([\s|]|$)'
    $projectExists = $projects.Text -match $projectPattern
}

if (-not $projectExists) {
    if (-not $ConfirmCreateProject) {
        throw @"
Production Firebase project '$ProductionProjectId' was not found.

Re-run with -ConfirmCreateProject to create it, or choose an existing Firebase
project you control. The Development project will never be accepted.
"@
    }

    Write-Host "Creating Firebase project '$ProductionProjectId'..."
    Invoke-Firebase -Arguments @(
        'projects:create',
        $ProductionProjectId,
        '--display-name',
        $DisplayName,
        '--non-interactive'
    ) | Out-Null
} else {
    Write-Host 'PASS  Production Firebase project already exists and is accessible.'
}

New-Item -ItemType Directory -Force -Path $ConfigRoot | Out-Null
$googleServicesPath = Join-Path $ConfigRoot 'google-services.json'
$optionsPath = Join-Path $ConfigRoot 'firebase_options.dart'

Write-Section 'Production Android Firebase app'

function Read-ValidatedGoogleServices {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [string]$ExpectedAppId = ''
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    try {
        $googleConfig = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    } catch {
        return $null
    }

    if ("$($googleConfig.project_info.project_id)" -ne $ProductionProjectId) {
        return $null
    }

    $matchingClient = @(
        $googleConfig.client |
            Where-Object {
                "$($_.client_info.android_client_info.package_name)" -eq $PackageName
            }
    ) | Select-Object -First 1

    if ($null -eq $matchingClient) {
        return $null
    }

    $configAppId = "$($matchingClient.client_info.mobilesdk_app_id)".Trim()
    if ([string]::IsNullOrWhiteSpace($configAppId)) {
        return $null
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedAppId) -and $configAppId -ne $ExpectedAppId) {
        return $null
    }

    return [pscustomobject]@{
        Google = $googleConfig
        Client = $matchingClient
        AppId = $configAppId
    }
}

$candidateGoogleServicesPath = Join-Path $ConfigRoot 'google-services.candidate.json'
Remove-Item -LiteralPath $candidateGoogleServicesPath -Force -ErrorAction SilentlyContinue

$downloadArguments = @('apps:sdkconfig', 'android')
if (-not [string]::IsNullOrWhiteSpace($AndroidAppId)) {
    $downloadArguments += $AndroidAppId
}
$downloadArguments += @(
    '--project', $ProductionProjectId,
    '--out', $candidateGoogleServicesPath,
    '--non-interactive'
)

$sdkConfig = Invoke-Firebase -Arguments $downloadArguments -AllowFailure
$candidate = Read-ValidatedGoogleServices `
    -Path $candidateGoogleServicesPath `
    -ExpectedAppId $AndroidAppId

if ($sdkConfig.ExitCode -eq 0 -and $null -ne $candidate) {
    Move-Item -LiteralPath $candidateGoogleServicesPath -Destination $googleServicesPath -Force
    Write-Host 'PASS  Refreshed Production google-services.json.'
} else {
    Remove-Item -LiteralPath $candidateGoogleServicesPath -Force -ErrorAction SilentlyContinue

    if ([string]::IsNullOrWhiteSpace($AndroidAppId)) {
        $existing = Read-ValidatedGoogleServices -Path $googleServicesPath
        if ($null -eq $existing) {
            Write-Host 'No unambiguous Android app configuration was available. Registering HomeVault Production Android.'
            Invoke-Firebase -Arguments @(
                'apps:create',
                '-a', $PackageName,
                'android',
                'HomeVault Production Android',
                '--project', $ProductionProjectId,
                '--non-interactive'
            ) | Out-Null

            $sdkConfig = Invoke-Firebase -Arguments @(
                'apps:sdkconfig',
                'android',
                '--project', $ProductionProjectId,
                '--out', $candidateGoogleServicesPath,
                '--non-interactive'
            ) -AllowFailure

            $candidate = Read-ValidatedGoogleServices -Path $candidateGoogleServicesPath
            if ($sdkConfig.ExitCode -ne 0 -or $null -eq $candidate) {
                Remove-Item -LiteralPath $candidateGoogleServicesPath -Force -ErrorAction SilentlyContinue
                throw 'Could not obtain a valid Production Android Firebase configuration after app registration.'
            }

            Move-Item -LiteralPath $candidateGoogleServicesPath -Destination $googleServicesPath -Force
            Write-Host 'PASS  Downloaded Production google-services.json after Android app registration.'
        } else {
            Write-Warning 'Firebase CLI could not refresh google-services.json. Continuing with the previously validated Production config; finalization must refresh or validate the post-Authentication config.'
        }
    } else {
        $existing = Read-ValidatedGoogleServices `
            -Path $googleServicesPath `
            -ExpectedAppId $AndroidAppId

        if ($null -eq $existing) {
            throw @"
Firebase CLI could not refresh the requested Android Firebase app configuration,
and no previously downloaded Production google-services.json matches:
  Project: $ProductionProjectId
  Package: $PackageName
  App ID:  $AndroidAppId

Download google-services.json from Firebase Console -> Project settings ->
General -> Your apps -> HomeVault Production Android, save it to:
  $googleServicesPath
then re-run provisioning.
"@
        }

        Write-Warning 'Firebase CLI could not refresh google-services.json. Continuing with the previously validated Production config; finalization must refresh or validate the post-Authentication config.'
    }
}

$validatedGoogle = Read-ValidatedGoogleServices `
    -Path $googleServicesPath `
    -ExpectedAppId $AndroidAppId
if ($null -eq $validatedGoogle) {
    throw 'Production google-services.json failed project/package/App-ID validation.'
}

$google = $validatedGoogle.Google
$client = $validatedGoogle.Client
$resolvedAppId = $validatedGoogle.AppId
Write-Host "PASS  Android Firebase App ID: $resolvedAppId"

Write-Section 'Release SHA-1'
if ([string]::IsNullOrWhiteSpace($ReleaseSha1)) {
    $shaHelper = Join-Path $ProjectRoot 'scripts\firebase\Get-HomeVault-ReleaseSha1.ps1'
    if (Test-Path -LiteralPath $shaHelper) {
        try {
            $ReleaseSha1 = (
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $shaHelper -ProjectRoot $ProjectRoot
            ).Trim()
        } catch {
            $ReleaseSha1 = ''
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($ReleaseSha1)) {
    $normalizedSha1 = Normalize-Sha1 $ReleaseSha1
    if ($normalizedSha1.Length -ne 40) {
        throw 'ReleaseSha1 must contain exactly 40 hexadecimal SHA-1 characters.'
    }

    $listedSha = Invoke-Firebase -Arguments @(
        'apps:android:sha:list',
        $resolvedAppId,
        '--project', $ProductionProjectId
    ) -AllowFailure -Quiet

    $listedNormalized = Normalize-Sha1 $listedSha.Text
    if ($listedNormalized -notmatch [regex]::Escape($normalizedSha1)) {
        Invoke-Firebase -Arguments @(
            'apps:android:sha:create',
            $resolvedAppId,
            $ReleaseSha1,
            '--project', $ProductionProjectId,
            '--non-interactive'
        ) | Out-Null
    }
    Write-Host "PASS  Production release SHA-1 is registered."
} else {
    Write-Warning 'Release SHA-1 was not auto-detected. Add the release SHA-1 before enabling Google sign-in.'
}

Write-Section 'Production Firestore'
$firestore = Invoke-Firebase -Arguments @(
    'firestore:databases:get',
    '(default)',
    '--project', $ProductionProjectId
) -AllowFailure -Quiet

if ($firestore.ExitCode -ne 0) {
    if (-not $ConfirmCreateFirestore) {
        throw @"
The Production default Firestore database does not exist.

Re-run with -ConfirmCreateFirestore to create it at '$FirestoreLocation'
with deletion protection enabled.
"@
    }

    Invoke-Firebase -Arguments @(
        'firestore:databases:create',
        '(default)',
        "--location=$FirestoreLocation",
        '--delete-protection', 'ENABLED',
        '--project', $ProductionProjectId,
        '--non-interactive'
    ) | Out-Null

    $firestore = Invoke-Firebase -Arguments @(
        'firestore:databases:get',
        '(default)',
        '--project', $ProductionProjectId
    ) -Quiet
}

if ($firestore.Text -notmatch [regex]::Escape($FirestoreLocation)) {
    Write-Warning "Firestore exists, but its CLI description did not confirm '$FirestoreLocation'. Review the database location before production launch."
} else {
    Write-Host "PASS  Production Firestore location: $FirestoreLocation"
}

Write-Section 'Generate external Production Dart configuration'
$generator = Join-Path $ProjectRoot 'scripts\firebase\New-HomeVault-ProductionFirebaseOptions.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $generator `
    -ExpectedProjectId $ProductionProjectId `
    -GoogleServicesPath $googleServicesPath `
    -OutputPath $optionsPath
if ($LASTEXITCODE -ne 0) {
    throw 'Production firebase_options.dart generation failed.'
}

$statePath = Save-OnboardingState `
    -ProjectId $ProductionProjectId `
    -AppId $resolvedAppId `
    -Location $FirestoreLocation `
    -GoogleServicesPath $googleServicesPath `
    -OptionsPath $optionsPath `
    -Sha1 $ReleaseSha1

Write-Section 'Manual Firebase Console gates still required'
Write-Host '1. Project settings -> General: mark the project environment as Production.'
Write-Host '2. Upgrade/link the project to Blaze before provisioning Cloud Storage.'
Write-Host "3. Databases & Storage -> Storage: create the default bucket. For HomeVault India, use $FirestoreLocation unless you have a documented reason to choose another location."
Write-Host '4. Security -> Authentication -> Sign-in method: enable Email/Password.'
Write-Host '5. Security -> Authentication -> Sign-in method: enable Google and set a support email.'
Write-Host '6. Confirm the Production Android app contains the release SHA-1 fingerprint.'
Write-Host ''
Write-Host "External Production config: $ConfigRoot"
Write-Host "Onboarding state: $statePath"
Write-Host ''
Write-Host 'After completing these Console gates, run:'
Write-Host "  scripts\firebase\Finalize-HomeVault-ProductionFirebase.ps1"
Write-Host ''
Write-Host 'No Production Security Rules have been deployed by this provisioning step.'
