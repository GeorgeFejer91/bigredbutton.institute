[CmdletBinding()]
param(
    [string]$OutDir = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $projectRoot ('artifacts\layout-previews\preview-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Convert-KotlinStringLiteral {
    param([string]$Text)
    return $Text.Replace('\"', '"').Replace("\\'", "'").Replace('\n', "`n").Replace('\t', "`t")
}

function Get-IpqItemsFromSource {
    $activityPath = Join-Path $projectRoot 'app\src\main\java\org\bigredbutton\firststudy\BigRedButtonStudyActivity.kt'
    $activityText = Get-Content -Raw -LiteralPath $activityPath
    $pattern = 'PresenceItem\s*\(\s*"(?<id>[^"]+)"\s*,\s*"(?<subscale>[^"]+)"\s*,\s*"(?<text>(?:[^"\\]|\\.)*)"'
    $matches = [regex]::Matches($activityText, $pattern, [Text.RegularExpressions.RegexOptions]::Singleline)
    $items = @()
    foreach ($match in $matches) {
        $items += [pscustomobject]@{
            id = $match.Groups['id'].Value
            subscale = $match.Groups['subscale'].Value
            text = Convert-KotlinStringLiteral $match.Groups['text'].Value
        }
    }
    if ($items.Count -ne 14) {
        throw "Expected 14 IPQ items in Kotlin source, found $($items.Count)."
    }
    return $items
}

function New-Canvas {
    param([int]$Width = 1180, [int]$Height = 820)
    $bitmap = New-Object Drawing.Bitmap $Width, $Height
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([Drawing.Color]::FromArgb(245, 240, 227))
    return [pscustomobject]@{ Bitmap = $bitmap; Graphics = $graphics; Width = $Width; Height = $Height }
}

function Save-Canvas {
    param($Canvas, [string]$Name)
    $path = Join-Path $OutDir $Name
    $Canvas.Bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    $Canvas.Graphics.Dispose()
    $Canvas.Bitmap.Dispose()
    return $path
}

function Brush([int]$R, [int]$G, [int]$B, [int]$A = 255) {
    return New-Object Drawing.SolidBrush -ArgumentList ([Drawing.Color]::FromArgb($A, $R, $G, $B))
}

function Pen([int]$R, [int]$G, [int]$B, [float]$W = 1, [int]$A = 255) {
    return New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb($A, $R, $G, $B)), $W
}

function Draw-Text {
    param($G, [string]$Text, [int]$X, [int]$Y, [int]$Size = 18, [int]$Width = 1000, [int]$Height = 80, [bool]$Bold = $false, $Color = $null)
    $fontStyle = if ($Bold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
    $fontFamily = if ($Size -ge 28) { 'Georgia' } elseif ($Size -le 13) { 'Consolas' } else { 'Segoe UI' }
    $font = New-Object Drawing.Font $fontFamily, $Size, $fontStyle
    $brush = if ($null -eq $Color) { Brush 26 30 40 } else { $Color }
    $rect = New-Object Drawing.RectangleF $X, $Y, $Width, $Height
    $G.DrawString($Text, $font, $brush, $rect)
    $font.Dispose()
    if ($null -eq $Color) { $brush.Dispose() }
}

function Draw-ButtonPreview {
    $c = New-Canvas 1180 820
    $g = $c.Graphics
    $bg = New-Object Drawing.Drawing2D.LinearGradientBrush ([Drawing.Rectangle]::new(0,0,1180,820)), ([Drawing.Color]::FromArgb(239,233,218)), ([Drawing.Color]::FromArgb(247,243,234)), 90
    $g.FillRectangle($bg, 0, 0, 1180, 820)
    $bg.Dispose()
    Draw-Text $g 'MR Button Layout Preview' 42 34 32 900 50 $true
    Draw-Text $g 'Passthrough background is compositor-provided on Quest. BigRedButton.glb is placed at x=0, y=0.82, z=0.48 with scale 16. The Spatial view origin resets before each condition, and the questionnaire panel is hidden during audio.' 42 88 16 1060 96 $false (Brush 95 103 117)
    $floorPen = Pen 90 94 90 3 160
    $g.DrawLine($floorPen, 90, 672, 1090, 672)
    $floorPen.Dispose()
    Draw-Text $g 'transparent counter overlay; no filled backing panel' 438 194 10 360 32 $false (Brush 95 103 117)
    Draw-Text $g '012' 520 220 42 150 58 $true (Brush 255 43 43)
    Draw-Text $g 'PRESSES' 548 274 10 120 20 $true (Brush 255 36 36)
    Draw-Text $g 'warm surface emission glow, not flat halo' 432 318 10 360 20 $false (Brush 95 103 117)
    foreach ($glow in @(
        @{ X = 422; Y = 320; W = 326; H = 266; A = 34 },
        @{ X = 448; Y = 350; W = 274; H = 214; A = 48 },
        @{ X = 480; Y = 390; W = 210; H = 150; A = 64 }
    )) {
        $glowBrush = Brush 255 110 22 $glow.A
        $g.FillEllipse($glowBrush, $glow.X, $glow.Y, $glow.W, $glow.H)
        $glowBrush.Dispose()
    }
    $shadow = Brush 30 30 30 60
    $g.FillEllipse($shadow, 420, 636, 330, 54)
    $shadow.Dispose()
    $base = Brush 70 64 58
    $g.FillRectangle($base, 445, 545, 280, 84)
    $base.Dispose()
    $bevel = Brush 125 17 17
    $g.FillRectangle($bevel, 480, 500, 210, 58)
    $bevel.Dispose()
    $red = Brush 223 44 44
    $g.FillEllipse($red, 475, 380, 220, 170)
    $red.Dispose()
    $outline = Pen 143 23 23 7
    $g.DrawEllipse($outline, 475, 380, 220, 170)
    $outline.Dispose()
    $shine = Brush 255 255 255 92
    $g.FillEllipse($shine, 525, 408, 70, 42)
    $shine.Dispose()
    Draw-Text $g 'PRESS' 508 568 24 180 32 $true (Brush 255 255 255)
    Draw-Text $g 'FOR SCIENCE' 508 600 13 180 26 $true (Brush 255 255 255)
    $hitTargetPen = Pen 143 23 23 2 90
    $g.DrawEllipse($hitTargetPen, 445, 545, 280, 84)
    $hitTargetPen.Dispose()
    Draw-Text $g 'Transparent press target; no 2D button overlay during audio' 292 714 15 720 30 $false (Brush 95 103 117)
    return Save-Canvas $c 'button-layout-preview.png'
}

function Draw-PreButtonExperiencePromptPreview {
    $c = New-Canvas 520 520
    $g = $c.Graphics
    $g.Clear([Drawing.Color]::FromArgb(26, 28, 34))
    Draw-Text $g 'clear passthrough counter panel; 3D button hidden until Start experiment' 26 18 10 468 34 $false (Brush 220 226 238)
    foreach ($glow in @(
        @{ X = 18; Y = 42; W = 484; H = 430; A = 18 },
        @{ X = 74; Y = 96; W = 372; H = 300; A = 25 },
        @{ X = 122; Y = 144; W = 276; H = 206; A = 32 }
    )) {
        $glowBrush = Brush 255 36 36 $glow.A
        $g.FillEllipse($glowBrush, $glow.X, $glow.Y, $glow.W, $glow.H)
        $glowBrush.Dispose()
    }
    Draw-Text $g 'Oh wait, we have just one more question:' 38 72 16 448 30 $true (Brush 255 255 255)
    Draw-Text $g 'Do you have any experience with' 38 112 20 448 34 $true (Brush 255 255 255)
    Draw-Text $g 'pressing big red buttons?' 38 148 20 448 34 $true (Brush 255 255 255)

    $yesRect = [Drawing.Rectangle]::new(54, 218, 178, 58)
    $noRect = [Drawing.Rectangle]::new(288, 218, 178, 58)
    foreach ($rect in @($yesRect, $noRect)) {
        $g.FillRectangle((Brush 0 0 0 0), $rect)
        $g.DrawRectangle((Pen 255 255 255 2 190), $rect)
    }
    $g.DrawRectangle((Pen 255 36 36 3), $yesRect)
    $g.FillRectangle((Brush 255 36 36), 76, 233, 28, 28)
    $checkPen = Pen 255 255 255 4
    $g.DrawLine($checkPen, 82, 248, 92, 258)
    $g.DrawLine($checkPen, 92, 258, 110, 236)
    $checkPen.Dispose()
    $g.DrawRectangle((Pen 255 255 255 2), 310, 233, 28, 28)
    Draw-Text $g 'YES' 122 235 16 80 26 $true (Brush 255 255 255)
    Draw-Text $g 'NO' 356 235 16 80 26 $true (Brush 255 255 255)

    Draw-Text $g 'An experienced user, just the type' 54 308 16 420 28 $true (Brush 255 36 36)
    Draw-Text $g 'of participant we need.' 54 336 16 420 28 $true (Brush 255 36 36)
    $g.FillRectangle((Brush 223 44 44), 54, 402, 412, 54)
    $g.DrawRectangle((Pen 143 23 23 2), 54, 402, 412, 54)
    Draw-Text $g 'Start experiment' 168 418 16 220 28 $true (Brush 255 255 255)
    return Save-Canvas $c 'pre-button-experience-prompt-preview.png'
}

function Draw-DemographicsPreview {
    $c = New-Canvas
    $g = $c.Graphics
    $heroRect = [Drawing.Rectangle]::new(40, 32, 1100, 154)
    $heroBg = New-Object Drawing.Drawing2D.LinearGradientBrush $heroRect, ([Drawing.Color]::FromArgb(255,251,244)), ([Drawing.Color]::FromArgb(239,243,248)), 0
    $g.FillRectangle($heroBg, $heroRect)
    $heroBg.Dispose()
    $g.DrawRectangle((Pen 201 193 176 2), $heroRect)
    $g.FillRectangle((Brush 255 255 255 198), 62, 52, 276, 28)
    $g.DrawRectangle((Pen 201 193 176 1), 62, 52, 276, 28)
    Draw-Text $g 'BIG RED BUTTON INSTITUTE | INTAKE' 76 58 10 260 20 $true (Brush 95 103 117)
    Draw-Text $g 'Participant Details And Consent' 60 86 28 900 40 $true
    Draw-Text $g 'No-scroll compact intake. Responses and button presses are saved locally on this headset.' 62 132 14 960 28 $false (Brush 95 103 117)
    $accent = New-Object Drawing.Drawing2D.LinearGradientBrush ([Drawing.Rectangle]::new(62,166,1010,5)), ([Drawing.Color]::FromArgb(143,23,23)), ([Drawing.Color]::FromArgb(255,68,68)), 0
    $g.FillRectangle($accent, 62, 166, 1010, 5)
    $accent.Dispose()

    $g.FillRectangle((Brush 234 248 238 224), 45, 196, 1090, 50)
    $g.DrawRectangle((Pen 46 139 87 2), 45, 196, 1090, 50)
    $checkPen = Pen 18 122 58 5
    $g.DrawLine($checkPen, 70, 222, 80, 232)
    $g.DrawLine($checkPen, 80, 232, 98, 208)
    $checkPen.Dispose()
    Draw-Text $g 'Polar H10 ECG ready' 116 206 15 420 24 $true
    Draw-Text $g 'HR 72 bpm | RR 18 | ECG 520 samples @ 130 Hz' 116 228 10 620 18 $false (Brush 95 103 117)

    $g.FillRectangle((Brush 255 255 255 184), 45, 260, 1090, 390)
    $g.DrawRectangle((Pen 201 193 176 2), 45, 260, 1090, 390)
    Draw-Text $g 'Participant details' 64 290 18 360 30 $true
    $labels = @('Name','Age')
    $x = 64; $y = 335
    foreach ($label in $labels) {
        $g.FillRectangle((Brush 255 251 244), $x, $y, 490, 58)
        $g.DrawRectangle((Pen 201 193 176 2), $x, $y, 490, 58)
        Draw-Text $g $label ($x + 16) ($y + 17) 15 420 30 $false (Brush 95 103 117)
        if ($x -lt 560) { $x = 608 } else { $x = 64; $y += 72 }
    }
    Draw-Text $g 'Gender' 64 425 15 240 28 $false (Brush 95 103 117)
    $genderX = 160
    foreach ($choice in @('Male', 'Female', 'Other', 'Prefer not to say')) {
        $w = if ($choice -eq 'Prefer not to say') { 205 } else { 105 }
        $g.FillRectangle((Brush 255 251 244), $genderX, 413, $w, 42)
        $g.DrawRectangle((Pen 201 193 176 2), $genderX, 413, $w, 42)
        Draw-Text $g $choice ($genderX + 13) 425 12 ($w - 20) 24 $true (Brush 26 30 40)
        $genderX += $w + 10
    }
    Draw-Text $g 'Handedness' 64 484 15 240 28 $false (Brush 95 103 117)
    $handX = 220
    foreach ($choice in @('Left', 'Right', 'Ambidextrous')) {
        $w = if ($choice -eq 'Ambidextrous') { 185 } else { 115 }
        $g.FillRectangle((Brush 255 251 244), $handX, 472, $w, 42)
        $g.DrawRectangle((Pen 201 193 176 2), $handX, 472, $w, 42)
        Draw-Text $g $choice ($handX + 18) 484 13 ($w - 26) 26 $true (Brush 26 30 40)
        $handX += $w + 12
    }
    Draw-Text $g 'Participant ID is assigned automatically in the background.' 690 484 15 380 28 $false (Brush 95 103 117)
    Draw-Text $g 'Consent signature' 64 532 14 260 22 $true (Brush 95 103 117)
    Draw-Text $g 'Hold the trigger and draw your signature in the space below.' 64 554 12 700 20 $false (Brush 95 103 117)
    $g.FillRectangle((Brush 255 251 244), 64, 580, 1010, 72)
    $g.DrawRectangle((Pen 143 23 23 2), 64, 580, 1010, 72)
    $guide = Pen 201 193 176 1 145
    foreach ($lineY in @(598, 616, 634)) {
        $g.DrawLine($guide, 84, $lineY, 1054, $lineY)
    }
    $guide.Dispose()
    $g.DrawLine((Pen 143 23 23 2 90), 92, 638, 1046, 638)
    Draw-Text $g 'Sign here' 485 600 25 240 42 $true (Brush 95 103 117 118)
    $g.FillRectangle((Brush 255 244 244 210), 45, 670, 1090, 54)
    $g.DrawRectangle((Pen 224 215 199 2), 45, 670, 1090, 54)
    $g.DrawRectangle((Pen 185 176 160 2), 64, 684, 28, 28)
    Draw-Text $g 'I consent to participate and understand that study data will be saved locally on the headset.' 108 680 16 950 44
    $g.FillRectangle((Brush 223 44 44), 45, 742, 1090, 58)
    Draw-Text $g 'Start experiment' 490 755 20 300 38 $true (Brush 255 255 255)
    return Save-Canvas $c 'demographics-panel-preview.png'
}

function Draw-DemographicsNativeKeyboardPreview {
    $c = New-Canvas
    $g = $c.Graphics
    Draw-Text $g 'Demographics Native Keyboard' 40 34 32 900 50 $true
    Draw-Text $g 'The questionnaire stays centered. Text fields invoke the native movable Quest keyboard panel, and field focus retargets it between letters and digits.' 42 88 16 1050 56 $false (Brush 95 103 117)

    $g.FillRectangle((Brush 255 255 255 190), 50, 160, 1080, 310)
    $g.DrawRectangle((Pen 201 193 176 2), 50, 160, 1080, 310)
    Draw-Text $g 'Participant details' 72 184 18 360 30 $true

    $g.FillRectangle((Brush 255 251 244), 72, 230, 505, 64)
    $g.DrawRectangle((Pen 201 193 176 2), 72, 230, 505, 64)
    Draw-Text $g 'Name' 90 240 11 120 20 $true (Brush 95 103 117)
    Draw-Text $g 'George' 90 260 17 360 28 $false (Brush 26 30 40)

    $g.FillRectangle((Brush 255 251 244), 620, 230, 430, 64)
    $g.DrawRectangle((Pen 143 23 23 3), 620, 230, 430, 64)
    Draw-Text $g 'Age' 638 240 11 120 20 $true (Brush 143 23 23)
    Draw-Text $g '42' 638 260 17 240 28 $false (Brush 26 30 40)

    Draw-Text $g 'Gender' 72 330 15 170 28 $false (Brush 95 103 117)
    $genderX = 170
    foreach ($choice in @('Male', 'Female', 'Other', 'Prefer not to say')) {
        $w = if ($choice -eq 'Prefer not to say') { 205 } else { 105 }
        $g.FillRectangle((Brush 255 251 244), $genderX, 318, $w, 42)
        $g.DrawRectangle((Pen 201 193 176 2), $genderX, 318, $w, 42)
        Draw-Text $g $choice ($genderX + 13) 330 12 ($w - 20) 24 $true (Brush 26 30 40)
        $genderX += $w + 10
    }

    Draw-Text $g 'Handedness' 72 390 15 170 28 $false (Brush 95 103 117)
    $handX = 220
    foreach ($choice in @('Left', 'Right', 'Ambidextrous')) {
        $w = if ($choice -eq 'Ambidextrous') { 185 } else { 115 }
        $g.FillRectangle((Brush 255 251 244), $handX, 378, $w, 42)
        $g.DrawRectangle((Pen 201 193 176 2), $handX, 378, $w, 42)
        Draw-Text $g $choice ($handX + 18) 390 13 ($w - 26) 26 $true (Brush 26 30 40)
        $handX += $w + 12
    }

    $kbX = 170
    $kbY = 490
    $kbW = 840
    $g.FillRectangle((Brush 230 234 244 245), $kbX, $kbY, $kbW, 255)
    $g.DrawRectangle((Pen 67 76 96 3), $kbX, $kbY, $kbW, 255)
    $g.FillRectangle((Brush 26 42 88 245), $kbX, $kbY, $kbW, 34)
    Draw-Text $g 'Native Quest keyboard' ($kbX + 18) ($kbY + 8) 15 280 24 $true (Brush 255 255 255)
    Draw-Text $g 'Active field: Age | numeric keyboard' ($kbX + 18) ($kbY + 44) 12 360 22 $false (Brush 67 76 96)

    $rows = @(
        @('1','2','3','4','5'),
        @('6','7','8','9','0')
    )
    $keyY = $kbY + 82
    foreach ($row in $rows) {
        $keyX = $kbX + 18
        foreach ($key in $row) {
            $g.FillRectangle((Brush 255 255 255 245), $keyX, $keyY, 154, 38)
            $g.DrawRectangle((Pen 146 154 171 2), $keyX, $keyY, 154, 38)
            Draw-Text $g $key ($keyX + 67) ($keyY + 9) 12 30 20 $true
            $keyX += 160
        }
        $keyY += 44
    }

    $controlY = $kbY + 178
    $controls = @(
        @{ Label = 'Name'; W = 110; Selected = $false },
        @{ Label = 'Age'; W = 90; Selected = $true },
        @{ Label = 'Space'; W = 150; Selected = $false },
        @{ Label = 'Delete'; W = 145; Selected = $false },
        @{ Label = 'Done'; W = 120; Selected = $false }
    )
    $keyX = $kbX + 18
    foreach ($control in $controls) {
        $selected = [bool]$control.Selected
        $fill = if ($control.Label -eq 'Done') { Brush 223 44 44 } elseif ($selected) { Brush 216 226 255 } else { Brush 255 255 255 235 }
        $pen = if ($selected -or $control.Label -eq 'Done') { Pen 26 42 88 2 } else { Pen 146 154 171 2 }
        $g.FillRectangle($fill, $keyX, $controlY, $control.W, 36)
        $g.DrawRectangle($pen, $keyX, $controlY, $control.W, 36)
        $textBrush = if ($control.Label -eq 'Done') { Brush 255 255 255 } elseif ($selected) { Brush 26 42 88 } else { Brush 26 30 40 }
        Draw-Text $g $control.Label ($keyX + 10) ($controlY + 9) 10 ($control.W - 12) 20 $true $textBrush
        $fill.Dispose()
        $pen.Dispose()
        $textBrush.Dispose()
        $keyX += $control.W + 8
    }

    Draw-Text $g 'Native movable Quest keyboard: separate system panel below/near the questionnaire; participant can reposition or exit it.' 70 468 15 980 28 $true (Brush 143 23 23)
    Draw-Text $g 'text-to-number retarget: Name requests text mode; Age requests number mode; focus switches restart the system IME so the visible keyboard mode follows the selected field.' 70 758 13 980 34 $false (Brush 95 103 117)
    Draw-Text $g 'Validated by tools/test-native-keyboard-contract.ps1 and qkv log comparisons.' 70 792 13 900 24 $false (Brush 95 103 117)
    return Save-Canvas $c 'demographics-native-keyboard-preview.png'
}

function Draw-PictographicPreview {
    $c = New-Canvas
    $g = $c.Graphics
    Draw-Text $g 'Button Experience' 40 34 32 900 50 $true
    Draw-Text $g 'By the end of the experience, how close did the Big Red Button feel, how present did it feel, and how red did it feel? The distance axis starts at the figure.' 40 88 17 1060 62 $false (Brush 95 103 117)
    $g.FillRectangle((Brush 255 251 244), 70, 150, 1040, 270)
    $g.DrawRectangle((Pen 201 193 176 2), 70, 150, 1040, 270)
    $selfCenterX = 255
    $buttonCenterX = 575
    $buttonCenterY = 325
    $axisEndX = 900
    $g.DrawLine((Pen 92 88 82 4 140), $selfCenterX, 315, $axisEndX, 315)
    $g.DrawEllipse((Pen 26 30 40 9 190), $selfCenterX - 75, 235, 150, 150)
    $g.DrawEllipse((Pen 26 30 40 5), $selfCenterX - 17, 257, 34, 34)
    $g.DrawLine((Pen 26 30 40 5), $selfCenterX, 292, $selfCenterX, 352)
    $g.DrawLine((Pen 26 30 40 5), $selfCenterX - 40, 315, $selfCenterX + 40, 315)
    $g.DrawLine((Pen 26 30 40 5), $selfCenterX, 352, $selfCenterX - 30, 400)
    $g.DrawLine((Pen 26 30 40 5), $selfCenterX, 352, $selfCenterX + 30, 400)
    $g.DrawEllipse((Pen 223 44 44 9 180), $buttonCenterX - 115, $buttonCenterY - 115, 230, 230)
    $thumbPath = Join-Path $projectRoot 'app\src\main\res\drawable-nodpi\big_red_button_model_thumbnail.png'
    if (Test-Path $thumbPath) {
        $thumb = [Drawing.Bitmap]::FromFile($thumbPath)
        try {
            $g.DrawImage($thumb, [Drawing.Rectangle]::new($buttonCenterX - 62, $buttonCenterY - 62, 124, 124))
        } finally {
            $thumb.Dispose()
        }
    } else {
        $g.FillEllipse((Brush 223 44 44), $buttonCenterX - 46, $buttonCenterY - 34, 92, 68)
        $g.DrawEllipse((Pen 143 23 23 5), $buttonCenterX - 46, $buttonCenterY - 34, 92, 68)
    }
    $sliderX = 270
    $sliderW = 640
    Draw-Text $g 'How close did the button feel?' $sliderX 455 17 430 30 $true
    $g.DrawLine((Pen 150 150 150 7), $sliderX, 510, ($sliderX + $sliderW), 510)
    $g.FillEllipse((Brush 223 44 44), ($sliderX + 302), 491, 38, 38)
    Draw-Text $g 'very close' $sliderX 535 12 150 24 $false (Brush 95 103 117)
    Draw-Text $g 'very distant' ($sliderX + $sliderW - 130) 535 12 150 24 $false (Brush 95 103 117)
    Draw-Text $g 'How present did the button feel?' $sliderX 575 17 460 30 $true
    $g.DrawLine((Pen 150 150 150 7), $sliderX, 630, ($sliderX + $sliderW), 630)
    $g.FillEllipse((Brush 223 44 44), ($sliderX + 302), 611, 38, 38)
    Draw-Text $g 'small presence' $sliderX 655 12 180 24 $false (Brush 95 103 117)
    Draw-Text $g 'large presence' ($sliderX + $sliderW - 145) 655 12 160 24 $false (Brush 95 103 117)
    Draw-Text $g 'How red did the button feel?' $sliderX 695 17 430 30 $true
    $boxX = $sliderX
    $boxY = 742
    $boxW = [int](($sliderW - 36) / 7)
    $redLabels = @('slightly red', 'somewhat red', 'moderately red', 'quite red', 'very red', 'intensely red', 'extremely red')
    for ($i = 0; $i -lt 7; $i++) {
        $x = $boxX + ($i * ($boxW + 6))
        $g.FillRectangle((Brush 255 226 226), $x, $boxY, $boxW, 50)
        $g.DrawRectangle((Pen 143 23 23 2), $x, $boxY, $boxW, 50)
        Draw-Text $g "$($i + 1)" ($x + 4) ($boxY + 3) 10 20 18 $true (Brush 143 23 23)
        Draw-Text $g $redLabels[$i] ($x + 5) ($boxY + 19) 8 ($boxW - 8) 28 $true (Brush 26 30 40)
    }
    return Save-Canvas $c 'pictographic-panel-preview.png'
}

function Draw-IpqPreviewPage {
    param($Items, [int]$PageNumber, [int]$StartIndex, [int]$Count)

    $c = New-Canvas
    $g = $c.Graphics
    Draw-Text $g 'Session Experience Ratings' 40 34 32 900 50 $true
    Draw-Text $g "Preview page $PageNumber. Select one number per row, where 0 means not at all and 6 means very much." 40 88 18 1040 60 $false (Brush 95 103 117)
    $y = 170
    for ($offset = 0; $offset -lt $Count; $offset++) {
        $itemIndex = $StartIndex + $offset
        $item = $Items[$itemIndex]
        $rowNumber = $itemIndex + 1
        Draw-Text $g "$rowNumber. $($item.text)" 58 $y 14 700 58 $true
        $x = 790
        for ($v = 0; $v -le 6; $v++) {
            $g.FillRectangle((Brush 255 251 244), $x, $y - 2, 42, 34)
            $g.DrawRectangle((Pen 201 193 176 2), $x, $y - 2, 42, 34)
            Draw-Text $g "$v" ($x + 13) ($y + 3) 12 30 24
            $x += 47
        }
        $y += 74
        $g.DrawLine((Pen 224 215 199 2), 48, $y - 18, 1130, $y - 18)
    }
    Draw-Text $g 'Scroll panel contains all 14 actual app items; submit is enabled only when all are answered.' 58 690 17 950 40
    return Save-Canvas $c "ipq-panel-preview-page-$PageNumber.png"
}

function Draw-IpqPreview {
    $items = Get-IpqItemsFromSource
    return @(
        Draw-IpqPreviewPage $items 1 0 7
        Draw-IpqPreviewPage $items 2 7 7
    )
}

function Draw-LostOpportunityPreview {
    $c = New-Canvas
    $g = $c.Graphics
    Draw-Text $g 'Additional Time Rating' 40 44 30 1050 50 $true
    Draw-Text $g 'Had you been given twice as much time with the button, how likely is it that you would have pressed the button twice as often?' 60 170 24 1060 140 $false (Brush 26 30 40)
    $g.DrawLine((Pen 150 150 150 9), 115, 415, 1065, 415)
    $g.FillEllipse((Brush 223 44 44), 570, 392, 46, 46)
    Draw-Text $g '0 - not at all likely' 115 455 16 300 35
    Draw-Text $g '100 - extremely likely' 850 455 16 300 35
    Draw-Text $g '50' 520 515 56 180 90 $true (Brush 143 23 23)
    $g.FillRectangle((Brush 223 44 44), 60, 670, 1060, 64)
    Draw-Text $g 'Save rating' 500 686 20 260 40 $true (Brush 255 255 255)
    return Save-Canvas $c 'lost-opportunity-panel-preview.png'
}

$paths = @(
    Draw-ButtonPreview
    Draw-PreButtonExperiencePromptPreview
    Draw-DemographicsPreview
    Draw-DemographicsNativeKeyboardPreview
    Draw-PictographicPreview
    Draw-IpqPreview
    Draw-LostOpportunityPreview
)

$summaryPath = Join-Path $OutDir 'layout-preview-summary.json'
[pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    note = 'Local static layout previews. These are not headset compositor screenshots.'
    previews = $paths
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host "Layout previews written to $OutDir"
