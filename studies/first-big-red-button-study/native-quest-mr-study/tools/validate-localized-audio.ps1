[CmdletBinding()]
param(
    [switch]$RequireJapaneseAudio,
    [string]$Ffprobe = 'ffprobe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$studyRoot = (Resolve-Path (Join-Path $projectRoot '..')).Path
$localizedRoot = Join-Path $studyRoot 'audio-assets\localized'
$manifestPath = Join-Path $localizedRoot 'manifest.json'

if (-not (Test-Path $manifestPath)) {
    throw "Missing localized audio manifest: $manifestPath"
}

function Get-JsonPropertyValue {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-AudioDurationMs {
    param([string]$Path)
    $raw = & $Ffprobe -v error -show_entries format=duration -of default=nokey=1:noprint_wrappers=1 $Path
    if ($LASTEXITCODE -ne 0) {
        throw "ffprobe failed for $Path"
    }
    return [int][math]::Round([double]::Parse($raw.Trim(), [Globalization.CultureInfo]::InvariantCulture) * 1000.0)
}

function Add-Check {
    param(
        [string]$Name,
        [bool]$Pass,
        [string]$Detail = ''
    )
    $script:checks.Add([pscustomobject]@{
        name = $Name
        pass = $Pass
        detail = $Detail
    })
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$checks = New-Object System.Collections.Generic.List[object]

Add-Check 'localized audio schema' ((Get-JsonPropertyValue $manifest 'schema') -eq 'bigredbutton.localized_audio.v1') (Get-JsonPropertyValue $manifest 'schema')
Add-Check 'localized audio default locale' ((Get-JsonPropertyValue $manifest 'defaultLocale') -eq 'en-US') (Get-JsonPropertyValue $manifest 'defaultLocale')

$ttsPolicy = Get-JsonPropertyValue $manifest 'ttsPolicy'
Add-Check 'Japanese TTS uses eleven_v3' ((Get-JsonPropertyValue $ttsPolicy 'modelId') -eq 'eleven_v3') (Get-JsonPropertyValue $ttsPolicy 'modelId')
Add-Check 'Japanese TTS voice ID preserved' ((Get-JsonPropertyValue $ttsPolicy 'voiceId') -eq 'IVxgxz5EgbHtWNcgBjOV') (Get-JsonPropertyValue $ttsPolicy 'voiceId')
Add-Check 'Japanese TTS language code' ((Get-JsonPropertyValue $ttsPolicy 'languageCode') -eq 'ja') (Get-JsonPropertyValue $ttsPolicy 'languageCode')
Add-Check 'Japanese TTS output format' ((Get-JsonPropertyValue $ttsPolicy 'outputFormat') -eq 'mp3_44100_128') (Get-JsonPropertyValue $ttsPolicy 'outputFormat')

$backgroundStem = Get-JsonPropertyValue (Get-JsonPropertyValue $manifest 'stems') 'backgroundMusic'
$backgroundPath = Join-Path $localizedRoot (Get-JsonPropertyValue $backgroundStem 'path')
Add-Check 'background music stem exists' (Test-Path $backgroundPath) $backgroundPath
if (Test-Path $backgroundPath) {
    $backgroundHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $backgroundPath).Hash
    $backgroundDuration = Get-AudioDurationMs $backgroundPath
    Add-Check 'background music stem hash preserved' ($backgroundHash -eq (Get-JsonPropertyValue $backgroundStem 'sha256')) $backgroundHash
    Add-Check 'background music stem duration preserved' ($backgroundDuration -eq [int](Get-JsonPropertyValue $backgroundStem 'durationMs')) "observed=$backgroundDuration expected=$([int](Get-JsonPropertyValue $backgroundStem 'durationMs'))"
}

$assets = @(Get-JsonPropertyValue $manifest 'assets')
Add-Check 'participant-facing speech assets listed' ($assets.Count -ge 11) "count=$($assets.Count)"

foreach ($asset in $assets) {
    $audioId = Get-JsonPropertyValue $asset 'audioId'
    $participantFacing = [bool](Get-JsonPropertyValue $asset 'participantFacing')
    $locales = Get-JsonPropertyValue $asset 'locales'
    $en = Get-JsonPropertyValue $locales 'en-US'
    $ja = Get-JsonPropertyValue $locales 'ja-JP'
    Add-Check "$audioId has English locale" ($null -ne $en) ''
    Add-Check "$audioId has Japanese locale" ($null -ne $ja) ''
    if ($null -ne $en) {
        $enPath = Join-Path $localizedRoot (Get-JsonPropertyValue $en 'path')
        Add-Check "$audioId English file exists" (Test-Path $enPath) $enPath
        if (Test-Path $enPath) {
            $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $enPath).Hash
            $duration = Get-AudioDurationMs $enPath
            Add-Check "$audioId English hash matches manifest" ($hash -eq (Get-JsonPropertyValue $en 'sha256')) $hash
            Add-Check "$audioId English duration matches manifest" ($duration -eq [int](Get-JsonPropertyValue $en 'durationMs')) "observed=$duration expected=$([int](Get-JsonPropertyValue $en 'durationMs'))"
        }
    }
    if ($participantFacing -and $RequireJapaneseAudio) {
        $jaPath = Join-Path $localizedRoot (Get-JsonPropertyValue $ja 'path')
        Add-Check "$audioId Japanese file exists" (Test-Path $jaPath) $jaPath
        if (Test-Path $jaPath) {
            $duration = Get-AudioDurationMs $jaPath
            $manifestHash = Get-JsonPropertyValue $ja 'sha256'
            if (-not [string]::IsNullOrWhiteSpace($manifestHash)) {
                $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $jaPath).Hash
                Add-Check "$audioId Japanese hash matches manifest" ($hash -eq $manifestHash) $hash
            }
            $manifestDuration = Get-JsonPropertyValue $ja 'durationMs'
            if ($null -ne $manifestDuration) {
                Add-Check "$audioId Japanese duration matches manifest" ($duration -eq [int]$manifestDuration) "observed=$duration manifest=$([int]$manifestDuration)"
            }
            $durationMatchRequired = [bool](Get-JsonPropertyValue $asset 'durationMatchRequired')
            if ($durationMatchRequired) {
                $targetDuration = [int](Get-JsonPropertyValue $asset 'targetDurationMs')
                Add-Check "$audioId Japanese duration matches exact target" ($duration -eq $targetDuration) "observed=$duration target=$targetDuration"
            }
            $status = Get-JsonPropertyValue $ja 'status'
            Add-Check "$audioId Japanese generation status complete" (@('generated', 'mixed') -contains $status) $status
        }
        $scriptPath = Join-Path $localizedRoot (Get-JsonPropertyValue $ja 'scriptPath')
        Add-Check "$audioId Japanese script exists" (Test-Path $scriptPath) $scriptPath
        $transcriptPath = Get-JsonPropertyValue $ja 'transcriptPath'
        if (-not [string]::IsNullOrWhiteSpace($transcriptPath)) {
            $fullTranscriptPath = Join-Path $localizedRoot $transcriptPath
            Add-Check "$audioId Japanese transcript exists" (Test-Path $fullTranscriptPath) $fullTranscriptPath
        }
        $backTranslationPath = Get-JsonPropertyValue $ja 'backTranslationPath'
        if (-not [string]::IsNullOrWhiteSpace($backTranslationPath)) {
            $fullBackTranslationPath = Join-Path $localizedRoot $backTranslationPath
            Add-Check "$audioId Japanese back-translation exists" (Test-Path $fullBackTranslationPath) $fullBackTranslationPath
        }
    }
}

$shared = @(Get-JsonPropertyValue $manifest 'shared')
foreach ($item in $shared) {
    $audioId = Get-JsonPropertyValue $item 'audioId'
    $path = Join-Path $localizedRoot (Get-JsonPropertyValue $item 'path')
    Add-Check "$audioId shared file exists" (Test-Path $path) $path
    if (Test-Path $path) {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
        Add-Check "$audioId shared hash matches manifest" ($hash -eq (Get-JsonPropertyValue $item 'sha256')) $hash
    }
}

$failed = @($checks | Where-Object { -not $_.pass })
$outRoot = Join-Path $projectRoot 'artifacts\localized-audio-validation'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$summaryPath = Join-Path $outRoot ("localized-audio-validation-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
[pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
    requireJapaneseAudio = [bool]$RequireJapaneseAudio
    manifest = $manifestPath
    checks = $checks
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$checks | Format-Table name,pass,detail -AutoSize | Out-Host
Write-Host "Localized audio validation summary: $summaryPath"

if ($failed.Count -gt 0) {
    throw "Localized audio validation failed with $($failed.Count) failing checks."
}
