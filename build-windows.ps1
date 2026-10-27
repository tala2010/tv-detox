param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'out'),
    [string]$AndroidSdk = $(if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { $env:ANDROID_SDK_ROOT }),
    [string]$BuildToolsVersion = '34.0.0',
    [string]$D8Jar,
    [string]$Keystore = (Join-Path $PSScriptRoot 'local-home-key.jks'),
    [string]$KeystorePassword = $(if ($env:KEYSTORE_PASS) { $env:KEYSTORE_PASS } else { 'local-tvhome' })
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (!$AndroidSdk) { throw 'Set ANDROID_HOME or pass -AndroidSdk with your Android SDK path.' }
$tools = Join-Path $AndroidSdk "build-tools\$BuildToolsVersion"
$jar = Join-Path $AndroidSdk 'platforms\android-34\android.jar'
if (!(Test-Path -LiteralPath $jar) -or !(Test-Path -LiteralPath (Join-Path $tools 'aapt2.exe'))) { throw 'Install platforms;android-34 and build-tools;34.0.0 using sdkmanager.' }
if (!$D8Jar) { $D8Jar = Join-Path $tools 'lib\d8.jar' }
$build = Join-Path $root 'out\build-windows'
$classes = Join-Path $build 'classes'
$gen = Join-Path $build 'gen'
$dex = Join-Path $build 'dex'
New-Item -ItemType Directory -Force -Path $classes,$gen,$dex,$OutputDirectory | Out-Null
function CheckExit { if ($LASTEXITCODE -ne 0) { throw "Build failed: $LASTEXITCODE" } }
$appsFile = if ($env:APPS) { $env:APPS } else { Join-Path $root 'apps.txt' }
$appLines = @(Get-Content -LiteralPath $appsFile | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() } | ForEach-Object { '"' + ($_.Trim() -replace '\s','') + '"' })
('package dev.local.mitvhome; final class Apps { static final String[] LIST = {' + ($appLines -join ',') + '}; }') | Set-Content -Encoding utf8 -LiteralPath (Join-Path $gen 'Apps.java')
& (Join-Path $tools 'aapt2.exe') compile --dir (Join-Path $root 'res') -o (Join-Path $build 'res.zip')
CheckExit
& (Join-Path $tools 'aapt2.exe') link -o (Join-Path $build 'base.apk') -I $jar --manifest (Join-Path $root 'AndroidManifest.xml') --java $gen (Join-Path $build 'res.zip')
CheckExit
$sources = @(Get-ChildItem -LiteralPath (Join-Path $root 'src'),$gen -Filter '*.java' -Recurse | ForEach-Object FullName)
& javac -nowarn -Xlint:-options -encoding UTF-8 -source 8 -target 8 -bootclasspath "$jar;$(Join-Path $tools 'core-lambda-stubs.jar')" -d $classes @sources
CheckExit
$classFiles = @(Get-ChildItem -LiteralPath $classes -Recurse -Filter '*.class' | ForEach-Object FullName)
& java -cp $D8Jar com.android.tools.r8.D8 --min-api 21 --release --lib $jar --output $dex @classFiles
CheckExit
Copy-Item -LiteralPath (Join-Path $build 'base.apk') -Destination (Join-Path $build 'unsigned.apk') -Force
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open((Join-Path $build 'unsigned.apk'),'Update')
try { [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $dex 'classes.dex'),'classes.dex') | Out-Null } finally { $zip.Dispose() }
& (Join-Path $tools 'zipalign.exe') -f 4 (Join-Path $build 'unsigned.apk') (Join-Path $build 'aligned.apk')
CheckExit
$key = $Keystore
if (!(Test-Path -LiteralPath $key)) {
    & keytool -genkeypair -keystore $key -storepass $KeystorePassword -keypass $KeystorePassword -alias home -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=Local Xiaomi Home'
    CheckExit
}
$apk = Join-Path $OutputDirectory 'tvhome-xiaomi.apk'
$env:TVHOME_SIGNING_PASS = $KeystorePassword
try { & java -jar (Join-Path $tools 'lib\apksigner.jar') sign --ks $key --ks-pass env:TVHOME_SIGNING_PASS --out $apk (Join-Path $build 'aligned.apk'); CheckExit }
finally { Remove-Item Env:\TVHOME_SIGNING_PASS -ErrorAction SilentlyContinue }
CheckExit
& java -jar (Join-Path $tools 'lib\apksigner.jar') verify --verbose $apk
CheckExit
Get-FileHash -LiteralPath $apk -Algorithm SHA256
