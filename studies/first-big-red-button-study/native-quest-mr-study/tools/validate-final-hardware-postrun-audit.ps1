[CmdletBinding()]
param(
    [string]$SummaryPath = '',
    [string]$OutDir = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing JSON file: $Path"
    }
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Get-PropertyValue {
    param(
        $Object,
        [string]$Name
    )
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Resolve-OptionalPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        return ''
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Same-Path {
    param(
        [string]$Left,
        [string]$Right
    )
    if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) {
        return $false
    }
    $leftFull = [IO.Path]::GetFullPath($Left)
    $rightFull = [IO.Path]::GetFullPath($Right)
    return [string]::Equals($leftFull, $rightFull, [StringComparison]::OrdinalIgnoreCase)
}

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$Rows,
        [string]$Name,
        [bool]$Passed,
        [string]$Detail
    )
    $Rows.Add([pscustomobject]@{
        name = $Name
        passed = $Passed
        detail = $Detail
    }) | Out-Null
}

function Test-GoalStatusMatchesReadiness {
    param(
        [string]$GoalStatus,
        [string]$ReadinessStatus
    )
    if ($ReadinessStatus -eq 'incomplete') {
        return $GoalStatus -in @('incomplete', 'incomplete_software_or_headset_gates')
    }
    return $GoalStatus -eq $ReadinessStatus
}

if ([string]::IsNullOrWhiteSpace($SummaryPath)) {
    $root = Join-Path $projectRoot 'artifacts\final-hardware-gates'
    if (-not (Test-Path -LiteralPath $root)) {
        throw "Final hardware gate artifact root not found: $root"
    }
    $latest =
        Get-ChildItem -LiteralPath $root -Directory |
            Sort-Object Name -Descending |
            Select-Object -First 1
    if ($null -eq $latest) {
        throw "No final hardware gate run folders found under $root"
    }
    $SummaryPath = Join-Path $latest.FullName 'final-hardware-gates-summary.json'
}
$SummaryPath = (Resolve-Path -LiteralPath $SummaryPath).Path

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $projectRoot ('artifacts\final-hardware-postrun-audit-validation\validation-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$summary = Read-JsonFile $SummaryPath
$postRunAudit = Get-PropertyValue $summary 'postRunAudit'
$readinessPath = Resolve-OptionalPath (Get-PropertyValue $postRunAudit 'readinessReport')
$goalAuditPath = Resolve-OptionalPath (Get-PropertyValue $postRunAudit 'goalCompletionAudit')
$readiness = if ($readinessPath) { Read-JsonFile $readinessPath } else { $null }
$goalAudit = if ($goalAuditPath) { Read-JsonFile $goalAuditPath } else { $null }

$summaryApk = Get-PropertyValue $summary 'apk'
$summaryApkSha256 = Get-PropertyValue $summaryApk 'sha256'
$readinessApk = Get-PropertyValue $readiness 'apk'
$goalApk = Get-PropertyValue $goalAudit 'apk'
$readinessEvidence = Get-PropertyValue $readiness 'evidence'
$goalReadinessJson = Resolve-OptionalPath (Get-PropertyValue $goalAudit 'readinessJson')
$readinessFinalWrapper = Resolve-OptionalPath (Get-PropertyValue $readinessEvidence 'finalHardwareGateWrapper')
$summaryStatus = Get-PropertyValue $summary 'status'
$summaryDryRun = [bool](Get-PropertyValue $summary 'dryRun')
$readinessStatus = Get-PropertyValue $readiness 'status'
$goalStatus = Get-PropertyValue $goalAudit 'status'
$completionAllowed = Get-PropertyValue $goalAudit 'completionAllowed'

$checks = New-Object System.Collections.Generic.List[object]
Add-Check $checks 'final hardware summary exists' (Test-Path -LiteralPath $SummaryPath) $SummaryPath
Add-Check $checks 'post-run audit status pass' ((Get-PropertyValue $postRunAudit 'status') -eq 'pass') "status=$(Get-PropertyValue $postRunAudit 'status')"
Add-Check $checks 'post-run readiness report exists' (-not [string]::IsNullOrWhiteSpace($readinessPath)) $readinessPath
Add-Check $checks 'post-run goal audit exists' (-not [string]::IsNullOrWhiteSpace($goalAuditPath)) $goalAuditPath
Add-Check $checks 'goal audit readiness matches postrun readiness' (Same-Path $goalReadinessJson $readinessPath) "goalReadiness=$goalReadinessJson readiness=$readinessPath"
Add-Check $checks 'goal audit status matches readiness' (Test-GoalStatusMatchesReadiness -GoalStatus $goalStatus -ReadinessStatus $readinessStatus) "goalStatus=$goalStatus readinessStatus=$readinessStatus"
Add-Check $checks 'readiness points back to final wrapper summary' (Same-Path $readinessFinalWrapper $SummaryPath) "readinessFinalWrapper=$readinessFinalWrapper summary=$SummaryPath"
Add-Check $checks 'readiness apk hash matches final wrapper' ((Get-PropertyValue $readinessApk 'sha256') -eq $summaryApkSha256) "readiness=$(Get-PropertyValue $readinessApk 'sha256') summary=$summaryApkSha256"
Add-Check $checks 'goal audit apk hash matches final wrapper' ((Get-PropertyValue $goalApk 'sha256') -eq $summaryApkSha256) "goal=$(Get-PropertyValue $goalApk 'sha256') summary=$summaryApkSha256"
if ($summaryDryRun) {
    Add-Check $checks 'dry run cannot allow completion' ($completionAllowed -eq $false) "completionAllowed=$completionAllowed"
}
if ($completionAllowed -eq $true) {
    Add-Check $checks 'completion allowed requires complete real wrapper' (
        $summaryStatus -eq 'pass' -and
        -not $summaryDryRun -and
        $readinessStatus -eq 'complete' -and
        $goalStatus -eq 'complete'
    ) "summaryStatus=$summaryStatus dryRun=$summaryDryRun readinessStatus=$readinessStatus goalStatus=$goalStatus completionAllowed=$completionAllowed"
}

$failed = @($checks | Where-Object { -not $_.passed })
$result = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
    summaryPath = $SummaryPath
    readinessReport = $readinessPath
    goalCompletionAudit = $goalAuditPath
    apkSha256 = $summaryApkSha256
    checks = $checks
}

$jsonPath = Join-Path $OutDir 'final-hardware-postrun-audit-validation.json'
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

if ($result.status -ne 'pass') {
    throw "Final hardware post-run audit validation failed. See $jsonPath"
}

Write-Host "PASS final hardware post-run audit validation"
Write-Host "JSON: $jsonPath"
