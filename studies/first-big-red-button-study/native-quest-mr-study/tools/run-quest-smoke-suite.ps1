[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$AdbPath = 'adb',
    [string]$ApkPath = '',
    [int]$TimeoutSeconds = 60,
    [switch]$SkipInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk'
}
$ApkPath = (Resolve-Path $ApkPath).Path
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $projectRoot "artifacts\quest-smoke-suite\$runId"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$steps = New-Object System.Collections.Generic.List[object]

function Invoke-SuiteStep {
    param(
        [string]$Name,
        [scriptblock]$Action
    )
    $logPath = Join-Path $outDir (($Name -replace '[^A-Za-z0-9_.-]', '-') + '.txt')
    $started = Get-Date
    Write-Host "QUEST SMOKE START $Name"
    try {
        & $Action |
            Tee-Object -FilePath $logPath |
            Out-Host
        $steps.Add([pscustomobject]@{
            name = $Name
            status = 'pass'
            startedAt = $started.ToString('o')
            endedAt = (Get-Date).ToString('o')
            log = $logPath
        })
        Write-Host "QUEST SMOKE PASS $Name"
    } catch {
        $steps.Add([pscustomobject]@{
            name = $Name
            status = 'fail'
            startedAt = $started.ToString('o')
            endedAt = (Get-Date).ToString('o')
            log = $logPath
            error = $_.Exception.Message
        })
        throw
    }
}

function Get-LatestSmokeSummary {
    param(
        [string]$ArtifactSubdir,
        [string]$SummaryName
    )
    $root = Join-Path $projectRoot "artifacts\$ArtifactSubdir"
    if (-not (Test-Path $root)) {
        throw "Missing artifact root: $root"
    }
    $latestDir =
        Get-ChildItem -LiteralPath $root -Directory |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    if ($null -eq $latestDir) {
        throw "No smoke artifact directories found under $root"
    }
    $summaryPath = Join-Path $latestDir.FullName $SummaryName
    if (-not (Test-Path $summaryPath)) {
        throw "Missing smoke summary: $summaryPath"
    }
    return [pscustomobject]@{
        directory = $latestDir.FullName
        summaryPath = $summaryPath
        summary = Get-Content -Raw -LiteralPath $summaryPath | ConvertFrom-Json
    }
}

try {
    Invoke-SuiteStep 'visual-layout-smoke' {
        if ($SkipInstall) {
            & (Join-Path $PSScriptRoot 'run-quest-visual-layout-smoke.ps1') `
                -Serial $Serial `
                -AdbPath $AdbPath `
                -ApkPath $ApkPath `
                -TimeoutSeconds $TimeoutSeconds `
                -SkipInstall
        } else {
            & (Join-Path $PSScriptRoot 'run-quest-visual-layout-smoke.ps1') `
                -Serial $Serial `
                -AdbPath $AdbPath `
                -ApkPath $ApkPath `
                -TimeoutSeconds $TimeoutSeconds
        }
    }

    $visual = Get-LatestSmokeSummary `
        -ArtifactSubdir 'quest-visual-layout-smoke' `
        -SummaryName 'quest-visual-layout-smoke-summary.json'
    if ($visual.summary.status -ne 'pass' -or -not $visual.summary.facingParticipant) {
        throw "Visual-layout smoke summary did not pass or did not face participant: $($visual.summaryPath)"
    }

    Invoke-SuiteStep 'panel-glitch-smoke' {
        & (Join-Path $PSScriptRoot 'run-quest-panel-smoke.ps1') `
            -Serial $Serial `
            -AdbPath $AdbPath `
            -ApkPath $ApkPath `
            -TimeoutSeconds $TimeoutSeconds `
            -SkipInstall
    }

    $panel = Get-LatestSmokeSummary `
        -ArtifactSubdir 'quest-panel-smoke' `
        -SummaryName 'quest-panel-smoke-summary.json'
    if ($panel.summary.status -ne 'pass' -or
        -not $panel.summary.demographicsIntroCue -or
        -not $panel.summary.firstQuestionnaireIntroCue -or
        -not $panel.summary.demographicsGlitch -or
        -not $panel.summary.firstQuestionnaireGlitch -or
        -not $panel.summary.pictographicReady -or
        $panel.summary.conditionStarted -or
        $panel.summary.exportCreated) {
        throw "Panel/glitch smoke summary did not meet pass criteria: $($panel.summaryPath)"
    }

    $apkItem = Get-Item -LiteralPath $ApkPath
    $suiteSummary = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = 'pass'
        serial = $Serial
        apk = [pscustomobject]@{
            path = $apkItem.FullName
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $apkItem.FullName).Hash
            sizeBytes = $apkItem.Length
        }
        outDir = $outDir
        steps = $steps
        visualLayout = [pscustomobject]@{
            summary = $visual.summaryPath
            evidenceDir = $visual.directory
            facingParticipant = $visual.summary.facingParticipant
            downwardAngleDeg = $visual.summary.downwardAngleDeg
            angularDiameterDeg = $visual.summary.angularDiameterDeg
            glbModelConfirmed = $visual.summary.glbModelConfirmed
            screenshot = $visual.summary.screenshot
        }
        panelGlitch = [pscustomobject]@{
            summary = $panel.summaryPath
            evidenceDir = $panel.directory
            demographicsIntroCue = $panel.summary.demographicsIntroCue
            firstQuestionnaireIntroCue = $panel.summary.firstQuestionnaireIntroCue
            demographicsGlitch = $panel.summary.demographicsGlitch
            firstQuestionnaireGlitch = $panel.summary.firstQuestionnaireGlitch
            pictographicReady = $panel.summary.pictographicReady
            conditionStarted = $panel.summary.conditionStarted
            exportCreated = $panel.summary.exportCreated
        }
        note = 'Short non-human Quest smoke suite only. It validates current headset visual/layout and panel intro/glitch gates, but it does not prove physical controller-contact pressing or full physical exports.'
    }
    $summaryPath = Join-Path $outDir 'quest-smoke-suite-summary.json'
    $suiteSummary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    Write-Host "PASS Quest smoke suite"
    Write-Host "Summary: $summaryPath"
} catch {
    $summaryPath = Join-Path $outDir 'quest-smoke-suite-summary.json'
    $suiteSummary = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = 'fail'
        serial = $Serial
        apk = $ApkPath
        outDir = $outDir
        steps = $steps
        error = $_.Exception.Message
        note = 'Short non-human Quest smoke suite failed before completing all runtime smoke gates.'
    }
    $suiteSummary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    Write-Host "FAIL Quest smoke suite"
    Write-Host "Summary: $summaryPath"
    throw
}
