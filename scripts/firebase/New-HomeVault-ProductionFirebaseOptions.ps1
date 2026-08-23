param(
    [Parameter(Mandatory = $true)]
    [string]$ExpectedProjectId,
    [string]$GoogleServicesPath = 'C:\Projects\HomeVault-Firebase-Config\production\google-services.json',
    [string]$OutputPath = 'C:\Projects\HomeVault-Firebase-Config\production\firebase_options.dart'
)

$ErrorActionPreference = 'Stop'
$ExpectedPackageName = 'com.amuaamir.homevault'
$DevelopmentProjectId = 'homevault-aamir-india-1701'

function Escape-DartSingleQuoted([string]$Value) {
    return $Value.Replace('\', '\\').Replace("'", "\'")
}

if ([string]::IsNullOrWhiteSpace($ExpectedProjectId)) {
    throw 'ExpectedProjectId is required.'
}
if ($ExpectedProjectId -eq $DevelopmentProjectId) {
    throw 'Production Firebase options cannot target the HomeVault Development project.'
}
if (-not (Test-Path -LiteralPath $GoogleServicesPath -PathType Leaf)) {
    throw "google-services.json was not found: $GoogleServicesPath"
}

$google = Get-Content -Raw -LiteralPath $GoogleServicesPath | ConvertFrom-Json
$projectId = "$($google.project_info.project_id)".Trim()
$projectNumber = "$($google.project_info.project_number)".Trim()
$storageBucket = "$($google.project_info.storage_bucket)".Trim()

if ($projectId -ne $ExpectedProjectId) {
    throw "google-services.json targets '$projectId', not '$ExpectedProjectId'."
}
if ([string]::IsNullOrWhiteSpace($projectNumber)) {
    throw 'google-services.json does not contain project_info.project_number.'
}

$client = @(
    $google.client |
        Where-Object {
            "$($_.client_info.android_client_info.package_name)" -eq $ExpectedPackageName
        }
) | Select-Object -First 1

if ($null -eq $client) {
    throw "google-services.json is not registered for $ExpectedPackageName."
}

$appId = "$($client.client_info.mobilesdk_app_id)".Trim()
$apiKey = @($client.api_key | ForEach-Object { "$($_.current_key)".Trim() }) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($appId)) {
    throw 'The Android Firebase App ID is missing from google-services.json.'
}
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'The Android Firebase API key is missing from google-services.json.'
}

$storageLine = ''
if (-not [string]::IsNullOrWhiteSpace($storageBucket)) {
    $storageLine = "    storageBucket: '$(Escape-DartSingleQuoted $storageBucket)',`r`n"
}

$dart = @"
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'HomeVault Production Firebase is currently configured for Android only.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'HomeVault Production Firebase is currently configured for Android only.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '$(Escape-DartSingleQuoted $apiKey)',
    appId: '$(Escape-DartSingleQuoted $appId)',
    messagingSenderId: '$(Escape-DartSingleQuoted $projectNumber)',
    projectId: '$(Escape-DartSingleQuoted $projectId)',
$storageLine  );
}
"@

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutputPath, $dart, $utf8)

Write-Host "PASS  Generated external Production firebase_options.dart"
Write-Host "Project: $projectId"
Write-Host "Android App ID: $appId"
if ($storageBucket) {
    Write-Host "Storage bucket: $storageBucket"
} else {
    Write-Warning 'No Storage bucket is present yet. Final Production onboarding must provision Storage and regenerate this file.'
}
