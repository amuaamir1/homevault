param(
    [Parameter(Mandatory = $true)]
    [string]$ProductionProjectId,
    [string]$ConfigRoot = 'C:\Projects\HomeVault-Firebase-Config\production'
)

$ErrorActionPreference = 'Stop'
$DevelopmentProjectId = 'homevault-aamir-india-1701'

if ($ProductionProjectId -eq $DevelopmentProjectId) {
    throw 'Production live smoke cannot target the Development Firebase project.'
}

$googleServicesPath = Join-Path $ConfigRoot 'google-services.json'
if (-not (Test-Path -LiteralPath $googleServicesPath -PathType Leaf)) {
    throw "Production google-services.json not found: $googleServicesPath"
}

$google = Get-Content -Raw -LiteralPath $googleServicesPath | ConvertFrom-Json
if ("$($google.project_info.project_id)" -ne $ProductionProjectId) {
    throw 'Production live smoke config does not match ProductionProjectId.'
}

$client = @(
    $google.client |
        Where-Object {
            "$($_.client_info.android_client_info.package_name)" -eq 'com.amuaamir.homevault'
        }
) | Select-Object -First 1

$apiKey = @($client.api_key | ForEach-Object { "$($_.current_key)".Trim() }) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'Could not determine the Production Firebase API key.'
}

$guid = [Guid]::NewGuid().ToString('N')
$email = "homevault-p16-smoke-$guid@example.com"
$password = "Hv!$([Guid]::NewGuid().ToString('N'))9a"
$idToken = $null
$uid = $null
$profileCreated = $false

function Invoke-FirebaseAuthRest {
    param(
        [string]$Method,
        [string]$Action,
        [hashtable]$Body
    )

    $uri = "https://identitytoolkit.googleapis.com/v1/accounts:$Action" + "?key=$apiKey"
    return Invoke-RestMethod `
        -Method $Method `
        -Uri $uri `
        -ContentType 'application/json' `
        -Body ($Body | ConvertTo-Json -Depth 6)
}

try {
    Write-Host 'Creating temporary Production Firebase Auth smoke user...'
    try {
        $signup = Invoke-FirebaseAuthRest `
            -Method Post `
            -Action 'signUp' `
            -Body @{
                email = $email
                password = $password
                returnSecureToken = $true
            }
    } catch {
        $message = "$($_.Exception.Message)"
        if ($message -match 'OPERATION_NOT_ALLOWED') {
            throw 'Email/Password authentication is not enabled in Production Firebase.'
        }
        throw
    }

    $idToken = "$($signup.idToken)"
    $uid = "$($signup.localId)"

    if ([string]::IsNullOrWhiteSpace($idToken) -or [string]::IsNullOrWhiteSpace($uid)) {
        throw 'Production Firebase Auth did not return a usable smoke-test session.'
    }
    Write-Host 'PASS  Production Email/Password authentication'

    $headers = @{ Authorization = "Bearer $idToken" }
    $profileUri = "https://firestore.googleapis.com/v1/projects/$ProductionProjectId/databases/(default)/documents/users/$uid"

    $profileBody = @{
        fields = @{
            uid = @{ stringValue = $uid }
            fullName = @{ stringValue = 'P16 Production Smoke Test' }
            phoneNumber = @{ stringValue = '' }
            email = @{ stringValue = $email }
            addressLine1 = @{ stringValue = '' }
            addressLine2 = @{ stringValue = '' }
            landmark = @{ stringValue = '' }
            state = @{ stringValue = '' }
            city = @{ stringValue = '' }
            pinCode = @{ stringValue = '' }
        }
    } | ConvertTo-Json -Depth 8

    Invoke-RestMethod `
        -Method Patch `
        -Uri $profileUri `
        -Headers $headers `
        -ContentType 'application/json' `
        -Body $profileBody | Out-Null
    $profileCreated = $true
    Write-Host 'PASS  Production Firestore owner write is allowed'

    Invoke-RestMethod `
        -Method Get `
        -Uri $profileUri `
        -Headers $headers | Out-Null
    Write-Host 'PASS  Production Firestore owner read is allowed'

    $crossUserUri = "https://firestore.googleapis.com/v1/projects/$ProductionProjectId/databases/(default)/documents/users/not-$uid"
    $crossUserDenied = $false
    try {
        Invoke-RestMethod -Method Get -Uri $crossUserUri -Headers $headers | Out-Null
    } catch {
        $statusCode = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        if ($statusCode -eq 403) {
            $crossUserDenied = $true
        } else {
            throw
        }
    }

    if (-not $crossUserDenied) {
        throw 'Cross-user Firestore read was not denied.'
    }
    Write-Host 'PASS  Production Firestore cross-user read is denied'

    Invoke-RestMethod `
        -Method Delete `
        -Uri $profileUri `
        -Headers $headers | Out-Null
    $profileCreated = $false
    Write-Host 'PASS  Production Firestore owner cleanup'

    Write-Host ''
    Write-Host 'Production live Auth/Firestore smoke: PASS'
} finally {
    if ($profileCreated -and $idToken -and $uid) {
        try {
            $headers = @{ Authorization = "Bearer $idToken" }
            $profileUri = "https://firestore.googleapis.com/v1/projects/$ProductionProjectId/databases/(default)/documents/users/$uid"
            Invoke-RestMethod -Method Delete -Uri $profileUri -Headers $headers | Out-Null
        } catch {
            Write-Warning 'Temporary Firestore smoke profile cleanup failed.'
        }
    }

    if ($idToken) {
        try {
            Invoke-FirebaseAuthRest `
                -Method Post `
                -Action 'delete' `
                -Body @{ idToken = $idToken } | Out-Null
            Write-Host 'PASS  Temporary Production Firebase Auth smoke user deleted'
        } catch {
            Write-Warning 'Temporary Firebase Auth smoke user cleanup failed. Delete the homevault-p16-smoke-* user from Authentication if it remains.'
        }
    }
}
