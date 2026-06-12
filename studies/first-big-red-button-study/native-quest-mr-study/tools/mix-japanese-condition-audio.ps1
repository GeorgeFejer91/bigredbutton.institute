[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('aud_0100', 'aud_0110')]
    [string]$AudioId,
    [Parameter(Mandatory = $true)]
    [string]$SpeechPath,
    [double]$PauseKeepSeconds = -1.0,
    [int]$Mp3DurationCompensationMs = 52,
    [string]$Ffmpeg = 'ffmpeg',
    [string]$Ffprobe = 'ffprobe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$studyRoot = (Resolve-Path (Join-Path $projectRoot '..')).Path
$localizedRoot = Join-Path $studyRoot 'audio-assets\localized'
$manifest = Get-Content -Raw -LiteralPath (Join-Path $localizedRoot 'manifest.json') | ConvertFrom-Json

function Get-JsonPropertyValue {
    param($Object, [string]$Name)
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-DurationSeconds {
    param([string]$Path)
    $raw = & $Ffprobe -v error -show_entries format=duration -of default=nokey=1:noprint_wrappers=1 $Path
    if ($LASTEXITCODE -ne 0) {
        throw "ffprobe failed for $Path"
    }
    return [double]::Parse($raw.Trim(), [Globalization.CultureInfo]::InvariantCulture)
}

if (-not (Test-Path $SpeechPath)) {
    throw "Missing Japanese speech input: $SpeechPath"
}

$asset = @(Get-JsonPropertyValue $manifest 'assets') | Where-Object { (Get-JsonPropertyValue $_ 'audioId') -eq $AudioId } | Select-Object -First 1
if ($null -eq $asset) {
    throw "AudioId not found in manifest: $AudioId"
}
$ja = Get-JsonPropertyValue (Get-JsonPropertyValue $asset 'locales') 'ja-JP'
$targetMs = [int](Get-JsonPropertyValue $asset 'targetDurationMs')
$targetSeconds = $targetMs / 1000.0
$contentTargetMs = [math]::Max(1, $targetMs - $Mp3DurationCompensationMs)
$contentTargetSeconds = $contentTargetMs / 1000.0
$music = Join-Path $localizedRoot (Get-JsonPropertyValue (Get-JsonPropertyValue (Get-JsonPropertyValue $manifest 'stems') 'backgroundMusic') 'path')
if (-not (Test-Path $music)) {
    throw "Missing localized background music stem: $music"
}

$output = Join-Path $localizedRoot (Get-JsonPropertyValue $ja 'path')
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null

$tmpRoot = Join-Path $projectRoot ('artifacts\localized-audio-mix\' + $AudioId + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
$processedSpeech = Join-Path $tmpRoot 'pause-adjusted-speech.wav'
$timedSpeech = Join-Path $tmpRoot 'timed-speech.wav'
$speechDuration = Get-DurationSeconds $SpeechPath

if ($PauseKeepSeconds -lt 0.0) {
    $PauseKeepSeconds = if ($AudioId -eq 'aud_0100') { 0.44 } else { 0.675 }
}

if ($speechDuration -gt $contentTargetSeconds) {
    & $Ffmpeg -y -i $SpeechPath -af "silenceremove=start_periods=1:start_duration=0.05:start_threshold=-50dB:start_silence=0.05:stop_periods=-1:stop_duration=0.22:stop_threshold=-50dB:stop_silence=$PauseKeepSeconds" -ar 44100 -ac 2 $processedSpeech
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to remove superfluous pauses for $AudioId"
    }
    $speechForTiming = $processedSpeech
} else {
    $speechForTiming = $SpeechPath
}

$processedDuration = Get-DurationSeconds $speechForTiming
if ($processedDuration -lt $contentTargetSeconds) {
    $padSeconds = [math]::Max(0.0, $contentTargetSeconds - $processedDuration)
    & $Ffmpeg -y -i $speechForTiming -af "apad=pad_dur=$padSeconds,atrim=0:$contentTargetSeconds" -ar 44100 -ac 2 $timedSpeech
} else {
    & $Ffmpeg -y -i $speechForTiming -af "atrim=0:$contentTargetSeconds" -ar 44100 -ac 2 $timedSpeech
}
if ($LASTEXITCODE -ne 0) {
    throw "Failed to time-align Japanese speech for $AudioId"
}

& $Ffmpeg -y `
    -stream_loop -1 -i $music `
    -i $timedSpeech `
    -filter_complex "[0:a]atrim=0:$contentTargetSeconds,asetpts=PTS-STARTPTS,volume=0.38[music];[1:a]atrim=0:$contentTargetSeconds,asetpts=PTS-STARTPTS,volume=1.0[speech];[music][speech]amix=inputs=2:duration=first:dropout_transition=0,atrim=0:$contentTargetSeconds" `
    -codec:a libmp3lame -b:a 128k -ar 44100 $output
if ($LASTEXITCODE -ne 0) {
    throw "Failed to mix Japanese condition audio for $AudioId"
}

$observedMs = [int][math]::Round((Get-DurationSeconds $output) * 1000.0)
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $output).Hash
Write-Host "Mixed Japanese condition audio for $AudioId"
Write-Host "Output: $output"
Write-Host "Target duration ms: $targetMs"
Write-Host "Content target ms: $contentTargetMs"
Write-Host "Observed duration ms: $observedMs"
Write-Host "Original speech seconds: $speechDuration"
Write-Host "Pause keep seconds: $PauseKeepSeconds"
Write-Host "Processed speech seconds: $processedDuration"
Write-Host "SHA256: $hash"
if ($observedMs -ne $targetMs) {
    throw "Mixed audio duration mismatch for $AudioId`: observed=$observedMs target=$targetMs"
}
