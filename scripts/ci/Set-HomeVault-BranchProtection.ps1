[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)][ValidateSet('develop','main')][string]$Branch,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required.'
}
$repo = gh repo view --json nameWithOwner --jq '.nameWithOwner'
if (-not $repo) { throw 'Unable to resolve the current GitHub repository.' }

$checks = if ($Branch -eq 'main') { @('Analyze and test') } else { @('Analyze and test') }
Write-Host "Repository: $repo"
Write-Host "Branch: $Branch"
Write-Host "Recommended required check(s): $($checks -join ', ')"
Write-Host 'Recommended: require pull requests, prevent deletion, require conversation resolution.'

if (-not $Apply) {
    Write-Host 'DRY RUN ONLY. Re-run with -Apply to change GitHub branch protection.' -ForegroundColor Yellow
    return
}

if ($PSCmdlet.ShouldProcess("$repo/$Branch", 'Configure HomeVault branch protection')) {
    $body = @{
        required_status_checks = @{ strict = $true; contexts = $checks }
        enforce_admins = $false
        required_pull_request_reviews = @{ dismiss_stale_reviews = $true; require_code_owner_reviews = $false; required_approving_review_count = 1 }
        restrictions = $null
        required_conversation_resolution = $true
        allow_force_pushes = $false
        allow_deletions = $false
    } | ConvertTo-Json -Depth 6 -Compress
    $body | gh api --method PUT "repos/$repo/branches/$Branch/protection" --input -
    if ($LASTEXITCODE -ne 0) { throw 'GitHub branch protection update failed.' }
    Write-Host 'Branch protection updated.' -ForegroundColor Green
}
