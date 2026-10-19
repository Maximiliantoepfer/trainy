[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$DeviceId,
  [ValidateSet('plan_onboarding_test', 'cardio_native_test')]
  [string]$Test = 'plan_onboarding_test'
)
$ErrorActionPreference = 'Stop'
if ($DeviceId -notmatch '^emulator-\d+$') {
  throw 'Device integration tests are restricted to an explicitly selected emulator.'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$local = Get-Content (Join-Path $projectRoot 'android\local.properties')
$sdk = (($local | Where-Object { $_ -match '^sdk\.dir=' }) -split '=', 2)[1].Replace('\\', '\')
$flutterSdk = (($local | Where-Object { $_ -match '^flutter\.sdk=' }) -split '=', 2)[1].Replace('\\', '\')
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$flutter = Join-Path $flutterSdk 'bin\flutter.bat'
$buildTools = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$aapt = Join-Path $buildTools.FullName 'aapt.exe'
$target = "integration_test/$Test.dart"
$apk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-debug.apk'
$productionBefore = (& $adb -s $DeviceId shell pm path com.example.trainy) -join ''
Push-Location $projectRoot
try {
  # Flutter 3.29 captures the OLD APK ID before compiling listener.dart and uses
  # that ID during teardown. Prebuilding and checking the test artifact is vital.
  & $flutter build apk --debug --no-pub --target $target
  if ($LASTEXITCODE -ne 0) { throw 'Could not build the isolated test APK.' }
  $badging = (& $aapt dump badging $apk) -join "`n"
  if ($LASTEXITCODE -ne 0 -or $badging -notmatch "package: name='com\.example\.trainy\.integration'") {
    throw 'Refusing device test: APK does not use the isolated test package ID.'
  }
  # Only the separate test package receives test permissions.
  & $adb -s $DeviceId install -r -g $apk
  if ($LASTEXITCODE -ne 0) { throw 'Could not prepare the isolated test package.' }
  & $flutter test $target -d $DeviceId --no-pub --reporter expanded
  if ($LASTEXITCODE -ne 0) { throw 'Integration test failed.' }
  $productionAfter = (& $adb -s $DeviceId shell pm path com.example.trainy) -join ''
  if ($productionBefore -and !$productionAfter) { throw 'Production installation unexpectedly missing.' }
  Write-Host 'Isolated Android integration test passed; production package was not removed.'
} finally {
  # Do not leave the normal APK delivery path pointing at a test entry point.
  & $flutter build apk --debug --no-pub --target lib/main.dart
  $restoreExit = $LASTEXITCODE
  Pop-Location
  if ($restoreExit -ne 0) { throw 'Normal APK rebuild failed after the test.' }
}
