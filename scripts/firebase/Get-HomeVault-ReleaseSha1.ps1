param(
    [string]$ProjectRoot = 'C:\Projects\homeVaultApp'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$AndroidRoot = Join-Path $ProjectRoot 'android'
$GradleWrapper = Join-Path $AndroidRoot 'gradlew.bat'

if (-not (Test-Path -LiteralPath $GradleWrapper -PathType Leaf)) {
    throw "Gradle wrapper not found: $GradleWrapper"
}

Push-Location $AndroidRoot
try {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $GradleWrapper signingReport 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
} finally {
    Pop-Location
}

if ($exitCode -ne 0) {
    $output | ForEach-Object { Write-Host $_ }
    throw "Gradle signingReport failed with exit code $exitCode."
}

$lines = @($output | ForEach-Object { "$_" })
$insideRelease = $false
$releaseSha1 = $null

foreach ($line in $lines) {
    if ($line -match '^\s*Variant:\s*(.+?)\s*$') {
        $variant = $Matches[1].Trim()
        $insideRelease = $variant -match '^release$'
        continue
    }

    if ($insideRelease -and $line -match '^\s*SHA1:\s*([0-9A-Fa-f:]{40,})\s*$') {
        $releaseSha1 = $Matches[1].ToUpperInvariant()
        break
    }
}

if ([string]::IsNullOrWhiteSpace($releaseSha1)) {
    Write-Host 'Gradle signingReport output:'
    $lines | ForEach-Object { Write-Host $_ }
    throw 'Could not determine the release SHA-1 fingerprint. Verify android/key.properties and the release signing configuration.'
}

Write-Output $releaseSha1
