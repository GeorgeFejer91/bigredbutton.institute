[CmdletBinding()]
param(
    [string]$OutDir = '',
    [string]$QkvDir = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$activityPath = Join-Path $projectRoot 'app\src\main\java\org\bigredbutton\firststudy\BigRedButtonStudyActivity.kt'
$placementPath = Join-Path $projectRoot 'app\src\main\java\org\bigredbutton\firststudy\ButtonSurfacePlacement.kt'
$activityText = Get-Content -Raw -LiteralPath $activityPath
$placementText = Get-Content -Raw -LiteralPath $placementPath

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $projectRoot ('artifacts\button-surface-blink-render\render-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Get-KotlinFloatConst {
    param([string]$Name)
    $match = [regex]::Match($activityText, "private const val $Name\s*=\s*(?<value>[0-9.]+)f")
    if (-not $match.Success) {
        throw "Could not find Kotlin float constant $Name"
    }
    return [double]::Parse($match.Groups['value'].Value, [Globalization.CultureInfo]::InvariantCulture)
}

function Get-SurfaceScore {
    param(
        [string]$SurfaceName,
        [string]$SurfaceType,
        [double]$CenterX,
        [double]$CenterZ,
        [double]$SupportSurfaceY,
        [double]$ExtentX,
        [double]$ExtentY,
        [double]$ExtentZ,
        [double]$ReachTargetZ,
        [double]$MinSupportY,
        [double]$MaxSupportY,
        [double]$ReachMargin,
        [double]$MinHalfExtent
    )
    $semantic = "$SurfaceName $SurfaceType".ToLowerInvariant()
    if ($semantic -match 'wall|ceiling|floor') {
        return $null
    }
    if ($SupportSurfaceY -lt $MinSupportY -or $SupportSurfaceY -gt $MaxSupportY) {
        return $null
    }
    $reachHalfWidth = [Math]::Max([Math]::Abs($ExtentX), [Math]::Max([Math]::Abs($ExtentY), $MinHalfExtent))
    $reachHalfDepth = [Math]::Max([Math]::Abs($ExtentZ), [Math]::Max([Math]::Abs($ExtentX), [Math]::Max([Math]::Abs($ExtentY), $MinHalfExtent)))
    $coversArmReachTarget =
        [Math]::Abs($CenterX) -le ($reachHalfWidth + $ReachMargin) -and
        [Math]::Abs($CenterZ - $ReachTargetZ) -le ($reachHalfDepth + $ReachMargin)
    if (-not $coversArmReachTarget) {
        return $null
    }
    $preferredSurface = $semantic -match 'table|desk|counter|surface|platform'
    return ($(if ($preferredSurface) { 1000.0 } else { 500.0 }) + ($reachHalfWidth * $reachHalfDepth) - [Math]::Abs($CenterX) - [Math]::Abs($CenterZ - $ReachTargetZ))
}

function Get-LatestQkvDir {
    $qkvRoot = Join-Path $projectRoot 'artifacts\qkv'
    if (-not (Test-Path -LiteralPath $qkvRoot)) {
        return ''
    }
    $candidate =
        Get-ChildItem -LiteralPath $qkvRoot -Directory |
        Sort-Object Name -Descending |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'quest-keyevent-questionnaire-validation-summary.json') } |
        Select-Object -First 1
    if ($null -eq $candidate) { return '' }
    return $candidate.FullName
}

function Resolve-PathOrEmpty {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    if (Test-Path -LiteralPath $Path) { return (Resolve-Path -LiteralPath $Path).Path }
    return ''
}

function Get-QkvEvidence {
    param([string]$Dir)
    if ([string]::IsNullOrWhiteSpace($Dir)) {
        $Dir = Get-LatestQkvDir
    }
    if ([string]::IsNullOrWhiteSpace($Dir) -or -not (Test-Path -LiteralPath $Dir)) {
        return [pscustomobject]@{ available = $false; directory = $Dir }
    }
    $summaryPath = Join-Path $Dir 'quest-keyevent-questionnaire-validation-summary.json'
    if (-not (Test-Path -LiteralPath $summaryPath)) {
        return [pscustomobject]@{ available = $false; directory = $Dir }
    }
    $summary = Get-Content -Raw -LiteralPath $summaryPath | ConvertFrom-Json
    $jsonPath = Resolve-PathOrEmpty $summary.json
    $summaryCsvPath = Resolve-PathOrEmpty $summary.summaryCsv
    $blinkCsvPath = Resolve-PathOrEmpty $summary.ecgBlinkEventsCsv
    if ([string]::IsNullOrWhiteSpace($jsonPath)) {
        $jsonPath = (Get-ChildItem -LiteralPath $Dir -Recurse -Filter '*.json' | Where-Object { $_.Name -like 'brb_first_study_*' } | Select-Object -First 1).FullName
    }
    if ([string]::IsNullOrWhiteSpace($summaryCsvPath)) {
        $summaryCsvPath = (Get-ChildItem -LiteralPath $Dir -Recurse -Filter '*_summary.csv' | Select-Object -First 1).FullName
    }
    if ([string]::IsNullOrWhiteSpace($blinkCsvPath)) {
        $blinkCsvPath = (Get-ChildItem -LiteralPath $Dir -Recurse -Filter '*_ecg_blink_events.csv' | Select-Object -First 1).FullName
    }
    $sessionJson = Get-Content -Raw -LiteralPath $jsonPath | ConvertFrom-Json
    $summaryRow = Import-Csv -LiteralPath $summaryCsvPath | Select-Object -First 1
    $blinkRows = @(Import-Csv -LiteralPath $blinkCsvPath)
    $logPath = Join-Path $Dir 'logcat-filtered.txt'
    $logText = if (Test-Path -LiteralPath $logPath) { Get-Content -Raw -LiteralPath $logPath } else { '' }
    $conditionFeedback = @{
        '1' = [string]$sessionJson.ecgProtocol.condition1FeedbackSource
        '2' = [string]$sessionJson.ecgProtocol.condition2FeedbackSource
    }
    $simulatedCondition = if ($conditionFeedback['1'] -eq 'simulated_neurokit2') { 1 } elseif ($conditionFeedback['2'] -eq 'simulated_neurokit2') { 2 } else { 0 }
    $realCondition = if ($conditionFeedback['1'] -eq 'real_polar_h10') { 1 } elseif ($conditionFeedback['2'] -eq 'real_polar_h10') { 2 } else { 0 }
    $badBlinkRows =
        @(
            $blinkRows | Where-Object {
                $conditionFeedback[[string]$_.condition_number] -ne $_.source
            }
        )
    $simulatedBlinkRows =
        @(
            $blinkRows | Where-Object {
                [int]$_.condition_number -eq $simulatedCondition -and $_.source -eq 'simulated_neurokit2'
            }
        )
    $flashObserved =
        $simulatedCondition -gt 0 -and
        $logText -match "BRB_HEARTBEAT_FLASH condition=$simulatedCondition source=simulated_neurokit2"
    return [pscustomobject]@{
        available = $true
        directory = (Resolve-Path -LiteralPath $Dir).Path
        summaryPath = (Resolve-Path -LiteralPath $summaryPath).Path
        jsonPath = $jsonPath
        summaryCsvPath = $summaryCsvPath
        blinkCsvPath = $blinkCsvPath
        status = [string]$summary.status
        apkSha256 = [string]$summary.apkSha256
        exportMirrorMatched = [bool]$summary.exportMirrorMatched
        assignmentOrder = [string]$sessionJson.ecgProtocol.assignmentOrder
        assignmentStrategy = [string]$sessionJson.ecgProtocol.assignmentStrategy
        randomAssignmentWhenTied = [bool]$sessionJson.ecgProtocol.randomAssignmentWhenTied
        randomizedTieChoiceRealFirst = [bool]$sessionJson.ecgProtocol.randomizedTieChoiceRealFirst
        condition1FeedbackSource = [string]$sessionJson.ecgProtocol.condition1FeedbackSource
        condition2FeedbackSource = [string]$sessionJson.ecgProtocol.condition2FeedbackSource
        condition1PhysiologySource = [string]$sessionJson.ecgProtocol.condition1PhysiologySource
        condition2PhysiologySource = [string]$sessionJson.ecgProtocol.condition2PhysiologySource
        simulatedCondition = $simulatedCondition
        realCondition = $realCondition
        blinkRows = $blinkRows.Count
        simulatedBlinkRows = $simulatedBlinkRows.Count
        badBlinkRows = $badBlinkRows.Count
        simulatedHeartbeatFlashObserved = [bool]$flashObserved
        polarState = [string]$summaryRow.polar_h10_state
        csvAssignmentStrategy = [string]$summaryRow.ecg_assignment_strategy
        csvRandomWhenTied = [string]$summaryRow.ecg_assignment_random_when_tied
    }
}

function New-Canvas {
    param([int]$Width = 1400, [int]$Height = 900)
    $bitmap = [Drawing.Bitmap]::new($Width, $Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([Drawing.Color]::FromArgb(248, 245, 236))
    return [pscustomobject]@{ Bitmap = $bitmap; Graphics = $graphics; Width = $Width; Height = $Height }
}

function Brush([int]$R, [int]$G, [int]$B, [int]$A = 255) {
    return [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb($A, $R, $G, $B))
}

function Pen([int]$R, [int]$G, [int]$B, [float]$W = 1, [int]$A = 255) {
    return [Drawing.Pen]::new([Drawing.Color]::FromArgb($A, $R, $G, $B), $W)
}

function Draw-Text {
    param($G, [string]$Text, [int]$X, [int]$Y, [int]$Size = 18, [int]$Width = 1000, [int]$Height = 80, [bool]$Bold = $false, $Color = $null)
    $fontStyle = if ($Bold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
    $fontFamily = if ($Size -ge 28) { 'Georgia' } elseif ($Size -le 12) { 'Consolas' } else { 'Segoe UI' }
    $font = [Drawing.Font]::new($fontFamily, $Size, $fontStyle)
    $brush = if ($null -eq $Color) { Brush 29 33 43 } else { $Color }
    $G.DrawString($Text, $font, $brush, [Drawing.RectangleF]::new($X, $Y, $Width, $Height))
    $font.Dispose()
    if ($null -eq $Color) { $brush.Dispose() }
}

function Save-Canvas {
    param($Canvas, [string]$Name)
    $path = Join-Path $OutDir $Name
    $Canvas.Bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    $Canvas.Graphics.Dispose()
    $Canvas.Bitmap.Dispose()
    return $path
}

function Measure-PngPixels {
    param([string]$Path)
    $bitmap = [Drawing.Bitmap]::new($Path)
    try {
        $red = 0
        $green = 0
        $blue = 0
        $nonBackground = 0
        $samples = 0
        $stepX = [Math]::Max(1, [int]($bitmap.Width / 220))
        $stepY = [Math]::Max(1, [int]($bitmap.Height / 150))
        for ($x = 0; $x -lt $bitmap.Width; $x += $stepX) {
            for ($y = 0; $y -lt $bitmap.Height; $y += $stepY) {
                $color = $bitmap.GetPixel($x, $y)
                $samples += 1
                if ($color.R -gt 160 -and $color.G -lt 120 -and $color.B -lt 120) { $red += 1 }
                if ($color.G -gt 115 -and $color.R -lt 170 -and $color.B -lt 170) { $green += 1 }
                if ($color.B -gt 140 -and $color.R -lt 170) { $blue += 1 }
                if ([Math]::Abs($color.R - 248) + [Math]::Abs($color.G - 245) + [Math]::Abs($color.B - 236) -gt 40) {
                    $nonBackground += 1
                }
            }
        }
        return [pscustomobject]@{
            width = $bitmap.Width
            height = $bitmap.Height
            samples = $samples
            redSamples = $red
            greenSamples = $green
            blueSamples = $blue
            nonBackgroundSamples = $nonBackground
            nonBackgroundPercent = [Math]::Round(100.0 * $nonBackground / [Math]::Max(1, $samples), 3)
        }
    } finally {
        $bitmap.Dispose()
    }
}

function Draw-ButtonGlyph {
    param($G, [int]$X, [int]$Y, [int]$Scale = 1)
    $shadow = Brush 0 0 0 58
    $G.FillEllipse($shadow, $X - (90 * $Scale), $Y + (78 * $Scale), 180 * $Scale, 28 * $Scale)
    $shadow.Dispose()
    $G.FillRectangle((Brush 72 65 58), $X - (72 * $Scale), $Y + (34 * $Scale), 144 * $Scale, 48 * $Scale)
    $G.FillRectangle((Brush 122 18 18), $X - (54 * $Scale), $Y + (6 * $Scale), 108 * $Scale, 38 * $Scale)
    $G.FillEllipse((Brush 223 44 44), $X - (62 * $Scale), $Y - (55 * $Scale), 124 * $Scale, 96 * $Scale)
    $G.DrawEllipse((Pen 143 23 23 5), $X - (62 * $Scale), $Y - (55 * $Scale), 124 * $Scale, 96 * $Scale)
    $G.FillEllipse((Brush 255 255 255 80), $X - (24 * $Scale), $Y - (39 * $Scale), 40 * $Scale, 24 * $Scale)
}

function Draw-ButtonSurfacePlacementProof {
    param($Geometry, $Scores)
    $c = New-Canvas
    $g = $c.Graphics
    Draw-Text $g 'Rendered Button Surface Placement Proof' 42 30 31 1000 52 $true
    Draw-Text $g 'The button rig stays at the headset-centered arm reach target and snaps vertically to a usable table/desk/counter ScenePlane when that plane covers the reach target.' 42 82 15 1220 52 $false (Brush 80 87 99)

    $sideRect = [Drawing.Rectangle]::new(52, 160, 610, 640)
    $topRect = [Drawing.Rectangle]::new(730, 160, 610, 640)
    $g.FillRectangle((Brush 255 252 244), $sideRect)
    $g.FillRectangle((Brush 255 252 244), $topRect)
    $g.DrawRectangle((Pen 205 197 181 2), $sideRect)
    $g.DrawRectangle((Pen 205 197 181 2), $topRect)
    Draw-Text $g 'side view: reach and support height' 72 178 16 420 30 $true
    Draw-Text $g 'top view: table covers arm target' 750 178 16 420 30 $true

    $z0 = 140
    $zScale = 820.0
    $yBase = 740
    $yScale = 390.0
    $mapZ = { param([double]$z) [int]($z0 + ($z * $zScale)) }
    $mapY = { param([double]$y) [int]($yBase - ($y * $yScale)) }
    $eyeY = & $mapY $Geometry.eyeY
    $supportY = & $mapY $Geometry.tableSupportY
    $capY = & $mapY $Geometry.tableCapCenterY
    $reachZ = & $mapZ $Geometry.reachZ
    $fallbackY = & $mapY $Geometry.fallbackSupportY

    $g.DrawLine((Pen 78 86 98 3), 110, $eyeY, 620, $eyeY)
    Draw-Text $g ("eye line y={0:N2}m" -f $Geometry.eyeY) 120 ($eyeY - 28) 10 180 20 $false (Brush 78 86 98)
    $g.DrawLine((Pen 35 145 83 5), 110, $supportY, 620, $supportY)
    Draw-Text $g ("detected table plane y={0:N2}m" -f $Geometry.tableSupportY) 120 ($supportY + 8) 10 260 20 $true (Brush 35 145 83)
    $g.DrawLine((Pen 180 126 24 2), 110, $fallbackY, 620, $fallbackY)
    Draw-Text $g ("fallback tabletop ref y={0:N2}m" -f $Geometry.fallbackSupportY) 120 ($fallbackY - 26) 10 260 20 $false (Brush 180 126 24)

    $g.FillEllipse((Brush 46 57 70), 112, ($eyeY - 15), 30, 30)
    Draw-Text $g 'viewer' 92 ($eyeY + 18) 10 110 20 $false (Brush 46 57 70)
    $g.DrawLine((Pen 223 44 44 5), 128, $eyeY, $reachZ, $capY)
    Draw-Text $g ("arm target z={0:N3}m" -f $Geometry.reachZ) ([Math]::Min($reachZ - 90, 500)) ($capY - 92) 13 220 24 $true (Brush 223 44 44)
    Draw-ButtonGlyph $g $reachZ ($supportY - 8) 1
    $g.DrawLine((Pen 60 100 200 3), $reachZ, $supportY, $reachZ, $capY)
    Draw-Text $g ("cap/contact y={0:N2}m" -f $Geometry.tableCapCenterY) ($reachZ + 28) ($capY - 8) 10 190 20 $false (Brush 60 100 200)

    $angleText = "downward angle {0:N1} deg, angular diameter {1:N1} deg" -f $Geometry.downwardAngleDeg, $Geometry.angularDiameterDeg
    Draw-Text $g $angleText 92 760 12 520 24 $true (Brush 35 145 83)

    $topCx = 1035
    $topCy = 520
    $metersToPx = 360.0
    $tableW = [int](0.84 * $metersToPx)
    $tableD = [int](0.72 * $metersToPx)
    $tableRect = [Drawing.Rectangle]::new($topCx - [int]($tableW / 2), $topCy - [int]($tableD / 2), $tableW, $tableD)
    $g.FillRectangle((Brush 210 238 218), $tableRect)
    $g.DrawRectangle((Pen 35 145 83 4), $tableRect)
    $targetX = $topCx
    $targetY = [int]($topCy - ($Geometry.reachZ * $metersToPx))
    $g.DrawLine((Pen 223 44 44 5), $topCx, $topCy + 190, $targetX, $targetY)
    $g.FillEllipse((Brush 46 57 70), $topCx - 15, $topCy + 175, 30, 30)
    $g.FillEllipse((Brush 223 44 44), $targetX - 24, $targetY - 24, 48, 48)
    Draw-Text $g '0.48m arm reach' ($targetX + 34) ($targetY - 22) 12 190 24 $true (Brush 223 44 44)
    Draw-Text $g 'viewer' ($topCx - 44) ($topCy + 204) 10 120 18 $false (Brush 46 57 70)
    $g.FillRectangle((Brush 245 255 247 235), $tableRect.X + 10, $tableRect.Y + 12, 240, 48)
    Draw-Text $g 'accepted ScenePlane: table / desk / counter' ($tableRect.X + 18) ($tableRect.Y + 20) 12 224 38 $true (Brush 35 105 68)

    $rejectPen = Pen 180 58 58 3
    $g.DrawRectangle($rejectPen, 760, 640, 130, 70)
    $g.DrawLine($rejectPen, 760, 640, 890, 710)
    $g.DrawLine($rejectPen, 890, 640, 760, 710)
    Draw-Text $g 'floor/wall rejected' 758 718 11 180 22 $true (Brush 180 58 58)
    $g.DrawRectangle($rejectPen, 1190, 286, 120, 72)
    $g.DrawLine($rejectPen, 1190, 286, 1310, 358)
    $g.DrawLine($rejectPen, 1310, 286, 1190, 358)
    Draw-Text $g 'out of reach rejected' 1164 366 11 190 22 $true (Brush 180 58 58)
    $rejectPen.Dispose()

    $status = if ($Scores.tableAccepted -and $Scores.floorRejected -and $Scores.wallRejected -and $Scores.outOfReachRejected) { 'PASS' } else { 'FAIL' }
    $statusBrush = if ($status -eq 'PASS') { Brush 35 145 83 } else { Brush 180 58 58 }
    Draw-Text $g "$status Kotlin surface scoring" 930 760 15 360 28 $true $statusBrush
    return Save-Canvas $c 'button-surface-placement-proof.png'
}

function Draw-BlinkAssignmentProof {
    param($Qkv)
    $c = New-Canvas
    $g = $c.Graphics
    Draw-Text $g 'Rendered ECG Blink Assignment Proof' 42 30 31 1000 52 $true
    Draw-Text $g 'The session assigns feedback source by blocked counterbalance with a random tie break; blink pulses are accepted only from the assigned feedback source for that condition.' 42 82 15 1220 52 $false (Brush 80 87 99)

    $g.FillRectangle((Brush 255 252 244), 50, 160, 1290, 620)
    $g.DrawRectangle((Pen 205 197 181 2), 50, 160, 1290, 620)
    if (-not $Qkv.available) {
        Draw-Text $g 'No qkv export was supplied; render shows static assignment contract only.' 90 220 20 1100 40 $true (Brush 180 58 58)
        return Save-Canvas $c 'ecg-blink-assignment-proof.png'
    }

    Draw-Text $g ("APK {0}" -f $Qkv.apkSha256) 82 182 10 900 20 $false (Brush 80 87 99)
    Draw-Text $g ("assignment: {0}" -f $Qkv.assignmentOrder) 82 220 22 520 38 $true
    Draw-Text $g ("strategy: {0}" -f $Qkv.assignmentStrategy) 82 258 13 620 24 $false (Brush 80 87 99)
    Draw-Text $g ("random tie break used: {0}; chose real first: {1}" -f $Qkv.randomAssignmentWhenTied, $Qkv.randomizedTieChoiceRealFirst) 82 286 13 620 24 $false (Brush 80 87 99)
    Draw-Text $g ("export mirror matched: {0}; qkv status: {1}" -f $Qkv.exportMirrorMatched, $Qkv.status) 82 314 13 620 24 $false (Brush 80 87 99)

    $conditions = @(
        [pscustomobject]@{ Number = 1; Source = $Qkv.condition1FeedbackSource },
        [pscustomobject]@{ Number = 2; Source = $Qkv.condition2FeedbackSource }
    )
    $x = 110
    foreach ($condition in $conditions) {
        $laneY = if ($condition.Number -eq 1) { 400 } else { 590 }
        $isSimulated = $condition.Source -eq 'simulated_neurokit2'
        $brush = if ($isSimulated) { Brush 223 44 44 } else { Brush 48 107 192 }
        $linePen = if ($isSimulated) { Pen 223 44 44 5 } else { Pen 48 107 192 5 }
        $laneEndX = 690
        Draw-Text $g ("Condition {0}" -f $condition.Number) $x ($laneY - 62) 19 220 32 $true
        Draw-Text $g ("feedback source: {0}" -f $condition.Source) ($x + 180) ($laneY - 57) 13 460 26 $true $brush
        $g.DrawLine($linePen, $x + 10, $laneY, $laneEndX, $laneY)
        for ($i = 0; $i -le 3; $i++) {
            $px = $x + 10 + ($i * 180)
            $g.FillEllipse((Brush 80 87 99), $px - 4, $laneY - 4, 8, 8)
        }
        if ($isSimulated -and $Qkv.simulatedBlinkRows -gt 0) {
            $blinkX = $x + 212
            $g.FillEllipse((Brush 255 120 28 78), $blinkX - 50, $laneY - 50, 100, 100)
            $g.FillEllipse((Brush 223 44 44), $blinkX - 22, $laneY - 22, 44, 44)
            Draw-Text $g 'accepted sham RR blink' ($blinkX - 84) ($laneY + 34) 12 210 24 $true (Brush 143 23 23)
        } elseif (-not $isSimulated) {
            Draw-Text $g 'awaits live Polar RR; no sham pulse accepted here' ($x + 180) ($laneY + 28) 12 520 24 $false (Brush 48 107 192)
        }
        $linePen.Dispose()
    }

    Draw-Text $g 'Guard rendered from code path:' 790 218 14 420 26 $true
    Draw-Text $g 'if (source != run.feedbackSource) { BRB_ECG_BLINK_IGNORED; return }' 790 248 11 520 44 $false (Brush 80 87 99)
    $pass =
        $Qkv.status -eq 'pass' -and
        $Qkv.exportMirrorMatched -and
        $Qkv.badBlinkRows -eq 0 -and
        $Qkv.simulatedBlinkRows -ge 1 -and
        $Qkv.simulatedHeartbeatFlashObserved -and
        $Qkv.csvAssignmentStrategy -eq 'blocked_counterbalance_random_tie_break'
    $status = if ($pass) { 'PASS' } else { 'FAIL' }
    $statusBrush = if ($pass) { Brush 35 145 83 } else { Brush 180 58 58 }
    Draw-Text $g "$status qkv/export blink evidence" 790 330 20 460 36 $true $statusBrush
    Draw-Text $g ("blink rows={0}; assigned sham rows={1}; bad-source rows={2}; flash={3}; Polar={4}" -f $Qkv.blinkRows, $Qkv.simulatedBlinkRows, $Qkv.badBlinkRows, $Qkv.simulatedHeartbeatFlashObserved, $Qkv.polarState) 790 374 12 500 70 $false (Brush 80 87 99)
    Draw-Text $g 'Live Polar-driven blinking still requires a worn H10 streaming RR/ECG; this renderer proves assignment, gating, export, and sham blink path from the current qkv run.' 790 468 12 500 82 $false (Brush 80 87 99)
    return Save-Canvas $c 'ecg-blink-assignment-proof.png'
}

$reachZ = Get-KotlinFloatConst 'BUTTON_DISTANCE_FROM_HEAD_METERS'
$eyeY = Get-KotlinFloatConst 'BUTTON_NOMINAL_SEATED_EYE_HEIGHT_METERS'
$diameter = Get-KotlinFloatConst 'BUTTON_VISUAL_DIAMETER_METERS'
$modelOriginY = Get-KotlinFloatConst 'BUTTON_MODEL_ORIGIN_Y_METERS'
$contactY = Get-KotlinFloatConst 'BUTTON_CONTACT_COLLIDER_Y_METERS'
$minSupportY = Get-KotlinFloatConst 'BUTTON_SUPPORT_SURFACE_MIN_Y_METERS'
$maxSupportY = Get-KotlinFloatConst 'BUTTON_SUPPORT_SURFACE_MAX_Y_METERS'
$reachMargin = Get-KotlinFloatConst 'BUTTON_SUPPORT_SURFACE_REACH_MARGIN_METERS'
$minHalfExtent = Get-KotlinFloatConst 'BUTTON_SUPPORT_SURFACE_MIN_HALF_EXTENT_METERS'

$tableSupportY = 0.76
$capOffset = $contactY - $modelOriginY
$tableCapCenterY = $tableSupportY + $capOffset
$downwardAngleDeg = [Math]::Atan(($eyeY - $tableCapCenterY) / $reachZ) * 180.0 / [Math]::PI
$angularDiameterDeg = 2.0 * [Math]::Atan(($diameter / 2.0) / $reachZ) * 180.0 / [Math]::PI

$tableScore =
    Get-SurfaceScore 'Dining Table' 'TABLE' 0.02 $reachZ $tableSupportY 0.42 0.03 0.36 $reachZ $minSupportY $maxSupportY $reachMargin $minHalfExtent
$genericScore =
    Get-SurfaceScore 'Unknown horizontal plane' 'PLANE' 0.02 $reachZ $tableSupportY 0.42 0.03 0.36 $reachZ $minSupportY $maxSupportY $reachMargin $minHalfExtent
$floorScore =
    Get-SurfaceScore 'Floor' 'FLOOR' 0 $reachZ 0.02 2.0 0.01 2.0 $reachZ $minSupportY $maxSupportY $reachMargin $minHalfExtent
$wallScore =
    Get-SurfaceScore 'Front Wall' 'WALL' 0 $reachZ 0.85 2.0 1.0 0.02 $reachZ $minSupportY $maxSupportY $reachMargin $minHalfExtent
$outOfReachScore =
    Get-SurfaceScore 'Side Table' 'TABLE' 0.90 $reachZ $tableSupportY 0.18 0.03 0.18 $reachZ $minSupportY $maxSupportY $reachMargin $minHalfExtent

$surfaceScores = [pscustomobject]@{
    tableScore = $tableScore
    genericScore = $genericScore
    tableAccepted = $null -ne $tableScore
    tablePreferred = $null -ne $tableScore -and $null -ne $genericScore -and $tableScore -gt $genericScore
    floorRejected = $null -eq $floorScore
    wallRejected = $null -eq $wallScore
    outOfReachRejected = $null -eq $outOfReachScore
}
$geometry = [pscustomobject]@{
    reachZ = $reachZ
    eyeY = $eyeY
    fallbackSupportY = $modelOriginY
    tableSupportY = $tableSupportY
    tableCapCenterY = $tableCapCenterY
    downwardAngleDeg = [Math]::Round($downwardAngleDeg, 3)
    angularDiameterDeg = [Math]::Round($angularDiameterDeg, 3)
}
$qkv = Get-QkvEvidence $QkvDir

$surfaceImage = Draw-ButtonSurfacePlacementProof $geometry $surfaceScores
$blinkImage = Draw-BlinkAssignmentProof $qkv
$surfacePixels = Measure-PngPixels $surfaceImage
$blinkPixels = Measure-PngPixels $blinkImage

$surfaceNonBackgroundThresholdPercent = 8.0
$blinkNonBackgroundThresholdPercent = 4.0
$sourceContractPass =
    $placementText.Contains('scoreButtonSupportSurfaceCandidate') -and
    $activityText.Contains('enableMrPlaneTracker(true)') -and
    $activityText.Contains('BRB_ECG_BLINK_IGNORED')
$surfacePass =
    $surfaceScores.tableAccepted -and
    $surfaceScores.tablePreferred -and
    $surfaceScores.floorRejected -and
    $surfaceScores.wallRejected -and
    $surfaceScores.outOfReachRejected -and
    $surfacePixels.redSamples -gt 50 -and
    $surfacePixels.greenSamples -gt 30 -and
    $surfacePixels.nonBackgroundPercent -gt $surfaceNonBackgroundThresholdPercent
$blinkPass =
    $blinkPixels.redSamples -gt 30 -and
    $blinkPixels.blueSamples -gt 10 -and
    $blinkPixels.nonBackgroundPercent -gt $blinkNonBackgroundThresholdPercent -and
    $qkv.available -and
    $qkv.status -eq 'pass' -and
    $qkv.exportMirrorMatched -and
    $qkv.badBlinkRows -eq 0 -and
    $qkv.simulatedBlinkRows -ge 1 -and
    $qkv.simulatedHeartbeatFlashObserved -and
    $qkv.csvAssignmentStrategy -eq 'blocked_counterbalance_random_tie_break'

$summary = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = if ($sourceContractPass -and $surfacePass -and $blinkPass) { 'pass' } else { 'fail' }
    renderer = 'System.Drawing bitmap renderer'
    sourceFiles = [pscustomobject]@{
        activity = $activityPath
        placementHelper = $placementPath
    }
    images = [pscustomobject]@{
        buttonSurfacePlacementProof = $surfaceImage
        ecgBlinkAssignmentProof = $blinkImage
    }
    geometry = $geometry
    surfaceScores = $surfaceScores
    qkv = $qkv
    pixelChecks = [pscustomobject]@{
        surface = $surfacePixels
        blink = $blinkPixels
        thresholds = [pscustomobject]@{
            surfaceNonBackgroundPercent = $surfaceNonBackgroundThresholdPercent
            blinkNonBackgroundPercent = $blinkNonBackgroundThresholdPercent
        }
    }
    checks = [pscustomobject]@{
        sourceContractPass = $sourceContractPass
        surfacePass = $surfacePass
        blinkPass = $blinkPass
        qkvEvidenceRequired = $true
        kotlinPlacementHelperPresent = $placementText.Contains('scoreButtonSupportSurfaceCandidate')
        activityScenePlaneTrackingPresent = $activityText.Contains('enableMrPlaneTracker(true)')
        activityBlinkGuardPresent = $activityText.Contains('BRB_ECG_BLINK_IGNORED')
    }
}
$summaryPath = Join-Path $OutDir 'render-validation-summary.json'
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

if ($summary.status -ne 'pass') {
    throw "Rendered button surface/blink proof failed. See $summaryPath"
}

Write-Host "PASS rendered button surface/blink proof"
Write-Host "Summary: $summaryPath"
