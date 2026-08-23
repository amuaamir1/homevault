param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)

if (-not (Test-Path (Join-Path $ProjectRoot 'pubspec.yaml'))) {
    throw "HomeVault project was not found at '$ProjectRoot'."
}

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$Message) {
    $script:failures.Add($Message)
    Write-Host "FAIL  $Message"
}

function Add-Pass([string]$Message) {
    Write-Host "PASS  $Message"
}

$git = Get-Command git -ErrorAction SilentlyContinue
if ($git -and (Test-Path (Join-Path $ProjectRoot '.git'))) {
    Push-Location $ProjectRoot
    try {
        $tracked = @(& git ls-files)
        $sensitiveFilePattern = '(?i)(^|/)(\.env($|\.)|key\.properties$|[^/]+\.(jks|keystore|p12|pfx|pem|key)$|[^/]*(service[-_]?account|adminsdk)[^/]*\.json$)'
        $badTracked = @($tracked | Where-Object { $_ -match $sensitiveFilePattern })
        if ($badTracked.Count -gt 0) {
            Add-Failure "Sensitive credential file(s) are tracked by Git: $($badTracked -join ', ')"
        } else {
            Add-Pass 'No sensitive credential filenames are tracked by Git'
        }

        $patterns = @(
            '-----BEGIN PRIVATE KEY-----',
            '-----BEGIN RSA PRIVATE KEY-----',
            'aws_secret_access_key',
            '"private_key"[[:space:]]*:',
            'client_secret[[:space:]]*[:=]'
        )
        $scanPaths = @(
            'lib',
            'android',
            'ios',
            'macos',
            'windows',
            'linux',
            'web',
            '.github',
            'pubspec.yaml',
            'firebase.json'
        )
        foreach ($pattern in $patterns) {
            $matches = @(
                & git grep -n -I -E -i -e $pattern -- @scanPaths 2>$null
            )
            if ($matches.Count -gt 0) {
                Add-Failure "Tracked source contains a high-risk secret pattern: $pattern"
            }
        }
        if ($failures.Count -eq 0) {
            Add-Pass 'Tracked source secret-pattern scan'
        }
    } finally {
        Pop-Location
    }
} else {
    Add-Pass 'Git tracking scan skipped because no .git worktree is available'
}

$gitignore = [System.IO.File]::ReadAllText((Join-Path $ProjectRoot '.gitignore'))
$requiredIgnorePatterns = @(
    'android/key.properties',
    '*.jks',
    '*.keystore',
    '*.p12',
    '*.pfx',
    '*.pem',
    '*.key',
    '.env',
    '**/*service-account*.json',
    '**/*adminsdk*.json'
)
foreach ($pattern in $requiredIgnorePatterns) {
    if (-not $gitignore.Contains($pattern)) {
        Add-Failure ".gitignore is missing: $pattern"
    }
}
if ($failures.Count -eq 0) {
    Add-Pass 'Credential and private-key ignore patterns'
}

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host "OVERALL: FAIL ($($failures.Count) security scan issue(s))"
    exit 1
}

Write-Host ''
Write-Host 'OVERALL: PASS'
exit 0
