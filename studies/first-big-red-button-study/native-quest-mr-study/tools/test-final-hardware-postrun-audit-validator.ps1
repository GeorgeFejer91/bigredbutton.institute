[CmdletBinding()]
param(
    [string]$OutDir = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $projectRoot ('artifacts\final-hardware-postrun-audit-tests\t-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$validatorScript = Join-Path $PSScriptRoot 'validate-final-hardware-postrun-audit.ps1'
if (-not (Test-Path -LiteralPath $validatorScript)) {
    throw "Missing validator script: $validatorScript"
}

function Write-JsonFile {
    param(
        [string]$Path,
        $Object
    )
    $Object | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-ChainCase {
    param(
        [string]$Name,
        [string]$Mode
    )

    $caseRoot = Join-Path $OutDir $Name
    New-Item -ItemType Directory -Force -Path $caseRoot | Out-Null

    $summaryPath = Join-Path $caseRoot 'final-hardware-gates-summary.json'
    $readinessPath = Join-Path $caseRoot 'readiness-report.json'
    $goalAuditPath = Join-Path $caseRoot 'goal-completion-audit.json'
    $otherReadinessPath = Join-Path $caseRoot 'other-readiness-report.json'
    $sha = '55E3B082077BD55D939D1610E5FEC7AC56641B8FA62C201804AEE322CC951C2A'
    $otherSha = '0000000000000000000000000000000000000000000000000000000000000000'

    $realWrapperModes = @('valid-real-pass', 'incomplete-readiness-completion-allowed')
    $dryRun = -not ($Mode -in $realWrapperModes)
    $postRunStatus = if ($Mode -eq 'postrun-status-fail') { 'fail' } else { 'pass' }
    $readinessSha = if ($Mode -eq 'readiness-apk-mismatch') { $otherSha } else { $sha }
    $goalSha = if ($Mode -eq 'goal-apk-mismatch') { $otherSha } else { $sha }
    $goalReadinessPath = if ($Mode -eq 'goal-readiness-mismatch') { $otherReadinessPath } else { $readinessPath }
    $completionAllowed = if ($Mode -in @('dry-run-completion-allowed', 'valid-real-pass', 'incomplete-readiness-completion-allowed')) { $true } else { $false }

    $summary = [ordered]@{
        generatedAt = '2026-06-10T12:00:00.0000000+02:00'
        status = if ($dryRun) { 'dry_run' } else { 'pass' }
        dryRun = $dryRun
        apk = [ordered]@{
            sha256 = $sha
            sizeBytes = 107315659
        }
        postRunAudit = [ordered]@{
            status = $postRunStatus
            readinessReport = $readinessPath
            goalCompletionAudit = $goalAuditPath
            error = if ($postRunStatus -eq 'pass') { '' } else { 'synthetic failure' }
        }
    }

    $readiness = [ordered]@{
        generatedAt = '2026-06-10T12:00:01.0000000+02:00'
        status =
            if ($Mode -eq 'valid-real-pass') {
                'complete'
            } elseif ($Mode -eq 'valid-incomplete-bootstrap') {
                'incomplete'
            } else {
                'ready_except_physical_and_live_polar_gates'
            }
        apk = [ordered]@{
            sha256 = $readinessSha
            sizeBytes = 107315659
        }
        evidence = [ordered]@{
            finalHardwareGateWrapper = $summaryPath
        }
    }

    $otherReadiness = [ordered]@{
        generatedAt = '2026-06-10T12:00:02.0000000+02:00'
        status = 'ready_except_physical_and_live_polar_gates'
        apk = [ordered]@{
            sha256 = $sha
            sizeBytes = 107315659
        }
        evidence = [ordered]@{
            finalHardwareGateWrapper = $summaryPath
        }
    }

    $goalStatus =
        if ($Mode -eq 'goal-status-mismatch') {
            'complete'
        } elseif ($Mode -eq 'valid-incomplete-bootstrap') {
            'incomplete_software_or_headset_gates'
        } else {
            $readiness.status
        }
    $goalAudit = [ordered]@{
        generatedAt = '2026-06-10T12:00:03.0000000+02:00'
        status = $goalStatus
        completionAllowed = $completionAllowed
        readinessJson = $goalReadinessPath
        apk = [ordered]@{
            sha256 = $goalSha
            sizeBytes = 107315659
        }
    }

    Write-JsonFile -Path $summaryPath -Object $summary
    Write-JsonFile -Path $readinessPath -Object $readiness
    Write-JsonFile -Path $goalAuditPath -Object $goalAudit
    Write-JsonFile -Path $otherReadinessPath -Object $otherReadiness

    return [pscustomobject]@{
        name = $Name
        mode = $Mode
        summaryPath = $summaryPath
    }
}

function Invoke-ValidatorCase {
    param(
        $Case,
        [bool]$ShouldPass
    )

    $caseOut = Join-Path (Split-Path -Parent $Case.summaryPath) 'validator-output'
    $passed = $false
    $errorMessage = ''
    try {
        & $validatorScript -SummaryPath $Case.summaryPath -OutDir $caseOut *> (Join-Path (Split-Path -Parent $Case.summaryPath) 'validator-console.txt')
        $passed = $true
    } catch {
        $errorMessage = $_.Exception.Message
    }

    $expected = if ($ShouldPass) { 'pass' } else { 'fail' }
    $observed = if ($passed) { 'pass' } else { 'fail' }
    $ok = ($passed -eq $ShouldPass)
    return [pscustomobject]@{
        name = $Case.name
        mode = $Case.mode
        expected = $expected
        observed = $observed
        passed = $ok
        summaryPath = $Case.summaryPath
        validatorOutput = Join-Path $caseOut 'final-hardware-postrun-audit-validation.json'
        error = $errorMessage
    }
}

$caseSpecs = @(
    [pscustomobject]@{ Name = 'valid-dry-run'; Mode = 'valid-dry-run'; ShouldPass = $true },
    [pscustomobject]@{ Name = 'valid-real-pass'; Mode = 'valid-real-pass'; ShouldPass = $true },
    [pscustomobject]@{ Name = 'valid-incomplete-bootstrap'; Mode = 'valid-incomplete-bootstrap'; ShouldPass = $true },
    [pscustomobject]@{ Name = 'reject-goal-readiness-mismatch'; Mode = 'goal-readiness-mismatch'; ShouldPass = $false },
    [pscustomobject]@{ Name = 'reject-dry-run-completion-allowed'; Mode = 'dry-run-completion-allowed'; ShouldPass = $false },
    [pscustomobject]@{ Name = 'reject-incomplete-readiness-completion-allowed'; Mode = 'incomplete-readiness-completion-allowed'; ShouldPass = $false },
    [pscustomobject]@{ Name = 'reject-goal-status-mismatch'; Mode = 'goal-status-mismatch'; ShouldPass = $false },
    [pscustomobject]@{ Name = 'reject-readiness-apk-mismatch'; Mode = 'readiness-apk-mismatch'; ShouldPass = $false },
    [pscustomobject]@{ Name = 'reject-goal-apk-mismatch'; Mode = 'goal-apk-mismatch'; ShouldPass = $false },
    [pscustomobject]@{ Name = 'reject-postrun-status-fail'; Mode = 'postrun-status-fail'; ShouldPass = $false }
)

$results = New-Object System.Collections.Generic.List[object]
foreach ($spec in $caseSpecs) {
    $case = New-ChainCase -Name $spec.Name -Mode $spec.Mode
    $results.Add((Invoke-ValidatorCase -Case $case -ShouldPass ([bool]$spec.ShouldPass))) | Out-Null
}

$failed = @($results | Where-Object { -not $_.passed })
$summary = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
    validatorScript = $validatorScript
    results = $results
}

$summaryPath = Join-Path $OutDir 'final-hardware-postrun-audit-validator-test-summary.json'
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

if ($summary.status -ne 'pass') {
    throw "Final hardware post-run audit validator behavioral tests failed. See $summaryPath"
}

Write-Host "PASS final hardware post-run audit validator behavioral tests"
Write-Host "Summary: $summaryPath"
