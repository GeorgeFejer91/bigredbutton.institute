[CmdletBinding()]
param(
    [string]$OutPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutPath)) {
    $OutPath = Join-Path $projectRoot 'app\src\main\res\raw\retro_startup_chime.wav'
}
$outDir = Split-Path -Parent $OutPath
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$sampleRate = 44100
$durationSeconds = 1.58
$sampleCount = [int]($sampleRate * $durationSeconds)
$channels = 1
$bitsPerSample = 16
$bytesPerSample = 2
$dataBytes = $sampleCount * $channels * $bytesPerSample

function Note-Amp {
    param([double]$T, [double]$Start, [double]$Duration)
    $local = $T - $Start
    if ($local -lt 0 -or $local -gt $Duration) { return 0.0 }
    $attack = 0.035
    $release = 0.32
    $amp = 1.0
    if ($local -lt $attack) {
        $amp = $local / $attack
    } elseif ($local -gt ($Duration - $release)) {
        $amp = [Math]::Max(0.0, ($Duration - $local) / $release)
    }
    return $amp * [Math]::Exp(-1.25 * $local)
}

function Tone {
    param([double]$T, [double]$Freq, [double]$Start, [double]$Duration, [double]$Gain)
    $amp = Note-Amp $T $Start $Duration
    if ($amp -eq 0.0) { return 0.0 }
    $phase = 2.0 * [Math]::PI * $Freq * ($T - $Start)
    $fundamental = [Math]::Sin($phase)
    $softHarmonic = 0.34 * [Math]::Sin($phase * 2.0)
    $air = 0.11 * [Math]::Sin($phase * 3.0 + 0.4)
    return ($fundamental + $softHarmonic + $air) * $amp * $Gain
}

$stream = [IO.File]::Open($OutPath, [IO.FileMode]::Create, [IO.FileAccess]::Write)
$writer = New-Object IO.BinaryWriter($stream)
try {
    $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
    $writer.Write([int](36 + $dataBytes))
    $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
    $writer.Write([Text.Encoding]::ASCII.GetBytes('fmt '))
    $writer.Write([int]16)
    $writer.Write([Int16]1)
    $writer.Write([Int16]$channels)
    $writer.Write([int]$sampleRate)
    $writer.Write([int]($sampleRate * $channels * $bytesPerSample))
    $writer.Write([Int16]($channels * $bytesPerSample))
    $writer.Write([Int16]$bitsPerSample)
    $writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
    $writer.Write([int]$dataBytes)

    for ($i = 0; $i -lt $sampleCount; $i++) {
        $t = $i / $sampleRate
        $sample =
            (Tone $t 329.628 0.00 1.10 0.28) +
            (Tone $t 493.883 0.13 1.18 0.24) +
            (Tone $t 659.255 0.32 1.12 0.21) +
            (Tone $t 987.767 0.54 0.76 0.13)
        $sample += 0.035 * [Math]::Sin(2.0 * [Math]::PI * 1318.51 * $t) * [Math]::Exp(-5.5 * [Math]::Max(0.0, $t - 0.62))
        $sample = [Math]::Max(-0.96, [Math]::Min(0.96, $sample))
        $writer.Write([Int16][Math]::Round($sample * 32767))
    }
} finally {
    $writer.Dispose()
    $stream.Dispose()
}

[pscustomobject]@{
    output = (Resolve-Path $OutPath).Path
    durationSeconds = $durationSeconds
    sampleRate = $sampleRate
    sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $OutPath).Hash
    note = 'Generated retro computer-startup chime. It is not the Microsoft Windows XP startup sound.'
} | ConvertTo-Json -Depth 3
