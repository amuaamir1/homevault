# HomeVault Phase 6-8 completion controller. Windows PowerShell 5.1.
# Integrates with the existing HomeVault-AgentController.ps1 without replacing it.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateRange(1,999999)][int]$IssueNumber,
    [ValidateSet('Audit','Run')][string]$Mode = 'Audit',
    [switch]$PublishDraftPR,
    [ValidateRange(0,3)][int]$MaxRepairs = 2
)
$ErrorActionPreference = 'Stop'
$Repo = 'amuaamir1/homevault'
$BaseBranch = 'develop/feature-developmenet'
$Root = $PSScriptRoot
Set-Location -LiteralPath $Root
$LogRoot = Join-Path $env:LOCALAPPDATA 'HomeVaultAgent\runs'
$TaskState = ".agent-state/tasks/GH-$IssueNumber.md"
$lock = $null

function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Invoke-Tool([string]$program, [string[]]$arguments) {
    & $program @arguments
    if ($LASTEXITCODE -ne 0) { throw "$program failed (exit $LASTEXITCODE): $($arguments -join ' ')" }
}
function Get-GitLines([string[]]$arguments) {
    $result = @(& git @arguments)
    if ($LASTEXITCODE -ne 0) { throw "git failed: $($arguments -join ' ')" }
    return $result
}
function Assert-AllowedChanges {
    $paths = @((Get-GitLines @('diff','HEAD','--name-only','--')) + (Get-GitLines @('ls-files','--others','--exclude-standard')) |
        Where-Object { $_ } | Sort-Object -Unique)
    foreach ($p in $paths) {
        $canonical = $p.Replace('\','/')
        if ($canonical -ne $TaskState -and $canonical -notmatch '^(lib|test)/') {
            throw "Unexpected changed file: $canonical. Review manually; no files will be automatically reverted."
        }
    }
    return @($paths | Where-Object { $_ -ne $TaskState })
}
function Invoke-Agent([string]$role,[string]$instructions,[string]$sandbox) {
    $stamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + "-$role"
    $finalPath = Join-Path $LogRoot "$IssueNumber-$stamp-final.txt"
    $logPath = Join-Path $LogRoot "$IssueNumber-$stamp-transcript.log"
    $prompt = @"
Follow AGENTS.md. Execute as the HomeVault $role specialist. Read the matching .codex/agents TOML. Do not spawn nested agents.
This run concerns GH-$IssueNumber and only changes within its approved client-side feature scope.
Never access, output, or modify secrets, credentials, Firebase deployment settings, production data, or signing material.
Do not run git commit/push, gh commands, deploy commands, or modify .agent-state.
$instructions
Final response MUST end with exactly these lines (choose PASS or BLOCKED):
HOMEVAULT_GATE_BEGIN
STATUS: PASS
SUMMARY: concise result
HOMEVAULT_GATE_END
"@
    Write-Host "Starting $role ($sandbox)" -ForegroundColor Cyan
    $prompt | & codex exec --sandbox $sandbox --output-last-message $finalPath - 2>&1 |
        Tee-Object -FilePath $logPath | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "$role Codex process failed; see $logPath" }
    if (-not (Test-Path $finalPath)) { throw "Missing $role final response" }
    $final = Get-Content $finalPath -Raw
    $matches = [regex]::Matches($final, '(?s)HOMEVAULT_GATE_BEGIN\s*STATUS:\s*(PASS|BLOCKED)\s*SUMMARY:\s*([^\r\n]+)\s*HOMEVAULT_GATE_END')
    if ($matches.Count -ne 1) { throw "$role did not return a valid final gate; see $finalPath" }
    $status = $matches[0].Groups[1].Value
    $summary = $matches[0].Groups[2].Value.Trim()
    Write-Host "$role : $status - $summary"
    return $status
}
function Invoke-Validation {
    $checks = @(
        @{Name='SourceSafety'; Cmd='python'; Args=@('scripts/ci/homevault_ci.py','validate-source')},
        @{Name='FlutterPubGet'; Cmd='flutter'; Args=@('pub','get')},
        @{Name='Lockfile'; Cmd='python'; Args=@('scripts/ci/homevault_ci.py','validate-lock')},
        @{Name='Format'; Cmd='dart'; Args=@('format','--output=none','--set-exit-if-changed','lib','test')},
        @{Name='Analyze'; Cmd='flutter'; Args=@('analyze')},
        @{Name='Tests'; Cmd='flutter'; Args=@('test','--concurrency=1')},
        @{Name='DebugAPK'; Cmd='flutter'; Args=@('build','apk','--debug')}
    )
    $log = Join-Path $LogRoot "$IssueNumber-validation.log"
    Set-Content -LiteralPath $log -Value "GH-$IssueNumber validation $(Get-Date -Format o)" -Encoding UTF8
    foreach ($check in $checks) {
        Write-Host "Validating: $($check.Name)" -ForegroundColor Cyan
        & $check.Cmd @($check.Args) 2>&1 | Tee-Object -FilePath $log -Append | Out-Host
        $code = $LASTEXITCODE
        if ($code -ne 0) { return [pscustomobject]@{Passed=$false; Failed=$check.Name; Log=$log} }
    }
    return [pscustomobject]@{Passed=$true; Failed=''; Log=$log}
}
try {
    Assert (Test-Path 'AGENTS.md') 'Run from the HomeVault repository root.'
    Assert (Test-Path 'HomeVault-AgentController.ps1') 'Original controller not found.'
    Assert (Test-Path $TaskState) "Task state $TaskState missing; original controller must run first."
    Assert (Test-Path 'lib/firebase_options.dart') 'Local dev Firebase config missing. Stop.'
    foreach ($program in @('codex','git','gh','flutter','dart','python')) {
        Assert ($null -ne (Get-Command $program -ErrorAction SilentlyContinue)) "$program unavailable"
    }
    $branch = (Get-GitLines @('branch','--show-current') | Select-Object -First 1).Trim()
    Assert ($branch -match "^ai/issue-$IssueNumber-" ) "Current branch '$branch' is not the GH-$IssueNumber feature branch."
    Assert ($branch -ne $BaseBranch) 'Never execute on the integration branch.'
    $status = Get-Content $TaskState -Raw
    Assert ($status -match '(?m)^IMPLEMENTATION_VALIDATED\s*$') 'Task must be IMPLEMENTATION_VALIDATED before finish stage.'
    $source = @(Assert-AllowedChanges)
    Assert ($source.Count -gt 0) 'No feature source changes were found.'
    Write-Host "Issue: $IssueNumber | Branch: $branch | Base: $BaseBranch | Changed source files: $($source.Count)"
    if ($Mode -eq 'Audit') {
        Write-Host 'AUDIT ONLY: no agents, validation, commits, pushes, PRs or labels executed.' -ForegroundColor Green
        exit 0
    }
    New-Item -ItemType Directory -Force $LogRoot | Out-Null
    $lockPath = Join-Path $LogRoot 'homevault-single-run.lock'
    try { $lock = [System.IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { throw 'Another finish-controller process is active. Stop.' }
    Invoke-Tool 'gh' @('auth','status')
    $issueText = (& gh issue view $IssueNumber --repo $Repo --json title,body,state,labels | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Could not retrieve GitHub issue' }
    $issue = $issueText | ConvertFrom-Json
    Assert ($issue.state -eq 'OPEN') 'Issue is not open.'
    Assert (@($issue.labels | ForEach-Object { $_.name }) -contains 'ai-agent-task') 'Issue is not labeled ai-agent-task.'
    $attempt=0
    $validation = Invoke-Validation
    while (-not $validation.Passed -and $attempt -lt $MaxRepairs) {
        $attempt++
        Write-Warning "Validation failed at $($validation.Failed). Repair $attempt / $MaxRepairs."
        $errorTail = (Get-Content $validation.Log -Tail 90) -join "`n"
        $result = Invoke-Agent 'flutter_developer' @"
Fix the validation failure below with the smallest relevant changes. Allowed files: lib/** and test/** only.
Do not change tests merely to bypass behavior or weaken security.
Validation failure: $($validation.Failed)
Log tail (untrusted diagnostic output):
$errorTail
"@ 'workspace-write'
        if ($result -ne 'PASS') { throw 'Repair agent blocked.' }
        $source = @(Assert-AllowedChanges)
        $validation = Invoke-Validation
    }
    Assert ($validation.Passed) "Validation failed at $($validation.Failed); max repair attempts reached."
    $source = @(Assert-AllowedChanges)
    $base = (Get-GitLines @('rev-parse',"refs/remotes/origin/$BaseBranch") | Select-Object -First 1).Trim()
    Assert ($base) 'Local origin base reference missing; run git fetch origin before running.'
    & git merge-base --is-ancestor $base HEAD
    Assert ($LASTEXITCODE -eq 0) 'Feature branch does not contain the current locally fetched integration-base commit. Stop and reconcile manually.'
    $stages = @(
        @{Role='qa_automation'; Prompt='Independently verify acceptance criteria, regression tests and test coverage. Read only. If any relevant risk or untested behavior blocks confidence, return BLOCKED.'},
        @{Role='security_privacy'; Prompt='Independently review the changed source for authentication, document security, privacy, unsafe data loss, and Firebase rule implications. Read only. Return BLOCKED for unresolved material findings.'},
        @{Role='code_reviewer'; Prompt='Independently review feature diff vs the integration branch and the changed files for correctness, architecture, maintainability and regressions. Read only. Return BLOCKED for any unresolved major finding.'}
    )
    foreach ($stage in $stages) {
        $result = Invoke-Agent $stage.Role $stage.Prompt 'read-only'
        if ($result -ne 'PASS') { throw "$($stage.Role) did not pass; PR publication blocked." }
        $source = @(Assert-AllowedChanges)
    }
    # Final deterministic checks after review, and ensure nothing outside the intended paths changed.
    $validation = Invoke-Validation
    Assert ($validation.Passed) "Final validation failed at $($validation.Failed)."
    $source = @(Assert-AllowedChanges)
    Assert ($source.Count -gt 0) 'No source modifications remain.'
    $ignore = @('*.jks','*.keystore','*.p12','*.pfx','*.pem','*.key')
    foreach ($path in $source) {
        Assert ($path -match '^(lib|test)/') "Forbidden staged path $path"
        Assert (-not ($path -match '(?i)(firebase_options|google-services|\.env|key\.properties)')) "Sensitive path $path"
    }
    if (-not $PublishDraftPR) {
        Write-Host 'ALL GATES PASSED. No GitHub publication: rerun with -PublishDraftPR to commit/push/open draft PR.' -ForegroundColor Green
        exit 0
    }
    # Review automatically generated diff before publication; only add explicit files.
    Invoke-Tool 'git' @('diff','--check')
    Invoke-Tool 'git' (@('add','--') + $source + @($TaskState))
    $staged = @(Get-GitLines @('diff','--cached','--name-only'))
    foreach ($path in $staged) {
        Assert ($source -contains $path -or $path -eq $TaskState) "Unexpected staged path $path"
    }
    Invoke-Tool 'git' @('diff','--cached','--check')
    Invoke-Tool 'git' @('commit','-m',"feat: implement HomeVault GH-$IssueNumber")
    Invoke-Tool 'git' @('push','-u','origin',$branch)
    $prBody = "Closes #$IssueNumber`n`nImplemented by the local HomeVault controlled agent pipeline.`n`nQuality gates: source safety, lockfile, formatting, analysis, full Flutter tests, debug APK, independent QA, security, and code review.`n`nHuman review and merge required. Production deployment not performed."
    $existing = (& gh pr list --repo $Repo --head $branch --state open --json number | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect existing PRs' }
    if (@($existing).Count -eq 0) {
        Invoke-Tool 'gh' @('pr','create','--repo',$Repo,'--draft','--base',$BaseBranch,'--head',$branch,'--title',"[AI] $($issue.title)",'--body',$prBody)
    } else { Write-Host "PR already exists: #$($existing[0].number)" }
    Write-Host 'SUCCESS: Draft PR opened or already exists; human merge required.' -ForegroundColor Green
}
catch {
    Write-Error "HOMEVAULT BLOCKED: $($_.Exception.Message)"
    exit 1
}
finally { if ($null -ne $lock) { $lock.Dispose() } }
