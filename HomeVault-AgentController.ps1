param(
    [switch]$DryRun,
    [int]$MaxIssues = 10
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

Set-Location $PSScriptRoot

Section "HomeVault Agent Controller"

Write-Host "Repository: $Repo"
Write-Host "Model:      $CodexModel"
Write-Host "Mode:       $(if ($DryRun) { 'DRY RUN' } else { 'DISCOVERY ONLY' })"

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
    & git status --porcelain |
        Where-Object {
            $_ -and
            $_ -notmatch '^\?\? HomeVault-AgentController\.ps1$'
        }
)

if ($statusLines.Count -gt 0) {
    Fail "Working tree contains changes other than the controller under development."
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
# Fetch candidate AI tasks
#

Section "Discover AI Tasks"

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

$issues = $issueJson | ConvertFrom-Json

if (-not $issues -or $issues.Count -eq 0) {
    Write-Host "No eligible AI-agent tasks found."
    exit 0
}

$issues = @(
    $issues |
        Sort-Object number
)

Write-Host ""
Write-Host "Eligible issues:"

foreach ($issue in $issues) {
    Write-Host ("  GH-{0}  {1}" -f $issue.number, $issue.title)
    Write-Host ("         {0}" -f $issue.url)
}

#
# Select exactly one task
#

$selected = $issues | Select-Object -First 1

Section "Selected Task"

Write-Host "Issue: GH-$($selected.number)"
Write-Host "Title: $($selected.title)"
Write-Host "URL:   $($selected.url)"

if ($DryRun) {
    Write-Host ""
    Write-Host "DRY RUN COMPLETE"
    Write-Host "No branch was created."
    Write-Host "No labels were changed."
    Write-Host "No Codex agent was started."
    Write-Host "No repository files were modified."
    exit 0
}

Write-Host ""
Write-Host "Discovery phase complete."
Write-Host "Controller write actions are intentionally disabled in this version."
