[CmdletBinding()]
param(
    [string]$OutDir = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $projectRoot ('artifacts\name-keyboard-preview\preview-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$activityPath = Join-Path $projectRoot 'app\src\main\java\org\bigredbutton\firststudy\BigRedButtonStudyActivity.kt'
$activityText = Get-Content -Raw -LiteralPath $activityPath

function Get-KotlinFloatConst {
    param([string]$Name)
    $pattern = "private\s+const\s+val\s+$Name\s*=\s*(?<value>-?\d+(?:\.\d+)?)f"
    $match = [regex]::Match($activityText, $pattern)
    if (-not $match.Success) {
        throw "Missing Kotlin float constant $Name"
    }
    return [double]::Parse($match.Groups['value'].Value, [Globalization.CultureInfo]::InvariantCulture)
}

function Brush([int]$R, [int]$G, [int]$B, [int]$A = 255) {
    return New-Object Drawing.SolidBrush -ArgumentList ([Drawing.Color]::FromArgb($A, $R, $G, $B))
}

function Pen([int]$R, [int]$G, [int]$B, [float]$W = 1, [int]$A = 255) {
    return New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb($A, $R, $G, $B)), $W
}

function Draw-Text {
    param(
        [Drawing.Graphics]$Graphics,
        [string]$Text,
        [single]$X,
        [single]$Y,
        [single]$Width,
        [single]$Height,
        [single]$Size = 16,
        [bool]$Bold = $false,
        [Drawing.Brush]$Color = $null,
        [Drawing.StringAlignment]$Align = [Drawing.StringAlignment]::Near
    )
    $fontStyle = if ($Bold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
    $fontFamily = if ($Size -le 15) { 'Consolas' } else { 'Segoe UI' }
    $font = New-Object Drawing.Font $fontFamily, $Size, $fontStyle
    $brush = if ($null -eq $Color) { Brush 26 30 40 } else { $Color }
    $format = New-Object Drawing.StringFormat
    $format.Alignment = $Align
    $format.LineAlignment = [Drawing.StringAlignment]::Center
    $format.Trimming = [Drawing.StringTrimming]::EllipsisCharacter
    $rect = New-Object Drawing.RectangleF $X, $Y, $Width, $Height
    $Graphics.DrawString($Text, $font, $brush, $rect, $format)
    $format.Dispose()
    $font.Dispose()
    if ($null -eq $Color) {
        $brush.Dispose()
    }
}

function Draw-Key {
    param(
        [Drawing.Graphics]$Graphics,
        [string]$Label,
        [single]$X,
        [single]$Y,
        [single]$Width,
        [single]$Height,
        [bool]$Selected = $false
    )
    $fill = if ($Selected) { Brush 223 44 44 } else { Brush 255 255 255 242 }
    $outline = if ($Selected) { Pen 143 23 23 3 } else { Pen 224 215 199 2 }
    $rect = [Drawing.RectangleF]::new($X, $Y, $Width, $Height)
    $Graphics.FillRectangle($fill, $rect)
    $Graphics.DrawRectangle($outline, $X, $Y, $Width, $Height)
    $textBrush = if ($Selected) { Brush 255 255 255 } else { Brush 26 30 40 }
    Draw-Text $Graphics $Label $X $Y $Width $Height 15 $true $textBrush ([Drawing.StringAlignment]::Center)
    $textBrush.Dispose()
    $fill.Dispose()
    $outline.Dispose()
}

function Draw-LetterRow {
    param(
        [Drawing.Graphics]$Graphics,
        [string]$Letters,
        [single]$Y,
        [single]$KeyWidth,
        [single]$KeyHeight,
        [single]$Gap,
        [single]$ContentX,
        [single]$ContentWidth,
        [string]$SelectedLabel
    )
    $labels = @($Letters.ToCharArray() | ForEach-Object { [string]$_ })
    $rowWidth = ($labels.Count * $KeyWidth) + (($labels.Count - 1) * $Gap)
    $x = $ContentX + (($ContentWidth - $rowWidth) / 2.0)
    foreach ($label in $labels) {
        Draw-Key $Graphics $label $x $Y $KeyWidth $KeyHeight ($label -eq $SelectedLabel)
        $x += $KeyWidth + $Gap
    }
}

$widthMeters = Get-KotlinFloatConst 'NAME_KEYBOARD_PANEL_WIDTH_METERS'
$heightMeters = Get-KotlinFloatConst 'NAME_KEYBOARD_PANEL_HEIGHT_METERS'
$distanceMeters = Get-KotlinFloatConst 'NAME_KEYBOARD_PANEL_RADIAL_DISTANCE_METERS'
$angleDegrees = Get-KotlinFloatConst 'NAME_KEYBOARD_PANEL_RADIAL_ANGLE_DEGREES'
$yMeters = Get-KotlinFloatConst 'NAME_KEYBOARD_PANEL_Y_METERS'
$displayWidth = [int](Get-KotlinFloatConst 'NAME_KEYBOARD_PANEL_DISPLAY_WIDTH_DP')
$displayHeight = [int](Get-KotlinFloatConst 'NAME_KEYBOARD_PANEL_DISPLAY_HEIGHT_DP')

$bitmap = New-Object Drawing.Bitmap $displayWidth, $displayHeight
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([Drawing.Color]::FromArgb(0, 0, 0, 0))

$outerMargin = 10.0
$panelX = $outerMargin
$panelY = $outerMargin
$panelW = $displayWidth - (2.0 * $outerMargin)
$panelH = $displayHeight - (2.0 * $outerMargin)
$paper = Brush 255 251 244 250
$border = Pen 143 23 23 3
$graphics.FillRectangle($paper, [Drawing.RectangleF]::new($panelX, $panelY, $panelW, $panelH))
$graphics.DrawRectangle($border, $panelX, $panelY, $panelW, $panelH)
$paper.Dispose()
$border.Dispose()

$contentX = $panelX + 12.0
$contentW = $panelW - 24.0
$handleY = $panelY + 12.0
$handleH = 28.0
$handleFill = Brush 255 255 255 168
$handleBorder = Pen 224 215 199 2
$graphics.FillRectangle($handleFill, [Drawing.RectangleF]::new($contentX, $handleY, $contentW, $handleH))
$graphics.DrawRectangle($handleBorder, $contentX, $handleY, $contentW, $handleH)
$handlePen = Pen 95 103 117 3 210
$gripW = 96.0
$gripX = $contentX + (($contentW - $gripW) / 2.0)
foreach ($offset in @(8.0, 14.0, 20.0)) {
    $graphics.DrawLine($handlePen, $gripX, ($handleY + $offset), ($gripX + $gripW), ($handleY + $offset))
}
$handleFill.Dispose()
$handleBorder.Dispose()
$handlePen.Dispose()

$fieldY = $handleY + $handleH + 8.0
$fieldH = 52.0
$fieldFill = Brush 255 255 255 236
$fieldBorder = Pen 201 193 176 2
$graphics.FillRectangle($fieldFill, [Drawing.RectangleF]::new($contentX, $fieldY, $contentW, $fieldH))
$graphics.DrawRectangle($fieldBorder, $contentX, $fieldY, $contentW, $fieldH)
$fieldFill.Dispose()
$fieldBorder.Dispose()
Draw-Text $graphics 'George Fejer|' ($contentX + 14) $fieldY ($contentW - 28) $fieldH 23 $true (Brush 26 30 40)

$keyboardY = $fieldY + $fieldH + 10.0
$keyboardPad = 8.0
$gap = 7.0
$keyHeight = 40.0
$keyAreaX = $contentX + $keyboardPad
$keyAreaW = $contentW - (2.0 * $keyboardPad)
$row1KeyWidth = ($keyAreaW - (9.0 * $gap)) / 10.0
$keyboardH = (4.0 * $keyHeight) + (3.0 * $gap) + (2.0 * $keyboardPad)
$kbFill = Brush 255 251 244 245
$kbBorder = Pen 201 193 176 2
$graphics.FillRectangle($kbFill, [Drawing.RectangleF]::new($contentX, $keyboardY, $contentW, $keyboardH))
$graphics.DrawRectangle($kbBorder, $contentX, $keyboardY, $contentW, $keyboardH)
$kbFill.Dispose()
$kbBorder.Dispose()

$rowY = $keyboardY + $keyboardPad
Draw-LetterRow $graphics 'QWERTYUIOP' $rowY $row1KeyWidth $keyHeight $gap $keyAreaX $keyAreaW 'Q'
$rowY += $keyHeight + $gap
Draw-LetterRow $graphics 'ASDFGHJKL' $rowY $row1KeyWidth $keyHeight $gap $keyAreaX $keyAreaW ''
$rowY += $keyHeight + $gap
Draw-LetterRow $graphics 'ZXCVBNM' $rowY $row1KeyWidth $keyHeight $gap $keyAreaX $keyAreaW ''
$rowY += $keyHeight + $gap

$weights = @(1.15, 2.20, 1.15, 1.15)
$labels = @('Clear', 'Space', 'Back', 'Next')
$weightSum = ($weights | Measure-Object -Sum).Sum
$controlGapTotal = ($labels.Count - 1) * $gap
$unit = ($keyAreaW - $controlGapTotal) / $weightSum
$x = $keyAreaX
for ($i = 0; $i -lt $labels.Count; $i++) {
    $w = [single]($weights[$i] * $unit)
    Draw-Key $graphics $labels[$i] $x $rowY $w $keyHeight ($labels[$i] -eq 'Next')
    $x += $w + $gap
}

$infoBrush = Brush 95 103 117
Draw-Text $graphics ("panel {0:0.00}m x {1:0.00}m, distance {2:0.00}m, angle {3:0} deg" -f $widthMeters, $heightMeters, $distanceMeters, $angleDegrees) 18 ($displayHeight - 34) ($displayWidth - 36) 22 10 $false $infoBrush
$infoBrush.Dispose()

$previewPath = Join-Path $OutDir 'name-keyboard-popup-preview.png'
$bitmap.Save($previewPath, [Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()

$physicalAspect = $widthMeters / $heightMeters
$displayAspect = $displayWidth / $displayHeight
$aspectDelta = [math]::Abs($physicalAspect - $displayAspect)
$letterKeyWidthMeters = $widthMeters * ($row1KeyWidth / $displayWidth)
$letterKeyHeightMeters = $heightMeters * ($keyHeight / $displayHeight)
$letterKeyAspect = $row1KeyWidth / $keyHeight
$angularWidthDegrees = 2.0 * [math]::Atan(($widthMeters / 2.0) / $distanceMeters) * 180.0 / [math]::PI

$checks = [ordered]@{
    aspectMatched = $aspectDelta -le 0.08
    comfortableDistance = $distanceMeters -ge 0.70 -and $distanceMeters -le 0.95
    higherLargerCloser = $widthMeters -ge 0.63 -and $heightMeters -ge 0.25 -and $distanceMeters -le 0.90 -and $yMeters -ge 1.20
    keyWidthReadable = $letterKeyWidthMeters -ge 0.045
    keyHeightReadable = $letterKeyHeightMeters -ge 0.024
    keyShapeNativeLike = $letterKeyAspect -ge 1.5 -and $letterKeyAspect -le 2.5
    higherLeftRadialPlacement = $angleDegrees -le -18 -and $angleDegrees -ge -42 -and $yMeters -ge 1.20 -and $yMeters -le 1.38
    controllerBeamMovableContract = $activityText.Contains('BRB_NAME_APP_KEYBOARD_DRAG') -and $activityText.Contains('dragHandle=true') -and $activityText.Contains('controllerBeamDraggable=true')
}
$failedCheckCount = @($checks.Values | Where-Object { -not $_ }).Count
$status = if ($failedCheckCount -eq 0) { 'pass' } else { 'fail' }

$summaryPath = Join-Path $OutDir 'name-keyboard-preview-summary.json'
$summary = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = $status
    note = '2D prerender of app-owned pop-out Name keyboard. This is not a headset compositor screenshot.'
    preview = $previewPath
    constants = [pscustomobject]@{
        widthMeters = $widthMeters
        heightMeters = $heightMeters
        radialDistanceMeters = $distanceMeters
        radialAngleDegrees = $angleDegrees
        yMeters = $yMeters
        displayWidthDp = $displayWidth
        displayHeightDp = $displayHeight
    }
    metrics = [pscustomobject]@{
        physicalAspect = [math]::Round($physicalAspect, 3)
        displayAspect = [math]::Round($displayAspect, 3)
        aspectDelta = [math]::Round($aspectDelta, 3)
        letterKeyWidthMeters = [math]::Round($letterKeyWidthMeters, 3)
        letterKeyHeightMeters = [math]::Round($letterKeyHeightMeters, 3)
        letterKeyAspect = [math]::Round($letterKeyAspect, 3)
        angularWidthDegrees = [math]::Round($angularWidthDegrees, 1)
    }
    checks = $checks
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host "Name keyboard preview written to $previewPath"
Write-Host "Summary: $summaryPath"
if ($status -ne 'pass') {
    throw "Name keyboard preview checks failed. See $summaryPath"
}
