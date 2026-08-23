param(
    [string]$ReportRoot = "C:\Projects\HomeVault-Test-Reports",
    [ValidateSet('PASS','FAIL','NOT_RUN')][string]$EmailPasswordPinFlow = 'NOT_RUN',
    [ValidateSet('PASS','FAIL','NOT_RUN')][string]$GoogleSignIn = 'NOT_RUN',
    [ValidateSet('PASS','FAIL','NOT_RUN')][string]$DocumentVault = 'NOT_RUN',
    [ValidateSet('PASS','FAIL','NOT_RUN')][string]$CloudBackup = 'NOT_RUN',
    [ValidateSet('PASS','FAIL','NOT_RUN')][string]$BetaFeedback = 'NOT_RUN',
    [ValidateSet('PASS','FAIL','NOT_RUN')][string]$Persistence = 'NOT_RUN',
    [ValidateSet('PASS','FAIL','NOT_RUN')][string]$ProductionIsolation = 'NOT_RUN',
    [string]$Notes = ''
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $ReportRoot | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$jsonPath = Join-Path $ReportRoot "p16-phase3-device-smoke-$stamp.json"
$txtPath = Join-Path $ReportRoot "p16-phase3-device-smoke-$stamp.log"

$checks = [ordered]@{
    EmailPasswordPinFlow = $EmailPasswordPinFlow
    GoogleSignIn          = $GoogleSignIn
    DocumentVault         = $DocumentVault
    CloudBackup           = $CloudBackup
    BetaFeedback          = $BetaFeedback
    Persistence           = $Persistence
    ProductionIsolation   = $ProductionIsolation
}

$values = @($checks.Values)
$overall = if ($values -contains 'FAIL') {
    'FAIL'
} elseif ($values -contains 'NOT_RUN') {
    'INCOMPLETE'
} else {
    'PASS'
}

$result = [ordered]@{
    phase = 'P16 Phase 3'
    createdAt = (Get-Date).ToString('o')
    checks = $checks
    overall = $overall
    notes = $Notes
}

$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('HomeVault P16 Phase 3 - Production Device Smoke')
$lines.Add("Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
$lines.Add('')
foreach ($entry in $checks.GetEnumerator()) {
    $lines.Add(('{0,-28} {1}' -f $entry.Key, $entry.Value))
}
$lines.Add('')
$lines.Add("OVERALL: $overall")
if ($Notes) {
    $lines.Add('')
    $lines.Add('Notes:')
    $lines.Add($Notes)
}
$lines | Set-Content -LiteralPath $txtPath -Encoding UTF8

Write-Host "Device smoke report: $txtPath"
Write-Host "Structured result : $jsonPath"
if ($overall -eq 'PASS') {
    Write-Host 'OVERALL: PASS' -ForegroundColor Green
    exit 0
}
if ($overall -eq 'FAIL') {
    Write-Host 'OVERALL: FAIL' -ForegroundColor Red
    exit 1
}
Write-Host 'OVERALL: INCOMPLETE' -ForegroundColor Yellow
exit 2
