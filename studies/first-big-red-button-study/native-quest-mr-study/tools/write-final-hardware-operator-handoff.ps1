[CmdletBinding()]
param(
    [string]$ReadinessJson = '',
    [string]$GoalAuditJson = '',
    [string]$Serial = '',
    [string]$AdbPath = 'adb',
    [string]$OutDir = '',
    [switch]$CheckAdb,
    [switch]$RefreshAudit,
    [switch]$RequireReady
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

function Get-JsonPropertyValue {
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

function Get-LatestJson {
    param(
        [string]$RelativePath,
        [string]$Filter
    )
    $root = Join-Path $projectRoot $RelativePath
    if (-not (Test-Path -LiteralPath $root)) {
        throw "Artifact folder not found: $root"
    }
    $latest =
        Get-ChildItem -LiteralPath $root -Recurse -File -Filter $Filter |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $latest) {
        throw "No $Filter found under $root"
    }
    return $latest.FullName
}

function Get-LatestJsonAfter {
    param(
        [string]$RelativePath,
        [string]$Filter,
        [datetime]$StartedAt
    )
    $root = Join-Path $projectRoot $RelativePath
    if (-not (Test-Path -LiteralPath $root)) {
        return $null
    }
    $latest =
        Get-ChildItem -LiteralPath $root -Recurse -File -Filter $Filter |
        Where-Object { $_.LastWriteTime -ge $StartedAt.AddSeconds(-2) } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $latest) {
        return $null
    }
    return $latest.FullName
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

if ($RefreshAudit) {
    $startedAt = Get-Date
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'write-readiness-report.ps1')
    if ($LASTEXITCODE -ne 0) {
        throw "write-readiness-report.ps1 exited with code $LASTEXITCODE"
    }
    $freshReadiness = Get-LatestJsonAfter -RelativePath 'artifacts\readiness-report' -Filter 'readiness-report.json' -StartedAt $startedAt
    if ([string]::IsNullOrWhiteSpace($freshReadiness)) {
        throw 'write-readiness-report.ps1 completed, but no fresh readiness-report.json was found.'
    }
    $ReadinessJson = $freshReadiness

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'write-goal-completion-audit.ps1') -ReadinessJson $ReadinessJson
    if ($LASTEXITCODE -ne 0) {
        throw "write-goal-completion-audit.ps1 exited with code $LASTEXITCODE"
    }
    $freshGoalAudit = Get-LatestJsonAfter -RelativePath 'artifacts\goal-completion-audit' -Filter 'goal-completion-audit.json' -StartedAt $startedAt
    if ([string]::IsNullOrWhiteSpace($freshGoalAudit)) {
        throw 'write-goal-completion-audit.ps1 completed, but no fresh goal-completion-audit.json was found.'
    }
    $GoalAuditJson = $freshGoalAudit
}

if ([string]::IsNullOrWhiteSpace($ReadinessJson)) {
    $ReadinessJson = Get-LatestJson -RelativePath 'artifacts\readiness-report' -Filter 'readiness-report.json'
}
if ([string]::IsNullOrWhiteSpace($GoalAuditJson)) {
    $GoalAuditJson = Get-LatestJson -RelativePath 'artifacts\goal-completion-audit' -Filter 'goal-completion-audit.json'
}

$ReadinessJson = (Resolve-Path $ReadinessJson).Path
$GoalAuditJson = (Resolve-Path $GoalAuditJson).Path
$readiness = Read-JsonFile $ReadinessJson
$goalAudit = Read-JsonFile $GoalAuditJson

$apkPath = Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk'
if (-not (Test-Path -LiteralPath $apkPath)) {
    throw "Missing debug APK: $apkPath"
}
$apkItem = Get-Item -LiteralPath $apkPath
$apkSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $apkItem.FullName).Hash
$readinessApkSha256 = Get-JsonPropertyValue (Get-JsonPropertyValue $readiness 'apk') 'sha256'
$goalApkSha256 = Get-JsonPropertyValue (Get-JsonPropertyValue $goalAudit 'apk') 'sha256'
$goalReadinessJson = Get-JsonPropertyValue $goalAudit 'readinessJson'

$requirements = @((Get-JsonPropertyValue $goalAudit 'requirements'))
$finalAuditChain = $requirements | Where-Object { (Get-JsonPropertyValue $_ 'id') -eq 'final_hardware_postrun_audit_chain' } | Select-Object -First 1
$missingRequirementIds = @((Get-JsonPropertyValue $goalAudit 'missingRequirementIds'))
$externalMissingRows =
    @($requirements | Where-Object {
        (Get-JsonPropertyValue $_ 'kind') -eq 'external_hardware' -and
        -not [bool](Get-JsonPropertyValue $_ 'proven')
    })

$apkHashMatches =
    $apkSha256 -eq $readinessApkSha256 -and
    $apkSha256 -eq $goalApkSha256
$goalAuditBoundToReadiness = Same-Path $goalReadinessJson $ReadinessJson
$softwareRequirementsProven = [bool](Get-JsonPropertyValue $goalAudit 'softwareRequirementsProven')
$finalAuditChainProven = $null -ne $finalAuditChain -and [bool](Get-JsonPropertyValue $finalAuditChain 'proven')
$completionAllowed = [bool](Get-JsonPropertyValue $goalAudit 'completionAllowed')
$readyForOperator =
    $apkHashMatches -and
    $goalAuditBoundToReadiness -and
    $softwareRequirementsProven -and
    $finalAuditChainProven
$softwareAuditReadyForOperator = $readyForOperator

$adbCheck = [pscustomobject]@{
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

if ($CheckAdb) {
    $readyForOperator = $readyForOperator -and [bool]$adbCheck.deviceReady
}

$commandSerial =
    if (-not [string]::IsNullOrWhiteSpace($Serial)) {
        $Serial
    } elseif ($CheckAdb -and -not [string]::IsNullOrWhiteSpace($adbCheck.detectedSerial)) {
        $adbCheck.detectedSerial
    } else {
        '<quest-serial>'
    }
$finalCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-final-hardware-gates.ps1 -Serial $commandSerial -AdbPath $AdbPath"
$dryRunCommand = "$finalCommand -DryRun"

$status =
    if ($completionAllowed) {
        'complete'
    } elseif ($readyForOperator) {
        'ready_for_operator_external_gates'
    } else {
        'not_ready_for_operator'
    }

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $projectRoot ('artifacts\final-operator-handoff\handoff-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$jsonPath = Join-Path $OutDir 'final-operator-handoff.json'
$mdPath = Join-Path $OutDir 'final-operator-handoff.md'

$handoff = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = $status
    readyForOperatorExternalGates = $readyForOperator
    completionAllowed = $completionAllowed
    projectRoot = $projectRoot
    apk = [pscustomobject]@{
        path = $apkItem.FullName
        sha256 = $apkSha256
        sizeBytes = $apkItem.Length
        lastWriteTime = $apkItem.LastWriteTime.ToString('o')
    }
    readiness = [pscustomobject]@{
        path = $ReadinessJson
        status = Get-JsonPropertyValue $readiness 'status'
        apkSha256 = $readinessApkSha256
    }
    goalAudit = [pscustomobject]@{
        path = $GoalAuditJson
        status = Get-JsonPropertyValue $goalAudit 'status'
        apkSha256 = $goalApkSha256
        readinessJson = $goalReadinessJson
        readinessMatchesSelected = $goalAuditBoundToReadiness
        softwareRequirementsProven = $softwareRequirementsProven
        externalHardwareRequirementsProven = [bool](Get-JsonPropertyValue $goalAudit 'externalHardwareRequirementsProven')
        finalHardwarePostRunAuditChainProven = $finalAuditChainProven
        missingRequirementIds = $missingRequirementIds
    }
    checks = [pscustomobject]@{
        apkHashMatchesReadinessAndGoalAudit = $apkHashMatches
        goalAuditBoundToSelectedReadiness = $goalAuditBoundToReadiness
        softwareRequirementsProven = $softwareRequirementsProven
        finalHardwarePostRunAuditChainProven = $finalAuditChainProven
        softwareAuditReadyForOperator = $softwareAuditReadyForOperator
        adbDeviceReadyWhenRequested = if ($CheckAdb) { [bool]$adbCheck.deviceReady } else { $null }
    }
    adb = $adbCheck
    remainingExternalGates = @($externalMissingRows | ForEach-Object {
        [pscustomobject]@{
            id = Get-JsonPropertyValue $_ 'id'
            requirement = Get-JsonPropertyValue $_ 'requirement'
            evidence = Get-JsonPropertyValue $_ 'evidence'
            missing = Get-JsonPropertyValue $_ 'missing'
        }
    })
    commands = [pscustomobject]@{
        finalHardwareGates = $finalCommand
        dryRun = $dryRunCommand
        livePolarSmoke = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-polar-h10-live-smoke.ps1 -Serial $commandSerial -AdbPath $AdbPath"
        controllerContactSmoke = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-controller-contact-smoke.ps1 -Serial $commandSerial -AdbPath $AdbPath"
        physicalExportGate = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-physical-press-validation.ps1 -Serial $commandSerial -AdbPath $AdbPath"
    }
    operatorRequirements = @(
        'Wear an awake/wet Polar H10 near the headset before launch.',
        'Wear the Quest and hold a tracked Quest controller.',
        'Physically press the modeled 3D Big Red Button with the controller at least once in each condition.',
        'Keep the headset and Polar H10 on until exports are pulled and validated.'
    )
}
$handoff | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Final Hardware Operator Handoff') | Out-Null
$lines.Add('') | Out-Null
$lines.Add("- Generated: $($handoff.generatedAt)") | Out-Null
$lines.Add("- Status: $status") | Out-Null
$lines.Add("- Ready for operator external gates: $readyForOperator") | Out-Null
$lines.Add("- Completion allowed: $completionAllowed") | Out-Null
$lines.Add("- APK SHA-256: $apkSha256") | Out-Null
$lines.Add('- Readiness: `' + $ReadinessJson + '`') | Out-Null
$lines.Add('- Goal audit: `' + $GoalAuditJson + '`') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## Required Command') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('```powershell') | Out-Null
$lines.Add($finalCommand) | Out-Null
$lines.Add('```') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('Optional command-construction check only; this is not hardware evidence:') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('```powershell') | Out-Null
$lines.Add($dryRunCommand) | Out-Null
$lines.Add('```') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## Operator Requirements') | Out-Null
$lines.Add('') | Out-Null
foreach ($requirement in $handoff.operatorRequirements) {
    $lines.Add("- $requirement") | Out-Null
}
$lines.Add('') | Out-Null
$lines.Add('## Evidence Checks') | Out-Null
$lines.Add('') | Out-Null
$lines.Add("- APK hash matches readiness and goal audit: $apkHashMatches") | Out-Null
$lines.Add("- Goal audit bound to selected readiness: $goalAuditBoundToReadiness") | Out-Null
$lines.Add("- Software requirements proven: $softwareRequirementsProven") | Out-Null
$lines.Add("- Final hardware post-run audit chain proven: $finalAuditChainProven") | Out-Null
if ($CheckAdb) {
    $lines.Add("- ADB device ready: $($adbCheck.deviceReady) serial=$($adbCheck.detectedSerial)") | Out-Null
}
$lines.Add('') | Out-Null
$lines.Add('## Remaining External Gates') | Out-Null
$lines.Add('') | Out-Null
foreach ($gate in @($handoff.remainingExternalGates)) {
    $lines.Add('- `' + $gate.id + '`: ' + $gate.missing) | Out-Null
}
$lines.Add('') | Out-Null
$lines.Add('This handoff does not prove live Polar H10 streaming or human controller-contact pressing. It only proves the current software/readiness/audit chain is coherent enough to start the operator hardware gates.') | Out-Null
$lines | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host "PASS final hardware operator handoff"
Write-Host "Status: $status"
Write-Host "Ready for operator external gates: $readyForOperator"
Write-Host "JSON: $jsonPath"
Write-Host "Markdown: $mdPath"

if ($RequireReady -and -not $readyForOperator) {
    throw 'Final hardware operator handoff is not ready. Inspect the JSON checks before running hardware gates.'
}
