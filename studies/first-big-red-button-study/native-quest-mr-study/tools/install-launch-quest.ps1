[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$ApkPath = '',
    [string]$AdbPath = 'adb'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk'
}
$ApkPath = (Resolve-Path $ApkPath).Path
$package = 'org.bigredbutton.firststudy'
$activity = 'org.bigredbutton.firststudy/.BigRedButtonStudyActivity'

& $AdbPath -s $Serial devices -l | Out-Host
& $AdbPath -s $Serial install -r -d -g $ApkPath
if ($LASTEXITCODE -ne 0) {
    throw "adb install failed with exit code $LASTEXITCODE"
}

& $AdbPath -s $Serial shell am start -n $activity
if ($LASTEXITCODE -ne 0) {
    throw "adb launch failed with exit code $LASTEXITCODE"
}

& $AdbPath -s $Serial shell dumpsys window | Select-String -Pattern 'mCurrentFocus|mFocusedApp' | Out-Host
Write-Host "Launched $package from $ApkPath"
