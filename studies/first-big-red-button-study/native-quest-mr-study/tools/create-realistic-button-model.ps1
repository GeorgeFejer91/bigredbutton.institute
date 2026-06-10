[CmdletBinding()]
param(
    [string]$OutPath = '',
    [string]$NodePath = 'node'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutPath)) {
    $OutPath = Join-Path $projectRoot 'app\src\main\assets\models\BigRedButton.glb'
}

function Resolve-Node {
    param([string]$Requested)
    $candidates = New-Object System.Collections.Generic.List[string]
    $command = Get-Command $Requested -ErrorAction SilentlyContinue
    if ($command) { $candidates.Add($command.Source) }
    $candidates.Add($Requested)
    Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin\*\node.exe') -ErrorAction SilentlyContinue | ForEach-Object {
        $candidates.Add($_.FullName)
    }
    $vsNode = Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2022\Community\MSBuild\Microsoft\VisualStudio\NodeJs\node.exe'
    if (Test-Path $vsNode) { $candidates.Add($vsNode) }
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        try {
            if (Test-Path -LiteralPath $candidate) {
                & $candidate --version *> $null
                if ($LASTEXITCODE -eq 0) { return (Resolve-Path $candidate).Path }
            }
        } catch {
            continue
        }
    }
    throw "Could not execute Node. Pass -NodePath with a working node.exe."
}

$node = Resolve-Node $NodePath
$script = Join-Path $projectRoot 'tools\create-realistic-button-model.mjs'
$outDir = Split-Path -Parent $OutPath
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

& $node $script --out $OutPath
if ($LASTEXITCODE -ne 0) {
    throw "Realistic Big Red Button model generation failed with exit code $LASTEXITCODE"
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $OutPath).Hash
[pscustomobject]@{
    output = (Resolve-Path $OutPath).Path
    node = $node
    sha256 = $hash
    note = 'Generated smooth packaged GLB with a glossy red cap, dark base, metal bezel, and pressed animation.'
} | ConvertTo-Json -Depth 4
