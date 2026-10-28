# One-task-per-run HomeVault local launcher. Scheduling is optional; human merge remains mandatory.
[CmdletBinding()]
param(
    [int]$IssueNumber = 0,
    [switch]$EnableGitHubWrites,
    [ValidateRange(0,3)][int]$MaxRepairs = 2
)
$ErrorActionPreference = 'Stop'
$repo = 'amuaamir1/homevault'
$base = 'develop/feature-developmenet'
Set-Location $PSScriptRoot
function Run([string]$tool,[string[]]$arguments) {
    & $tool @arguments
    if ($LASTEXITCODE -ne 0) { throw "$tool exited with $LASTEXITCODE" }
}
try {
    if (-not $EnableGitHubWrites) {
        Write-Host 'PREVIEW ONLY. Add -EnableGitHubWrites for implementation and draft PR.'
    }
    $branch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $branch -ne $base) { throw "Start from $base; currently '$branch'" }
    if (@(& git status --porcelain).Count -gt 0) { throw 'Working tree is not clean.' }
    Run 'gh' @('auth','status')
    if ($IssueNumber -eq 0) {
        $raw = & gh issue list --repo $repo --state open --label ai-agent-task --label needs-orchestration --limit 20 --json number,title
        if ($LASTEXITCODE -ne 0) { throw 'Issue discovery failed' }
        $issues = @($raw | ConvertFrom-Json)
        if ($issues.Count -eq 0) { Write-Host 'No queued AI issues.'; exit 0 }
        $IssueNumber = [int]($issues | Sort-Object number | Select-Object -First 1).number
    }
    Write-Host "Selected: GH-$IssueNumber"
    if (-not $EnableGitHubWrites) {
        Run 'powershell.exe' @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSScriptRoot\HomeVault-AgentController.ps1",'-DryRun','-IssueNumber',"$IssueNumber")
        exit 0
    }
    Run 'powershell.exe' @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSScriptRoot\HomeVault-AgentController.ps1",'-IssueNumber',"$IssueNumber",'-RunImplementation')
    Run 'powershell.exe' @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSScriptRoot\HomeVault-AgentFinish.ps1",'-IssueNumber',"$IssueNumber",'-Mode','Run','-PublishDraftPR','-MaxRepairs',"$MaxRepairs")
    if (@(& git status --porcelain).Count -gt 0) { throw 'PR created but worktree is not clean; leave feature branch for inspection.' }
    Run 'git' @('switch',$base)
    Write-Host "GH-$IssueNumber complete: draft PR created and local base restored." -ForegroundColor Green
}
catch {
    Write-Error "HomeVault runner blocked: $($_.Exception.Message). Do not reset or force-checkout."
    exit 1
}
