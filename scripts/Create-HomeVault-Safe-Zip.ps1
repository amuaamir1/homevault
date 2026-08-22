param(
    [string]$Source = "",
    [string]$OutputRoot = "C:\Projects\HomeVault-Safe-Zips"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Source)) {
    $Source = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "HomeVault source folder not found: $Source"
}

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$WorkingRoot = Join-Path $env:TEMP "homevault-safe-$Timestamp"
$WorkingCopy = Join-Path $WorkingRoot "homeVaultApp"
$ZipPath = Join-Path $OutputRoot "homeVaultApp-safe-$Timestamp.zip"

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
Remove-Item -LiteralPath $WorkingRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $WorkingCopy | Out-Null

$ExcludedDirectoryNames = @(
    ".git", ".dart_tool", ".idea", ".vscode", "build",
    ".gradle", "Pods", "DerivedData", "node_modules", "coverage"
)

$ExcludedExtensions = @(
    ".jks", ".keystore", ".p12", ".pfx", ".pem", ".key",
    ".cer", ".crt", ".der"
)

$SecretLikeNamePatterns = @(
    ".env",
    ".env.*",
    "local.properties",
    "local.properties.*",
    "key.properties",
    "key.properties.*",
    "google-services.json",
    "google-services.json.*",
    "GoogleService-Info.plist",
    "GoogleService-Info.plist.*",
    "firebase_options.dart",
    "firebase_options.dart.*",
    "*service-account*.json",
    "*service_account*.json",
    "*firebase-admin*.json",
    "*firebase_admin*.json",
    "*adminsdk*.json",
    "*credentials*.json",
    "*secrets*.json"
)

function Should-ExcludeFile {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$File,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $segments = $RelativePath -split '[\\/]'
    foreach ($segment in $segments) {
        if ($ExcludedDirectoryNames -contains $segment) { return $true }
    }

    if ($ExcludedExtensions -contains $File.Extension.ToLowerInvariant()) {
        return $true
    }

    foreach ($Pattern in $SecretLikeNamePatterns) {
        if ($File.Name -like $Pattern) { return $true }
    }

    return $false
}

function Is-TestLikePath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $normalized = $RelativePath.Replace("\", "/").ToLowerInvariant()

    return (
        $normalized.StartsWith("test/") -or
        $normalized.StartsWith("integration_test/") -or
        $normalized.Contains("/test/") -or
        $normalized.Contains("/tests/") -or
        $normalized.Contains("/fixtures/") -or
        $normalized.Contains("/fixture/") -or
        $normalized.Contains("/example/") -or
        $normalized.Contains("/examples/") -or
        $normalized.Contains("/mock/") -or
        $normalized.Contains("/mocks/")
    )
}

Write-Host "Creating sanitized HomeVault copy..." -ForegroundColor Cyan

$SourceRoot = (Resolve-Path -LiteralPath $Source).Path
$Files = Get-ChildItem -LiteralPath $SourceRoot -Recurse -File -Force

$Copied = 0
$Excluded = 0

foreach ($File in $Files) {
    $RelativePath = $File.FullName.Substring($SourceRoot.Length).TrimStart("\", "/")

    if (Should-ExcludeFile -File $File -RelativePath $RelativePath) {
        $Excluded++
        continue
    }

    $Destination = Join-Path $WorkingCopy $RelativePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    Copy-Item -LiteralPath $File.FullName -Destination $Destination -Force
    $Copied++
}

$TextExtensions = @(
    ".dart", ".yaml", ".yml", ".json", ".xml", ".gradle", ".kts",
    ".properties", ".md", ".txt", ".ps1", ".sh", ".bat", ".cmd",
    ".html", ".js", ".ts", ".java", ".kt", ".swift"
)

$BlockingPatterns = @(
    @{ Name = "private key"; Pattern = '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' },
    @{ Name = "Google API key"; Pattern = '\bAIza[0-9A-Za-z\-_]{30,}\b' },
    @{ Name = "GitHub token"; Pattern = '\bgh[pousr]_[0-9A-Za-z]{30,}\b' },
    @{ Name = "AWS access key"; Pattern = '\bAKIA[0-9A-Z]{16}\b' },
    @{ Name = "AWS temporary access key"; Pattern = '\bASIA[0-9A-Z]{16}\b' },
    @{ Name = "Slack token"; Pattern = 'xox[baprs]-[0-9A-Za-z-]{10,}' },
    @{ Name = "client/private/API secret"; Pattern = '(?i)\b(client_secret|private_key|api_secret|access_token|refresh_token)\b\s*[:=]\s*["''][^"'']{8,}' }
)

$PasswordPattern = '(?i)\b(password|passwd)\b\s*[:=]\s*["''][^"'']{6,}'

$BlockingFindings = New-Object System.Collections.Generic.List[string]
$Warnings = New-Object System.Collections.Generic.List[string]

$SafeFiles = Get-ChildItem -LiteralPath $WorkingCopy -Recurse -File -Force |
    Where-Object { $TextExtensions -contains $_.Extension.ToLowerInvariant() }

foreach ($File in $SafeFiles) {
    try {
        $Content = [System.IO.File]::ReadAllText($File.FullName)
    }
    catch {
        continue
    }

    $RelativePath = $File.FullName.Substring($WorkingCopy.Length).TrimStart("\", "/")

    foreach ($Rule in $BlockingPatterns) {
        if ([regex]::IsMatch($Content, $Rule.Pattern)) {
            $BlockingFindings.Add("$RelativePath -> $($Rule.Name)")
        }
    }

    if ([regex]::IsMatch($Content, $PasswordPattern)) {
        if (Is-TestLikePath -RelativePath $RelativePath) {
            $Warnings.Add("$RelativePath -> password-like test fixture")
        }
        else {
            $BlockingFindings.Add(
                "$RelativePath -> password-like literal outside test fixtures"
            )
        }
    }
}

if ($Warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "Review-only warnings:" -ForegroundColor Yellow
    $Warnings | Sort-Object -Unique | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Yellow
    }
    Write-Host "Test/example fixture warnings do not block the ZIP."
}

if ($BlockingFindings.Count -gt 0) {
    Write-Host ""
    Write-Host "Potential real secrets were detected. ZIP was NOT created." -ForegroundColor Red
    $BlockingFindings | Sort-Object -Unique | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Red
    }

    Remove-Item -LiteralPath $WorkingRoot -Recurse -Force -ErrorAction SilentlyContinue
    throw "Sanitization stopped because blocking secret findings were detected."
}

if (Test-Path -LiteralPath $ZipPath) {
    Remove-Item -LiteralPath $ZipPath -Force
}

Compress-Archive -Path (Join-Path $WorkingCopy "*") -DestinationPath $ZipPath -Force

Write-Host ""
Write-Host "Sanitized HomeVault ZIP created successfully." -ForegroundColor Green
Write-Host "Source   : $Source"
Write-Host "ZIP      : $ZipPath"
Write-Host "Copied   : $Copied files"
Write-Host "Excluded : $Excluded files"
Write-Host "Blocking secret scan: clear" -ForegroundColor Green

if ($Warnings.Count -gt 0) {
    Write-Host "Review-only test fixture warnings: $($Warnings.Count)" -ForegroundColor Yellow
}
else {
    Write-Host "Review-only warnings: none" -ForegroundColor Green
}

Write-Host ""
Write-Host "Upload this ZIP to ChatGPT as the baseline for the next development batch." -ForegroundColor Cyan

Remove-Item -LiteralPath $WorkingRoot -Recurse -Force -ErrorAction SilentlyContinue
