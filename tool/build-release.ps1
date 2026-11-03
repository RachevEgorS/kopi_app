$ErrorActionPreference = 'Stop'
$kopiSource = Split-Path -Parent $PSScriptRoot
$kopiBuildRoot = Join-Path $env:USERPROFILE '.codex\builds\kopi-release'
$kopiFlutter = Join-Path $env:USERPROFILE 'develop\flutter\bin\flutter.bat'
if (-not (Test-Path -LiteralPath $kopiFlutter)) { throw 'Flutter SDK was not found in the expected location.' }
if (-not $env:JAVA_HOME) { $env:JAVA_HOME = Join-Path $env:LOCALAPPDATA 'Programs\Android Studio\jbr' }
New-Item -ItemType Directory -Path $kopiBuildRoot -Force | Out-Null
# The Android/Dart release compiler fails to read generated AOT snapshots when
# the project path contains Cyrillic characters. Build from this ASCII copy.
robocopy $kopiSource $kopiBuildRoot /E /XD .git .dart_tool build .gradle previews .idea .vscode /XF .flutter-plugins-dependencies /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -ge 8) { throw 'Could not prepare the release build directory.' }
Push-Location $kopiBuildRoot
try {
  & $kopiFlutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed.' }
  & $kopiFlutter build apk --release
  if ($LASTEXITCODE -ne 0) { throw 'Release APK build failed.' }
  Write-Output "APK: $(Join-Path $kopiBuildRoot 'build\app\outputs\flutter-apk\app-release.apk')"
} finally { Pop-Location }
