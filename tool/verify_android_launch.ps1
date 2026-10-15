[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$DeviceId,
  [string]$ExpectedAvdName,
  [switch]$SkipBuild,
  [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$localProperties = Join-Path $projectRoot 'android\local.properties'
if (-not (Test-Path -LiteralPath $localProperties)) {
  throw "Android local.properties was not found: $localProperties"
}

$sdkLine = Get-Content -LiteralPath $localProperties |
  Where-Object { $_ -match '^sdk\.dir=' } |
  Select-Object -First 1
if (-not $sdkLine) {
  throw 'sdk.dir is missing in android/local.properties.'
}
$androidSdk = (($sdkLine -split '=', 2)[1]).Replace('\\', '\')
$adb = Join-Path $androidSdk 'platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adb)) {
  throw "adb.exe was not found: $adb"
}

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
  throw 'DeviceId must identify a connected Android emulator or physical device.'
}

& $adb -s $DeviceId wait-for-device
if ($LASTEXITCODE -ne 0) {
  throw "Android emulator '$DeviceId' is not available."
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedAvdName)) {
  if ($DeviceId -notmatch '^emulator-\d+$') {
    throw 'ExpectedAvdName can only be verified for an Android emulator.'
  }
  $avdLines = @(& $adb -s $DeviceId shell getprop ro.boot.qemu.avd_name 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "Could not determine the AVD name for '$DeviceId'."
  }
  $actualAvdName = $avdLines |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and $_ -ne 'OK' } |
    Select-Object -Last 1
  if ($actualAvdName -cne $ExpectedAvdName) {
    throw "Refusing to use '$DeviceId': expected AVD '$ExpectedAvdName', found '$actualAvdName'."
  }
}

$buildToolsRoot = Join-Path $androidSdk 'build-tools'
$buildTools = Get-ChildItem -LiteralPath $buildToolsRoot -Directory |
  Sort-Object { [version]$_.Name } -Descending |
  Select-Object -First 1
if (-not $buildTools) {
  throw "No Android build-tools directory was found below $buildToolsRoot"
}
$aapt = Join-Path $buildTools.FullName 'aapt.exe'
$dexdump = Join-Path $buildTools.FullName 'dexdump.exe'
if (-not (Test-Path -LiteralPath $aapt) -or -not (Test-Path -LiteralPath $dexdump)) {
  throw 'aapt.exe or dexdump.exe is missing from the selected build-tools.'
}

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutter = if ($flutterCommand) {
  $flutterCommand.Source
} else {
  'C:\flutter\bin\flutter.bat'
}
if (-not (Test-Path -LiteralPath $flutter)) {
  throw "Flutter executable was not found: $flutter"
}

Push-Location $projectRoot
try {
  if (-not $SkipBuild) {
    & $flutter build apk --debug
    if ($LASTEXITCODE -ne 0) {
      throw "flutter build apk --debug failed with exit code $LASTEXITCODE"
    }
  }

  $apk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-debug.apk'
  if (-not (Test-Path -LiteralPath $apk)) {
    throw "Debug APK was not found: $apk"
  }

  $badging = (& $aapt dump badging $apk) -join [Environment]::NewLine
  if ($LASTEXITCODE -ne 0 -or $badging -notmatch "package: name='com\.example\.trainy'") {
    throw 'APK package verification failed.'
  }
  if ($badging -notmatch "launchable-activity: name='com\.example\.trainy\.MainActivity'") {
    throw 'APK launcher activity verification failed.'
  }

  $dexFiles = Get-ChildItem -Path (Join-Path $projectRoot 'build\app\intermediates\dex\debug\mergeProjectDexDebug') -Recurse -Filter classes.dex
  $hasMainActivity = $false
  foreach ($dex in $dexFiles) {
    if (& $dexdump -d $dex.FullName | Select-String -SimpleMatch 'Lcom/example/trainy/MainActivity;' -Quiet) {
      $hasMainActivity = $true
      break
    }
  }
  if (-not $hasMainActivity) {
    throw 'DEX verification failed: Trainy MainActivity is missing.'
  }

  if (-not $SkipInstall) {
    & $adb -s $DeviceId install -r $apk
    if ($LASTEXITCODE -ne 0) {
      throw "APK installation failed with exit code $LASTEXITCODE"
    }
    $launch = (& $adb -s $DeviceId shell am start -W -n 'com.example.trainy/.MainActivity') -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0 -or $launch -match 'Error type 3|does not exist' -or $launch -notmatch 'Activity: com\.example\.trainy/.MainActivity') {
      throw "Launcher smoke test failed:`n$launch"
    }
  }

  Write-Host 'Android launch smoke test passed.' -ForegroundColor Green
} finally {
  Pop-Location
}
