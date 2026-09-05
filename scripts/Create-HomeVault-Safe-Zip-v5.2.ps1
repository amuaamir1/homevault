param(
    [string]$Source = "C:\Projects\homeVaultApp",
    [string]$OutputRoot = "C:\Projects\HomeVault-Safe-Zips"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# HomeVault Safe ZIP v5.2
#
# Purpose:
#   Create a sanitized SOURCE snapshot that is safer to upload/share for
#   development assistance. This is NOT a disaster-recovery backup because
#   credentials, Firebase configuration, databases, build artifacts, archives,
#   logs, and other potentially sensitive/generated files are deliberately
#   omitted.
#
# Safety model:
#   1. Work only on a temporary copy (never modify the original project).
#   2. Exclude known secret/generated/user-data files and directories.
#   3. Scan copied text files for high-confidence credential patterns.
#   4. Abort if a text file cannot be inspected.
#   5. Add a manifest to the sanitized copy.
#   6. Create ZIP using .NET so legitimate dot/hidden files are preserved.
#   7. Re-open the finished ZIP and verify forbidden content is absent.
#   8. Produce a SHA-256 sidecar checksum.
# -----------------------------------------------------------------------------

function Normalize-RelativePath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    return $RelativePath.Replace("\", "/").TrimStart("/")
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "HomeVault source folder not found: $Source"
}

$SourceRoot = (Resolve-Path -LiteralPath $Source).Path.TrimEnd("\", "/")
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$WorkingRoot = Join-Path $env:TEMP "homevault-safe-$Timestamp-$PID"
$WorkingCopy = Join-Path $WorkingRoot "homeVaultApp"
$ZipPath = Join-Path $OutputRoot "homeVaultApp-safe-$Timestamp.zip"
$HashPath = "$ZipPath.sha256"
$ManifestPath = Join-Path $WorkingCopy "SAFE_ZIP_MANIFEST.txt"

# Directory names omitted anywhere in the source tree.
$ExcludedDirectoryNames = @(
    ".git",
    ".dart_tool",
    ".idea",
    ".vscode",
    "build",
    ".gradle",
    "Pods",
    "DerivedData",
    "node_modules",
    "coverage"
)

# Exact filenames that should never be included in a shared source snapshot.
$ExcludedFileNames = @(
    "local.properties",
    "key.properties",
    "google-services.json",
    "GoogleService-Info.plist",
    "firebase_options.dart",
    ".env",
    ".env.local",
    ".env.development",
    ".env.production",
    ".env.test"
)

# Extensions omitted because they are commonly credentials, local user data,
# generated packages, logs, or opaque archives whose contents are not scanned.
$ExcludedExtensions = @(
    # Keys / certificates
    ".jks", ".keystore", ".p12", ".pfx", ".pem", ".key",
    ".cer", ".crt", ".der",

    # Local/user databases and backups
    ".db", ".sqlite", ".sqlite3", ".realm", ".bak", ".backup",

    # Generated Android packages
    ".apk", ".aab",

    # Logs
    ".log",

    # Nested archives / opaque bundles
    ".zip", ".7z", ".rar", ".tar", ".gz", ".tgz"
)

# Credential-like filenames that are not expected in a source-sharing ZIP.
$SecretLikeNamePatterns = @(
    "*service-account*.json",
    "*service_account*.json",
    "*firebase-admin*.json",
    "*firebase_admin*.json",
    "*adminsdk*.json",
    "*credentials*.json",
    "*secrets*.json"
)

# Source filenames that merely contain security words are not auto-blocked
# because legitimate code can be named token_service.dart, password_field.dart,
# etc. They are reported for review if they look like non-source credential
# payloads.
$ReviewNamePatterns = @(
    "*token*",
    "*apikey*",
    "*api-key*",
    "*private-key*",
    "*private_key*",
    "*password*"
)

# These internal security/production smoke scripts intentionally contain
# secret-shaped detector/fixture literals. They are not required in a sanitized
# development snapshot, so omit them rather than weakening the secret scanner.
$ExcludedRelativePaths = @(
    "scripts/firebase/Test-HomeVault-ProductionFirebase-Live.ps1",
    "scripts/Test-HomeVault-Release-Security.ps1"
)

# Text files that are safe to inspect as text.
$TextExtensions = @(
    ".dart", ".yaml", ".yml", ".json", ".xml", ".gradle", ".kts",
    ".properties", ".md", ".txt", ".ps1", ".sh", ".bat", ".cmd",
    ".html", ".htm", ".js", ".ts", ".java", ".kt", ".swift",
    ".plist", ".toml", ".ini", ".cfg", ".conf", ".csv"
)

# The sanitizer script intentionally contains credential-shaped examples and
# regex detector literals. It is safe to INCLUDE in the ZIP, but scanning it
# against its own rules would create false positives.
$SelfScannerFilePatterns = @(
    "Create-HomeVault-Safe-Zip*.ps1"
)

# High-confidence patterns. Any match blocks ZIP creation.
$BlockingPatterns = @(
    @{ Name = "private key"; Pattern = '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' },
    @{ Name = "Google API key"; Pattern = '\bAIza[0-9A-Za-z\-_]{30,}\b' },
    @{ Name = "GitHub token"; Pattern = '\bgh[pousr]_[0-9A-Za-z]{30,}\b' },
    @{ Name = "GitHub fine-grained token"; Pattern = '\bgithub_pat_[0-9A-Za-z_]{40,}\b' },
    @{ Name = "AWS access key"; Pattern = '\bAKIA[0-9A-Z]{16}\b' },
    @{ Name = "AWS temporary access key"; Pattern = '\bASIA[0-9A-Z]{16}\b' },
    @{ Name = "Slack token"; Pattern = '\bxox[baprs]-[0-9A-Za-z-]{10,}\b' },
    @{ Name = "Bearer token"; Pattern = '(?i)\bAuthorization\s*[:=]\s*["'']?Bearer\s+[A-Za-z0-9\-._~+/]+=*' },
    @{ Name = "JWT"; Pattern = '\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{8,}\b' },

    # Quoted or unquoted secret assignments with a non-trivial literal value.
    # Placeholder-like values are filtered separately below.
    @{ Name = "client/private/API secret or token"; Pattern = '(?im)\b(client_secret|api_secret|access_token|refresh_token)\b\s*[:=]\s*["'']?([A-Za-z0-9+/_\-.=]{12,})["'']?' }
)

# Password detection is intentionally format-aware:
# - In source code, only QUOTED literals are blocking. This avoids false positives
#   from normal Dart named arguments such as `password: password`.
# - In configuration-oriented text files, unquoted values may also be real
#   credentials, so they receive an additional conservative check.
$QuotedPasswordPattern = '(?im)\b(password|passwd)\b\s*[:=]\s*(?:"([^"]{6,})"|''([^'']{6,})'')'
$UnquotedConfigPasswordPattern = '(?im)^\s*(password|passwd)\s*[:=]\s*([^\s#;,]{8,})\s*(?:#.*)?$'

$ConfigLikeExtensions = @(
    ".yaml", ".yml", ".properties", ".ini", ".cfg", ".conf", ".toml", ".json", ".xml"
)

# Values commonly used intentionally in examples/config contracts.
$PlaceholderValues = @(
    "changeme",
    "change-me",
    "example",
    "example123",
    "placeholder",
    "your-password",
    "your_password",
    "your-secret",
    "your_secret",
    "dummy",
    "dummyvalue",
    "testpassword",
    "password123",
    "<password>",
    "<secret>",
    "REDACTED"
)

function Is-TestLikePath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $normalized = (Normalize-RelativePath -RelativePath $RelativePath).ToLowerInvariant()

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

function Is-PlaceholderValue {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $true
    }

    $normalized = $Value.Trim().Trim('"', "'")
    foreach ($placeholder in $PlaceholderValues) {
        if ($normalized.Equals($placeholder, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    if ($normalized -match '^\$\{?[A-Z0-9_]+\}?$') { return $true }
    if ($normalized -match '^%[A-Z0-9_]+%$') { return $true }

    return $false
}

function Should-ExcludeFile {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$File,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $normalized = Normalize-RelativePath -RelativePath $RelativePath
    $segments = $normalized -split '/'

    foreach ($segment in $segments) {
        if ($ExcludedDirectoryNames -contains $segment) {
            return $true
        }
    }

    if ($ExcludedFileNames -contains $File.Name) { return $true }
    if ($File.Name -like ".env.*") { return $true }

    $extension = $File.Extension.ToLowerInvariant()
    if ($ExcludedExtensions -contains $extension) { return $true }

    foreach ($pattern in $SecretLikeNamePatterns) {
        if ($File.Name -like $pattern) { return $true }
    }

    foreach ($blockedPath in $ExcludedRelativePaths) {
        if ($normalized.Equals($blockedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    if ($normalized.Equals("lib/firebase_options.dart", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    return $false
}

# ZIP-level forbidden checks are intentionally redundant with the source-copy
# exclusions. This is a second line of defense.
function Is-ForbiddenZipEntry {
    param([Parameter(Mandatory = $true)][string]$EntryPath)

    $normalized = Normalize-RelativePath -RelativePath $EntryPath
    $segments = $normalized -split '/'

    foreach ($segment in $segments) {
        if ($ExcludedDirectoryNames -contains $segment) { return $true }
    }

    $name = [System.IO.Path]::GetFileName($normalized)
    $ext = [System.IO.Path]::GetExtension($name).ToLowerInvariant()

    if ($ExcludedFileNames -contains $name) { return $true }
    if ($name -like ".env.*") { return $true }
    if ($ExcludedExtensions -contains $ext) { return $true }

    foreach ($pattern in $SecretLikeNamePatterns) {
        if ($name -like $pattern) { return $true }
    }

    foreach ($blockedPath in $ExcludedRelativePaths) {
        if ($normalized.Equals($blockedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    if ($normalized.Equals("lib/firebase_options.dart", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    return $false
}


function Is-SelfScannerFile {
    param([Parameter(Mandatory = $true)][string]$FileName)

    foreach ($pattern in $SelfScannerFilePatterns) {
        if ($FileName -like $pattern) {
            return $true
        }
    }

    return $false
}

function Get-LineNumberForIndex {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][int]$Index
    )

    if ($Index -le 0) { return 1 }

    $prefix = $Content.Substring(0, [Math]::Min($Index, $Content.Length))
    return ([regex]::Matches($prefix, "`n").Count + 1)
}

function Looks-Like-Identifier {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }

    # Normal programming-language identifiers such as:
    # password, newPassword, currentPassword, user_password
    return ($Value -match '^[A-Za-z_][A-Za-z0-9_]*$')
}

$Copied = 0
$Excluded = 0
$BlockingFindings = New-Object System.Collections.Generic.List[string]
$Warnings = New-Object System.Collections.Generic.List[string]
$UnreadableTextFiles = New-Object System.Collections.Generic.List[string]

try {
    New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

    Remove-Item -LiteralPath $WorkingRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $WorkingCopy | Out-Null

    Write-Host ""
    Write-Host "HomeVault Safe ZIP v5.2" -ForegroundColor Cyan
    Write-Host "Source sanitization started..." -ForegroundColor Cyan
    Write-Host "Source : $SourceRoot"

    # Enumerate source files once, before any output artifacts are created.
    $Files = Get-ChildItem -LiteralPath $SourceRoot -Recurse -File -Force

    foreach ($File in $Files) {
        $RelativePath = $File.FullName.Substring($SourceRoot.Length).TrimStart("\", "/")

        if (Should-ExcludeFile -File $File -RelativePath $RelativePath) {
            $Excluded++
            continue
        }

        $Destination = Join-Path $WorkingCopy $RelativePath
        $DestinationParent = Split-Path -Parent $Destination
        if (-not (Test-Path -LiteralPath $DestinationParent -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $DestinationParent | Out-Null
        }

        Copy-Item -LiteralPath $File.FullName -Destination $Destination -Force
        $Copied++

        foreach ($pattern in $ReviewNamePatterns) {
            if ($File.Name -like $pattern) {
                # Only warn for credential-looking non-source payload names.
                if ($TextExtensions -notcontains $File.Extension.ToLowerInvariant()) {
                    $Warnings.Add("$RelativePath  -> credential-like filename; review recommended")
                }
                break
            }
        }
    }

    Write-Host "Copied sanitized source files: $Copied"
    Write-Host "Excluded files             : $Excluded"

    # -------------------------------------------------------------------------
    # Secret scan
    # -------------------------------------------------------------------------
    Write-Host ""
    Write-Host "Scanning copied text files for secrets..." -ForegroundColor Cyan
    Write-Host "Scanner self-files are excluded from content scan to avoid detector self-matches." -ForegroundColor DarkGray

    $SafeTextFiles = Get-ChildItem -LiteralPath $WorkingCopy -Recurse -File -Force |
        Where-Object {
            ($TextExtensions -contains $_.Extension.ToLowerInvariant()) -and
            (-not (Is-SelfScannerFile -FileName $_.Name))
        }

    foreach ($File in $SafeTextFiles) {
        $RelativePath = $File.FullName.Substring($WorkingCopy.Length).TrimStart("\", "/")

        try {
            $Content = [System.IO.File]::ReadAllText($File.FullName)
        }
        catch {
            $UnreadableTextFiles.Add("$RelativePath  -> $($_.Exception.Message)")
            continue
        }

        foreach ($Rule in $BlockingPatterns) {
            $Matches = [regex]::Matches($Content, $Rule.Pattern)
            foreach ($Match in $Matches) {
                if ($Rule.Name -eq "client/private/API secret or token" -and $Match.Groups.Count -ge 3) {
                    $candidate = $Match.Groups[2].Value
                    if (Is-PlaceholderValue -Value $candidate) {
                        continue
                    }
                }

                $lineNumber = Get-LineNumberForIndex -Content $Content -Index $Match.Index
                $BlockingFindings.Add("$RelativePath`:$lineNumber  -> $($Rule.Name)")
                break
            }
        }

        # 1) Quoted password literals: blocking outside tests/examples.
        #    Example we DO want to catch:
        #      password: "ActualSecret123!"
        #
        #    Example that is NOT matched:
        #      password: password
        $QuotedPasswordMatches = [regex]::Matches($Content, $QuotedPasswordPattern)
        foreach ($Match in $QuotedPasswordMatches) {
            $candidate = ""
            if ($Match.Groups[2].Success) { $candidate = $Match.Groups[2].Value }
            elseif ($Match.Groups[3].Success) { $candidate = $Match.Groups[3].Value }

            if (Is-PlaceholderValue -Value $candidate) {
                continue
            }

            $lineNumber = Get-LineNumberForIndex -Content $Content -Index $Match.Index

            if (Is-TestLikePath -RelativePath $RelativePath) {
                $Warnings.Add("$RelativePath`:$lineNumber  -> quoted password-like test/example fixture")
            }
            else {
                $BlockingFindings.Add("$RelativePath`:$lineNumber  -> quoted password literal outside test/example fixtures")
            }
            break
        }

        # 2) Unquoted password assignments are checked only in configuration-like
        #    files. Source-code identifiers such as `password: password` and
        #    `password: newPassword` are intentionally not treated as secrets.
        $extension = $File.Extension.ToLowerInvariant()
        if ($ConfigLikeExtensions -contains $extension) {
            $UnquotedPasswordMatches = [regex]::Matches($Content, $UnquotedConfigPasswordPattern)

            foreach ($Match in $UnquotedPasswordMatches) {
                $candidate = $Match.Groups[2].Value

                if (Is-PlaceholderValue -Value $candidate) {
                    continue
                }

                # A bare identifier in JSON/YAML/etc. is more likely to be a
                # reference/placeholder than a literal credential. Only block
                # an unquoted value when it has some secret-like complexity.
                if (Looks-Like-Identifier -Value $candidate) {
                    $hasDigit = $candidate -match '\d'
                    $hasSymbol = $candidate -match '[^A-Za-z0-9_]'
                    if (-not ($hasDigit -or $hasSymbol)) {
                        continue
                    }
                }

                $lineNumber = Get-LineNumberForIndex -Content $Content -Index $Match.Index

                if (Is-TestLikePath -RelativePath $RelativePath) {
                    $Warnings.Add("$RelativePath`:$lineNumber  -> unquoted password-like test/example fixture")
                }
                else {
                    $BlockingFindings.Add("$RelativePath`:$lineNumber  -> unquoted password-like configuration value")
                }
                break
            }
        }
    }

    # Fail safe: if a file we intended to inspect cannot be read, do not package it.
    if ($UnreadableTextFiles.Count -gt 0) {
        Write-Host ""
        Write-Host "Text files could not be inspected. ZIP was NOT created." -ForegroundColor Red
        $UnreadableTextFiles | Sort-Object -Unique | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Red
        }
        throw "Sanitization stopped because one or more text files could not be inspected."
    }

    if ($Warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "Review-only warnings:" -ForegroundColor Yellow
        $Warnings | Sort-Object -Unique | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Yellow
        }
    }

    if ($BlockingFindings.Count -gt 0) {
        Write-Host ""
        Write-Host "Potential real secrets were detected. ZIP was NOT created." -ForegroundColor Red
        $BlockingFindings | Sort-Object -Unique | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Red
        }
        throw "Sanitization stopped because blocking secret findings were detected."
    }

    Write-Host "Blocking secret scan       : PASS" -ForegroundColor Green

    # -------------------------------------------------------------------------
    # Manifest added only to the sanitized copy.
    # -------------------------------------------------------------------------
    $ManifestLines = @(
        "HomeVault Safe ZIP Manifest",
        "===========================",
        "",
        "Generator          : Create-HomeVault-Safe-Zip-v5.2.ps1",
        "Generated          : $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))",
        "Source folder      : $SourceRoot",
        "Files copied       : $Copied",
        "Files excluded     : $Excluded",
        "Secret scan        : PASS (format-aware; scanner self-files excluded)",
        "Unreadable text    : 0",
        "Review warnings    : $($Warnings.Count)",
        "",
        "IMPORTANT:",
        "This archive is a sanitized source snapshot for sharing/development.",
        "It is NOT a complete disaster-recovery backup.",
        "Credentials, Firebase configuration, keys/certificates, local databases,",
        "logs, generated Android packages, and nested archives are intentionally omitted.",
        "",
        "The original HomeVault project was not modified."
    )

    Write-Utf8NoBom -Path $ManifestPath -Content ($ManifestLines -join [Environment]::NewLine)

    # -------------------------------------------------------------------------
    # Create ZIP using .NET ZipFile.
    # Unlike Compress-Archive with wildcard paths, this preserves legitimate
    # dot-prefixed/hidden project files such as .github and .gitignore.
    # -------------------------------------------------------------------------
    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }
    if (Test-Path -LiteralPath $HashPath) {
        Remove-Item -LiteralPath $HashPath -Force
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    Write-Host ""
    Write-Host "Creating ZIP..." -ForegroundColor Cyan

    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $WorkingCopy,
        $ZipPath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    # -------------------------------------------------------------------------
    # Final ZIP verification.
    # -------------------------------------------------------------------------
    Write-Host "Verifying final ZIP contents..." -ForegroundColor Cyan

    $ForbiddenEntries = New-Object System.Collections.Generic.List[string]
    $ZipEntryCount = 0

    $Archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        foreach ($Entry in $Archive.Entries) {
            if ([string]::IsNullOrWhiteSpace($Entry.Name)) {
                continue
            }

            $ZipEntryCount++
            if (Is-ForbiddenZipEntry -EntryPath $Entry.FullName) {
                $ForbiddenEntries.Add($Entry.FullName)
            }
        }
    }
    finally {
        $Archive.Dispose()
    }

    if ($ForbiddenEntries.Count -gt 0) {
        Remove-Item -LiteralPath $ZipPath -Force -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Host "Final ZIP verification FAILED. ZIP was removed." -ForegroundColor Red
        $ForbiddenEntries | Sort-Object -Unique | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Red
        }
        throw "A forbidden file was found inside the final ZIP."
    }

    if ($ZipEntryCount -lt 1) {
        Remove-Item -LiteralPath $ZipPath -Force -ErrorAction SilentlyContinue
        throw "Final ZIP verification failed because the archive is empty."
    }

    Write-Host "Final ZIP verification     : PASS ($ZipEntryCount files)" -ForegroundColor Green

    # -------------------------------------------------------------------------
    # Integrity checksum.
    # -------------------------------------------------------------------------
    $Hash = Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256
    $HashLine = "$($Hash.Hash.ToLowerInvariant())  $([System.IO.Path]::GetFileName($ZipPath))"
    Write-Utf8NoBom -Path $HashPath -Content ($HashLine + [Environment]::NewLine)

    $ZipItem = Get-Item -LiteralPath $ZipPath
    $ZipSizeMB = [Math]::Round($ZipItem.Length / 1MB, 2)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "SAFE HOMEVAULT ZIP CREATED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "Source       : $SourceRoot"
    Write-Host "ZIP          : $ZipPath"
    Write-Host "SHA-256 file : $HashPath"
    Write-Host "SHA-256      : $($Hash.Hash.ToLowerInvariant())"
    Write-Host "ZIP size     : $ZipSizeMB MB"
    Write-Host "Copied       : $Copied source files"
    Write-Host "Excluded     : $Excluded source files"
    Write-Host "ZIP entries  : $ZipEntryCount files"
    Write-Host "Secret scan  : PASS" -ForegroundColor Green
    Write-Host "ZIP verify   : PASS" -ForegroundColor Green

    if ($Warnings.Count -gt 0) {
        Write-Host "Warnings     : $($Warnings.Count) review-only warning(s)" -ForegroundColor Yellow
    }
    else {
        Write-Host "Warnings     : none" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "The original HomeVault project was NOT modified." -ForegroundColor Green
    Write-Host "This is a sanitized source snapshot, not a full recovery backup." -ForegroundColor Yellow
    Write-Host "You can upload the ZIP shown above for the next HomeVault development batch." -ForegroundColor Cyan
}
finally {
    # Always remove the temporary sanitized working copy, including on failure.
    Remove-Item -LiteralPath $WorkingRoot -Recurse -Force -ErrorAction SilentlyContinue
}
