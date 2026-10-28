# Recovery ONLY after an AI issue feature commit was pushed but draft PR creation failed.
# Default is read-only. Never reruns agents, resets Git, or deploys.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateRange(1,999999)][int]$IssueNumber,
    [switch]$PublishDraftPR
)
$ErrorActionPreference = 'Stop'
$repo = 'amuaamir1/homevault'
$base = 'develop/feature-developmenet'
$root = $PSScriptRoot
Set-Location -LiteralPath $root
$lock = $null
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Invoke-GitChecked([string[]]$arguments) {
    $result = @(& git @arguments)
    Assert ($LASTEXITCODE -eq 0) "Git check failed: $($arguments -join ' ')"
    return $result
}
try {
    Assert (Test-Path -LiteralPath 'AGENTS.md') 'This script must be in the HomeVault repository.'
    foreach ($command in @('git','gh')) {
        Assert ($null -ne (Get-Command $command -ErrorAction SilentlyContinue)) "$command is unavailable."
    }
    $runRoot = Join-Path $env:LOCALAPPDATA 'HomeVaultAgent\runs'
    New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
    $lockPath = Join-Path $runRoot 'homevault-single-run.lock'
    try { $lock = [System.IO.File]::Open($lockPath,'OpenOrCreate','ReadWrite','None') }
    catch { throw 'A HomeVault agent controller is already running.' }
    Assert (-not (Test-Path -LiteralPath "$lockPath.owner.json")) 'Unresolved prior-run lock-owner metadata; inspect it manually.'

    $branch = ((Invoke-GitChecked @('branch','--show-current')) | Select-Object -First 1).Trim()
    Assert ($branch -match "^ai/issue-$IssueNumber-[a-z0-9][a-z0-9-]*$") 'Not on the exact issue feature branch.'
    Assert (@(Invoke-GitChecked @('status','--porcelain=v1','--untracked-files=all')).Count -eq 0) 'Worktree is not clean; refusing recovery.'
    & git diff --cached --quiet --
    Assert ($LASTEXITCODE -eq 0) 'Index is not clean.'
    foreach ($name in @('MERGE_HEAD','CHERRY_PICK_HEAD','REVERT_HEAD','REBASE_HEAD','rebase-merge','rebase-apply')) {
        $path = ((Invoke-GitChecked @('rev-parse','--git-path',$name)) | Select-Object -First 1).Trim()
        Assert (-not (Test-Path -LiteralPath $path)) "Incomplete Git operation: $name"
    }
    $origin = ((Invoke-GitChecked @('remote','get-url','origin')) | Select-Object -First 1).Trim()
    Assert ($origin -in @('https://github.com/amuaamir1/homevault.git','https://github.com/amuaamir1/homevault','git@github.com:amuaamir1/homevault.git','git@github.com:amuaamir1/homevault','ssh://git@github.com/amuaamir1/homevault.git')) 'Unexpected origin remote.'
    $head = ((Invoke-GitChecked @('rev-parse','HEAD')) | Select-Object -First 1).Trim()
    $subject = ((Invoke-GitChecked @('log','-1','--pretty=%s')) | Select-Object -First 1).Trim()
    Assert ($subject -ceq "feat: implement HomeVault GH-$IssueNumber") 'HEAD is not a controller-created feature commit.'
    $parents = @(((Invoke-GitChecked @('rev-list','--parents','-n','1','HEAD')) | Select-Object -First 1) -split '\s+')
    Assert ($parents.Count -eq 2) 'HEAD is not a one-parent feature commit.'
    $paths = @(Invoke-GitChecked @('diff-tree','--no-commit-id','--name-only','-r','HEAD','--'))
    Assert ($paths.Count -ge 2) 'Feature commit has no expected application changes.'
    $taskPath = ".agent-state/tasks/GH-$IssueNumber.md"
    Assert ($paths -ccontains $taskPath) 'Feature commit does not include the task state file.'
    foreach ($path in $paths) {
        Assert ($path -eq $taskPath -or $path -match '^(lib|test)/') "Unexpected committed path: $path"
        Assert ($path -notmatch '(?i)(firebase_options|google-services|\.env|key\.properties|\.jks$|\.keystore$|\.pem$|\.p12$|\.pfx$)') "Sensitive committed path: $path"
    }
    $state = (& git show "HEAD:$taskPath" | Out-String)
    Assert ($LASTEXITCODE -eq 0) 'Committed task state could not be inspected.'
    Assert ($state -match "(?m)^# GH-$IssueNumber\s*$") 'Committed task issue identity mismatch.'
    Assert ($state -match '(?m)^IMPLEMENTATION_VALIDATED\s*$') 'Committed state lacks IMPLEMENTATION_VALIDATED checkpoint.'
    Assert ($state -match '(?m)^QA_READY\s*$') 'Committed state lacks QA_READY checkpoint.'
    Assert ($state -match '(?m)^- Local Validation: PASS\s*$') 'Committed task state lacks local validation PASS.'

    $logs = @(Get-ChildItem -LiteralPath $runRoot -Filter "$IssueNumber-*-gate-evidence.log" -File | Sort-Object LastWriteTime -Descending)
    Assert ($logs.Count -gt 0) 'No local independent-review evidence found; manual recovery only.'
    $evidence = Get-Content -LiteralPath $logs[0].FullName -Raw
    foreach ($role in @('qa_automation','security_privacy','code_reviewer')) {
        $pattern = "(?s)===== $role \|[^\r\n]+\| PASS =====(?:(?!=====).)*?HOMEVAULT_GATE_BEGIN\s+ROLE: $role\s+STATUS: PASS\s+UNRESOLVED_SEVERITY: NONE\b"
        Assert ([regex]::IsMatch($evidence,$pattern)) "Missing PASS evidence for $role in latest review evidence log."
    }
    & gh auth status *> $null
    Assert ($LASTEXITCODE -eq 0) 'GitHub CLI is not authenticated.'
    & git fetch --no-tags origin "+refs/heads/${base}:refs/remotes/origin/${base}" | Out-Null
    Assert ($LASTEXITCODE -eq 0) 'Cannot fetch current integration base.'
    $baseSha = ((Invoke-GitChecked @('rev-parse',"refs/remotes/origin/$base")) | Select-Object -First 1).Trim()
    & git merge-base --is-ancestor $baseSha HEAD
    Assert ($LASTEXITCODE -eq 0) 'Base branch moved since this feature was created; manual integration required.'
    $remote = @(& git ls-remote --heads origin "refs/heads/$branch")
    Assert ($LASTEXITCODE -eq 0 -and $remote.Count -eq 1) 'Pushed remote feature branch not found.'
    $remoteSha = ($remote[0] -split '\s+')[0]
    Assert ($remoteSha -eq $head) 'Remote feature tip differs from local HEAD.'
    $existing = @(& gh pr list --repo $repo --head $branch --state all --json number,url,state,isDraft,baseRefName | ConvertFrom-Json)
    Assert ($LASTEXITCODE -eq 0) 'Cannot check existing PRs.'
    if ($existing.Count -gt 0) {
        Assert ($existing.Count -eq 1 -and $existing[0].state -eq 'OPEN' -and $existing[0].isDraft -eq $true -and $existing[0].baseRefName -eq $base) 'Existing PR needs human review.'
        Write-Host "Draft PR already exists: $($existing[0].url). No action needed." -ForegroundColor Green
        exit 0
    }
    $issue = (& gh issue view $IssueNumber --repo $repo --json title,state,labels | ConvertFrom-Json)
    Assert ($LASTEXITCODE -eq 0 -and $issue.state -eq 'OPEN') 'GitHub issue is not open.'
    Assert (@($issue.labels | ForEach-Object { $_.name }) -contains 'ai-agent-task') 'Issue lacks ai-agent-task label.'
    if (-not $PublishDraftPR) {
        Write-Host "RECOVERY PREVIEW PASS: remote $branch at $head and review evidence verified. No PR created." -ForegroundColor Green
        Write-Host "To create the draft PR: .\Recover-HomeVault-DraftPR.ps1 -IssueNumber $IssueNumber -PublishDraftPR"
        exit 0
    }
    $title = "[AI] $($issue.title)"
    $body = "Closes #$IssueNumber`n`nRecovery after a verified successful feature-branch push. Local QA, security and code-review evidence found. Human review and merge required. No production deployment."
    & gh pr create --repo $repo --draft --base $base --head $branch --title $title --body $body
    Assert ($LASTEXITCODE -eq 0) 'Draft PR creation failed. Re-run preview; no cleanup was attempted.'
    Write-Host 'Draft PR created successfully; human merge required.' -ForegroundColor Green
}
catch { Write-Error "HomeVault PR recovery blocked: $($_.Exception.Message)"; exit 1 }
finally { if ($null -ne $lock) { $lock.Dispose() } }
