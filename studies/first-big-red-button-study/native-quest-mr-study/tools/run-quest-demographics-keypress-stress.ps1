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
if ([string]::IsNullOrWhiteSpace($AdbPath) -or $AdbPath -eq 'adb') {
    $localAdb = Join-Path $projectRoot 'artifacts\toolchain\android-platform-tools\platform-tools\adb.exe'
    if (Test-Path -LiteralPath $localAdb) {
        $AdbPath = (Resolve-Path $localAdb).Path
    } else {
        $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
        if ($null -ne $adbCommand) {
            $AdbPath = $adbCommand.Source
        }
    }
}
if (-not (Test-Path -LiteralPath $AdbPath) -and $null -eq (Get-Command $AdbPath -ErrorAction SilentlyContinue)) {
    throw "adb not found. Pass -AdbPath or install platform-tools. Tried '$AdbPath'."
}
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk'
}
$ApkPath = (Resolve-Path $ApkPath).Path
$apkItem = Get-Item -LiteralPath $ApkPath
$apkSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $ApkPath).Hash
$package = 'org.bigredbutton.firststudy'
$activity = 'org.bigredbutton.firststudy/.BigRedButtonStudyActivity'
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$logRunId = $runId -replace '[^A-Za-z0-9_]', '_'
$outDir = Join-Path $projectRoot "artifacts\quest-demographics-keypress-stress\$runId"
$remoteScreenshot = '/sdcard/Download/brb_demographics_keypress_stress.png'

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$comparisons = New-Object System.Collections.Generic.List[object]

function Invoke-Adb {
    & $AdbPath -s $Serial @args
}

function Get-LogText {
    return (Invoke-Adb logcat -d -v time | Out-String)
}

function Save-FilteredLog {
    param([string]$Name)
    $path = Join-Path $outDir "$Name-logcat-filtered.txt"
    (Get-LogText) -split "`r?`n" |
        Select-String -Pattern 'BigRedButtonStudy|BRB_|FATAL EXCEPTION|E/AndroidRuntime' |
        ForEach-Object { $_.Line } |
        Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Wait-LogPattern {
    param(
        [string]$Pattern,
        [string]$Description,
        [int]$Seconds = $TimeoutSeconds
    )
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 250
        $log = Get-LogText
        if ($log -match 'FATAL EXCEPTION|E/AndroidRuntime') {
            $path = Save-FilteredLog "failure-$($Description -replace '[^A-Za-z0-9_-]', '_')"
            throw "Fatal runtime marker while waiting for $Description. See $path"
        }
        if ($log -match $Pattern) {
            return $log
        }
    }
    $path = Save-FilteredLog "timeout-$($Description -replace '[^A-Za-z0-9_-]', '_')"
    throw "Timed out waiting for $Description ($Pattern). See $path"
}

function Add-Comparison {
    param(
        [string]$Name,
        $Expected,
        $Observed,
        [string]$Evidence
    )
    $pass = $Expected -eq $Observed
    $script:comparisons.Add([pscustomobject]@{
        name = $Name
        expected = $Expected
        observed = $Observed
        pass = $pass
        evidence = $Evidence
    }) | Out-Null
    if ($pass) {
        Write-Host "PASS $Name expected=$Expected observed=$Observed"
    } else {
        Write-Host "FAIL $Name expected=$Expected observed=$Observed"
    }
}

function Invoke-DemographicsValidationCommand {
    param([string]$Command)
    Invoke-Adb shell am start -n $activity `
        --ez brb.demographicsKeyboardValidation true `
        --es brb.demographicsKeyboardValidationSession $runId `
        --es brb.demographicsKeyboardValidationCommand $Command |
        Tee-Object -FilePath (Join-Path $outDir "command-$Command.txt") |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "demographics validation command '$Command' failed with exit code $LASTEXITCODE"
    }
    Start-Sleep -Milliseconds 350
}

function Send-TextToken {
    param([string]$Text)
    Write-Host "Typing token '$Text' as key events"
    foreach ($char in $Text.ToCharArray()) {
        if ($char -eq ' ') {
            Send-KeyCode -KeyCode 62 -Name "SPACE"
            continue
        }

        if ([char]::IsDigit($char)) {
            $digit = [int]([string]$char)
            Send-KeyCode -KeyCode (7 + $digit) -Name "DIGIT_$digit"
            continue
        }

        $upper = [char]::ToUpperInvariant($char)
        if ($upper -ge 'A' -and $upper -le 'Z') {
            $keyCode = 29 + ([int][char]$upper - [int][char]'A')
            Send-KeyCode -KeyCode $keyCode -Name "LETTER_$upper"
            continue
        }

        throw "Unsupported scripted keyboard character '$char'."
    }
}

function Send-KeyCode {
    param([int]$KeyCode, [string]$Name)
    Invoke-Adb shell input keyevent $KeyCode | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "adb keyevent $Name failed with exit code $LASTEXITCODE"
    }
    Start-Sleep -Milliseconds 350
}

function Save-Screenshot {
    Invoke-Adb shell screencap -p $remoteScreenshot | Out-Null
    Invoke-Adb pull $remoteScreenshot (Join-Path $outDir 'demographics-keypress-after-entry.png') |
        Tee-Object -FilePath (Join-Path $outDir 'screenshot.pull.txt') |
        Out-Host
    Invoke-Adb shell rm $remoteScreenshot | Out-Null
}

$model = (Invoke-Adb shell getprop ro.product.model).Trim()
$android = (Invoke-Adb shell getprop ro.build.version.release).Trim()
Write-Host "Quest demographics keypress stress target: serial=$Serial model=$model android=$android"
Write-Host "This test focuses the real visible EditText controls, then sends ADB key/text events for George Fejer, Enter/Next, 34, and Enter/Done."

try {
    if (-not $SkipInstall) {
        Write-Host "Installing $ApkPath"
        Write-Host "APK SHA-256: $apkSha256"
        Invoke-Adb install -r -d -g $ApkPath | Tee-Object -FilePath (Join-Path $outDir 'install.txt') | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb install failed with exit code $LASTEXITCODE"
        }
    }

    Invoke-Adb logcat -c | Out-Null
    Invoke-Adb shell am force-stop $package | Out-Null
    Invoke-Adb shell am start -n $activity --ez brb.demographicsKeyboardValidation true --es brb.demographicsKeyboardValidationSession $runId |
        Tee-Object -FilePath (Join-Path $outDir 'launch.txt') |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "adb launch failed with exit code $LASTEXITCODE"
    }

    Wait-LogPattern 'BRB_STUDY_CREATED .*demographicsKeyboardValidation=true' 'validation launch extra'
    Wait-LogPattern "BRB_DEMOGRAPHICS_VALIDATION_SESSION session=$logRunId accepted=true state=start" 'validation session marker'
    Wait-LogPattern 'BRB_PANEL_GLITCH state=end mode=intro trigger=demographics' 'stable demographics panel after intro'

    Invoke-DemographicsValidationCommand 'focus_name'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_EDITTEXT_FOCUS field=name .*keyboardMode=text' 'name EditText focus'
    Wait-LogPattern 'BRB_SOFT_KEYBOARD_REQUEST reason=field_name keyboardMode=text .*focusedView=EditText' 'name keyboard request'

    Send-TextToken 'George'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_VALUE field=name .*value=george .*length=6 .*source=activity_key_event' 'George typed into name'
    Send-KeyCode 62 'SPACE'
    Send-TextToken 'Fejer'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_VALUE field=name .*value=george_fejer .*length=12 .*source=activity_key_event' 'George Fejer typed into name'

    Send-KeyCode 66 'ENTER_NEXT'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_EDITOR_ACTION field=name action=next .*source=activity_key_event' 'Enter advances name to age'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_EDITTEXT_FOCUS field=age .*keyboardMode=number' 'age EditText focus'
    Wait-LogPattern 'BRB_SOFT_KEYBOARD_REQUEST reason=field_age keyboardMode=number .*focusedView=EditText' 'age keyboard request'

    Send-TextToken '3'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_VALUE field=age keyboardMode=number value=3 .*length=1 .*source=activity_key_event' 'age first digit typed'
    Send-TextToken '4'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_VALUE field=age keyboardMode=number value=34 .*length=2 .*source=activity_key_event' 'age second digit typed'
    Send-KeyCode 66 'ENTER_DONE'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_EDITOR_ACTION field=age action=done .*source=activity_key_event' 'Enter completes age'

    Start-Sleep -Seconds 1
    Save-Screenshot
    $logPath = Save-FilteredLog 'final'
    $logText = Get-Content -Raw -LiteralPath $logPath

    Add-Comparison 'name retained all keypress text' $true ($logText -match 'BRB_DEMOGRAPHICS_TEXT_VALUE field=name .*value=george_fejer .*length=12 .*source=activity_key_event') $logPath
    Add-Comparison 'name advanced only after Enter/Next' $true ($logText -match 'BRB_DEMOGRAPHICS_TEXT_EDITOR_ACTION field=name action=next .*source=activity_key_event') $logPath
    Add-Comparison 'age accepted two typed digits' $true ($logText -match 'BRB_DEMOGRAPHICS_TEXT_VALUE field=age keyboardMode=number value=34 .*length=2 .*source=activity_key_event') $logPath
    Add-Comparison 'age completed through Enter/Done' $true ($logText -match 'BRB_DEMOGRAPHICS_TEXT_EDITOR_ACTION field=age action=done .*source=activity_key_event') $logPath

    $failed = @($comparisons | Where-Object { -not $_.pass })
    $summary = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
        serial = $Serial
        model = $model
        android = $android
        package = $package
        apk = $ApkPath
        apkSha256 = $apkSha256
        apkSizeBytes = $apkItem.Length
        evidenceDir = $outDir
        screenshot = Join-Path $outDir 'demographics-keypress-after-entry.png'
        logcat = $logPath
        typedName = 'George Fejer'
        typedAge = '34'
        comparisons = $comparisons
        note = 'Headset stress for real focused Android EditText input using ADB key/text events. It complements the app-side demographics validation route by proving typed text is retained until explicit Enter/Next.'
    }
    $summaryPath = Join-Path $outDir 'quest-demographics-keypress-stress-summary.json'
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

    if ($failed.Count -gt 0) {
        throw "Quest demographics keypress stress failed: $($failed.Count) comparison(s) failed. Summary: $summaryPath"
    }

    Write-Host "PASS Quest demographics keypress stress"
    Write-Host "Summary: $summaryPath"
} catch {
    $logPath = Save-FilteredLog 'failure'
    $summaryPath = Join-Path $outDir 'quest-demographics-keypress-stress-summary.json'
    [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = 'fail'
        serial = $Serial
        model = $model
        android = $android
        package = $package
        apk = $ApkPath
        apkSha256 = $apkSha256
        evidenceDir = $outDir
        logcat = $logPath
        error = $_.Exception.Message
        comparisons = $comparisons
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    Write-Host "FAIL Quest demographics keypress stress"
    Write-Host "Summary: $summaryPath"
    throw
} finally {
    Invoke-Adb shell am force-stop $package | Out-Null
}
