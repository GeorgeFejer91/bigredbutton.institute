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
        expectedDurationSeconds = 300.773878
        expectedSha256 = 'A3767727AE935BE2455282F52C4765833DA9C04F95EDA81BA0354C7E1CE4F0C6'
    },
    [pscustomobject]@{
        condition = 2
        path = Join-Path $studyRoot 'audio-assets\final\first-big-red-button-vr-study-instructions-second-instructions-5-final.mp3'
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
    $duration = Get-AudioDurationSeconds -Path $item.path
    $delta = [math]::Abs($duration - [double]$item.expectedDurationSeconds)
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.path).Hash
    $results.Add([pscustomobject]@{
        condition = $item.condition
        path = $item.path
        durationSeconds = [math]::Round($duration, 6)
        expectedDurationSeconds = $item.expectedDurationSeconds
        durationMatchesOriginal = $delta -le 0.05
        sha256 = $hash
        expectedSha256 = $item.expectedSha256
        sha256MatchesOriginal = $hash -eq $item.expectedSha256
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
    usesOriginalGeneratedAssetStaging = $activityText.Contains('first-big-red-button-vr-study-instructions-final.mp3') -and $activityText.Contains('first-big-red-button-vr-study-instructions-second-instructions-5-final.mp3')
}

$failedAudio = @($results | Where-Object { -not $_.durationMatchesOriginal -or -not $_.sha256MatchesOriginal })
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

$results | Format-Table condition,durationSeconds,expectedDurationSeconds,durationMatchesOriginal,sha256MatchesOriginal -AutoSize | Out-Host
Write-Host "Audio validation summary: $summaryPath"

if ($summary.status -ne 'pass') {
    throw "Audio validation failed."
}
