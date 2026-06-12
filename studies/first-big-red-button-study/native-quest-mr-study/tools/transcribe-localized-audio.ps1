[CmdletBinding()]
param(
    [ValidateSet('en_us', 'ja_jp')]
    [string]$Locale = 'en_us',
    [string]$AudioId = '',
    [string]$Whisper = 'whisper',
    [string]$Model = 'small',
    [string]$Language = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$env:PYTHONIOENCODING = 'utf-8'

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

$localeTag = if ($Locale -eq 'en_us') { 'en-US' } else { 'ja-JP' }
$languageArg = if (-not [string]::IsNullOrWhiteSpace($Language)) { $Language } elseif ($Locale -eq 'ja_jp') { 'Japanese' } else { 'English' }
$transcriptDir = Join-Path $localizedRoot "transcripts\$Locale"
New-Item -ItemType Directory -Force -Path $transcriptDir | Out-Null

$assets = @(Get-JsonPropertyValue $manifest 'assets')
if (-not [string]::IsNullOrWhiteSpace($AudioId)) {
    $assets = @($assets | Where-Object { (Get-JsonPropertyValue $_ 'audioId') -eq $AudioId })
}
if ($assets.Count -eq 0) {
    throw "No localized audio manifest rows matched AudioId '$AudioId'."
}

foreach ($asset in $assets) {
    $id = Get-JsonPropertyValue $asset 'audioId'
    $localeEntry = Get-JsonPropertyValue (Get-JsonPropertyValue $asset 'locales') $localeTag
    if ($null -eq $localeEntry) {
        Write-Warning "Skipping $id because locale $localeTag is not present."
        continue
    }
    $relativePath = Get-JsonPropertyValue $localeEntry 'path'
    $audioPath = Join-Path $localizedRoot $relativePath
    if (-not (Test-Path $audioPath)) {
        Write-Warning "Skipping $id because audio is missing: $audioPath"
        continue
    }
    $base = [IO.Path]::GetFileNameWithoutExtension($relativePath)
    $workDir = Join-Path $projectRoot "artifacts\localized-transcripts\$Locale\$base"
    New-Item -ItemType Directory -Force -Path $workDir | Out-Null
    & $Whisper $audioPath --model $Model --language $languageArg --output_format json --output_dir $workDir
    if ($LASTEXITCODE -ne 0) {
        throw "Whisper failed for $audioPath"
    }
    $generated = Join-Path $workDir "$base.json"
    if (-not (Test-Path $generated)) {
        $generated = Get-ChildItem -Path $workDir -Filter '*.json' | Select-Object -First 1 -ExpandProperty FullName
    }
    $manifestTranscriptPath = Get-JsonPropertyValue $localeEntry 'transcriptPath'
    if (-not [string]::IsNullOrWhiteSpace($manifestTranscriptPath)) {
        $dest = Join-Path $localizedRoot $manifestTranscriptPath
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
    } else {
        $dest = Join-Path $transcriptDir "$base.json"
    }
    Copy-Item -LiteralPath $generated -Destination $dest -Force
    Write-Host "Transcript written: $dest"
}
