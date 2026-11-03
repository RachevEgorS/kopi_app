$ErrorActionPreference = 'Stop'
$kopiSource = Split-Path -Parent $PSScriptRoot
$kopiTestRoot = Join-Path $env:USERPROFILE '.codex\builds\kopi-android-tests'
$kopiFlutter = Join-Path $env:USERPROFILE 'develop\flutter\bin\flutter.bat'
if (-not $env:JAVA_HOME) { $env:JAVA_HOME = Join-Path $env:LOCALAPPDATA 'Programs\Android Studio\jbr' }
New-Item -ItemType Directory -Path $kopiTestRoot -Force | Out-Null
# Robolectric/Gradle and the release compiler have trouble with Cyrillic paths on Windows.
# Copy source only; no application APK is assembled by this task.
robocopy $kopiSource $kopiTestRoot /E /XD .git .dart_tool build .gradle previews .idea .vscode /XF .flutter-plugins-dependencies /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -ge 8) { throw 'Could not prepare the Android test directory.' }
Push-Location $kopiTestRoot
try {
  & $kopiFlutter pub get
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & '.\android\gradlew.bat' -p android :app:testDebugUnitTest
  exit $LASTEXITCODE
} finally { Pop-Location }
