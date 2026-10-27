[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$BackupDirectory,
    [string]$TvAddress,
    [string]$AdbPath = 'adb'
)
$ErrorActionPreference = 'Stop'
$record = Get-Content -LiteralPath (Join-Path $BackupDirectory 'restore.json') -Raw | ConvertFrom-Json
if (!$TvAddress) { $TvAddress = $record.TvAddress }
if ($TvAddress -notmatch '^[a-zA-Z0-9_.:-]+$') { throw 'Invalid TV address.' }
function Run-Adb([string[]]$Arguments) {
    & $AdbPath @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'ADB command failed. Re-enable debugging and authorize this computer.' }
}
Run-Adb @('connect',$TvAddress)
if ($record.StockDisabledByInstaller) {
    Run-Adb @('-s',$TvAddress,'shell','pm','enable','--user','0','com.mitv.tvhome')
}
if ($record.Home -match '^[a-zA-Z0-9_.]+/[a-zA-Z0-9_.$]+$' -and $record.Home -notmatch '^android/') {
    Run-Adb @('-s',$TvAddress,'shell','cmd','package','set-home-activity',$record.Home)
    Run-Adb @('-s',$TvAddress,'shell','am','start','-n',$record.Home)
} else {
    Write-Warning 'No single previous Home was saved. Choose a default Home in TV settings.'
}
Write-Host 'Restored only Home changes made by this installer. No app was uninstalled and no saved settings were imported.'
