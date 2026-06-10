[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$AdbPath = 'adb',
    [string]$ApkPath = '',
    [int]$TimeoutSeconds = 120,
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
$outDir = Join-Path $projectRoot "artifacts\qpolar\$runId"

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Invoke-Adb {
    & $AdbPath -s $Serial @args
}

function Get-FilteredLogcat {
    Invoke-Adb logcat -d -v time |
        Select-String -Pattern 'BigRedButtonStudy|BRB_POLAR|BRB_ECG|FATAL EXCEPTION|E/AndroidRuntime'
}

function Save-Evidence {
    Get-FilteredLogcat |
        ForEach-Object { $_.Line } |
        Set-Content -LiteralPath (Join-Path $outDir 'logcat-filtered.txt') -Encoding UTF8
    Invoke-Adb shell dumpsys activity activities |
        Select-String -Pattern 'bigredbutton|mCurrentFocus|mFocusedApp|ResumedActivity|topResumedActivity' |
        Set-Content -LiteralPath (Join-Path $outDir 'foreground.txt') -Encoding UTF8
}

$model = (Invoke-Adb shell getprop ro.product.model).Trim()
$android = (Invoke-Adb shell getprop ro.build.version.release).Trim()
$apkHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ApkPath).Hash
$summaryPath = Join-Path $outDir 'quest-polar-h10-live-smoke-summary.json'
$detected = $false
$connected = $false
$pmdReady = $false
$ecgStreaming = $false
$rawSamples = 0
$requestedMtu = 0
$negotiatedMtu = 0
$ecgHz = 0
$lowLatencyConfigMarkers = 0

function Write-PolarSummary {
    param(
        [string]$Status,
        [string]$ErrorMessage = ''
    )
    [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = $Status
        error = $ErrorMessage
        serial = $Serial
        model = $model
        android = $android
        package = $package
        apk = [pscustomobject]@{
            path = $ApkPath
            sha256 = $apkHash
        }
        evidenceDir = $outDir
        detected = $script:detected
        connected = $script:connected
        pmdReady = $script:pmdReady
        ecgStreaming = $script:ecgStreaming
        ecgSamples = $script:rawSamples
        requestedMtu = $script:requestedMtu
        expectedRequestedMtu = 70
        negotiatedMtu = $script:negotiatedMtu
        ecgSampleRateHz = $script:ecgHz
        lowLatencyConfigMarkers = $script:lowLatencyConfigMarkers
        note = 'Live Polar H10 smoke only. It proves BLE PMD ECG samples reach the headset/app, but it does not validate full condition export or human controller-contact pressing.'
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
}

Write-Host "Quest Polar H10 live smoke target: serial=$Serial model=$model android=$android"
Write-Host "Operator requirement: wear a Polar H10, keep the sensor awake/wet, and keep it near the headset."
Write-Host "This gate proves live BLE PMD ECG streaming only; it does not replace the full experiment or physical button gate."

try {
    if (-not $SkipInstall) {
        Write-Host "Installing $ApkPath"
        Invoke-Adb install -r -d -g $ApkPath | Tee-Object -FilePath (Join-Path $outDir 'install.txt') | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb install failed with exit code $LASTEXITCODE"
        }
    }

    Invoke-Adb shell pm grant $package android.permission.BLUETOOTH_SCAN 2>$null | Out-Null
    Invoke-Adb shell pm grant $package android.permission.BLUETOOTH_CONNECT 2>$null | Out-Null
    Invoke-Adb shell pm grant $package android.permission.ACCESS_FINE_LOCATION 2>$null | Out-Null
    Invoke-Adb logcat -c
    Invoke-Adb shell am start -n $activity |
        Tee-Object -FilePath (Join-Path $outDir 'launch.txt') |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "adb launch failed with exit code $LASTEXITCODE"
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        $markers = Get-FilteredLogcat
        if ($markers | Select-String -Pattern 'FATAL EXCEPTION|E/AndroidRuntime') {
            $markers | ForEach-Object { $_.Line } | Set-Content -LiteralPath (Join-Path $outDir 'failure-markers.txt') -Encoding UTF8
            throw "Fatal runtime marker detected during Polar H10 live smoke."
        }

        $logText = ($markers | ForEach-Object { $_.Line }) -join "`n"
        $detected = $detected -or ($logText -match 'BRB_POLAR_H10_STATUS .*detected=true')
        $connected = $connected -or ($logText -match 'BRB_POLAR_H10_STATUS .*connected=true')
        $pmdReady = $pmdReady -or ($logText -match 'BRB_POLAR_H10_STATUS .*pmdReady=true')
        $ecgStreaming = $ecgStreaming -or ($logText -match 'BRB_POLAR_H10_STATUS .*ecgStreaming=true')
        $lowLatencyMatches = [regex]::Matches(
            $logText,
            'BRB_POLAR_H10_LOW_LATENCY_CONFIG .*requestedMtu=70.*strategy=minimum_mtu_low_latency_ecg'
        )
        $script:lowLatencyConfigMarkers = [math]::Max($script:lowLatencyConfigMarkers, $lowLatencyMatches.Count)

        $statusMatches = [regex]::Matches(
            $logText,
            'BRB_POLAR_H10_STATUS .*ecgSamples=(?<samples>\d+).*requestedMtu=(?<requested>\d+).*negotiatedMtu=(?<negotiated>\d+).*ecgHz=(?<hz>\d+)'
        )
        foreach ($match in $statusMatches) {
            $script:rawSamples = [math]::Max($script:rawSamples, [int]$match.Groups['samples'].Value)
            $script:requestedMtu = [math]::Max($script:requestedMtu, [int]$match.Groups['requested'].Value)
            $script:negotiatedMtu = [math]::Max($script:negotiatedMtu, [int]$match.Groups['negotiated'].Value)
            $script:ecgHz = [math]::Max($script:ecgHz, [int]$match.Groups['hz'].Value)
        }

        if ($ecgStreaming -and $rawSamples -gt 0 -and $ecgHz -eq 130) {
            break
        }
        $elapsed = [int]($TimeoutSeconds - [math]::Max(0, ($deadline - (Get-Date)).TotalSeconds))
        Write-Host "Waiting for Polar PMD ECG stream... elapsed ${elapsed}s detected=$detected connected=$connected pmdReady=$pmdReady ecgStreaming=$ecgStreaming ecgSamples=$rawSamples"
    }

    Save-Evidence

    if (-not $detected) {
        throw "No Polar H10-compatible BLE advertisement/status was detected within $TimeoutSeconds seconds. See $outDir"
    }
    if (-not $connected) {
        throw "Polar H10 was detected but not connected within $TimeoutSeconds seconds. See $outDir"
    }
    if (-not $pmdReady) {
        throw "Polar H10 connected but PMD service/data notifications did not become ready. See $outDir"
    }
    if (-not $ecgStreaming) {
        throw "Polar H10 PMD ECG stream did not start. See $outDir"
    }
    if ($rawSamples -lt 1) {
        throw "Polar H10 PMD ECG stream started but no raw ECG samples were observed. See $outDir"
    }
    if ($ecgHz -ne 130) {
        throw "Polar H10 PMD ECG stream reported unexpected sample rate $ecgHz Hz; expected 130 Hz."
    }
    if ($requestedMtu -ne 70) {
        throw "Polar H10 PMD ECG stream reported requested MTU $requestedMtu; expected minimum ECG MTU 70."
    }
    if ($lowLatencyConfigMarkers -lt 1) {
        throw "Missing Polar H10 minimum-MTU low-latency config marker with requestedMtu=70."
    }

    Write-PolarSummary -Status 'pass'
    Write-Host "PASS Quest Polar H10 live smoke"
    Write-Host "Summary: $summaryPath"
} catch {
    Write-PolarSummary -Status 'fail' -ErrorMessage $_.Exception.Message
    Write-Host "FAIL Quest Polar H10 live smoke"
    Write-Host "Summary: $summaryPath"
    throw
} finally {
    Save-Evidence
    Invoke-Adb shell am force-stop $package | Out-Null
}
