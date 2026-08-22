param(
    [ValidateSet("Quick", "Full")]
    [string]$Mode = "Quick",

    # Semicolon-separated targeted tests, for example:
    # test\homevault_error_telemetry_test.dart;test\technical_error_leakage_test.dart
    [string]$Tests = "",

    [switch]$BuildDebug,
    [switch]$SkipPubGet,
    [switch]$SkipFormatCheck,

    [string]$ProjectPath = "",
    [string]$ReportRoot = "C:\Projects\HomeVault-Test-Reports"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath "pubspec.yaml") -PathType Leaf)) {
    throw "HomeVault pubspec.yaml was not found under: $ProjectPath"
}

New-Item -ItemType Directory -Force -Path $ReportRoot | Out-Null

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = Join-Path $ReportRoot "homevault-validation-$Timestamp.log"

$Results = New-Object System.Collections.Generic.List[object]

function Write-LogLine {
    param([string]$Text = "")
    $Text | Tee-Object -FilePath $LogFile -Append
}

function Invoke-ValidationStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @()
    )

    Write-LogLine ""
    Write-LogLine ("=" * 78)
    Write-LogLine "STEP: $Name"
    Write-LogLine "COMMAND: $Command $($Arguments -join ' ')"
    Write-LogLine ("=" * 78)

    $Started = Get-Date
    $ExitCode = 0

    Push-Location $ProjectPath
    try {
        & $Command @Arguments 2>&1 |
            ForEach-Object {
                $line = $_.ToString()
                Write-Host $line
                Add-Content -LiteralPath $LogFile -Value $line
            }
        $ExitCode = $LASTEXITCODE
        if ($null -eq $ExitCode) { $ExitCode = 0 }
    }
    catch {
        $ExitCode = 1
        $line = $_.Exception.Message
        Write-Host $line -ForegroundColor Red
        Add-Content -LiteralPath $LogFile -Value $line
    }
    finally {
        Pop-Location
    }

    $Duration = [math]::Round(((Get-Date) - $Started).TotalSeconds, 1)
    $Status = if ($ExitCode -eq 0) { "PASS" } else { "FAIL" }

    $Results.Add([pscustomobject]@{
        Step = $Name
        Status = $Status
        ExitCode = $ExitCode
        Seconds = $Duration
    })

    Write-LogLine "RESULT: $Status (exit=$ExitCode, ${Duration}s)"
}

Write-LogLine "HomeVault validation"
Write-LogLine "Started    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
Write-LogLine "Project    : $ProjectPath"
Write-LogLine "Mode       : $Mode"
Write-LogLine "BuildDebug : $BuildDebug"
Write-LogLine "Report     : $LogFile"

Invoke-ValidationStep -Name "Flutter environment" -Command "flutter" -Arguments @("--version")

if (-not $SkipPubGet) {
    Invoke-ValidationStep -Name "Resolve packages" -Command "flutter" -Arguments @("pub", "get")
}

if (-not $SkipFormatCheck) {
    Invoke-ValidationStep `
        -Name "Dart format check" `
        -Command "dart" `
        -Arguments @("format", "--output=none", "--set-exit-if-changed", "lib", "test")
}

Invoke-ValidationStep -Name "Flutter analyze" -Command "flutter" -Arguments @("analyze")

$TargetTests = @()
if (-not [string]::IsNullOrWhiteSpace($Tests)) {
    $TargetTests = $Tests.Split(";") |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

foreach ($TestPath in $TargetTests) {
    $FullTestPath = Join-Path $ProjectPath $TestPath
    if (-not (Test-Path -LiteralPath $FullTestPath -PathType Leaf)) {
        Write-LogLine ""
        Write-LogLine "Target test not found: $TestPath"
        $Results.Add([pscustomobject]@{
            Step = "Target test: $TestPath"
            Status = "FAIL"
            ExitCode = 2
            Seconds = 0
        })
        continue
    }

    Invoke-ValidationStep `
        -Name "Target test: $TestPath" `
        -Command "flutter" `
        -Arguments @("test", $TestPath)
}

if ($Mode -eq "Full") {
    Invoke-ValidationStep `
        -Name "Full Flutter test suite" `
        -Command "flutter" `
        -Arguments @("test")
}

if ($BuildDebug) {
    Invoke-ValidationStep `
        -Name "Debug APK build" `
        -Command "flutter" `
        -Arguments @("build", "apk", "--debug")
}

Write-LogLine ""
Write-LogLine ("=" * 78)
Write-LogLine "VALIDATION SUMMARY"
Write-LogLine ("=" * 78)

foreach ($Result in $Results) {
    $Summary = "{0,-46} {1,-5} exit={2,-3} {3,7}s" -f `
        $Result.Step, $Result.Status, $Result.ExitCode, $Result.Seconds
    Write-LogLine $Summary
}

$Failed = @($Results | Where-Object { $_.Status -eq "FAIL" })

Write-LogLine ""
if ($Failed.Count -eq 0) {
    Write-LogLine "OVERALL: PASS"
    Write-Host ""
    Write-Host "HomeVault validation PASSED." -ForegroundColor Green
    Write-Host "Report: $LogFile"
    exit 0
}

Write-LogLine "OVERALL: FAIL ($($Failed.Count) failed step(s))"
Write-Host ""
Write-Host "HomeVault validation FAILED." -ForegroundColor Red
Write-Host "Failed steps: $($Failed.Count)"
Write-Host "Report: $LogFile"
Write-Host ""
Write-Host "Upload this single log file to ChatGPT for one consolidated fix." -ForegroundColor Yellow
exit 1
