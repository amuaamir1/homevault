param(
    [ValidateSet('development', 'production')]
    [string]$Environment = 'development',
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,
    [string]$ProjectRoot = 'C:\Projects\homeVaultApp',
    [string]$FirebaseNodeExe = 'C:\Tools\Node22\node.exe',
    [string]$FirebaseCliJs = '',
    [switch]$ConfirmProduction
)

$ErrorActionPreference = 'Stop'
$DevelopmentProjectId = 'homevault-aamir-india-1701'
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)

if ($Environment -eq 'development') {
    if ($ProjectId -ne $DevelopmentProjectId) {
        throw "Development deploys must target $DevelopmentProjectId."
    }
} else {
    if ($ProjectId -eq $DevelopmentProjectId) {
        throw 'Production deploy cannot target the development Firebase project.'
    }
    if (-not $ConfirmProduction) {
        throw 'Production rules deployment requires -ConfirmProduction.'
    }
}

$script:FirebaseNodeExe = $FirebaseNodeExe
$script:FirebaseCliJs = $FirebaseCliJs
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
$expectedHashes = @{
    'firestore.rules' = '6c1719fbc83104953d1ef9cd62660e8d55dcbf2485712b6af08d523238deb0a7'
    'storage.rules' = '1606d4fbde8ffb7fd5dd6427794d1f6490ef2d283de18780b67df89fbf4dae21'
}

foreach ($relative in $expectedHashes.Keys) {
    $path = Join-Path $ProjectRoot $relative
    if (-not (Test-Path $path)) { throw "Missing rule file: $path" }
    $hash = (Get-FileHash -Algorithm SHA256 -Path $path).Hash.ToLowerInvariant()
    if ($hash -ne $expectedHashes[$relative]) {
        throw "$relative differs from the validated P13 Phase 2 rules."
    }
}

Push-Location $ProjectRoot
try {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $script:FirebaseNodeExe $script:FirebaseCliJs deploy --only 'firestore:rules,storage' --project $ProjectId
        $firebaseExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($firebaseExitCode -ne 0) {
        throw "Firebase rules deployment failed with exit code $firebaseExitCode."
    }
} finally {
    Pop-Location
}

Write-Host "HomeVault $Environment rules deployment completed for $ProjectId."
