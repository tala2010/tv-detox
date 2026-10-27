[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$TvAddress,
    [string]$ApkPath,
    [string]$AdbPath = 'adb',
    [switch]$SetDefault,
    [switch]$DisableStockHome,
    [switch]$AllowUntestedModel
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$package = 'dev.local.mitvhome'
if ($TvAddress -notmatch '^[a-zA-Z0-9_.:-]+$') { throw 'Invalid TV address.' }
if ($TvAddress -match '^\d+\.\d+\.\d+\.\d+$') { $TvAddress += ':5555' }
if ($DisableStockHome -and !$SetDefault) { throw '-DisableStockHome requires -SetDefault.' }
function Invoke-Adb([string[]]$Arguments) {
    $result = & $AdbPath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($result -join "`n") }
    return $result
}
function Tv([string[]]$Arguments) { Invoke-Adb (@('-s',$TvAddress,'shell') + $Arguments) }
Invoke-Adb @('connect',$TvAddress) | Out-Host
if ((Invoke-Adb @('-s',$TvAddress,'get-state')) -ne 'device') { throw 'Authorize ADB on the TV first.' }
$model = (Tv @('getprop','ro.product.model') | Out-String).Trim()
$sdk = [int]((Tv @('getprop','ro.build.version.sdk') | Out-String).Trim())
if ($sdk -lt 21) { throw 'Android 5.0 or newer is required.' }
if ($model -ne 'MiTV-MFTP0' -and !$AllowUntestedModel) { throw "Untested model: $model. Use -AllowUntestedModel only after reviewing docs/xiaomi/COMPATIBILITY.md." }
$backup = Join-Path $repo ('backups\xiaomi-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Force -Path $backup | Out-Null
$disabled = @(Tv @('pm','list','packages','-d'))
$homeRaw = @(Tv @('cmd','package','resolve-activity','--brief','-a','android.intent.action.MAIN','-c','android.intent.category.HOME'))
$previousHome = @($homeRaw | Where-Object { $_ -match '^[a-zA-Z0-9_.]+/[a-zA-Z0-9_.$]+$' }) | Select-Object -Last 1
$disabled | Set-Content -Encoding utf8 (Join-Path $backup 'disabled-before.txt')
$homeRaw | Set-Content -Encoding utf8 (Join-Path $backup 'home-before.txt')
Tv @('getprop') | Set-Content -Encoding utf8 (Join-Path $backup 'properties-before.txt')
foreach ($scope in @('system','secure','global')) {
    Tv @('settings','list',$scope) | Set-Content -Encoding utf8 (Join-Path $backup "settings-$scope-before.txt")
}
$record = [ordered]@{ TvAddress=$TvAddress; Model=$model; Home=$previousHome; ChangedDefault=$false; StockDisabledByInstaller=$false }
$metadata = Join-Path $backup 'restore.json'
$record | ConvertTo-Json | Set-Content -Encoding utf8 $metadata
Write-Host "Backup: $backup"
Write-Host 'This is a settings/state snapshot, not a full system or private app-data backup.'
if (!$ApkPath) {
    $ApkPath = Join-Path $repo 'out\tvhome-xiaomi.apk'
    if (!(Test-Path -LiteralPath $ApkPath)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $ApkPath -Parent) | Out-Null
        $release = 'https://github.com/tala2010/tv-detox/releases/download/xiaomi-v1.0.0'
        Invoke-WebRequest "$release/tvhome-xiaomi.apk" -OutFile $ApkPath
        $hashFile = Join-Path (Split-Path $ApkPath -Parent) 'SHA256SUMS.txt'
        Invoke-WebRequest "$release/SHA256SUMS.txt" -OutFile $hashFile
        $expected = ((Get-Content $hashFile | Where-Object { $_ -match '\s+tvhome-xiaomi\.apk$' }) -split '\s+')[0]
        if (!$expected -or (Get-FileHash $ApkPath -Algorithm SHA256).Hash -ine $expected) { throw 'APK SHA256 mismatch.' }
    }
}
Invoke-Adb @('-s',$TvAddress,'install','-r',(Resolve-Path -LiteralPath $ApkPath).Path) | Out-Host
try {
    if ($SetDefault) {
        $record.ChangedDefault = $true
        $record | ConvertTo-Json | Set-Content -Encoding utf8 $metadata
        if ($DisableStockHome -and 'package:com.mitv.tvhome' -notin $disabled) {
            $record.StockDisabledByInstaller = $true
            $record | ConvertTo-Json | Set-Content -Encoding utf8 $metadata
            Tv @('pm','disable-user','--user','0','com.mitv.tvhome') | Out-Host
            'com.mitv.tvhome' | Set-Content -Encoding ascii (Join-Path $backup 'stock-disabled-by-installer.txt')
        }
        Tv @('cmd','package','set-home-activity',"$package/.MainActivity") | Out-Host
        $winner = Tv @('cmd','package','resolve-activity','--brief','-a','android.intent.action.MAIN','-c','android.intent.category.HOME')
        if (!($winner -match '^dev\.local\.mitvhome/')) { throw 'Firmware did not accept the new default Home.' }
    } elseif ($previousHome -and $previousHome -notmatch '^android/') {
        # Installing a second Home can clear Android's previous default. Keep the user's choice.
        Tv @('cmd','package','set-home-activity',$previousHome) | Out-Host
    }
    Tv @('am','start','-n',"$package/.MainActivity") | Out-Host
    if ($SetDefault) {
        Start-Sleep -Seconds 15
        $winner = Tv @('cmd','package','resolve-activity','--brief','-a','android.intent.action.MAIN','-c','android.intent.category.HOME')
        if (!($winner -match '^dev\.local\.mitvhome/')) { throw 'Firmware reclaimed Home during verification.' }
    }
} catch {
    Write-Warning 'Restoring the previous Home configuration.'
    & (Join-Path $PSScriptRoot 'Restore-Xiaomi.ps1') -BackupDirectory $backup -AdbPath $AdbPath
    throw
}
Write-Host 'Installed. Test remote Home, HDMI, settings, real standby/wake, and a reboot.'
Write-Host "Restore: ./scripts/Restore-Xiaomi.ps1 -BackupDirectory '$backup'"
Write-Host 'After verification, turn ADB debugging off on the TV.'
