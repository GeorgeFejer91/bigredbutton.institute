[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$AdbPath = 'adb',
    [string]$ApkPath = '',
    [int]$PolarSmokeTimeoutSeconds = 120,
    [int]$ControllerSmokeTimeoutSeconds = 90,
    [int]$PhysicalWaitSeconds = 760,
    [int]$MinCondition1ControllerPresses = 1,
    [int]$MinCondition2ControllerPresses = 1,
    [switch]$SkipControllerSmoke,
    [switch]$SkipInstall,
    [switch]$SkipPreRunHandoff,
    [switch]$SkipPostRunAudit,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk'
}
$ApkPath = (Resolve-Path $ApkPath).Path
$apkItem = Get-Item -LiteralPath $ApkPath
$apkSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $ApkPath).Hash
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $projectRoot "artifacts\final-hardware-gates\$runId"
$summaryPath = Join-Path $outDir 'final-hardware-gates-summary.json'
$steps = New-Object System.Collections.Generic.List[object]
$script:postRunAuditStatus = if ($SkipPostRunAudit) { 'skipped' } else { 'not_started' }
$script:postRunReadinessReport = ''
$script:postRunGoalCompletionAudit = ''
$script:postRunAuditError = ''
$script:preRunHandoffStatus = if ($SkipPreRunHandoff) { 'skipped' } else { 'not_started' }
$script:preRunHandoffJson = ''
$script:preRunHandoffMarkdown = ''
$script:preRunHandoffError = ''

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Get-LatestSummaryAfter {
    param(
        [string]$Root,
        [string]$Filter,
        [datetime]$StartedAt
    )
    if (-not (Test-Path -LiteralPath $Root)) {
        return $null
    }
    $match =
        Get-ChildItem -LiteralPath $Root -Recurse -Filter $Filter -File |
            Where-Object { $_.LastWriteTime -ge $StartedAt.AddSeconds(-2) } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    if ($null -eq $match) {
        return $null
    }
    return $match.FullName
}

function Write-FinalSummary {
    param(
        [string]$Status,
        [string]$ErrorMessage = ''
    )
    [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = $Status
        error = $ErrorMessage
        serial = $Serial
        apk = [pscustomobject]@{
            path = $ApkPath
            sha256 = $apkSha256
            sizeBytes = $apkItem.Length
            lastWriteTime = $apkItem.LastWriteTime.ToString('o')
        }
        dryRun = [bool]$DryRun
        outDir = $outDir
        steps = @($steps.ToArray())
        preRunHandoff = [pscustomobject]@{
            status = $script:preRunHandoffStatus
            json = $script:preRunHandoffJson
            markdown = $script:preRunHandoffMarkdown
            error = $script:preRunHandoffError
            skipped = [bool]$SkipPreRunHandoff
        }
        postRunAudit = [pscustomobject]@{
            status = $script:postRunAuditStatus
            readinessReport = $script:postRunReadinessReport
            goalCompletionAudit = $script:postRunGoalCompletionAudit
            error = $script:postRunAuditError
            skipped = [bool]$SkipPostRunAudit
        }
        note = 'Final hardware gate wrapper. Pass requires live Polar H10 PMD ECG smoke, optional fast controller-contact smoke, and full controller-contact/live-H10 export validation.'
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
}

function Add-Step {
    param(
        [string]$Name,
        [string]$Status,
        [datetime]$StartedAt,
        [datetime]$EndedAt,
        [string[]]$Command,
        [string]$Summary = '',
        [string]$ErrorMessage = ''
    )
    $steps.Add([pscustomobject]@{
        name = $Name
        status = $Status
        startedAt = $StartedAt.ToString('o')
        endedAt = $EndedAt.ToString('o')
        command = ($Command -join ' ')
        summary = $Summary
        error = $ErrorMessage
    })
}

function Invoke-GateStep {
    param(
        [string]$Name,
        [string]$ScriptName,
        [string[]]$ArgumentList,
        [string]$SummaryRoot,
        [string]$SummaryFilter
    )
    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    $command = @('powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath) + $ArgumentList
    $startedAt = Get-Date

    if ($DryRun) {
        Add-Step -Name $Name -Status 'dry_run' -StartedAt $startedAt -EndedAt (Get-Date) -Command $command
        Write-Host "DRY RUN $Name"
        Write-Host ($command -join ' ')
        return
    }

    Write-Host "FINAL HARDWARE START $Name"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @ArgumentList
    $exitCode = $LASTEXITCODE
    $endedAt = Get-Date
    $summary = Get-LatestSummaryAfter -Root $SummaryRoot -Filter $SummaryFilter -StartedAt $startedAt
    if ($exitCode -ne 0) {
        Add-Step -Name $Name -Status 'fail' -StartedAt $startedAt -EndedAt $endedAt -Command $command -Summary $summary -ErrorMessage "Step exited with code $exitCode"
        throw "$Name failed with exit code $exitCode. See child summary: $summary"
    }
    Add-Step -Name $Name -Status 'pass' -StartedAt $startedAt -EndedAt $endedAt -Command $command -Summary $summary
    Write-Host "FINAL HARDWARE PASS $Name"
}

function Invoke-PreRunHandoff {
    if ($SkipPreRunHandoff) {
        $script:preRunHandoffStatus = 'skipped'
        return
    }

    $startedAt = Get-Date
    try {
        Write-Host "FINAL HARDWARE PRE-RUN operator-handoff"
        $handoffArgs = @(
            '-Serial', $Serial,
            '-AdbPath', $AdbPath,
            '-RefreshAudit',
            '-RequireReady'
        )
        if (-not $DryRun) {
            $handoffArgs += '-CheckAdb'
        }
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'write-final-hardware-operator-handoff.ps1') @handoffArgs
        if ($LASTEXITCODE -ne 0) {
            throw "write-final-hardware-operator-handoff.ps1 exited with code $LASTEXITCODE"
        }
        $handoffJson =
            Get-LatestSummaryAfter `
                -Root (Join-Path $projectRoot 'artifacts\final-operator-handoff') `
                -Filter 'final-operator-handoff.json' `
                -StartedAt $startedAt
        if ([string]::IsNullOrWhiteSpace($handoffJson)) {
            throw 'write-final-hardware-operator-handoff.ps1 completed, but no fresh final-operator-handoff.json was found.'
        }
        $script:preRunHandoffJson = $handoffJson
        $script:preRunHandoffMarkdown = Join-Path (Split-Path -Parent $handoffJson) 'final-operator-handoff.md'
        $script:preRunHandoffStatus = 'pass'
        $script:preRunHandoffError = ''
        Write-Host "FINAL HARDWARE PRE-RUN operator handoff pass"
    } catch {
        $script:preRunHandoffStatus = 'fail'
        $script:preRunHandoffError = $_.Exception.Message
        throw "Final hardware pre-run operator handoff failed: $script:preRunHandoffError"
    }
}

function Invoke-PostRunAudit {
    if ($SkipPostRunAudit) {
        $script:postRunAuditStatus = 'skipped'
        return
    }

    $startedAt = Get-Date
    try {
        Write-Host "FINAL HARDWARE POST-RUN readiness-report"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'write-readiness-report.ps1') -FinalHardwareGateSummaryPath $summaryPath
        $readinessExitCode = $LASTEXITCODE
        $readinessSummary =
            Get-LatestSummaryAfter `
                -Root (Join-Path $projectRoot 'artifacts\readiness-report') `
                -Filter 'readiness-report.json' `
                -StartedAt $startedAt
        $script:postRunReadinessReport = if ($readinessSummary) { $readinessSummary } else { '' }
        if ([string]::IsNullOrWhiteSpace($script:postRunReadinessReport)) {
            throw 'write-readiness-report.ps1 completed, but no fresh readiness-report.json was found for this post-run audit.'
        }
        if ($readinessExitCode -ne 0) {
            Write-Warning "write-readiness-report.ps1 exited with code $readinessExitCode, but produced a readiness JSON for wrapper binding: $script:postRunReadinessReport"
        }

        Write-Host "FINAL HARDWARE POST-RUN goal-completion-audit"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'write-goal-completion-audit.ps1') -ReadinessJson $script:postRunReadinessReport
        if ($LASTEXITCODE -ne 0) {
            throw "write-goal-completion-audit.ps1 exited with code $LASTEXITCODE"
        }
        $goalAudit =
            Get-LatestSummaryAfter `
                -Root (Join-Path $projectRoot 'artifacts\goal-completion-audit') `
                -Filter 'goal-completion-audit.json' `
                -StartedAt $startedAt
        $script:postRunGoalCompletionAudit = if ($goalAudit) { $goalAudit } else { '' }
        $script:postRunAuditStatus = 'pass'
        $script:postRunAuditError = ''
        Write-Host "FINAL HARDWARE POST-RUN audit pass"
    } catch {
        $script:postRunAuditStatus = 'fail'
        $script:postRunAuditError = $_.Exception.Message
        Write-Warning "Final hardware post-run audit failed: $script:postRunAuditError"
    }
}

try {
    Write-Host "Final hardware gates target: serial=$Serial"
    Write-Host "APK SHA-256: $apkSha256"
    Write-Host "Operator requirements: wear an awake/wet Polar H10, keep it near the headset, then physically press the modeled 3D button with a Quest controller in both conditions."
    Invoke-PreRunHandoff
    Write-FinalSummary -Status 'running'

    $polarArgs = @(
        '-Serial', $Serial,
        '-AdbPath', $AdbPath,
        '-ApkPath', $ApkPath,
        '-TimeoutSeconds', $PolarSmokeTimeoutSeconds.ToString()
    )
    if ($SkipInstall) {
        $polarArgs += '-SkipInstall'
    }
    Invoke-GateStep `
        -Name 'live-polar-h10-pmd-ecg-smoke' `
        -ScriptName 'run-quest-polar-h10-live-smoke.ps1' `
        -ArgumentList $polarArgs `
        -SummaryRoot (Join-Path $projectRoot 'artifacts\qpolar') `
        -SummaryFilter 'quest-polar-h10-live-smoke-summary.json'

    if ($SkipControllerSmoke) {
        $startedAt = Get-Date
        Add-Step `
            -Name 'fast-controller-contact-smoke' `
            -Status 'skipped' `
            -StartedAt $startedAt `
            -EndedAt $startedAt `
            -Command @('skipped by -SkipControllerSmoke')
    } else {
        $contactArgs = @(
            '-Serial', $Serial,
            '-AdbPath', $AdbPath,
            '-ApkPath', $ApkPath,
            '-TimeoutSeconds', $ControllerSmokeTimeoutSeconds.ToString(),
            '-SkipInstall'
        )
        Invoke-GateStep `
            -Name 'fast-controller-contact-smoke' `
            -ScriptName 'run-quest-controller-contact-smoke.ps1' `
            -ArgumentList $contactArgs `
            -SummaryRoot (Join-Path $projectRoot 'artifacts\qcs') `
            -SummaryFilter 'quest-controller-contact-smoke-summary.json'
    }

    $physicalArgs = @(
        '-Serial', $Serial,
        '-AdbPath', $AdbPath,
        '-ApkPath', $ApkPath,
        '-WaitSeconds', $PhysicalWaitSeconds.ToString(),
        '-MinCondition1ControllerPresses', $MinCondition1ControllerPresses.ToString(),
        '-MinCondition2ControllerPresses', $MinCondition2ControllerPresses.ToString(),
        '-SkipPolarPrecheck',
        '-SkipInstall'
    )
    Invoke-GateStep `
        -Name 'full-controller-contact-live-h10-export-validation' `
        -ScriptName 'run-quest-physical-press-validation.ps1' `
        -ArgumentList $physicalArgs `
        -SummaryRoot (Join-Path $projectRoot 'artifacts\qpv') `
        -SummaryFilter 'quest-physical-press-validation-summary.json'

    if ($DryRun) {
        Write-FinalSummary -Status 'dry_run'
        Invoke-PostRunAudit
        Write-FinalSummary -Status 'dry_run'
        Write-Host "DRY RUN final hardware gates"
    } else {
        Write-FinalSummary -Status 'pass'
        Invoke-PostRunAudit
        Write-FinalSummary -Status 'pass'
        Write-Host "PASS final hardware gates"
    }
    Write-Host "Summary: $summaryPath"
} catch {
    $message = $_.Exception.Message
    Write-FinalSummary -Status 'fail' -ErrorMessage $message
    Invoke-PostRunAudit
    Write-FinalSummary -Status 'fail' -ErrorMessage $message
    Write-Host "FAIL final hardware gates"
    Write-Host "Summary: $summaryPath"
    throw
}
