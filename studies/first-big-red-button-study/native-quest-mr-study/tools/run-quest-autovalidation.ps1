[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$AdbPath = 'adb',
    [string]$ApkPath = '',
    [ValidateSet('', 'en-US', 'ja-JP')]
    [string]$Language = '',
    [int]$WaitSeconds = 760,
    [switch]$SkipInstall
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
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $projectRoot "artifacts\qav\$runId"
$exportPullDir = Join-Path $outDir 'x'
$pulledExportRoot = Join-Path $exportPullDir 'e'
$deviceExportDir = "/sdcard/Android/data/$package/files/BigRedButtonFirstStudyExports"
$remoteScreenshot = '/sdcard/Download/brb_firststudy_autovalidation.png'

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Invoke-Adb {
    & $AdbPath -s $Serial @args
}

function Write-TextArtifact {
    param([string]$Name, [string[]]$Lines)
    $path = Join-Path $outDir $Name
    $Lines | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

$model = (Invoke-Adb shell getprop ro.product.model).Trim()
$android = (Invoke-Adb shell getprop ro.build.version.release).Trim()
Write-Host "Quest autorun validation target: serial=$Serial model=$model android=$android"

if (-not $SkipInstall) {
    Write-Host "Installing $ApkPath"
    Invoke-Adb install -r -d -g $ApkPath | Tee-Object -FilePath (Join-Path $outDir 'install.txt') | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "adb install failed with exit code $LASTEXITCODE"
    }
}

Write-Host "Clearing previous app exports and logcat"
Invoke-Adb shell rm -rf $deviceExportDir | Out-Null
Invoke-Adb logcat -c

Write-Host "Launching autorun mode. This waits for the real MP3 playback durations."
$languageArgs = @()
if (-not [string]::IsNullOrWhiteSpace($Language)) {
    $languageArgs = @('--es', 'brb.studyLanguage', $Language)
}
Invoke-Adb shell am start -n $activity --ez brb.autoValidation true @languageArgs | Tee-Object -FilePath (Join-Path $outDir 'launch.txt') | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "adb launch failed with exit code $LASTEXITCODE"
}

$deadline = (Get-Date).AddSeconds($WaitSeconds)
$completed = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 10
    $markers = Invoke-Adb logcat -d -v time | Select-String -Pattern 'BRB_VALIDATION_AUTORUN_COMPLETE|BRB_EXPORT_COMPLETE|FATAL EXCEPTION|E/AndroidRuntime'
    if ($markers | Select-String -Pattern 'FATAL EXCEPTION|E/AndroidRuntime') {
        $markers | Set-Content -LiteralPath (Join-Path $outDir 'failure-markers.txt') -Encoding UTF8
        throw "Fatal runtime marker detected during Quest autorun validation."
    }
    if ($markers | Select-String -Pattern 'BRB_VALIDATION_AUTORUN_COMPLETE') {
        $completed = $true
        break
    }
    $elapsed = [int]($WaitSeconds - [math]::Max(0, ($deadline - (Get-Date)).TotalSeconds))
    Write-Host "Waiting for autorun export... elapsed ${elapsed}s"
}

Invoke-Adb logcat -d -v time | Select-String -Pattern 'BigRedButtonStudy|BRB_|PTApiClients|MIXEDREALITY|OpenXR|FATAL EXCEPTION|E/AndroidRuntime' | Set-Content -LiteralPath (Join-Path $outDir 'logcat-filtered.txt') -Encoding UTF8
Invoke-Adb shell dumpsys activity activities | Select-String -Pattern 'bigredbutton|mCurrentFocus|mFocusedApp|ResumedActivity|topResumedActivity' | Set-Content -LiteralPath (Join-Path $outDir 'foreground.txt') -Encoding UTF8

Invoke-Adb shell screencap -p $remoteScreenshot | Out-Null
Invoke-Adb pull $remoteScreenshot (Join-Path $outDir 'final-screenshot.png') | Tee-Object -FilePath (Join-Path $outDir 'screenshot-pull.txt') | Out-Host
Invoke-Adb shell rm $remoteScreenshot | Out-Null

if (-not $completed) {
    throw "Quest autorun validation timed out after $WaitSeconds seconds. See $outDir"
}

New-Item -ItemType Directory -Force -Path $pulledExportRoot | Out-Null
$exportPullLog = Join-Path $outDir 'export-pull.txt'
$deviceFilesRaw = Invoke-Adb shell ls -1 $deviceExportDir
if ($LASTEXITCODE -ne 0) {
    throw "adb export listing failed with exit code $LASTEXITCODE"
}
$deviceFiles = @(
    $deviceFilesRaw |
        ForEach-Object { "$_".Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch '^total\s+' }
)
if ($deviceFiles.Count -eq 0) {
    throw "No export files found at $deviceExportDir"
}

$shortPullRoot = Join-Path $env:TEMP ("brb-autovalidation-pull-" + $runId)
if (Test-Path $shortPullRoot) {
    Remove-Item -Recurse -Force -LiteralPath $shortPullRoot
}
New-Item -ItemType Directory -Force -Path $shortPullRoot | Out-Null
try {
    $fileIndex = 0
    foreach ($deviceFile in $deviceFiles) {
        $fileIndex += 1
        $remoteFile = "$deviceExportDir/$deviceFile"
        $shortLocalFile = Join-Path $shortPullRoot ("export-$fileIndex.tmp")
        $localFile = Join-Path $pulledExportRoot $deviceFile
        Invoke-Adb pull $remoteFile $shortLocalFile | Tee-Object -Append -FilePath $exportPullLog | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb export pull failed for $remoteFile with exit code $LASTEXITCODE"
        }
        Move-Item -LiteralPath $shortLocalFile -Destination $localFile -Force
    }
} finally {
    if (Test-Path $shortPullRoot) {
        Remove-Item -Recurse -Force -LiteralPath $shortPullRoot
    }
}
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate-export-schema.ps1') -ExportDir $pulledExportRoot | Tee-Object -FilePath (Join-Path $outDir 'export-schema-validation.txt') | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "export schema validation failed with exit code $LASTEXITCODE"
}

$jsonFile = Get-ChildItem -LiteralPath $pulledExportRoot -Filter 'brb_first_study_*.json' | Where-Object { $_.Name -notlike '*summary*' -and $_.Name -notlike '*press_events*' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$exportJson = Get-Content -Raw -LiteralPath $jsonFile.FullName | ConvertFrom-Json
$conditions = @($exportJson.conditions)
$condition1 = $conditions | Where-Object { $_.conditionNumber -eq 1 } | Select-Object -First 1
$condition2 = $conditions | Where-Object { $_.conditionNumber -eq 2 } | Select-Object -First 1

$checks = [ordered]@{
    completed = $completed
    conditionCount = $conditions.Count
    condition1PressCount = $condition1.buttonPressCount
    condition2PressCount = $condition2.buttonPressCount
    condition1AudioDurationMs = $condition1.audioDurationMs
    condition2AudioDurationMs = $condition2.audioDurationMs
    condition1ElapsedMs = $condition1.elapsedMs
    condition2ElapsedMs = $condition2.elapsedMs
    selectedLanguageCode = $exportJson.localization.selectedLanguageCode
    selectedLanguageLabel = $exportJson.localization.selectedLanguageLabel
    condition1AudioLocaleCode = $condition1.audioLocaleCode
    condition2AudioLocaleCode = $condition2.audioLocaleCode
    condition1LostOpportunity = $condition1.lostOpportunity.score0To100
    condition2LostOpportunity = $condition2.lostOpportunity.score0To100
    json = $jsonFile.FullName
}

if ($checks.conditionCount -ne 2) { throw "Expected 2 conditions, found $($checks.conditionCount)" }
if ($checks.condition1PressCount -lt 1) { throw "Expected at least one condition 1 validation press, found $($checks.condition1PressCount)" }
if ($checks.condition2PressCount -lt 1) { throw "Expected at least one condition 2 validation press, found $($checks.condition2PressCount)" }
if ([math]::Abs([int]$checks.condition1AudioDurationMs - 300774) -gt 500) { throw "Condition 1 audio duration mismatch: $($checks.condition1AudioDurationMs)" }
if ([math]::Abs([int]$checks.condition2AudioDurationMs - 325590) -gt 500) { throw "Condition 2 audio duration mismatch: $($checks.condition2AudioDurationMs)" }
if (-not [string]::IsNullOrWhiteSpace($Language)) {
    if ($checks.selectedLanguageCode -ne $Language) { throw "Expected selected language $Language, found $($checks.selectedLanguageCode)" }
    $expectedAudioLocale = $Language
    if ($checks.condition1AudioLocaleCode -ne $expectedAudioLocale) { throw "Condition 1 audio locale mismatch: $($checks.condition1AudioLocaleCode)" }
    if ($checks.condition2AudioLocaleCode -ne $expectedAudioLocale) { throw "Condition 2 audio locale mismatch: $($checks.condition2AudioLocaleCode)" }
}

$summary = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = 'pass'
    serial = $Serial
    model = $model
    android = $android
    package = $package
    apk = $ApkPath
    language = $Language
    evidenceDir = $outDir
    pulledExportRoot = $pulledExportRoot
    checks = $checks
    note = 'Autorun uses real MediaPlayer completion for both study MP3s. Presses are app-triggered validation events, not proof of physical controller or hand input.'
}
$summaryPath = Join-Path $outDir 'quest-autovalidation-summary.json'
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Host "PASS Quest autorun validation"
Write-Host "Summary: $summaryPath"
