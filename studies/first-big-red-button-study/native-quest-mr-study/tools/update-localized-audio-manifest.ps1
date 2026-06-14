[CmdletBinding()]
param(
    [string]$Ffprobe = 'ffprobe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$studyRoot = (Resolve-Path (Join-Path $projectRoot '..')).Path
$localizedRoot = Join-Path $studyRoot 'audio-assets\localized'
$manifestPath = Join-Path $localizedRoot 'manifest.json'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json

function Get-JsonPropertyValue {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Set-JsonPropertyValue {
    param($Object, [string]$Name, $Value)
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    } else {
        $property.Value = $Value
    }
}

function Get-AudioDurationMs {
    param([string]$Path)
    $raw = & $Ffprobe -v error -show_entries format=duration -of default=nokey=1:noprint_wrappers=1 $Path
    if ($LASTEXITCODE -ne 0) {
        throw "ffprobe failed for $Path"
    }
    return [int][math]::Round([double]::Parse($raw.Trim(), [Globalization.CultureInfo]::InvariantCulture) * 1000.0)
}

$updatedAt = (Get-Date).ToString('o')

foreach ($asset in @(Get-JsonPropertyValue $manifest 'assets')) {
    $assetId = Get-JsonPropertyValue $asset 'audioId'
    $durationMatchRequired = [bool](Get-JsonPropertyValue $asset 'durationMatchRequired')
    $locales = Get-JsonPropertyValue $asset 'locales'

    foreach ($localeName in @('en-US', 'ja-JP')) {
        $locale = Get-JsonPropertyValue $locales $localeName
        if ($null -eq $locale) { continue }

        $relativePath = Get-JsonPropertyValue $locale 'path'
        if ([string]::IsNullOrWhiteSpace($relativePath)) { continue }

        $fullPath = Join-Path $localizedRoot $relativePath
        if (-not (Test-Path $fullPath)) { continue }

        Set-JsonPropertyValue $locale 'sha256' ((Get-FileHash -Algorithm SHA256 -LiteralPath $fullPath).Hash)
        $durationMs = Get-AudioDurationMs $fullPath
        Set-JsonPropertyValue $locale 'durationMs' $durationMs

        if ($localeName -eq 'ja-JP') {
            $base = [IO.Path]::GetFileNameWithoutExtension($relativePath)
            if ([string]::IsNullOrWhiteSpace((Get-JsonPropertyValue $locale 'transcriptPath'))) {
                Set-JsonPropertyValue $locale 'transcriptPath' "transcripts/ja_jp/$base.json"
            }
            if ([string]::IsNullOrWhiteSpace((Get-JsonPropertyValue $locale 'backTranslationPath'))) {
                Set-JsonPropertyValue $locale 'backTranslationPath' "transcripts/ja_jp/$base.backtranslation.txt"
            }
            Set-JsonPropertyValue $locale 'observedDurationMs' $durationMs
            Set-JsonPropertyValue $locale 'status' $(if ($durationMatchRequired) { 'mixed' } else { 'generated' })
            Set-JsonPropertyValue $locale 'generatedAt' $updatedAt
            if ($durationMatchRequired) {
                Set-JsonPropertyValue $locale 'mixTimingPolicy' 'pause_removal_then_subsecond_pad_trim'
                Set-JsonPropertyValue $locale 'backgroundStemId' (Get-JsonPropertyValue $asset 'backgroundStemId')
            }
        }
    }
}

foreach ($item in @(Get-JsonPropertyValue $manifest 'shared')) {
    $relativePath = Get-JsonPropertyValue $item 'path'
    if ([string]::IsNullOrWhiteSpace($relativePath)) { continue }

    $fullPath = Join-Path $localizedRoot $relativePath
    if (-not (Test-Path $fullPath)) { continue }

    Set-JsonPropertyValue $item 'sha256' ((Get-FileHash -Algorithm SHA256 -LiteralPath $fullPath).Hash)
    Set-JsonPropertyValue $item 'durationMs' (Get-AudioDurationMs $fullPath)
}

Set-JsonPropertyValue $manifest 'updatedAt' $updatedAt
$manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Write-Host "Updated localized audio manifest: $manifestPath"
