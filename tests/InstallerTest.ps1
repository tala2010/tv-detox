$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path $repo ('out-tests\installer-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
$apk = Join-Path $testRoot 'fixture.apk'
'not-an-apk: passed only to Fake-Adb.ps1' | Set-Content $apk
$fakeAdb = Join-Path $PSScriptRoot 'Fake-Adb.ps1'
function Reset-Fixture([string]$Name) {
    $env:TV_TEST_DIRECTORY = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path $env:TV_TEST_DIRECTORY | Out-Null
    'original.launcher/.Main' | Set-Content (Join-Path $env:TV_TEST_DIRECTORY 'home.txt')
    'package:already.disabled' | Set-Content (Join-Path $env:TV_TEST_DIRECTORY 'disabled.txt')
    $env:TV_TEST_RECLAIM = '0'
}
function Expect([bool]$Condition,[string]$Message) { if (!$Condition) { throw $Message } }
try {
    Reset-Fixture 'trial'
    & (Join-Path $repo 'scripts\Install-Xiaomi.ps1') -TvAddress '192.0.2.1' -AdbPath $fakeAdb -ApkPath $apk
    $calls = Get-Content (Join-Path $env:TV_TEST_DIRECTORY 'calls.txt')
    Expect (!($calls -match 'pm disable|pm enable|uninstall|settings put')) 'Trial must not disable/enable/uninstall apps or write settings'
    Expect ((Get-Content (Join-Path $env:TV_TEST_DIRECTORY 'home.txt')) -eq 'original.launcher/.Main') 'Trial must preserve the original default after APK installation'

    Reset-Fixture 'default-and-restore'
    & (Join-Path $repo 'scripts\Install-Xiaomi.ps1') -TvAddress '192.0.2.1' -AdbPath $fakeAdb -ApkPath $apk -SetDefault -DisableStockHome
    $backup = Get-ChildItem (Join-Path $repo 'backups') -Directory | Sort-Object Name | Select-Object -Last 1
    Expect ((Get-Content (Join-Path $env:TV_TEST_DIRECTORY 'home.txt')) -eq 'dev.local.mitvhome/.MainActivity') 'Opt-in must set custom Home'
    & (Join-Path $repo 'scripts\Restore-Xiaomi.ps1') -BackupDirectory $backup.FullName -AdbPath $fakeAdb
    Expect ((Get-Content (Join-Path $env:TV_TEST_DIRECTORY 'home.txt')) -eq 'original.launcher/.Main') 'Restore must restore original default'
    $disabled = @(Get-Content (Join-Path $env:TV_TEST_DIRECTORY 'disabled.txt'))
    Expect ($disabled.Count -eq 1 -and $disabled[0] -eq 'package:already.disabled') 'Restore must preserve pre-existing disabled apps'

    Reset-Fixture 'reclaimed-home'
    $env:TV_TEST_RECLAIM = '1'
    $rejected = $false
    try { & (Join-Path $repo 'scripts\Install-Xiaomi.ps1') -TvAddress '192.0.2.1' -AdbPath $fakeAdb -ApkPath $apk -SetDefault -DisableStockHome }
    catch { $rejected = $true }
    Expect $rejected 'Installer must report default-Home verification failure'
    Expect ((Get-Content (Join-Path $env:TV_TEST_DIRECTORY 'home.txt')) -eq 'original.launcher/.Main') 'Verification failure must roll back the original Home'
    $disabled = @(Get-Content (Join-Path $env:TV_TEST_DIRECTORY 'disabled.txt'))
    Expect ($disabled.Count -eq 1 -and $disabled[0] -eq 'package:already.disabled') 'Rollback must restore only the stock launcher it disabled'
    'PASS: trial preservation, explicit default opt-in, selective restore, and rollback'
} finally {
    Remove-Item Env:\TV_TEST_DIRECTORY,Env:\TV_TEST_RECLAIM -ErrorAction SilentlyContinue
}
