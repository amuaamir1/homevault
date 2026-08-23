param(
    [string]$ProjectPath = "C:\Projects\homeVaultApp",
    [string]$ProductionProjectId = "homevault-prod-in-2026-a1",
    [string]$DevelopmentProjectId = "homevault-aamir-india-1701",
    [string]$ProductionConfigRoot = "C:\Projects\HomeVault-Firebase-Config\production",
    [string]$ExpectedPackageName = "com.amuaamir.homevault",
    [string]$ExpectedProductionAndroidAppId = "1:676132710044:android:04d03b44c9b8e182afef59",
    [string]$ExpectedReleaseSha1 = "55:BD:58:B0:89:20:AD:F7:55:F1:05:F1:21:7E:D2:DE:90:9C:A9:EE",
    [string]$ExpectedReleaseSha256 = "21:B1:30:D8:3C:0B:84:D5:96:31:F3:EC:89:1E:E2:9A:96:81:C2:07:5F:F8:D0:67:ED:88:43:07:2B:9D:D2:4E",
    [string]$ExpectedFirestoreRulesSha256 = "6c1719fbc83104953d1ef9cd62660e8d55dcbf2485712b6af08d523238deb0a7",
    [string]$ExpectedStorageRulesSha256 = "1606d4fbde8ffb7fd5dd6427794d1f6490ef2d283de18780b67df89fbf4dae21",
    [switch]$CheckApk,
    [string]$ApkPath,
    [switch]$CheckDevice,
    [string]$DeviceId = "emulator-5554",
    [switch]$LaunchApp
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

function Write-Section([string]$Title) {
    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor DarkGray
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("=" * 78) -ForegroundColor DarkGray
}

function Pass([string]$Message) {
    Write-Host "PASS  $Message" -ForegroundColor Green
}

function Fail([string]$Message) {
    $script:Failures.Add($Message)
    Write-Host "FAIL  $Message" -ForegroundColor Red
}

function Warn([string]$Message) {
    $script:Warnings.Add($Message)
    Write-Host "WARN  $Message" -ForegroundColor Yellow
}

function Require-File([string]$Path, [string]$Label) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Pass $Label
        return $true
    }
    Fail "$Label (missing: $Path)"
    return $false
}

function Normalize-Fingerprint([string]$Value) {
    return ($Value -replace '[^0-9A-Fa-f]', '').ToUpperInvariant()
}

function Resolve-Adb {
    $candidates = @()
    if ($env:ANDROID_HOME) {
        $candidates += (Join-Path $env:ANDROID_HOME "platform-tools\adb.exe")
    }
    if ($env:ANDROID_SDK_ROOT) {
        $candidates += (Join-Path $env:ANDROID_SDK_ROOT "platform-tools\adb.exe")
    }
    $candidates += (Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe")
    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

function Resolve-ApkSigner {
    $roots = @()
    if ($env:ANDROID_HOME) { $roots += $env:ANDROID_HOME }
    if ($env:ANDROID_SDK_ROOT) { $roots += $env:ANDROID_SDK_ROOT }
    $roots += (Join-Path $env:LOCALAPPDATA "Android\Sdk")
    foreach ($root in $roots | Select-Object -Unique) {
        $buildTools = Join-Path $root "build-tools"
        if (-not (Test-Path -LiteralPath $buildTools -PathType Container)) { continue }
        $candidate = Get-ChildItem -LiteralPath $buildTools -Directory -ErrorAction SilentlyContinue |
            Sort-Object { try { [version]$_.Name } catch { [version]'0.0' } } -Descending |
            ForEach-Object { Join-Path $_.FullName "apksigner.bat" } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Select-Object -First 1
        if ($candidate) { return $candidate }
    }
    return $null
}

$ProjectPath = [System.IO.Path]::GetFullPath($ProjectPath)
if (-not $ApkPath) {
    $ApkPath = Join-Path $ProjectPath "build\app\outputs\flutter-apk\app-release.apk"
}

Write-Host "HomeVault P16 Phase 3 - Production Readiness" -ForegroundColor Cyan
Write-Host "Project    : $ProjectPath"
Write-Host "Production : $ProductionProjectId"
Write-Host "Development: $DevelopmentProjectId"

Write-Section "Environment isolation"
if ($ProductionProjectId -and $DevelopmentProjectId -and $ProductionProjectId -ne $DevelopmentProjectId) {
    Pass "Production and Development project IDs are different"
} else {
    Fail "Production and Development project IDs must be different"
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
    Fail "HomeVault project folder exists"
} else {
    Pass "HomeVault project folder exists"
}

$firebaseRcPath = Join-Path $ProjectPath ".firebaserc"
if (Require-File $firebaseRcPath ".firebaserc exists") {
    try {
        $firebaseRc = Get-Content -LiteralPath $firebaseRcPath -Raw | ConvertFrom-Json
        $defaultProject = [string]$firebaseRc.projects.default
        if ($defaultProject -eq $DevelopmentProjectId) {
            Pass ".firebaserc defaults to Development"
        } else {
            Fail ".firebaserc default is '$defaultProject' instead of Development '$DevelopmentProjectId'"
        }
        if ($defaultProject -ne $ProductionProjectId) {
            Pass ".firebaserc does not default to Production"
        } else {
            Fail ".firebaserc must never default to Production"
        }
    } catch {
        Fail ".firebaserc is not valid JSON"
    }
}

$firebaseJsonPath = Join-Path $ProjectPath "firebase.json"
if (Require-File $firebaseJsonPath "firebase.json exists") {
    $firebaseJsonText = Get-Content -LiteralPath $firebaseJsonPath -Raw
    if ($firebaseJsonText -notmatch [regex]::Escape($ProductionProjectId)) {
        Pass "firebase.json is environment-neutral (Production ID not pinned)"
    } else {
        Fail "firebase.json contains the Production project ID"
    }
}

Write-Section "External Production Firebase configuration"
$prodGoogleServices = Join-Path $ProductionConfigRoot "google-services.json"
$prodFirebaseOptions = Join-Path $ProductionConfigRoot "firebase_options.dart"

if (Require-File $prodGoogleServices "External Production google-services.json exists") {
    try {
        $prodGs = Get-Content -LiteralPath $prodGoogleServices -Raw | ConvertFrom-Json
        if ([string]$prodGs.project_info.project_id -eq $ProductionProjectId) {
            Pass "Production google-services.json project ID"
        } else {
            Fail "Production google-services.json project ID mismatch"
        }
        if ([string]$prodGs.project_info.storage_bucket -eq "$ProductionProjectId.firebasestorage.app") {
            Pass "Production Storage bucket"
        } else {
            Fail "Production Storage bucket mismatch"
        }
        $androidClients = @($prodGs.client | Where-Object {
            $_.client_info.android_client_info.package_name -eq $ExpectedPackageName
        })
        if ($androidClients.Count -gt 0) {
            Pass "Production Android package is $ExpectedPackageName"
        } else {
            Fail "Production Android package $ExpectedPackageName not found"
        }
        $appIds = @($androidClients | ForEach-Object { [string]$_.client_info.mobilesdk_app_id })
        if ($appIds -contains $ExpectedProductionAndroidAppId) {
            Pass "Production Android Firebase App ID"
        } else {
            Fail "Expected Production Android Firebase App ID not found"
        }
        $webClients = @($prodGs.client.oauth_client | Where-Object { $_.client_type -eq 3 })
        if ($webClients.Count -gt 0) {
            Pass "Production Google Sign-In web OAuth client present"
        } else {
            Fail "Production Google Sign-In web OAuth client missing"
        }
    } catch {
        Fail "Production google-services.json could not be parsed"
    }
}

if (Require-File $prodFirebaseOptions "External Production firebase_options.dart exists") {
    $prodOptionsText = Get-Content -LiteralPath $prodFirebaseOptions -Raw
    if ($prodOptionsText -match [regex]::Escape($ProductionProjectId)) {
        Pass "Production firebase_options.dart contains Production project"
    } else {
        Fail "Production firebase_options.dart does not contain Production project"
    }
    if ($prodOptionsText -notmatch [regex]::Escape($DevelopmentProjectId)) {
        Pass "Production firebase_options.dart excludes Development project"
    } else {
        Fail "Production firebase_options.dart contains Development project"
    }
    if ($prodOptionsText -match [regex]::Escape($ExpectedProductionAndroidAppId)) {
        Pass "Production firebase_options.dart contains Production Android App ID"
    } else {
        Fail "Production firebase_options.dart Android App ID mismatch"
    }
}

Write-Section "Local Development configuration restoration"
$localGoogleServices = Join-Path $ProjectPath "android\app\google-services.json"
if (Test-Path -LiteralPath $localGoogleServices -PathType Leaf) {
    try {
        $localGs = Get-Content -LiteralPath $localGoogleServices -Raw | ConvertFrom-Json
        $localProject = [string]$localGs.project_info.project_id
        if ($localProject -eq $DevelopmentProjectId) {
            Pass "Local google-services.json restored to Development"
        } elseif ($localProject -eq $ProductionProjectId) {
            Fail "Local google-services.json is still Production after build/finalization"
        } else {
            Fail "Local google-services.json has unexpected project '$localProject'"
        }
    } catch {
        Fail "Local google-services.json could not be parsed"
    }
} else {
    Warn "Local google-services.json is absent; Development restoration could not be checked"
}

$localOptions = Join-Path $ProjectPath "lib\firebase_options.dart"
if (Test-Path -LiteralPath $localOptions -PathType Leaf) {
    $localOptionsText = Get-Content -LiteralPath $localOptions -Raw
    if ($localOptionsText -match [regex]::Escape($ProductionProjectId)) {
        Fail "Local firebase_options.dart is still Production after build/finalization"
    } elseif ($localOptionsText -match [regex]::Escape($DevelopmentProjectId)) {
        Pass "Local firebase_options.dart restored to Development"
    } else {
        Fail "Local firebase_options.dart does not identify Development"
    }
} else {
    Warn "Local firebase_options.dart is absent; Development restoration could not be checked"
}

Write-Section "P13 Firebase Security Rules integrity"
$firestoreRules = Join-Path $ProjectPath "firestore.rules"
$storageRules = Join-Path $ProjectPath "storage.rules"
if (Require-File $firestoreRules "firestore.rules exists") {
    $hash = (Get-FileHash -LiteralPath $firestoreRules -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -eq $ExpectedFirestoreRulesSha256.ToLowerInvariant()) {
        Pass "Firestore rules exact P13 hardened hash"
    } else {
        Fail "Firestore rules hash changed: $hash"
    }
}
if (Require-File $storageRules "storage.rules exists") {
    $hash = (Get-FileHash -LiteralPath $storageRules -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -eq $ExpectedStorageRulesSha256.ToLowerInvariant()) {
        Pass "Storage rules exact P13 hardened hash"
    } else {
        Fail "Storage rules hash changed: $hash"
    }
}

Write-Section "Production tooling guards"
$buildScript = Join-Path $ProjectPath "scripts\firebase\Build-HomeVault-Production.ps1"
$finalizeScript = Join-Path $ProjectPath "scripts\firebase\Finalize-HomeVault-ProductionFirebase.ps1"
$deployScript = Join-Path $ProjectPath "scripts\firebase\Deploy-HomeVault-Firebase-Rules.ps1"
$liveScript = Join-Path $ProjectPath "scripts\firebase\Test-HomeVault-ProductionFirebase-Live.ps1"

if (Require-File $buildScript "scripts\firebase\Build-HomeVault-Production.ps1") {
    $buildText = Get-Content -LiteralPath $buildScript -Raw
    if ($buildText -match 'ProductionProjectId') { Pass "Production build uses an explicit ProductionProjectId contract" } else { Fail "Production build is missing ProductionProjectId contract" }
    if ($buildText -match 'finally') { Pass "Production build script has a restoration/finally guard" } else { Fail "Production build script is missing a finally restoration guard" }
}

if (Require-File $finalizeScript "scripts\firebase\Finalize-HomeVault-ProductionFirebase.ps1") {
    $text = Get-Content -LiteralPath $finalizeScript -Raw
    if ($text -match '--project') { Pass "Production finalizer uses explicit Firebase project selection" } else { Fail "Production finalizer is missing explicit --project selection" }
}

if (Require-File $deployScript "scripts\firebase\Deploy-HomeVault-Firebase-Rules.ps1") {
    $text = Get-Content -LiteralPath $deployScript -Raw
    if ($text -match '--project') { Pass "Rules deploy uses explicit Firebase project selection" } else { Fail "Rules deploy is missing explicit --project selection" }
}

if (Require-File $liveScript "scripts\firebase\Test-HomeVault-ProductionFirebase-Live.ps1") {
    $text = Get-Content -LiteralPath $liveScript -Raw
    if ($text -match 'ProductionProjectId') { Pass "Live smoke uses an explicit ProductionProjectId contract" } else { Fail "Live smoke is missing ProductionProjectId contract" }
    if ($text -match 'identitytoolkit.googleapis.com') { Pass "Live smoke retains Firebase Auth REST verification" } else { Fail "Live smoke Firebase Auth REST verification is missing" }
}

Write-Section "Tracked secret/config guard"
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git -and (Test-Path -LiteralPath (Join-Path $ProjectPath ".git") -PathType Container)) {
    Push-Location $ProjectPath
    try {
        $tracked = @(& git ls-files 2>$null)
        $blockedPatterns = @(
            '(^|/)google-services\.json$',
            '(^|/)GoogleService-Info\.plist$',
            '(^|/)firebase_options\.dart$',
            '(^|/)key\.properties$',
            '\.(jks|keystore|p12|pfx|pem|key)$',
            '(?i)service[-_]?account.*\.json$',
            '(?i)adminsdk.*\.json$'
        )
        $blocked = New-Object System.Collections.Generic.List[string]
        foreach ($file in $tracked) {
            foreach ($pattern in $blockedPatterns) {
                if ($file -match $pattern) { $blocked.Add($file); break }
            }
        }
        if ($blocked.Count -eq 0) {
            Pass "No sensitive Firebase/signing configuration is tracked by Git"
        } else {
            Fail ("Sensitive tracked files detected: " + (($blocked | Sort-Object -Unique) -join ', '))
        }
    } finally {
        Pop-Location
    }
} else {
    Warn "Git repository/tool unavailable; tracked-secret guard skipped"
}

if ($CheckApk) {
    Write-Section "Production APK integrity and signing"
    if (Require-File $ApkPath "Production APK exists") {
        $apkHash = (Get-FileHash -LiteralPath $ApkPath -Algorithm SHA256).Hash.ToLowerInvariant()
        Pass "APK SHA-256: $apkHash"
        $apksigner = Resolve-ApkSigner
        if (-not $apksigner) {
            Fail "apksigner.bat could not be located"
        } else {
            $verifyOutput = (& $apksigner verify --print-certs $ApkPath 2>&1 | Out-String)
            if ($LASTEXITCODE -ne 0) {
                Fail "apksigner verification failed"
            } else {
                Pass "APK signature verification"
                $expected1 = Normalize-Fingerprint $ExpectedReleaseSha1
                $expected256 = Normalize-Fingerprint $ExpectedReleaseSha256
                $actualText = Normalize-Fingerprint $verifyOutput
                if ($actualText.Contains($expected1)) { Pass "APK release SHA-1 matches Production" } else { Fail "APK release SHA-1 mismatch" }
                if ($actualText.Contains($expected256)) { Pass "APK release SHA-256 matches Production" } else { Fail "APK release SHA-256 mismatch" }
            }
        }
    }
}

if ($CheckDevice) {
    Write-Section "Connected Production device smoke guard"
    $adb = Resolve-Adb
    if (-not $adb) {
        Fail "adb.exe could not be located"
    } else {
        $state = (& $adb -s $DeviceId get-state 2>$null | Out-String).Trim()
        if ($state -eq 'device') { Pass "ADB device $DeviceId connected" } else { Fail "ADB device $DeviceId is not ready (state '$state')" }
        $packagePath = (& $adb -s $DeviceId shell pm path $ExpectedPackageName 2>$null | Out-String).Trim()
        if ($packagePath -match '^package:') { Pass "HomeVault package installed on $DeviceId" } else { Fail "HomeVault package not installed on $DeviceId" }
        if ($LaunchApp -and $state -eq 'device') {
            & $adb -s $DeviceId shell input keyevent KEYCODE_WAKEUP | Out-Null
            & $adb -s $DeviceId shell wm dismiss-keyguard | Out-Null
            & $adb -s $DeviceId shell svc power stayon true | Out-Null
            & $adb -s $DeviceId shell am start -W -n "$ExpectedPackageName/.MainActivity" | Out-Host
            Start-Sleep -Seconds 8
            $appPid = (& $adb -s $DeviceId shell pidof $ExpectedPackageName 2>$null | Out-String).Trim()
            if ($appPid) { Pass "HomeVault process running (PID $appPid)" } else { Fail "HomeVault process is not running after launch" }
            $focus = (& $adb -s $DeviceId shell dumpsys window 2>$null | Select-String 'mCurrentFocus|mFocusedApp' | Out-String)
            if ($focus -match [regex]::Escape($ExpectedPackageName)) { Pass "HomeVault owns/resolves focused app window" } else { Fail "HomeVault does not own the focused app window" }
            if ($focus -match 'Application Not Responding') { Fail "Android ANR window is active" } else { Pass "No Android ANR focus window" }
        }
    }
}

Write-Section "Summary"
Write-Host "Warnings: $($script:Warnings.Count)"
Write-Host "Failures: $($script:Failures.Count)"
if ($script:Failures.Count -gt 0) {
    Write-Host "OVERALL: FAIL" -ForegroundColor Red
    exit 1
}
Write-Host "OVERALL: PASS" -ForegroundColor Green
exit 0
