param(
    [switch]$DryRun,
    [int]$MaxIssues = 10,
    [int]$IssueNumber = 0
)

$ErrorActionPreference = 'Stop'

$Repo = 'amuaamir1/homevault'
$DevelopmentBranch = 'develop/feature-developmenet'
$CodexModel = 'gpt-5.6-sol'

function Fail {
    param([string]$Message)

    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Section {
    param([string]$Message)

    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function ConvertTo-BranchSlug {
    param([string]$Title)

    $slug = $Title.ToLowerInvariant()

    # Remove the standard issue-form prefix when present.
    $slug = $slug -replace '^\s*\[ai task\]\s*', ''

    # Convert everything except ASCII letters/numbers to hyphens.
    $slug = $slug -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')

    if ([string]::IsNullOrWhiteSpace($slug)) {
        $slug = 'task'
    }

    # Keep generated branch names manageable.
    if ($slug.Length -gt 48) {
        $slug = $slug.Substring(0, 48).TrimEnd('-')
    }

    return $slug
}

Set-Location $PSScriptRoot

Section "HomeVault Agent Controller"

Write-Host "Repository: $Repo"
Write-Host "Model:      $CodexModel"
Write-Host "Mode:       $(if ($DryRun) { 'DRY RUN' } else { 'TASK PREPARATION' })"

#
# Preflight
#

Section "Preflight"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "git is not available."
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail "GitHub CLI (gh) is not available."
}

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Fail "Codex CLI is not available."
}

$gitRoot = (& git rev-parse --show-toplevel 2>$null)

if (-not $gitRoot) {
    Fail "This script must run inside the HomeVault Git repository."
}

$currentBranch = (& git branch --show-current).Trim()

Write-Host "Current branch: $currentBranch"

if (-not $DryRun -and $currentBranch -ne $DevelopmentBranch) {
    Fail "Controller execution must start from $DevelopmentBranch."
}

if ($DryRun -and $currentBranch -ne $DevelopmentBranch) {
    Write-Host "Dry-run branch exception: $currentBranch"
}

$statusLines = @(
    & git status --porcelain
)

if ($DryRun) {
    # During controller development, allow only this controller file itself
    # to be modified/untracked.
    $blockingStatus = @(
        $statusLines |
            Where-Object {
                $_ -and
                $_ -notmatch '^..\s+HomeVault-AgentController\.ps1$'
            }
    )
}
else {
    $blockingStatus = $statusLines
}

if ($blockingStatus.Count -gt 0) {
    Write-Host ""
    Write-Host "Blocking worktree changes:"
    $blockingStatus | ForEach-Object {
        Write-Host "  $_"
    }

    Fail "Working tree contains changes that make controller execution unsafe."
}

if ($DryRun) {
    Write-Host "Git worktree: safe for dry-run"
}
else {
    Write-Host "Git worktree: clean"
}

#
# GitHub authentication
#

$null = & gh auth status 2>&1

if ($LASTEXITCODE -ne 0) {
    Fail "GitHub CLI is not authenticated."
}

Write-Host "GitHub CLI: authenticated"

#
# Codex / ChatGPT authentication
#

$loginStatus = (
    & cmd.exe /d /s /c "codex login status 2>&1" |
    Out-String
).Trim()

if ($LASTEXITCODE -ne 0) {
    Fail "Could not determine Codex login status."
}

if ($loginStatus -notmatch 'Logged in using ChatGPT') {
    Fail "Codex must be logged in using ChatGPT. Run: codex login"
}

if ($env:OPENAI_API_KEY) {
    Fail "OPENAI_API_KEY is set. Remove it before running the ChatGPT-plan controller."
}

Write-Host "Codex authentication: ChatGPT"

#
# Discover candidate issue
#

Section "Discover AI Tasks"

if ($IssueNumber -gt 0) {

    $issueJson = & gh issue view $IssueNumber `
        --repo $Repo `
        --json number,title,url,state,createdAt,labels

    if ($LASTEXITCODE -ne 0) {
        Fail "Could not retrieve GH-$IssueNumber."
    }

    $explicitIssue = $issueJson | ConvertFrom-Json

    if ($explicitIssue.state -ne 'OPEN') {
        Fail "GH-$IssueNumber is not open."
    }

    $labelNames = @(
        $explicitIssue.labels |
            ForEach-Object {
                $_.name
            }
    )

    if ($labelNames -notcontains 'ai-agent-task') {
        Fail "GH-$IssueNumber does not have label ai-agent-task."
    }

    if ($labelNames -notcontains 'needs-orchestration') {
        Fail "GH-$IssueNumber does not have label needs-orchestration."
    }

    $issues = @($explicitIssue)
}
else {

    $issueJson = & gh issue list `
        --repo $Repo `
        --state open `
        --label "ai-agent-task" `
        --label "needs-orchestration" `
        --limit $MaxIssues `
        --json number,title,url,createdAt,labels

    if ($LASTEXITCODE -ne 0) {
        Fail "Could not retrieve GitHub issues."
    }

    $issues = @(
        $issueJson |
            ConvertFrom-Json |
            Sort-Object number
    )
}

if (-not $issues -or $issues.Count -eq 0) {
    Write-Host "No eligible AI-agent tasks found."
    exit 0
}

Write-Host ""
Write-Host "Eligible issues:"

foreach ($issue in $issues) {
    Write-Host ("  GH-{0}  {1}" -f $issue.number, $issue.title)
    Write-Host ("         {0}" -f $issue.url)
}

#
# Select exactly one issue
#

$selected = $issues | Select-Object -First 1

$slug = ConvertTo-BranchSlug -Title $selected.title
$taskBranch = "ai/issue-$($selected.number)-$slug"
$taskId = "GH-$($selected.number)"
$taskStatePath = ".agent-state/tasks/$taskId.md"

Section "Selected Task"

Write-Host "Issue:       $taskId"
Write-Host "Title:       $($selected.title)"
Write-Host "URL:         $($selected.url)"
Write-Host "Task branch: $taskBranch"
Write-Host "State file:  $taskStatePath"

#
# Dry-run ends here.
#

if ($DryRun) {

    Section "Dry Run Plan"

    Write-Host "Would:"
    Write-Host "  1. Verify local development branch matches origin."
    Write-Host "  2. Create branch $taskBranch."
    Write-Host "  3. Create $taskStatePath."
    Write-Host "  4. Add label agent-in-progress."
    Write-Host "  5. Remove label needs-orchestration."
    Write-Host ""
    Write-Host "Would NOT:"
    Write-Host "  - start Codex"
    Write-Host "  - modify application source code"
    Write-Host "  - commit"
    Write-Host "  - push"
    Write-Host "  - create a pull request"
    Write-Host "  - merge"
    Write-Host "  - deploy"
    Write-Host ""
    Write-Host "DRY RUN COMPLETE"

    exit 0
}

#
# Live task preparation
#

Section "Verify Development Branch"

& git fetch origin $DevelopmentBranch

if ($LASTEXITCODE -ne 0) {
    Fail "Could not fetch $DevelopmentBranch from origin."
}

$localHead = (& git rev-parse HEAD).Trim()
$remoteHead = (& git rev-parse "origin/$DevelopmentBranch").Trim()

Write-Host "Local:  $localHead"
Write-Host "Remote: $remoteHead"

if ($localHead -ne $remoteHead) {
    Fail "Local $DevelopmentBranch is not synchronized with origin. Run git pull --ff-only origin $DevelopmentBranch first."
}

#
# Refuse duplicate branches.
#

$existingLocalBranch = (
    & git branch --list $taskBranch |
    Out-String
).Trim()

if ($existingLocalBranch) {
    Fail "Local branch $taskBranch already exists."
}

$existingRemoteBranch = (
    & git ls-remote --heads origin $taskBranch |
    Out-String
).Trim()

if ($existingRemoteBranch) {
    Fail "Remote branch $taskBranch already exists."
}

if (Test-Path $taskStatePath) {
    Fail "Task state file already exists: $taskStatePath"
}

#
# Create task branch.
#

Section "Create Task Branch"

& git switch -c $taskBranch

if ($LASTEXITCODE -ne 0) {
    Fail "Could not create task branch $taskBranch."
}

Write-Host "Created branch: $taskBranch"

#
# Initialize task state.
#

Section "Initialize Task State"

$taskDirectory = Split-Path $taskStatePath -Parent

if (-not (Test-Path $taskDirectory)) {
    New-Item `
        -ItemType Directory `
        -Path $taskDirectory `
        -Force |
        Out-Null
}

$taskState = @"
# $taskId

## GitHub Issue

- Number: $($selected.number)
- Title: $($selected.title)
- URL: $($selected.url)

## Status

PLANNING

## Stage

ORCHESTRATION

## Branch

$taskBranch

## Gates

- Requirements: NOT_RUN
- UX: NOT_RUN
- Architecture: NOT_RUN
- Implementation: NOT_RUN
- QA: NOT_RUN
- Security: NOT_RUN
- Code Review: NOT_RUN
- Release Readiness: NOT_RUN
- Human Review: NOT_RUN

## Repair Attempts

0 / 3

## Current Owner

app_orchestrator

## Decisions

None yet.

## Validation

Not started.

## Blockers

None.

## Next Action

Run the read-only app_orchestrator planning gate.
"@

Set-Content `
    -Path $taskStatePath `
    -Value $taskState `
    -Encoding UTF8

Write-Host "Created state file: $taskStatePath"

#
# Claim the GitHub issue.
#

Section "Claim GitHub Issue"

& gh issue edit $selected.number `
    --repo $Repo `
    --add-label "agent-in-progress" `
    --remove-label "needs-orchestration"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "WARNING: GitHub issue claim failed." -ForegroundColor Yellow
    Write-Host "The local task branch and state file were created."
    Write-Host "Manual recovery may be required."
    exit 1
}

Write-Host "Issue claimed: $taskId"
Write-Host "Added label:   agent-in-progress"
Write-Host "Removed label: needs-orchestration"

#
# Final state
#

Section "Task Prepared"

Write-Host "Issue:       $taskId"
Write-Host "Branch:      $taskBranch"
Write-Host "State file:  $taskStatePath"
Write-Host "Next owner:  app_orchestrator"
Write-Host ""
Write-Host "No Codex agent was started."
Write-Host "No commit was created."
Write-Host "No push was performed."
Write-Host "No pull request was created."