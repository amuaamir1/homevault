# One-task-per-run HomeVault local launcher. Preview is the default; human merge remains mandatory.
[CmdletBinding()]
param(
    [ValidateRange(0,999999)][int]$IssueNumber = 0,
    [switch]$EnableLocalImplementation,
    [switch]$EnableGitHubPublication,
    [switch]$RecoverValidatedBranch,
    [switch]$EnableGitHubWrites,
    [ValidateRange(0,3)][int]$MaxRepairs = 2
)

$ErrorActionPreference = 'Stop'
$repo = 'amuaamir1/homevault'
$base = 'develop/feature-developmenet'
$root = $PSScriptRoot
$logRoot = Join-Path $env:LOCALAPPDATA 'HomeVaultAgent\runs'
$lock = $null
$lockOwnerPath = $null
$ownsLockMetadata = $false
$env:HOMEVAULT_AUTONOMOUS_LOCK_OWNER_PID = $null
$env:HOMEVAULT_AUTONOMOUS_LOCK_TOKEN = $null
$env:HOMEVAULT_AUTONOMOUS_LOCK_ROOT = $null
Set-Location -LiteralPath $root

function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Run([string]$tool, [string[]]$arguments) {
    & $tool @arguments
    if ($LASTEXITCODE -ne 0) { throw "$tool exited with $LASTEXITCODE" }
}
function Get-TextHash([string]$text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','') }
    finally { $sha.Dispose() }
}
function Run-Finish([string[]]$arguments) {
    $cleanOwner = $env:HOMEVAULT_AUTONOMOUS_LOCK_OWNER_PID
    $cleanToken = $env:HOMEVAULT_AUTONOMOUS_LOCK_TOKEN
    $cleanRoot = $env:HOMEVAULT_AUTONOMOUS_LOCK_ROOT
    try {
        $env:HOMEVAULT_AUTONOMOUS_LOCK_OWNER_PID = "$PID"
        $env:HOMEVAULT_AUTONOMOUS_LOCK_TOKEN = $runToken
        $env:HOMEVAULT_AUTONOMOUS_LOCK_ROOT = $canonicalRoot
        Run 'powershell.exe' $arguments
    }
    finally {
        $env:HOMEVAULT_AUTONOMOUS_LOCK_OWNER_PID = $cleanOwner
        $env:HOMEVAULT_AUTONOMOUS_LOCK_TOKEN = $cleanToken
        $env:HOMEVAULT_AUTONOMOUS_LOCK_ROOT = $cleanRoot
    }
}
function Get-GitBranch {
    $value = (& git branch --show-current | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Unable to determine the current Git branch.' }
    return $value
}
function Assert-CleanWorktree {
    $status = @(& git status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the Git worktree.' }
    Assert ($status.Count -eq 0) 'Working tree is not clean.'
}
function Assert-StrictGitState {
    & git diff --cached --quiet --
    Assert ($LASTEXITCODE -eq 0) 'The index contains staged changes. Refusing an ambiguous run state.'
    $unmerged = @(& git ls-files --unmerged --)
    Assert ($LASTEXITCODE -eq 0) 'Unable to inspect unmerged Git entries.'
    Assert ($unmerged.Count -eq 0) 'The worktree contains unmerged entries.'
    foreach ($name in @('MERGE_HEAD','CHERRY_PICK_HEAD','REVERT_HEAD','REBASE_HEAD','BISECT_LOG','BISECT_START','sequencer','rebase-merge','rebase-apply')) {
        $path = (& git rev-parse --git-path $name | Out-String).Trim()
        Assert ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($path)) "Unable to inspect Git operation state: $name"
        Assert (-not (Test-Path -LiteralPath $path)) "Incomplete Git operation state found: $name"
    }
}

try {
    New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
    $lockPath = Join-Path $logRoot 'homevault-single-run.lock'
    try { $lock = [System.IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { throw 'Another HomeVault autonomous controller process is active. Stop.' }
    $lockOwnerPath = "$lockPath.owner.json"
    Assert (-not (Test-Path -LiteralPath $lockOwnerPath)) 'Stale lock-owner metadata exists from an interrupted run. Inspect and remove it manually before continuing.'
    $runToken = [guid]::NewGuid().ToString('N')
    $canonicalRoot = [System.IO.Path]::GetFullPath($root).TrimEnd('\')
    $ownerMetadata = [ordered]@{ Pid=$PID; TokenHash=(Get-TextHash $runToken); Root=$canonicalRoot }
    Set-Content -LiteralPath $lockOwnerPath -Value ($ownerMetadata | ConvertTo-Json -Compress) -Encoding UTF8
    $ownsLockMetadata = $true

    Assert (-not $EnableGitHubWrites) '-EnableGitHubWrites is intentionally rejected because it combines local implementation and remote publication. Use -EnableLocalImplementation and, separately, -EnableGitHubPublication.'
    Assert (-not ($EnableGitHubPublication -and -not $EnableLocalImplementation)) '-EnableGitHubPublication also requires explicit -EnableLocalImplementation.'
    Assert (-not ($RecoverValidatedBranch -and -not $EnableLocalImplementation)) '-RecoverValidatedBranch requires explicit -EnableLocalImplementation because a validation repair may write approved local files.'
    Assert (Test-Path -LiteralPath 'AGENTS.md' -PathType Leaf) 'AGENTS.md was not found.'
    Assert (Test-Path -LiteralPath 'HomeVault-AgentController.ps1' -PathType Leaf) 'Original controller was not found.'
    Assert (Test-Path -LiteralPath 'HomeVault-AgentFinish.ps1' -PathType Leaf) 'Finish controller was not found.'
    foreach ($program in @('git','gh','powershell.exe')) {
        Assert ($null -ne (Get-Command $program -ErrorAction SilentlyContinue)) "$program unavailable"
    }

    $branch = Get-GitBranch
    Assert-StrictGitState
    if (-not $EnableLocalImplementation) {
        Write-Host 'PREVIEW ONLY: no implementation agents, validation repairs, commits, pushes, PRs, merges, checkouts, or deployments will run.' -ForegroundColor Green
        Assert (-not $RecoverValidatedBranch) 'Recovery is not a preview operation.'
        Assert ($branch -eq $base) "Preview must start from $base; currently '$branch'."
        Assert-CleanWorktree
    }
    elseif ($RecoverValidatedBranch) {
        Assert ($IssueNumber -gt 0) 'Recovery requires an explicit -IssueNumber.'
        Assert ($branch -match "^ai/issue-$IssueNumber-") "Recovery branch '$branch' does not match GH-$IssueNumber."
        Assert ($branch -ne $base) 'Recovery cannot run on the integration branch.'
    }
    else {
        Assert ($branch -eq $base) "New implementation must start from $base; currently '$branch'."
        Assert-CleanWorktree
    }

    Run 'gh' @('auth','status')
    if ($IssueNumber -eq 0) {
        Assert (-not $RecoverValidatedBranch) 'Recovery cannot auto-select an issue.'
        $raw = & gh issue list --repo $repo --state open --label ai-agent-task --label needs-orchestration --limit 20 --json number,title
        if ($LASTEXITCODE -ne 0) { throw 'Issue discovery failed.' }
        $issues = @($raw | ConvertFrom-Json)
        if ($issues.Count -eq 0) { Write-Host 'No queued AI issues.'; exit 0 }
        $IssueNumber = [int](($issues | Sort-Object number | Select-Object -First 1).number)
    }

    Write-Host "Selected: GH-$IssueNumber | Base: $base"
    if (-not $EnableLocalImplementation) {
        Run 'powershell.exe' @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$root\HomeVault-AgentController.ps1",'-DryRun','-IssueNumber',"$IssueNumber")
        exit 0
    }

    if ($RecoverValidatedBranch) {
        Write-Host 'RECOVERY: validating the existing IMPLEMENTATION_VALIDATED handoff; implementation will not be replayed.' -ForegroundColor Cyan
        Run-Finish @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$root\HomeVault-AgentFinish.ps1",'-IssueNumber',"$IssueNumber",'-Mode','Audit','-MaxRepairs',"$MaxRepairs")
    }
    else {
        Run 'powershell.exe' @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$root\HomeVault-AgentController.ps1",'-IssueNumber',"$IssueNumber",'-RunImplementation')
    }

    $finishArguments = @(
        '-NoProfile','-ExecutionPolicy','Bypass','-File',"$root\HomeVault-AgentFinish.ps1",
        '-IssueNumber',"$IssueNumber",'-Mode','Run','-MaxRepairs',"$MaxRepairs"
    )
    if ($EnableGitHubPublication) { $finishArguments += '-PublishDraftPR' }
    Run-Finish $finishArguments

    $finalBranch = Get-GitBranch
    Assert ($finalBranch -match "^ai/issue-$IssueNumber-") "Unexpected branch after execution: '$finalBranch'."
    if ($EnableGitHubPublication) {
        Write-Host "GH-$IssueNumber draft PR publication completed. The feature branch remains checked out for inspection; human merge is required." -ForegroundColor Green
    }
    else {
        Write-Host "GH-$IssueNumber local gates completed. Publication was not authorized; the feature branch and local changes remain for inspection." -ForegroundColor Green
    }
}
catch {
    Write-Error "HomeVault runner blocked: $($_.Exception.Message). No reset, force-checkout, deletion, merge, or deployment was attempted."
    exit 1
}
finally {
    if ($ownsLockMetadata -and $null -ne $lockOwnerPath -and (Test-Path -LiteralPath $lockOwnerPath)) {
        [System.IO.File]::Delete($lockOwnerPath)
    }
    if ($null -ne $lock) { $lock.Dispose() }
    $env:HOMEVAULT_AUTONOMOUS_LOCK_OWNER_PID = $null
    $env:HOMEVAULT_AUTONOMOUS_LOCK_TOKEN = $null
    $env:HOMEVAULT_AUTONOMOUS_LOCK_ROOT = $null
}
