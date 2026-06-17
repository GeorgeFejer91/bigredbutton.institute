[CmdletBinding()]
param(
    [switch]$RequireJapaneseAudio,
    [switch]$RequireGermanAudio,
    [string[]]$RequireLocales = @(),
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

function Get-LocaleLabel {
    param([string]$Locale)
    switch ($Locale) {
        'en-US' { return 'English' }
        'ja-JP' { return 'Japanese' }
        'de-DE' { return 'German' }
        default { return $Locale }
    }
}

$requiredLocaleSet = [ordered]@{}
foreach ($locale in $RequireLocales) {
    if (-not [string]::IsNullOrWhiteSpace($locale)) {
        $requiredLocaleSet[$locale] = $true
    }
}
if ($RequireJapaneseAudio) { $requiredLocaleSet['ja-JP'] = $true }
if ($RequireGermanAudio) { $requiredLocaleSet['de-DE'] = $true }
$requiredLocalizedLocales = @($requiredLocaleSet.Keys)

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$checks = New-Object System.Collections.Generic.List[object]

Add-Check 'localized audio schema' ((Get-JsonPropertyValue $manifest 'schema') -eq 'bigredbutton.localized_audio.v1') (Get-JsonPropertyValue $manifest 'schema')
Add-Check 'localized audio default locale' ((Get-JsonPropertyValue $manifest 'defaultLocale') -eq 'en-US') (Get-JsonPropertyValue $manifest 'defaultLocale')

$declaredLocales = @(Get-JsonPropertyValue $manifest 'locales')
foreach ($locale in @('en-US') + $requiredLocalizedLocales) {
    Add-Check "localized audio manifest declares $locale" ($declaredLocales -contains $locale) (($declaredLocales -join ','))
}

$libraryLayout = Get-JsonPropertyValue $manifest 'libraryLayout'
Add-Check 'localized audio library layout declared' ($null -ne $libraryLayout) ''
if ($null -ne $libraryLayout) {
    Add-Check 'localized audio runtime root centralized' ((Get-JsonPropertyValue $libraryLayout 'runtimeAssetRoot') -eq 'localized') (Get-JsonPropertyValue $libraryLayout 'runtimeAssetRoot')
    Add-Check 'localized audio source root centralized' ((Get-JsonPropertyValue $libraryLayout 'sourceRoot') -eq 'audio-assets/localized') (Get-JsonPropertyValue $libraryLayout 'sourceRoot')
    Add-Check 'localized shared categories declared' ($null -ne (Get-JsonPropertyValue $libraryLayout 'sharedCategories')) ''
}

$ttsPolicy = Get-JsonPropertyValue $manifest 'ttsPolicy'
$localeLanguageCodes = Get-JsonPropertyValue $ttsPolicy 'localeLanguageCodes'
Add-Check 'localized TTS uses eleven_v3' ((Get-JsonPropertyValue $ttsPolicy 'modelId') -eq 'eleven_v3') (Get-JsonPropertyValue $ttsPolicy 'modelId')
Add-Check 'localized TTS voice ID preserved' ((Get-JsonPropertyValue $ttsPolicy 'voiceId') -eq 'IVxgxz5EgbHtWNcgBjOV') (Get-JsonPropertyValue $ttsPolicy 'voiceId')
Add-Check 'localized TTS output format' ((Get-JsonPropertyValue $ttsPolicy 'outputFormat') -eq 'mp3_44100_128') (Get-JsonPropertyValue $ttsPolicy 'outputFormat')
if ($requiredLocalizedLocales -contains 'ja-JP') {
    Add-Check 'Japanese TTS language code' ((Get-JsonPropertyValue $localeLanguageCodes 'ja-JP') -eq 'ja') (Get-JsonPropertyValue $localeLanguageCodes 'ja-JP')
}
if ($requiredLocalizedLocales -contains 'de-DE') {
    Add-Check 'German TTS language code smoke accepted' ((Get-JsonPropertyValue $localeLanguageCodes 'de-DE') -eq 'de') (Get-JsonPropertyValue $localeLanguageCodes 'de-DE')
    $germanSmokeTest = Get-JsonPropertyValue $ttsPolicy 'germanSmokeTest'
    Add-Check 'German TTS smoke test recorded' ((Get-JsonPropertyValue $germanSmokeTest 'acceptedLanguageCode') -eq 'de') (Get-JsonPropertyValue $germanSmokeTest 'acceptedLanguageCode')
}

$backgroundStem = Get-JsonPropertyValue (Get-JsonPropertyValue $manifest 'stems') 'backgroundMusic'
$backgroundPath = Join-Path $localizedRoot (Get-JsonPropertyValue $backgroundStem 'path')
Add-Check 'background music stem exists' (Test-Path $backgroundPath) $backgroundPath
if (Test-Path $backgroundPath) {
    $backgroundHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $backgroundPath).Hash
    $backgroundDuration = Get-AudioDurationMs $backgroundPath
    Add-Check 'background music stem hash preserved' ($backgroundHash -eq (Get-JsonPropertyValue $backgroundStem 'sha256')) $backgroundHash
    Add-Check 'background music stem duration preserved' ($backgroundDuration -eq [int](Get-JsonPropertyValue $backgroundStem 'durationMs')) "observed=$backgroundDuration expected=$([int](Get-JsonPropertyValue $backgroundStem 'durationMs'))"
}

function Test-LocaleAsset {
    param(
        $Asset,
        [string]$AudioId,
        [string]$Locale,
        $LocaleEntry,
        [bool]$RequireScriptArtifacts
    )

    $label = Get-LocaleLabel $Locale
    Add-Check "$AudioId has $label locale" ($null -ne $LocaleEntry) ''
    if ($null -eq $LocaleEntry) { return }

    $relativePath = Get-JsonPropertyValue $LocaleEntry 'path'
    $audioPath = Join-Path $localizedRoot $relativePath
    Add-Check "$AudioId $label file exists" (Test-Path $audioPath) $audioPath
    if (Test-Path $audioPath) {
        $duration = Get-AudioDurationMs $audioPath
        $manifestHash = Get-JsonPropertyValue $LocaleEntry 'sha256'
        if (-not [string]::IsNullOrWhiteSpace($manifestHash)) {
            $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $audioPath).Hash
            Add-Check "$AudioId $label hash matches manifest" ($hash -eq $manifestHash) $hash
        }
        $manifestDuration = Get-JsonPropertyValue $LocaleEntry 'durationMs'
        if ($null -ne $manifestDuration) {
            Add-Check "$AudioId $label duration matches manifest" ($duration -eq [int]$manifestDuration) "observed=$duration manifest=$([int]$manifestDuration)"
        }
        $durationMatchRequired = [bool](Get-JsonPropertyValue $Asset 'durationMatchRequired')
        if ($durationMatchRequired) {
            $targetDuration = [int](Get-JsonPropertyValue $Asset 'targetDurationMs')
            Add-Check "$AudioId $label duration matches exact target" ($duration -eq $targetDuration) "observed=$duration target=$targetDuration"
        }
    }

    $status = Get-JsonPropertyValue $LocaleEntry 'status'
    if ($Locale -ne 'en-US') {
        Add-Check "$AudioId $label generation status complete" (@('generated', 'mixed') -contains $status) $status
    }

    if ($RequireScriptArtifacts) {
        $scriptPath = Get-JsonPropertyValue $LocaleEntry 'scriptPath'
        Add-Check "$AudioId $label script exists" (Test-Path (Join-Path $localizedRoot $scriptPath)) $scriptPath
        $transcriptPath = Get-JsonPropertyValue $LocaleEntry 'transcriptPath'
        Add-Check "$AudioId $label transcript exists" (Test-Path (Join-Path $localizedRoot $transcriptPath)) $transcriptPath
        $backTranslationPath = Get-JsonPropertyValue $LocaleEntry 'backTranslationPath'
        Add-Check "$AudioId $label back-translation exists" (Test-Path (Join-Path $localizedRoot $backTranslationPath)) $backTranslationPath
    }
}

$assets = @(Get-JsonPropertyValue $manifest 'assets')
Add-Check 'participant-facing speech assets listed' ($assets.Count -ge 11) "count=$($assets.Count)"

foreach ($asset in $assets) {
    $audioId = Get-JsonPropertyValue $asset 'audioId'
    $participantFacing = [bool](Get-JsonPropertyValue $asset 'participantFacing')
    $locales = Get-JsonPropertyValue $asset 'locales'
    Test-LocaleAsset -Asset $asset -AudioId $audioId -Locale 'en-US' -LocaleEntry (Get-JsonPropertyValue $locales 'en-US') -RequireScriptArtifacts:$false
    if ($participantFacing) {
        foreach ($locale in $requiredLocalizedLocales) {
            Test-LocaleAsset -Asset $asset -AudioId $audioId -Locale $locale -LocaleEntry (Get-JsonPropertyValue $locales $locale) -RequireScriptArtifacts:$true
        }
    }
}

$shared = @(Get-JsonPropertyValue $manifest 'shared')
foreach ($item in $shared) {
    $audioId = Get-JsonPropertyValue $item 'audioId'
    $relativePath = Get-JsonPropertyValue $item 'path'
    $path = Join-Path $localizedRoot $relativePath
    Add-Check "$audioId shared file is categorized" ($relativePath -match '^shared/[^/]+/[^/]+$') $relativePath
    Add-Check "$audioId shared file exists" (Test-Path $path) $path
    if (Test-Path $path) {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
        $duration = Get-AudioDurationMs $path
        Add-Check "$audioId shared hash matches manifest" ($hash -eq (Get-JsonPropertyValue $item 'sha256')) $hash
        Add-Check "$audioId shared duration matches manifest" ($duration -eq [int](Get-JsonPropertyValue $item 'durationMs')) "observed=$duration expected=$([int](Get-JsonPropertyValue $item 'durationMs'))"
    }
}

$uncategorizedSharedFiles = @(Get-ChildItem -LiteralPath (Join-Path $localizedRoot 'shared') -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.mp3', '.wav', '.ogg') })
Add-Check 'localized shared root has no loose runtime audio' ($uncategorizedSharedFiles.Count -eq 0) (($uncategorizedSharedFiles | ForEach-Object { $_.Name }) -join ',')

$failed = @($checks | Where-Object { -not $_.pass })
$outRoot = Join-Path $projectRoot 'artifacts\localized-audio-validation'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$summaryPath = Join-Path $outRoot ("localized-audio-validation-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
[pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
    requireJapaneseAudio = [bool]$RequireJapaneseAudio
    requireGermanAudio = [bool]$RequireGermanAudio
    requiredLocales = $requiredLocalizedLocales
    manifest = $manifestPath
    checks = $checks
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$checks | Format-Table name,pass,detail -AutoSize | Out-Host
Write-Host "Localized audio validation summary: $summaryPath"

if ($failed.Count -gt 0) {
    throw "Localized audio validation failed with $($failed.Count) failing checks."
}
