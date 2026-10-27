# Test fixture only. Never connects to a device.
$items = @($args | ForEach-Object { [string]$_ })
$line = $items -join ' '
$testDir = $env:TV_TEST_DIRECTORY
if (!$testDir) { throw 'TV_TEST_DIRECTORY must be set by InstallerTest.ps1' }
$line | Add-Content -LiteralPath (Join-Path $testDir 'calls.txt')
if ($items[0] -eq 'connect') { 'connected'; exit 0 }
$operation = ($items | Select-Object -Skip 2) -join ' '
switch -Regex ($operation) {
    '^get-state$' { 'device'; break }
    '^install ' {
        # An APK adding HOME may reset Android's previous default.
        'android/com.android.internal.app.ResolverActivity' | Set-Content (Join-Path $testDir 'home.txt')
        'Success'; break
    }
    '^shell getprop ro.product.model$' { 'MiTV-MFTP0'; break }
    '^shell getprop ro.build.version.sdk$' { '28'; break }
    '^shell getprop$' { '[ro.product.model]: [MiTV-MFTP0]'; break }
    '^shell pm list packages -d$' { Get-Content (Join-Path $testDir 'disabled.txt'); break }
    '^shell settings list ' { 'intelligent_update=0'; break }
    '^shell cmd package resolve-activity ' { Get-Content (Join-Path $testDir 'home.txt'); break }
    '^shell cmd package set-home-activity (.+)$' {
        if (!($env:TV_TEST_RECLAIM -eq '1' -and $Matches[1] -eq 'dev.local.mitvhome/.MainActivity')) {
            $Matches[1] | Set-Content (Join-Path $testDir 'home.txt')
        }
        'Success'; break
    }
    '^shell pm disable-user --user 0 com.mitv.tvhome$' { 'package:com.mitv.tvhome' | Add-Content (Join-Path $testDir 'disabled.txt'); 'disabled-user'; break }
    '^shell pm enable --user 0 com.mitv.tvhome$' {
        @(Get-Content (Join-Path $testDir 'disabled.txt') | Where-Object { $_ -ne 'package:com.mitv.tvhome' }) | Set-Content (Join-Path $testDir 'disabled.txt')
        'enabled'; break
    }
    '^shell am start ' { 'Starting'; break }
    default { throw "Unexpected mock ADB operation: $operation" }
}
exit 0
