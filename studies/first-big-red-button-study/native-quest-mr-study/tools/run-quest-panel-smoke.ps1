[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$AdbPath = 'adb',
    [string]$ApkPath = '',
    [int]$TimeoutSeconds = 45,
    [switch]$SkipInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk'
}
$ApkPath = (Resolve-Path $ApkPath).Path
$package = 'org.bigredbutton.firststudy'
$activity = 'org.bigredbutton.firststudy/.BigRedButtonStudyActivity'
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $projectRoot "artifacts\quest-panel-smoke\$runId"
$remoteDemographics = '/sdcard/Download/brb_panel_smoke_demographics.png'
$remotePictographic = '/sdcard/Download/brb_panel_smoke_pictographic.png'
$runtimeFailurePattern = 'FATAL EXCEPTION|E/AndroidRuntime'
$conflictingValidationPattern = 'BRB_AUDIO_RIG_STRESS_COMMAND|BRB_DEMOGRAPHICS_VALIDATION_COMMAND|BRB_KEYEVENT_VALIDATION_COMMAND'

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Invoke-Adb {
    & $AdbPath -s $Serial @args
}

function Save-Screenshot {
    param(
        [string]$RemotePath,
        [string]$LocalName
    )
    Invoke-Adb shell screencap -p $RemotePath | Out-Null
    Invoke-Adb pull $RemotePath (Join-Path $outDir $LocalName) |
        Tee-Object -FilePath (Join-Path $outDir "$LocalName.pull.txt") |
        Out-Host
    Invoke-Adb shell rm $RemotePath | Out-Null
}

$model = (Invoke-Adb shell getprop ro.product.model).Trim()
$android = (Invoke-Adb shell getprop ro.build.version.release).Trim()
Write-Host "Quest panel/glitch smoke target: serial=$Serial model=$model android=$android"
Write-Host "This hidden mode captures demographics and first questionnaire panels without starting study audio or exporting data."
Write-Host "It expects questionnaire intro MP3/glitch markers rather than the retired startup chime markers."

try {
    if (-not $SkipInstall) {
        Write-Host "Installing $ApkPath"
        Invoke-Adb install -r -d -g $ApkPath | Tee-Object -FilePath (Join-Path $outDir 'install.txt') | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb install failed with exit code $LASTEXITCODE"
        }
    }

    Invoke-Adb shell am force-stop $package | Out-Null
    Start-Sleep -Milliseconds 500
    Invoke-Adb logcat -c
    Invoke-Adb shell am start -n $activity --ez brb.panelSmoke true |
        Tee-Object -FilePath (Join-Path $outDir 'launch.txt') |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "adb launch failed with exit code $LASTEXITCODE"
    }

    $demographicsReady = $false
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 1
        $markers = Invoke-Adb logcat -d -v time |
            Select-String -Pattern "BRB_QUESTIONNAIRE_INTRO_CUE trigger=demographics|BRB_PANEL_GLITCH state=start mode=intro trigger=demographics|$runtimeFailurePattern|$conflictingValidationPattern"
        if ($markers | Select-String -Pattern $runtimeFailurePattern) {
            $markers | Set-Content -LiteralPath (Join-Path $outDir 'failure-markers.txt') -Encoding UTF8
            throw "Fatal runtime marker detected before demographics screenshot."
        }
        if ($markers | Select-String -Pattern $conflictingValidationPattern) {
            $markers | Set-Content -LiteralPath (Join-Path $outDir 'failure-markers.txt') -Encoding UTF8
            throw "Conflicting validation mode marker detected before demographics screenshot."
        }
        if ($markers | Select-String -Pattern 'BRB_QUESTIONNAIRE_INTRO_CUE trigger=demographics') {
            $demographicsReady = $true
            break
        }
    }
    if (-not $demographicsReady) {
        Invoke-Adb logcat -d -v time |
            Select-String -Pattern 'BigRedButtonStudy|BRB_|FATAL EXCEPTION|E/AndroidRuntime' |
            Set-Content -LiteralPath (Join-Path $outDir 'timeout-logcat.txt') -Encoding UTF8
        Invoke-Adb shell dumpsys activity activities |
            Select-String -Pattern 'bigredbutton|mCurrentFocus|mFocusedApp|ResumedActivity|topResumedActivity' |
            Set-Content -LiteralPath (Join-Path $outDir 'timeout-foreground.txt') -Encoding UTF8
        throw "Demographics questionnaire intro cue marker was not observed within $TimeoutSeconds seconds."
    }
    Start-Sleep -Seconds 3
    Save-Screenshot -RemotePath $remoteDemographics -LocalName 'demographics-panel.png'

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $pictographicReady = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 1
        $markers = Invoke-Adb logcat -d -v time |
            Select-String -Pattern "BRB_PANEL_SMOKE_PICTOGRAPHIC_READY|BRB_QUESTIONNAIRE_INTRO_CUE|BRB_PANEL_GLITCH|$runtimeFailurePattern|$conflictingValidationPattern"
        if ($markers | Select-String -Pattern $runtimeFailurePattern) {
            $markers | Set-Content -LiteralPath (Join-Path $outDir 'failure-markers.txt') -Encoding UTF8
            throw "Fatal runtime marker detected during panel smoke."
        }
        if ($markers | Select-String -Pattern $conflictingValidationPattern) {
            $markers | Set-Content -LiteralPath (Join-Path $outDir 'failure-markers.txt') -Encoding UTF8
            throw "Conflicting validation mode marker detected during panel smoke."
        }
        if ($markers | Select-String -Pattern 'BRB_PANEL_SMOKE_PICTOGRAPHIC_READY') {
            $pictographicReady = $true
            break
        }
    }

    if (-not $pictographicReady) {
        Invoke-Adb logcat -d -v time |
            Select-String -Pattern 'BigRedButtonStudy|BRB_|FATAL EXCEPTION|E/AndroidRuntime' |
            Set-Content -LiteralPath (Join-Path $outDir 'timeout-logcat.txt') -Encoding UTF8
        Invoke-Adb shell dumpsys activity activities |
            Select-String -Pattern 'bigredbutton|mCurrentFocus|mFocusedApp|ResumedActivity|topResumedActivity' |
            Set-Content -LiteralPath (Join-Path $outDir 'timeout-foreground.txt') -Encoding UTF8
        throw "Pictographic panel was not reached within $TimeoutSeconds seconds."
    }

    Start-Sleep -Seconds 1
    Save-Screenshot -RemotePath $remotePictographic -LocalName 'pictographic-panel.png'

    Invoke-Adb logcat -d -v time |
        Select-String -Pattern 'BigRedButtonStudy|BRB_|GLTF|FATAL EXCEPTION|E/AndroidRuntime' |
        Set-Content -LiteralPath (Join-Path $outDir 'logcat-filtered.txt') -Encoding UTF8
    Invoke-Adb shell dumpsys activity activities |
        Select-String -Pattern 'bigredbutton|mCurrentFocus|mFocusedApp|ResumedActivity|topResumedActivity' |
        Set-Content -LiteralPath (Join-Path $outDir 'foreground.txt') -Encoding UTF8

    $logText = Get-Content -Raw -LiteralPath (Join-Path $outDir 'logcat-filtered.txt')
    $demographicsIntroCue = $logText -match 'BRB_QUESTIONNAIRE_INTRO_CUE trigger=demographics'
    $questionnaireIntroCue = $logText -match 'BRB_QUESTIONNAIRE_INTRO_CUE trigger=panel_smoke_pictographic'
    $demographicsGlitch = $logText -match 'BRB_PANEL_GLITCH state=start mode=intro trigger=demographics'
    $questionnaireGlitch = $logText -match 'BRB_PANEL_GLITCH state=start mode=intro trigger=panel_smoke_pictographic'
    $noConditionStart = -not ($logText -match 'BRB_CONDITION_START')
    $noExport = -not ($logText -match 'BRB_EXPORT_COMPLETE')
    if (-not $demographicsIntroCue) { throw "Missing demographics questionnaire intro cue marker." }
    if (-not $questionnaireIntroCue) { throw "Missing first questionnaire intro cue marker." }
    if (-not $demographicsGlitch) { throw "Missing demographics blue glitch marker." }
    if (-not $questionnaireGlitch) { throw "Missing first questionnaire blue glitch marker." }
    if (-not $noConditionStart) { throw "Panel smoke unexpectedly started a condition." }
    if (-not $noExport) { throw "Panel smoke unexpectedly exported data." }

    $summary = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = 'pass'
        serial = $Serial
        model = $model
        android = $android
        package = $package
        apk = $ApkPath
        evidenceDir = $outDir
        demographicsIntroCue = $demographicsIntroCue
        firstQuestionnaireIntroCue = $questionnaireIntroCue
        demographicsGlitch = $demographicsGlitch
        firstQuestionnaireGlitch = $questionnaireGlitch
        pictographicReady = $pictographicReady
        conditionStarted = -not $noConditionStart
        exportCreated = -not $noExport
        note = 'Hidden panel smoke only. It validates panel visibility plus questionnaire intro MP3/glitch markers without starting audio or exporting data.'
    }
    $summaryPath = Join-Path $outDir 'quest-panel-smoke-summary.json'
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    Write-Host "PASS Quest panel/glitch smoke"
    Write-Host "Summary: $summaryPath"
} finally {
    Invoke-Adb shell am force-stop $package | Out-Null
}
