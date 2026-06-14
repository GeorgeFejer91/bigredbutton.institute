[CmdletBinding()]
param(
    [string]$Ffprobe = 'ffprobe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$studyRoot = (Resolve-Path (Join-Path $projectRoot '..')).Path
$activity = Join-Path $projectRoot 'app\src\main\java\org\bigredbutton\firststudy\BigRedButtonStudyActivity.kt'
$audio = @(
    [pscustomobject]@{
        condition = 1
        path = Join-Path $studyRoot 'audio-assets\final\first-big-red-button-vr-study-instructions-final.mp3'
        runtimePath = Join-Path $studyRoot 'audio-assets\localized\en_us\aud_0100_condition_1_instructions__en_us.mp3'
        expectedDurationSeconds = 300.773878
        expectedSha256 = 'A3767727AE935BE2455282F52C4765833DA9C04F95EDA81BA0354C7E1CE4F0C6'
    },
    [pscustomobject]@{
        condition = 2
        path = Join-Path $studyRoot 'audio-assets\final\first-big-red-button-vr-study-instructions-second-instructions-5-final.mp3'
        runtimePath = Join-Path $studyRoot 'audio-assets\localized\en_us\aud_0110_condition_2_instructions__en_us.mp3'
        expectedDurationSeconds = 325.590204
        expectedSha256 = 'E52E53640DF5398FEC3DFE328877CBE429EDD3F5D3AB60E5A19FB1C6EBAD48A7'
    }
)

function Get-AudioDurationSeconds {
    param([string]$Path)
    $raw = & $Ffprobe -v error -show_entries format=duration -of default=nokey=1:noprint_wrappers=1 $Path
    if ($LASTEXITCODE -ne 0) {
        throw "ffprobe failed for $Path"
    }
    return [double]::Parse($raw.Trim(), [Globalization.CultureInfo]::InvariantCulture)
}

$results = New-Object System.Collections.Generic.List[object]
foreach ($item in $audio) {
    if (-not (Test-Path $item.path)) {
        throw "Missing condition $($item.condition) audio: $($item.path)"
    }
    if (-not (Test-Path $item.runtimePath)) {
        throw "Missing condition $($item.condition) runtime audio: $($item.runtimePath)"
    }
    $duration = Get-AudioDurationSeconds -Path $item.path
    $delta = [math]::Abs($duration - [double]$item.expectedDurationSeconds)
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.path).Hash
    $runtimeDuration = Get-AudioDurationSeconds -Path $item.runtimePath
    $runtimeDelta = [math]::Abs($runtimeDuration - [double]$item.expectedDurationSeconds)
    $runtimeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.runtimePath).Hash
    $results.Add([pscustomobject]@{
        condition = $item.condition
        path = $item.path
        runtimePath = $item.runtimePath
        durationSeconds = [math]::Round($duration, 6)
        runtimeDurationSeconds = [math]::Round($runtimeDuration, 6)
        expectedDurationSeconds = $item.expectedDurationSeconds
        durationMatchesOriginal = $delta -le 0.05
        runtimeDurationMatchesOriginal = $runtimeDelta -le 0.05
        sha256 = $hash
        runtimeSha256 = $runtimeHash
        expectedSha256 = $item.expectedSha256
        sha256MatchesOriginal = $hash -eq $item.expectedSha256
        runtimeSha256MatchesOriginal = $runtimeHash -eq $item.expectedSha256
    })
}

$activityText = Get-Content -Raw -LiteralPath $activity
$codeChecks = [ordered]@{
    usesMediaPlayer = $activityText.Contains('MediaPlayer()')
    recordsAudioDuration = $activityText.Contains('audioDurationMs = duration')
    completionListenerEndsCondition = $activityText.Contains('setOnCompletionListener { endConditionFromAudio() }')
    logsConditionStart = $activityText.Contains('BRB_CONDITION_START')
    logsConditionEnd = $activityText.Contains('BRB_CONDITION_END')
    buttonVisibleDuringCondition = $activityText.Contains('setButtonVisible(true)')
    buttonHiddenAfterCondition = $activityText.Contains('setButtonVisible(false)')
    usesCentralizedRuntimeAssetLibrary = $activityText.Contains('localized/en_us/aud_0100_condition_1_instructions__en_us.mp3') -and $activityText.Contains('localized/en_us/aud_0110_condition_2_instructions__en_us.mp3')
    avoidsRawAudioResources = -not $activityText.Contains('R.raw.') -and -not $activityText.Contains('resources.openRawResourceFd')
}

$failedAudio = @($results | Where-Object { -not $_.durationMatchesOriginal -or -not $_.sha256MatchesOriginal -or -not $_.runtimeDurationMatchesOriginal -or -not $_.runtimeSha256MatchesOriginal })
$failedCode = @($codeChecks.GetEnumerator() | Where-Object { -not $_.Value })

$outRoot = Join-Path $projectRoot 'artifacts\audio-validation'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$summaryPath = Join-Path $outRoot ("audio-validation-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
$summary = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = if ($failedAudio.Count -eq 0 -and $failedCode.Count -eq 0) { 'pass' } else { 'fail' }
    audio = $results
    codeChecks = $codeChecks
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$results | Format-Table condition,durationSeconds,runtimeDurationSeconds,expectedDurationSeconds,durationMatchesOriginal,runtimeDurationMatchesOriginal,sha256MatchesOriginal,runtimeSha256MatchesOriginal -AutoSize | Out-Host
Write-Host "Audio validation summary: $summaryPath"

if ($summary.status -ne 'pass') {
    throw "Audio validation failed."
}
