[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet('team','orchestrator','requirements','ux','architect','developer','backend','qa','security','release','list')]
    [string]$Role,

    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Task
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Error $Message
    exit 1
}

if ($Role -eq 'list') {
    Write-Host 'Available roles:'
    Write-Host '  team          Full gated end-to-end workflow'
    Write-Host '  orchestrator  Delivery planning/gates'
    Write-Host '  requirements  Product requirements/acceptance criteria'
    Write-Host '  ux            UX/workflow review'
    Write-Host '  architect     Mobile architecture/design'
    Write-Host '  developer     Flutter/Android implementation'
    Write-Host '  backend       Firebase/API/data implementation'
    Write-Host '  qa            Independent QA/test automation'
    Write-Host '  security      Independent security/privacy review'
    Write-Host '  release       Android/Google Play release readiness'
    exit 0
}

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Fail 'Codex CLI was not found. Install it first, then reopen PowerShell.'
}

if (-not (Test-Path '.git')) {
    Fail 'Run this command from the root of the Git repository.'
}

if (-not (Test-Path '.codex\agents')) {
    Fail 'The project agent definitions were not found under .codex\agents.'
}

$taskText = ($Task -join ' ').Trim()
if ([string]::IsNullOrWhiteSpace($taskText)) {
    Fail 'Provide a task in quotes. Example: .\agent.ps1 team "Add warranty reminders"'
}

$agentMap = @{
    orchestrator = 'app_orchestrator'
    requirements = 'product_requirements'
    ux           = 'ux_workflow'
    architect    = 'mobile_architect'
    developer    = 'flutter_developer'
    backend      = 'backend_data'
    qa           = 'qa_automation'
    security     = 'security_privacy'
    release      = 'release_play'
}

if ($Role -eq 'team') {
    $prompt = @"
Use the project multi-agent delivery workflow in AGENTS.md for this task:

$taskText

Act as the primary control plane. First spawn app_orchestrator to bound the task and gates. Then use product_requirements, ux_workflow, and mobile_architect as applicable before allowing implementation. Wait for those results and consolidate the approved behavior. Use flutter_developer and backend_data only for their assigned approved scope; do not allow overlapping write-heavy agents to edit the same files concurrently. After implementation stops, have qa_automation and security_privacy independently validate the result. A failed gate must route back to the relevant implementation owner and then be rerun. Only after QA and security pass should release_play assess release readiness. Do not publish to Google Play or perform irreversible production operations. Update concise .agent-state records for material work. Return the final gate status and next human action.
"@
    & codex exec --sandbox workspace-write $prompt
    exit $LASTEXITCODE
}

$agentName = $agentMap[$Role]
$sandbox = if ($Role -in @('developer','backend','qa','release','orchestrator')) { 'workspace-write' } else { 'read-only' }

$prompt = @"
Spawn the project custom agent named '$agentName' for the following task and wait for it to finish. Use that specialist as the primary owner of this run. Follow AGENTS.md. Do not substitute a different role unless the requested agent explicitly reports that another specialist is required.

Task:
$taskText

Return the specialist's final handoff, including STATUS and exact next action.
"@

& codex exec --sandbox $sandbox $prompt
exit $LASTEXITCODE
