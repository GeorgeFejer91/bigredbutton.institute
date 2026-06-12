[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AudioId,
    [string]$KeyPath = $env:ELEVENLABS_API_KEY_FILE
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
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

if ([string]::IsNullOrWhiteSpace($KeyPath)) {
    throw "Missing ElevenLabs API key file. Pass -KeyPath or set ELEVENLABS_API_KEY_FILE."
}
if (-not (Test-Path $KeyPath)) {
    throw "Missing ElevenLabs API key file: $KeyPath"
}
$apiKey = ([System.IO.File]::ReadAllText($KeyPath)).Trim()
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw "ElevenLabs API key file is empty: $KeyPath"
}

$asset = @(Get-JsonPropertyValue $manifest 'assets') | Where-Object { (Get-JsonPropertyValue $_ 'audioId') -eq $AudioId } | Select-Object -First 1
if ($null -eq $asset) {
    throw "AudioId not found in localized manifest: $AudioId"
}

$ja = Get-JsonPropertyValue (Get-JsonPropertyValue $asset 'locales') 'ja-JP'
if ($null -eq $ja) {
    throw "AudioId $AudioId has no ja-JP locale row."
}

$scriptPath = Join-Path $localizedRoot (Get-JsonPropertyValue $ja 'scriptPath')
if (-not (Test-Path $scriptPath)) {
    throw "Missing Japanese script for $AudioId`: $scriptPath"
}
$text = ([System.IO.File]::ReadAllText($scriptPath, [System.Text.Encoding]::UTF8)).Trim()
if ([string]::IsNullOrWhiteSpace($text)) {
    throw "Japanese script is empty: $scriptPath"
}

$voiceId = Get-JsonPropertyValue $ja 'voiceId'
$modelId = Get-JsonPropertyValue $ja 'modelId'
$languageCode = Get-JsonPropertyValue $ja 'languageCode'
$outputFormat = Get-JsonPropertyValue $ja 'outputFormat'
$outPath = Join-Path $localizedRoot (Get-JsonPropertyValue $ja 'path')
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null

$body = @{
    text = $text
    model_id = $modelId
    language_code = $languageCode
} | ConvertTo-Json -Depth 10
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

Invoke-WebRequest `
    -Method Post `
    -Uri "https://api.elevenlabs.io/v1/text-to-speech/${voiceId}?output_format=$outputFormat" `
    -Headers @{
        "xi-api-key" = $apiKey
        "Content-Type" = "application/json; charset=utf-8"
    } `
    -Body $bodyBytes `
    -OutFile $outPath

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $outPath).Hash
Write-Host "Generated ElevenLabs Japanese audio for $AudioId"
Write-Host "Output: $outPath"
Write-Host "SHA256: $hash"
