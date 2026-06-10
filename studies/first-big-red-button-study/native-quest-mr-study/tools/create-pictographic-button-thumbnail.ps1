[CmdletBinding()]
param(
    [string]$ModelPath = '',
    [string]$OutPath = '',
    [int]$Size = 512,
    [string]$NodePath = 'node',
    [string]$FfmpegPath = 'ffmpeg'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($ModelPath)) {
    $ModelPath = Join-Path $projectRoot 'app\src\main\assets\models\BigRedButton.glb'
}
if ([string]::IsNullOrWhiteSpace($OutPath)) {
    $OutPath = Join-Path $projectRoot 'app\src\main\res\drawable-nodpi\big_red_button_model_thumbnail.png'
}

$ModelPath = (Resolve-Path $ModelPath).Path
$renderer = Join-Path $projectRoot 'tools\render-button-model-thumbnail.mjs'
$outDir = Split-Path -Parent $OutPath
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Resolve-Executable {
    param(
        [string]$Requested,
        [string[]]$Fallbacks
    )

    $candidates = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($Requested)) {
        $command = Get-Command $Requested -ErrorAction SilentlyContinue
        if ($command) { $candidates.Add($command.Source) }
        $candidates.Add($Requested)
    }
    foreach ($fallback in $Fallbacks) {
        if (-not [string]::IsNullOrWhiteSpace($fallback)) {
            Get-ChildItem -Path $fallback -ErrorAction SilentlyContinue | ForEach-Object {
                $candidates.Add($_.FullName)
            }
        }
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate)) { continue }
        try {
            & $candidate --version *> $null
            if ($LASTEXITCODE -eq 0) { return (Resolve-Path $candidate).Path }
        } catch {
            continue
        }
    }
    throw "Could not execute $Requested. Pass -NodePath or install a callable Node runtime."
}

$resolvedNode = Resolve-Executable `
    -Requested $NodePath `
    -Fallbacks @(
        (Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin\*\node.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2022\Community\MSBuild\Microsoft\VisualStudio\NodeJs\node.exe'),
        (Join-Path $env:ProgramFiles 'Cycling ''74\Max 9\resources\packages\Node for Max\source\bin\pc_x64\node\node.exe')
    )

& $resolvedNode $renderer --model $ModelPath --out $OutPath --size $Size --ffmpeg $FfmpegPath
if ($LASTEXITCODE -ne 0) {
    throw "Button model thumbnail render failed with exit code $LASTEXITCODE"
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $OutPath).Hash
[pscustomobject]@{
    model = $ModelPath
    output = (Resolve-Path $OutPath).Path
    size = $Size
    node = $resolvedNode
    sha256 = $hash
    note = 'Thumbnail is rendered directly from BigRedButton.glb geometry and materials, not cropped from a stale headset screenshot.'
} | ConvertTo-Json -Depth 4
