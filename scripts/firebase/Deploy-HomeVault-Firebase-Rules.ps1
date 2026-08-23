param(
    [ValidateSet('development', 'production')]
    [string]$Environment = 'development',
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,
    [string]$ProjectRoot = 'C:\Projects\homeVaultApp',
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

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    throw 'Firebase CLI is not installed or not available in PATH.'
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
    & firebase deploy --only 'firestore:rules,storage' --project $ProjectId
    if ($LASTEXITCODE -ne 0) {
        throw "Firebase rules deployment failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

Write-Host "HomeVault $Environment rules deployment completed for $ProjectId."
