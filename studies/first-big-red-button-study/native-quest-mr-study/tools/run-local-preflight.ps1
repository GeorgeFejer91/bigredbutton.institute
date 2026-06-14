[CmdletBinding()]
param(
    [string]$JavaHome = 'D:\GithubVR\Immersive video player 0.0.6\.toolchain\jdk-17',
    [string]$AndroidSdkRoot = 'D:\GithubVR\Immersive video player 0.0.6\.toolchain\android-sdk',
    [string]$GradleUserHome = 'D:\GithubVR\Immersive video player 0.0.6\.toolchain\gradle-home',
    [switch]$Clean,
    [switch]$SkipBuild,
    [switch]$SkipLayoutPreviews
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $projectRoot "artifacts\local-preflight\$runId"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$steps = New-Object System.Collections.Generic.List[object]

function Invoke-PreflightStep {
    param(
        [string]$Name,
        [scriptblock]$Action
    )
    $logPath = Join-Path $outDir (($Name -replace '[^A-Za-z0-9_.-]', '-') + '.txt')
    Write-Host "PRELIGHT START $Name"
    $started = Get-Date
    try {
        & $Action *>&1 |
            Tee-Object -FilePath $logPath |
            Out-Host
        $steps.Add([pscustomobject]@{
            name = $Name
            status = 'pass'
            startedAt = $started.ToString('o')
            endedAt = (Get-Date).ToString('o')
            log = $logPath
        })
        Write-Host "PREFLIGHT PASS $Name"
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

function Get-LatestFile {
    param(
        [string]$Path,
        [string]$Filter
    )
    if (-not (Test-Path $Path)) {
        return $null
    }
    return Get-ChildItem -LiteralPath $Path -Filter $Filter -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Get-LatestDirectory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return $null
    }
    return Get-ChildItem -LiteralPath $Path -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

try {
    if (-not $SkipBuild) {
        Invoke-PreflightStep 'build-apk' {
            if ($Clean) {
                & (Join-Path $PSScriptRoot 'build-apk.ps1') `
                    -JavaHome $JavaHome `
                    -AndroidSdkRoot $AndroidSdkRoot `
                    -GradleUserHome $GradleUserHome `
                    -Clean
            } else {
                & (Join-Path $PSScriptRoot 'build-apk.ps1') `
                    -JavaHome $JavaHome `
                    -AndroidSdkRoot $AndroidSdkRoot `
                    -GradleUserHome $GradleUserHome
            }
        }
    }

    Invoke-PreflightStep 'validate-study-static' {
        & (Join-Path $PSScriptRoot 'validate-study.ps1') -SkipBuild
    }

    Invoke-PreflightStep 'validate-audio-assets' {
        & (Join-Path $PSScriptRoot 'validate-audio-assets.ps1')
    }

    Invoke-PreflightStep 'validate-localized-audio-catalog' {
        & (Join-Path $PSScriptRoot 'validate-localized-audio.ps1')
    }

    Invoke-PreflightStep 'validate-export-schema-synthetic' {
        & (Join-Path $PSScriptRoot 'validate-export-schema.ps1') -Synthetic
    }

    Invoke-PreflightStep 'test-native-keyboard-contract' {
        & (Join-Path $PSScriptRoot 'test-native-keyboard-contract.ps1')
    }

    Invoke-PreflightStep 'test-physical-press-evidence-validator' {
        & (Join-Path $PSScriptRoot 'test-physical-press-evidence-validator.ps1')
    }

    Invoke-PreflightStep 'test-final-hardware-postrun-audit-validator' {
        & (Join-Path $PSScriptRoot 'test-final-hardware-postrun-audit-validator.ps1')
    }

    $latestFinalHardwareSummary = $null
    $finalHardwareRoot = Join-Path $projectRoot 'artifacts\final-hardware-gates'
    if (Test-Path $finalHardwareRoot) {
        $latestFinalHardwareDir = Get-LatestDirectory $finalHardwareRoot
        if ($latestFinalHardwareDir) {
            $candidateFinalHardwareSummary = Join-Path $latestFinalHardwareDir.FullName 'final-hardware-gates-summary.json'
            if (Test-Path $candidateFinalHardwareSummary) {
                $latestFinalHardwareSummary = $candidateFinalHardwareSummary
            }
        }
    }
    if ($latestFinalHardwareSummary) {
        Invoke-PreflightStep 'validate-final-hardware-postrun-audit' {
            & (Join-Path $PSScriptRoot 'validate-final-hardware-postrun-audit.ps1') -SummaryPath $latestFinalHardwareSummary
        }
    }

    if (-not $SkipLayoutPreviews) {
        Invoke-PreflightStep 'render-layout-previews' {
            & (Join-Path $PSScriptRoot 'render-layout-previews.ps1')
        }

        Invoke-PreflightStep 'render-name-keyboard-preview' {
            & (Join-Path $PSScriptRoot 'render-name-keyboard-preview.ps1')
        }
    }

    $apkPath = Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk'
    $apkInfo = $null
    if (Test-Path $apkPath) {
        $apkItem = Get-Item -LiteralPath $apkPath
        $apkInfo = [pscustomobject]@{
            path = $apkItem.FullName
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $apkItem.FullName).Hash
            sizeBytes = $apkItem.Length
            lastWriteTime = $apkItem.LastWriteTime.ToString('o')
        }
    }

    $latestLocalValidation = Get-LatestFile (Join-Path $projectRoot 'artifacts\local-validation') 'validation-*.json'
    $latestAudioValidation = Get-LatestFile (Join-Path $projectRoot 'artifacts\audio-validation') 'audio-validation-*.json'
    $latestLocalizedAudioValidation = Get-LatestFile (Join-Path $projectRoot 'artifacts\localized-audio-validation') 'localized-audio-validation-*.json'
    $latestExportSchema = Get-LatestFile (Join-Path $projectRoot 'artifacts\export-schema-validation') 'export-schema-validation-*.json'
    $latestNativeKeyboardValidation = Get-LatestFile (Join-Path $projectRoot 'artifacts\native-keyboard-validation') 'native-keyboard-validation-*.json'
    $latestPhysicalEvidenceTest = Get-LatestDirectory (Join-Path $projectRoot 'artifacts\ppe-tests')
    $latestFinalHardwarePostRunAuditTest = Get-LatestDirectory (Join-Path $projectRoot 'artifacts\final-hardware-postrun-audit-tests')
    $latestFinalHardwarePostRunAuditValidation = Get-LatestDirectory (Join-Path $projectRoot 'artifacts\final-hardware-postrun-audit-validation')
    $latestLayoutPreview = Get-LatestDirectory (Join-Path $projectRoot 'artifacts\layout-previews')
    $latestNameKeyboardPreview = Get-LatestDirectory (Join-Path $projectRoot 'artifacts\name-keyboard-preview')

    $summaryPath = Join-Path $outDir 'local-preflight-summary.json'
    $summary = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = 'pass'
        projectRoot = $projectRoot
        runId = $runId
        outDir = $outDir
        skippedBuild = [bool]$SkipBuild
        skippedLayoutPreviews = [bool]$SkipLayoutPreviews
        steps = $steps
        apk = $apkInfo
        latestArtifacts = [pscustomobject]@{
            localValidation = if ($latestLocalValidation) { $latestLocalValidation.FullName } else { $null }
            audioValidation = if ($latestAudioValidation) { $latestAudioValidation.FullName } else { $null }
            localizedAudioValidation = if ($latestLocalizedAudioValidation) { $latestLocalizedAudioValidation.FullName } else { $null }
            exportSchemaValidation = if ($latestExportSchema) { $latestExportSchema.FullName } else { $null }
            nativeKeyboardValidation = if ($latestNativeKeyboardValidation) { $latestNativeKeyboardValidation.FullName } else { $null }
            physicalEvidenceValidatorTest = if ($latestPhysicalEvidenceTest) { Join-Path $latestPhysicalEvidenceTest.FullName 'physical-evidence-validator-test-summary.json' } else { $null }
            finalHardwarePostRunAuditValidatorTest = if ($latestFinalHardwarePostRunAuditTest) { Join-Path $latestFinalHardwarePostRunAuditTest.FullName 'final-hardware-postrun-audit-validator-test-summary.json' } else { $null }
            finalHardwarePostRunAuditValidation = if ($latestFinalHardwarePostRunAuditValidation) { Join-Path $latestFinalHardwarePostRunAuditValidation.FullName 'final-hardware-postrun-audit-validation.json' } else { $null }
            layoutPreview = if ($latestLayoutPreview) { $latestLayoutPreview.FullName } else { $null }
            nameKeyboardPreview = if ($latestNameKeyboardPreview) { Join-Path $latestNameKeyboardPreview.FullName 'name-keyboard-preview-summary.json' } else { $null }
        }
        remainingHardGate = 'Human-worn Quest controller-contact plus live-H10 ECG export validation via tools/run-quest-physical-press-validation.ps1'
    }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    Write-Host "PASS local preflight"
    Write-Host "Summary: $summaryPath"
} catch {
    $summaryPath = Join-Path $outDir 'local-preflight-summary.json'
    $summary = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = 'fail'
        projectRoot = $projectRoot
        runId = $runId
        outDir = $outDir
        steps = $steps
        error = $_.Exception.Message
        remainingHardGate = 'Human-worn Quest controller-contact plus live-H10 ECG export validation via tools/run-quest-physical-press-validation.ps1'
    }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    Write-Host "FAIL local preflight"
    Write-Host "Summary: $summaryPath"
    throw
}
