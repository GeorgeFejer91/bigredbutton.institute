[CmdletBinding()]
param(
    [string]$Serial = '',
    [string]$AdbPath = 'adb',
    [string]$OutDir = '',
    [switch]$CheckAdb
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $projectRoot ('artifacts\hand-contact-operator-handoff\handoff-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Get-LatestFile {
    param([string]$RelativePath, [string]$Filter)
    $root = Join-Path $projectRoot $RelativePath
    if (-not (Test-Path -LiteralPath $root)) {
        return $null
    }
    return Get-ChildItem -LiteralPath $root -Recurse -File -Filter $Filter -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Read-JsonStatus {
    param([System.IO.FileInfo]$File)
    if ($null -eq $File) {
        return $null
    }
    try {
        return Get-Content -Raw -LiteralPath $File.FullName | ConvertFrom-Json
    } catch {
        return $null
    }
}

$apkPath = Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk'
if (-not (Test-Path -LiteralPath $apkPath)) {
    throw "Missing debug APK: $apkPath"
}
$apkItem = Get-Item -LiteralPath $apkPath
$apkSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $apkItem.FullName).Hash

$latestStaticValidationFile = Get-LatestFile -RelativePath 'artifacts\local-validation' -Filter 'validation-*.json'
$latestHandEvidenceTestFile = Get-LatestFile -RelativePath 'artifacts\hand-contact-physics-evidence-tests' -Filter 'hand-contact-physics-evidence-validator-test-summary.json'
$latestHandMechanicsAnalysisTestFile = Get-LatestFile -RelativePath 'artifacts\hand-contact-press-mechanics-analysis-tests' -Filter 'hand-contact-press-mechanics-analysis-test-summary.json'
$staticValidation = Read-JsonStatus $latestStaticValidationFile
$handEvidenceTest = Read-JsonStatus $latestHandEvidenceTestFile
$handMechanicsAnalysisTest = Read-JsonStatus $latestHandMechanicsAnalysisTestFile

$adbCheck = [ordered]@{
    requested = [bool]$CheckAdb
    adbPath = $AdbPath
    serialRequested = $Serial
    deviceReady = $null
    detectedSerial = ''
    devices = @()
    error = ''
}

if ($CheckAdb) {
    try {
        $adbOutput = & $AdbPath devices -l 2>&1
        $deviceRows = New-Object System.Collections.Generic.List[object]
        foreach ($line in @($adbOutput)) {
            $text = [string]$line
            if ($text -match '^\s*$' -or $text -match '^List of devices') {
                continue
            }
            $parts = $text -split '\s+'
            if ($parts.Count -lt 2) {
                continue
            }
            $deviceRows.Add([pscustomobject]@{
                serial = $parts[0]
                state = $parts[1]
                detail = $text
            }) | Out-Null
        }
        $adbCheck.devices = @($deviceRows.ToArray())
        if ([string]::IsNullOrWhiteSpace($Serial)) {
            $readyDevices = @($deviceRows | Where-Object { $_.state -eq 'device' })
            $adbCheck.deviceReady = $readyDevices.Count -eq 1
            $adbCheck.detectedSerial = if ($readyDevices.Count -ge 1) { $readyDevices[0].serial } else { '' }
        } else {
            $match = @($deviceRows | Where-Object { $_.serial -eq $Serial } | Select-Object -First 1)
            $adbCheck.deviceReady = $match.Count -eq 1 -and $match[0].state -eq 'device'
            $adbCheck.detectedSerial = if ($match.Count -eq 1) { $match[0].serial } else { '' }
        }
    } catch {
        $adbCheck.deviceReady = $false
        $adbCheck.error = $_.Exception.Message
    }
}

$commandSerial =
    if (-not [string]::IsNullOrWhiteSpace($Serial)) {
        $Serial
    } elseif ($CheckAdb -and -not [string]::IsNullOrWhiteSpace($adbCheck.detectedSerial)) {
        $adbCheck.detectedSerial
    } else {
        '<quest-serial>'
    }

$quickCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-hand-contact-physics-smoke.ps1 -Serial $commandSerial -AdbPath `"$AdbPath`" -TimeoutSeconds 120"
$exportCommand = "$quickCommand -RequireExportEvidence -ExportTimeoutSeconds 760"
$recheckCommand = 'powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-hand-contact-physics-evidence.ps1 -EvidenceDir <artifacts\qhps\runId> [-RequireExportEvidence]'
$analysisCommand = 'powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\analyze-hand-contact-press-mechanics.ps1 -EvidenceDir <artifacts\qhps\runId> -RequireHandContact'

$staticValidationPass =
    $null -ne $staticValidation -and
    $staticValidation.status -eq 'pass' -and
    @($staticValidation.checks | Where-Object { -not $_.passed }).Count -eq 0
$handEvidenceTestPass = $null -ne $handEvidenceTest -and $handEvidenceTest.status -eq 'pass'
$handMechanicsAnalysisTestPass = $null -ne $handMechanicsAnalysisTest -and $handMechanicsAnalysisTest.status -eq 'pass'
$readyForOperator =
    $staticValidationPass -and
    $handEvidenceTestPass -and
    $handMechanicsAnalysisTestPass -and
    (-not $CheckAdb -or [bool]$adbCheck.deviceReady)

$summary = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    status = if ($readyForOperator) { 'ready_for_operator_hand_contact_physics_smoke' } else { 'not_ready' }
    readyForOperatorHandContactPhysicsSmoke = $readyForOperator
    apk = [ordered]@{
        path = $apkItem.FullName
        sha256 = $apkSha256
        sizeBytes = $apkItem.Length
        lastWriteTime = $apkItem.LastWriteTime.ToString('o')
    }
    adb = $adbCheck
    latestStaticValidation = [ordered]@{
        path = if ($null -ne $latestStaticValidationFile) { $latestStaticValidationFile.FullName } else { '' }
        status = if ($null -ne $staticValidation) { $staticValidation.status } else { '' }
        failedChecks = if ($null -ne $staticValidation) { @($staticValidation.checks | Where-Object { -not $_.passed }).Count } else { $null }
    }
    latestHandEvidenceValidatorTest = [ordered]@{
        path = if ($null -ne $latestHandEvidenceTestFile) { $latestHandEvidenceTestFile.FullName } else { '' }
        status = if ($null -ne $handEvidenceTest) { $handEvidenceTest.status } else { '' }
    }
    latestHandMechanicsAnalysisTest = [ordered]@{
        path = if ($null -ne $latestHandMechanicsAnalysisTestFile) { $latestHandMechanicsAnalysisTestFile.FullName } else { '' }
        status = if ($null -ne $handMechanicsAnalysisTest) { $handMechanicsAnalysisTest.status } else { '' }
    }
    quickSmokeCommand = $quickCommand
    exportEvidenceCommand = $exportCommand
    independentRecheckCommand = $recheckCommand
    independentAnalysisCommand = $analysisCommand
    note = 'Supplemental hand-contact physics smoke only. It proves visual-only predictive preload plus accepted hand_contact mechanics when run by a human operator; it does not satisfy the final controller_contact proof gate.'
}

$jsonPath = Join-Path $OutDir 'hand-contact-physics-operator-handoff.json'
$mdPath = Join-Path $OutDir 'hand-contact-physics-operator-handoff.md'
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$markdown = @"
# Hand-Contact Physics Operator Handoff

- Status: `$($summary.status)`
- Ready for operator hand-contact smoke: `$readyForOperator`
- APK: `$($apkItem.FullName)`
- APK SHA-256: `$apkSha256`
- APK size bytes: `$($apkItem.Length)`
- Static validation: `$($summary.latestStaticValidation.status)` (`$($summary.latestStaticValidation.path)`)
- Hand evidence validator test: `$($summary.latestHandEvidenceValidatorTest.status)` (`$($summary.latestHandEvidenceValidatorTest.path)`)
- Hand press mechanics analysis test: `$($summary.latestHandMechanicsAnalysisTest.status)` (`$($summary.latestHandMechanicsAnalysisTest.path)`)
- ADB device ready: `$($adbCheck.deviceReady)`
- Detected serial: `$($adbCheck.detectedSerial)`

## Quick Smoke

```powershell
$quickCommand
```

## Export Evidence Mode

```powershell
$exportCommand
```

## Independent Recheck

```powershell
$recheckCommand
```

## Independent Mechanics Analysis

```powershell
$analysisCommand
```

This hand-contact gate is supplemental and paper-relevant. It does not replace the final controller-contact/live-H10 export gate.
"@
$markdown | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host "Hand-contact physics operator handoff JSON: $jsonPath"
Write-Host "Hand-contact physics operator handoff Markdown: $mdPath"
if (-not $readyForOperator) {
    throw 'Hand-contact physics operator handoff is not ready. Inspect the JSON for missing local validation, evidence-validator test, mechanics-analysis test, or ADB readiness.'
}
