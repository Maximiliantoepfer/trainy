[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$local = Get-Content (Join-Path $projectRoot 'android/local.properties')
$sdk = (($local | Where-Object { $_ -match '^sdk\.dir=' }) -split '=', 2)[1].Replace('\\', '\')
$flutterSdk = (($local | Where-Object { $_ -match '^flutter\.sdk=' }) -split '=', 2)[1].Replace('\\', '\')
$flutter = Join-Path $flutterSdk 'bin/flutter.bat'
$buildTools = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$aapt = Join-Path $buildTools.FullName 'aapt.exe'
$apk = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-debug.apk'
$destination = Join-Path $projectRoot 'build/app/outputs/acceptance/trainy-acceptance.apk'
Push-Location $projectRoot
try {
  & $flutter build apk --debug --no-pub --target lib/main.dart --dart-define=TRAINY_ISOLATED_ACCEPTANCE=true
  if ($LASTEXITCODE -ne 0) { throw 'Acceptance build failed.' }
  $badging = (& $aapt dump badging $apk) -join "`n"
  if ($LASTEXITCODE -ne 0 -or $badging -notmatch "package: name='com\.example\.trainy\.acceptance'") {
    throw 'Refusing to deliver an APK without the separate acceptance identity.'
  }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
  Copy-Item -LiteralPath $apk -Destination $destination
  Write-Host "Manual acceptance APK: $destination"
  Write-Host 'No app was installed and no device data was changed.'
} finally {
  & $flutter build apk --debug --no-pub --target lib/main.dart
  $restoreExit = $LASTEXITCODE
  Pop-Location
  if ($restoreExit -ne 0) { throw 'Normal APK rebuild failed after acceptance build.' }
}
