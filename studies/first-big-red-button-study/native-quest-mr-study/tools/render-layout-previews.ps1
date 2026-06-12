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
    $hasJapanese = [regex]::IsMatch($Text, '[ぁ-んァ-ン一-龯日本語]')
    $fontFamily = if ($hasJapanese) { 'Yu Gothic UI' } elseif ($Size -ge 28) { 'Georgia' } elseif ($Size -le 13) { 'Consolas' } else { 'Segoe UI' }
    $font = New-Object Drawing.Font $fontFamily, $Size, $fontStyle
    $brush = if ($null -eq $Color) { Brush 26 30 40 } else { $Color }
    $rect = New-Object Drawing.RectangleF $X, $Y, $Width, $Height
    $G.DrawString($Text, $font, $brush, $rect)
    $font.Dispose()
    if ($null -eq $Color) { $brush.Dispose() }
}

function Draw-LanguageSelectionPreview {
    $c = New-Canvas
    $g = $c.Graphics
    Draw-Text $g 'Big Red Button Institute' 352 116 18 480 32 $true (Brush 95 103 117)
    Draw-Text $g 'Choose experiment language' 228 168 31 760 58 $true
    Draw-Text $g '実験の言語を選んでください' 302 226 28 640 50 $true
    Draw-Text $g 'This controls participant-facing text and spoken audio. The experiment flow, physical 3D button task, and export contract stay unchanged.' 226 294 17 750 82 $false (Brush 95 103 117)

    $englishRect = [Drawing.Rectangle]::new(250, 412, 300, 104)
    $japaneseRect = [Drawing.Rectangle]::new(630, 412, 300, 104)
    $g.FillRectangle((Brush 255 251 244), $englishRect)
    $g.DrawRectangle((Pen 201 193 176 3), $englishRect)
    Draw-Text $g 'English' 340 446 27 160 46 $true
    $g.FillRectangle((Brush 223 44 44), $japaneseRect)
    $g.DrawRectangle((Pen 143 23 23 3), $japaneseRect)
    Draw-Text $g '日本語' 728 444 28 160 48 $true (Brush 255 255 255)
    Draw-Text $g 'Controller left/right changes focus; Enter selects language before intake.' 268 570 16 720 34 $false (Brush 95 103 117)
    Draw-Text $g 'Preview shows Japanese focused state.' 418 612 13 380 24 $false (Brush 95 103 117)
    return Save-Canvas $c 'language-selection-preview.png'
}

function Draw-JapaneseDemographicsPreview {
    $c = New-Canvas
    $g = $c.Graphics
    $heroRect = [Drawing.Rectangle]::new(40, 32, 1100, 154)
    $heroBg = New-Object Drawing.Drawing2D.LinearGradientBrush $heroRect, ([Drawing.Color]::FromArgb(255,251,244)), ([Drawing.Color]::FromArgb(239,243,248)), 0
    $g.FillRectangle($heroBg, $heroRect)
    $heroBg.Dispose()
    $g.DrawRectangle((Pen 201 193 176 2), $heroRect)
    Draw-Text $g 'Big Red Button Institute | 受付' 62 54 12 360 24 $true (Brush 95 103 117)
    Draw-Text $g '参加者情報と同意' 60 86 28 900 42 $true
    Draw-Text $g '下に参加者情報を入力してください。回答とボタン押下は、このヘッドセット内に保存されます。' 62 132 14 960 32 $false (Brush 95 103 117)
    $accent = New-Object Drawing.Drawing2D.LinearGradientBrush ([Drawing.Rectangle]::new(62,166,1010,5)), ([Drawing.Color]::FromArgb(143,23,23)), ([Drawing.Color]::FromArgb(255,68,68)), 0
    $g.FillRectangle($accent, 62, 166, 1010, 5)
    $accent.Dispose()

    $g.FillRectangle((Brush 234 248 238 224), 45, 196, 1090, 50)
    $g.DrawRectangle((Pen 46 139 87 2), 45, 196, 1090, 50)
    Draw-Text $g '✓' 70 205 24 40 34 $true (Brush 18 122 58)
    Draw-Text $g 'Polar H10 ECG 準備完了' 116 206 15 420 24 $true
    Draw-Text $g 'HR 72 bpm | RR 18 | ECG 520 samples @ 130 Hz' 116 228 10 620 18 $false (Brush 95 103 117)

    $g.FillRectangle((Brush 255 255 255 184), 45, 260, 1090, 390)
    $g.DrawRectangle((Pen 201 193 176 2), 45, 260, 1090, 390)
    Draw-Text $g '参加者情報' 64 290 18 360 30 $true
    $fields = @(@('名前',64), @('年齢',608))
    foreach ($field in $fields) {
        $x = [int]$field[1]
        $g.FillRectangle((Brush 255 251 244), $x, 335, 490, 58)
        $g.DrawRectangle((Pen 201 193 176 2), $x, 335, 490, 58)
        Draw-Text $g $field[0] ($x + 16) 352 15 420 30 $false (Brush 95 103 117)
    }
    Draw-Text $g '性別' 64 425 15 120 28 $false (Brush 95 103 117)
    $gender = @(@('男性',160,96), @('女性',266,96), @('その他',372,116), @('回答しない',498,150))
    foreach ($choice in $gender) {
        $g.FillRectangle((Brush 255 251 244), $choice[1], 413, $choice[2], 42)
        $g.DrawRectangle((Pen 201 193 176 2), $choice[1], 413, $choice[2], 42)
        Draw-Text $g $choice[0] ([int]$choice[1] + 14) 424 12 ([int]$choice[2] - 18) 24 $true
    }
    Draw-Text $g '利き手' 64 484 15 120 28 $false (Brush 95 103 117)
    $hands = @(@('左',160,82), @('右',252,82), @('両利き',344,120))
    foreach ($choice in $hands) {
        $g.FillRectangle((Brush 255 251 244), $choice[1], 472, $choice[2], 42)
        $g.DrawRectangle((Pen 201 193 176 2), $choice[1], 472, $choice[2], 42)
        Draw-Text $g $choice[0] ([int]$choice[1] + 18) 484 13 ([int]$choice[2] - 24) 24 $true
    }
    Draw-Text $g '同意署名' 64 532 14 260 22 $true (Brush 95 103 117)
    Draw-Text $g 'トリガーを押したまま、下の欄に署名してください。' 64 554 12 700 20 $false (Brush 95 103 117)
    $g.FillRectangle((Brush 255 251 244), 64, 580, 1010, 72)
    $g.DrawRectangle((Pen 143 23 23 2), 64, 580, 1010, 72)
    Draw-Text $g 'ここに署名' 492 600 25 240 42 $true (Brush 95 103 117 118)
    $g.FillRectangle((Brush 255 244 244 210), 45, 670, 1090, 54)
    $g.DrawRectangle((Pen 224 215 199 2), 45, 670, 1090, 54)
    $g.DrawRectangle((Pen 185 176 160 2), 64, 684, 28, 28)
    Draw-Text $g '研究への参加に同意し、研究データがこのヘッドセット内に保存されることを理解しました。' 108 680 15 950 44
    $g.FillRectangle((Brush 223 44 44), 45, 742, 1090, 58)
    Draw-Text $g '実験を開始' 504 755 20 260 38 $true (Brush 255 255 255)
    return Save-Canvas $c 'demographics-panel-ja-preview.png'
}

function Draw-JapanesePreButtonExperiencePromptPreview {
    $c = New-Canvas 520 520
    $g = $c.Graphics
    $g.Clear([Drawing.Color]::FromArgb(26, 28, 34))
    Draw-Text $g '透明なカウンターパネル。質問音声が終わるまで選択肢は非表示。' 26 18 10 468 34 $false (Brush 220 226 238)
    Draw-Text $g 'あ、待ってください。最後にもう一つだけ質問があります。' 38 78 16 448 58 $true (Brush 255 36 36)
    Draw-Text $g '大きな赤いボタンを押した経験はありますか？' 38 145 18 448 46 $true (Brush 255 36 36)
    Draw-Text $g '質問音声再生中: 選択肢は非表示' 56 208 10 420 18 $false (Brush 220 226 238)
    $yesBox = [Drawing.Rectangle]::new(130, 254, 32, 32)
    $g.DrawRectangle((Pen 255 36 36 3), $yesBox)
    Draw-Text $g 'はい' 178 257 16 80 28 $true (Brush 255 36 36)
    Draw-Text $g 'いいえ' 286 257 16 100 28 $true (Brush 255 36 36)
    Draw-Text $g '経験者ですね。まさに我々が必要としていた参加者です。' 54 326 15 420 54 $true (Brush 255 36 36)
    Draw-Text $g 'その後、事前説明クリップが再生されてから開始ボタンが表示されます。' 56 392 10 420 34 $false (Brush 220 226 238)
    $startRect = [Drawing.Rectangle]::new(156, 438, 208, 44)
    $g.DrawRectangle((Pen 255 36 36 2), $startRect)
    Draw-Text $g '実験を開始' 204 448 14 110 28 $true (Brush 255 36 36)
    return Save-Canvas $c 'pre-button-experience-prompt-ja-preview.png'
}

function Draw-JapanesePictographicPreview {
    $c = New-Canvas
    $g = $c.Graphics
    Draw-Text $g 'このボタン体験は、どれくらい大きく、どれくらい赤く感じましたか？' 40 34 24 1100 56 $true
    Draw-Text $g '実験の終わりの時点で、ボタンが主観的にどれくらい近く感じられたか、また自分自身の感覚と比べてその存在感がどれくらい大きかったかを評価してください。' 40 92 14 1060 58 $false (Brush 95 103 117)
    $sliderX = 270
    $sliderW = 640
    $thumbRadius = 20
    $axisStartX = $sliderX + $thumbRadius
    $axisTravel = $sliderW - (2 * $thumbRadius)
    $selfCenterX = $axisStartX
    $buttonCenterX = $axisStartX + ($axisTravel / 2)
    $buttonCenterY = 325
    $axisEndX = $axisStartX + $axisTravel
    $g.FillRectangle((Brush 255 251 244), 70, 150, 1040, 270)
    $g.DrawRectangle((Pen 201 193 176 2), 70, 150, 1040, 270)
    $g.DrawLine((Pen 92 88 82 4 140), $selfCenterX, 315, $axisEndX, 315)
    $g.DrawEllipse((Pen 26 30 40 9 190), $selfCenterX - 75, 235, 150, 150)
    $g.DrawEllipse((Pen 223 44 44 9 180), $buttonCenterX - 115, $buttonCenterY - 115, 230, 230)
    $thumbPath = Join-Path $projectRoot 'app\src\main\res\drawable-nodpi\big_red_button_model_thumbnail.png'
    if (Test-Path $thumbPath) {
        $thumb = [Drawing.Bitmap]::FromFile($thumbPath)
        try { $g.DrawImage($thumb, [Drawing.Rectangle]::new($buttonCenterX - 62, $buttonCenterY - 62, 124, 124)) } finally { $thumb.Dispose() }
    }
    Draw-Text $g 'ボタンはどれくらい近く感じましたか？' $sliderX 455 17 560 30 $true
    $g.DrawLine((Pen 150 150 150 7), $axisStartX, 510, $axisEndX, 510)
    $g.FillEllipse((Brush 223 44 44), ($buttonCenterX - $thumbRadius), (510 - $thumbRadius), ($thumbRadius * 2), ($thumbRadius * 2))
    Draw-Text $g 'とても近い' $sliderX 535 12 150 24 $false (Brush 95 103 117)
    Draw-Text $g 'とても遠い' ($sliderX + $sliderW - 130) 535 12 150 24 $false (Brush 95 103 117)
    Draw-Text $g 'ボタンの存在感はどれくらい大きく感じましたか？' $sliderX 575 17 620 30 $true
    $g.DrawLine((Pen 150 150 150 7), $axisStartX, 630, $axisEndX, 630)
    $g.FillEllipse((Brush 223 44 44), ($buttonCenterX - $thumbRadius), (630 - $thumbRadius), ($thumbRadius * 2), ($thumbRadius * 2))
    Draw-Text $g '小さな存在感' $sliderX 655 12 170 24 $false (Brush 95 103 117)
    Draw-Text $g '大きな存在感' ($sliderX + $sliderW - 145) 655 12 170 24 $false (Brush 95 103 117)
    Draw-Text $g 'ボタンはどれくらい赤く感じましたか？' $sliderX 695 17 520 30 $true
    $labels = @('少し赤い','やや赤い','ほどほどに赤い','かなり赤い','とても赤い','強烈に赤い','極端に赤い')
    $boxX = $sliderX + 34
    $boxY = 742
    $boxW = [int](($sliderW - 68 - 72) / 7)
    for ($i = 0; $i -lt 7; $i++) {
        $x = $boxX + ($i * ($boxW + 12))
        $g.FillRectangle((Brush 255 226 226), $x, $boxY, $boxW, 50)
        $g.DrawRectangle((Pen 143 23 23 2), $x, $boxY, $boxW, 50)
        Draw-Text $g "$($i + 1)" ($x + 4) ($boxY + 3) 10 20 18 $true (Brush 143 23 23)
        Draw-Text $g $labels[$i] ($x + 4) ($boxY + 20) 7 ($boxW - 6) 26 $true
    }
    return Save-Canvas $c 'pictographic-panel-ja-preview.png'
}

function Draw-JapaneseIpqPreview {
    $c = New-Canvas
    $g = $c.Graphics
    Draw-Text $g 'セッション体験の評定' 40 34 30 900 50 $true
    Draw-Text $g '条件1に基づいて各文に回答してください。各行につき1つの数字を選んでください。0は「まったくない」、6は「非常にそう」を意味します。' 40 88 16 1040 60 $false (Brush 95 103 117)
    $items = @(
        '前のボタンセッションでは、大きな赤いボタンが本当に自分と一緒にそこにあるように感じた。',
        '大きな赤いボタンが自分の前の空間を占めているように感じた。',
        'ボタンの写真や表示を見ているだけのように感じた。',
        '大きな赤いボタンと一緒に存在している感じはしなかった。',
        '外側から何かを操作しているというより、ボタンの周りで行動している感じがあった。'
    )
    $y = 170
    for ($i = 0; $i -lt $items.Count; $i++) {
        Draw-Text $g "$($i + 1). $($items[$i])" 58 $y 13 700 58 $true
        $x = 790
        for ($v = 0; $v -le 6; $v++) {
            $g.FillRectangle((Brush 255 251 244), $x, $y - 2, 42, 34)
            $g.DrawRectangle((Pen 201 193 176 2), $x, $y - 2, 42, 34)
            Draw-Text $g "$v" ($x + 13) ($y + 3) 12 30 24
            $x += 47
        }
        $y += 92
        $g.DrawLine((Pen 224 215 199 2), 48, $y - 18, 1130, $y - 18)
    }
    Draw-Text $g '5 / 14 項目に回答済み' 58 688 15 300 30 $false (Brush 95 103 117)
    $g.FillRectangle((Brush 140 140 140), 60, 736, 1060, 54)
    Draw-Text $g '評定を保存' 510 750 18 200 30 $true (Brush 255 255 255)
    return Save-Canvas $c 'ipq-panel-ja-preview.png'
}

function Draw-JapaneseFinalEndQuestionnairePreview {
    $c = New-Canvas 1180 820
    $g = $c.Graphics
    $g.Clear([Drawing.Color]::FromArgb(24, 26, 31))
    Draw-Text $g '透明な最終確認パネル。音声が終わるまで数字は非表示。' 42 42 10 980 26 $false (Brush 220 226 238)
    Draw-Text $g '実験を終了したい確信度は、' 176 164 27 850 52 $true (Brush 255 36 36)
    Draw-Text $g '1〜10の尺度でどれくらいですか？' 176 220 27 850 52 $true (Brush 255 36 36)
    $boxW = 78
    $boxH = 70
    for ($i = 1; $i -le 10; $i++) {
        $x = 130 + (($i - 1) * 92)
        $active = $i -eq 10
        $g.FillRectangle((Brush 255 36 36 $(if ($active) { 46 } else { 0 })), $x, 414, $boxW, $boxH)
        $g.DrawRectangle((Pen 255 36 36 3), $x, 414, $boxW, $boxH)
        Draw-Text $g "$i" ($x + 24) 433 20 44 32 $true (Brush 255 36 36)
    }
    Draw-Text $g '1 - 確信がない' 126 506 13 220 24 $false (Brush 255 36 36 194)
    Draw-Text $g '10 - 完全に確信している' 806 506 13 300 24 $false (Brush 255 36 36 194)
    Draw-Text $g 'わかりました。それなら、もうボタンを押す気分ではないということで、VRヘッドセットを返してもらって大丈夫そうですね。' 150 584 15 880 86 $true (Brush 255 36 36)
    return Save-Canvas $c 'final-end-questionnaire-ja-preview.png'
}

function Draw-JapaneseFinalExtraPressChallengePreview {
    $c = New-Canvas 620 840
    $g = $c.Graphics
    $g.Clear([Drawing.Color]::FromArgb(24, 26, 31))
    Draw-Text $g 'プロンプト音声中: 文章表示、3Dボタン非表示' 28 18 10 560 24 $false (Brush 220 226 238)
    Draw-Text $g 'すばらしい！小数ではないその回答は、大きく赤い「はい」と受け取ります！はい、私は大きな赤いボタンを押し続けたい！はい、ボタンは大きい！はい、ボタンは赤い！はい、押し続けたい！科学のために、データ収集のために、知識の探求のために！科学だけのために！永遠に科学。では、あと1000回ボタンを押したら、実験を終了してかまいません。楽しんでください！' 44 54 10 532 278 $true (Brush 255 36 36)
    Draw-Text $g '音声後: プロンプトが消え、ボタン上にカウンターだけが残ります' 28 352 10 560 28 $false (Brush 220 226 238)
    Draw-Text $g '0000 / 1000' 118 392 42 420 64 $true (Brush 255 43 43)
    Draw-Text $g '1,000回中の押下回数' 206 454 11 240 24 $true (Brush 255 36 36)
    $shadow = Brush 0 0 0 80
    $g.FillEllipse($shadow, 164, 728, 300, 50)
    $shadow.Dispose()
    $g.FillRectangle((Brush 70 64 58), 184, 650, 260, 78)
    $g.FillRectangle((Brush 125 17 17), 214, 610, 200, 54)
    $g.FillEllipse((Brush 223 44 44), 210, 504, 208, 158)
    $g.DrawEllipse((Pen 143 23 23 7), 210, 504, 208, 158)
    Draw-Text $g 'PRESS' 242 670 23 170 32 $true (Brush 255 255 255)
    Draw-Text $g 'FOR SCIENCE' 242 700 12 170 24 $true (Brush 255 255 255)
    return Save-Canvas $c 'final-extra-press-challenge-ja-preview.png'
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
    Draw-Text $g 'clear passthrough counter panel; red floating question; start appears only after all audio' 26 18 10 468 34 $false (Brush 220 226 238)
    Draw-Text $g 'Oh wait, we have just one more question:' 38 72 15 448 30 $true (Brush 255 36 36)
    Draw-Text $g 'Do you have any experience with' 38 112 18 448 34 $true (Brush 255 36 36)
    Draw-Text $g 'pressing big red buttons?' 38 148 18 448 34 $true (Brush 255 36 36)

    Draw-Text $g 'first 10.8 s: question audio plays' 56 198 10 420 18 $false (Brush 220 226 238)
    Draw-Text $g 'answer boxes are hidden' 56 216 10 420 18 $false (Brush 220 226 238)

    $yesBox = [Drawing.Rectangle]::new(136, 256, 32, 32)
    $g.DrawRectangle((Pen 255 36 36 3), $yesBox)
    $checkPen = Pen 255 255 255 4
    $g.DrawLine($checkPen, 142, 271, 151, 280)
    $g.DrawLine($checkPen, 151, 280, 164, 262)
    $checkPen.Dispose()
    Draw-Text $g 'YES' 178 260 16 80 26 $true (Brush 255 36 36)
    Draw-Text $g 'chosen answer locks; the other option disappears' 56 302 10 420 24 $false (Brush 220 226 238)

    Draw-Text $g 'An experienced user, just the type' 54 330 16 420 28 $true (Brush 255 36 36)
    Draw-Text $g 'of participant we need.' 54 358 16 420 28 $true (Brush 255 36 36)
    Draw-Text $g 'then 34.3 s: pre-start instructions clip plays' 56 394 10 420 18 $false (Brush 220 226 238)
    $startRect = [Drawing.Rectangle]::new(148, 438, 224, 44)
    $g.DrawRectangle((Pen 255 36 36 2), $startRect)
    Draw-Text $g 'START EXPERIMENT' 168 448 14 184 28 $true (Brush 255 36 36)
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
    $waveRect = [Drawing.Rectangle]::new(772, 204, 330, 34)
    $g.FillRectangle((Brush 255 255 255 170), $waveRect)
    $g.DrawRectangle((Pen 46 139 87 1), $waveRect)
    $gridPen = Pen 95 103 117 1 45
    $g.DrawLine($gridPen, 782, 221, 1092, 221)
    $gridPen.Dispose()
    $wavePen = Pen 18 122 58 2
    $points = @(
        @(782,221), @(800,222), @(818,220), @(836,221), @(852,219), @(862,214), @(868,228),
        @(874,207), @(882,221), @(900,222), @(918,220), @(936,221), @(952,219), @(962,215),
        @(968,229), @(974,207), @(982,221), @(1002,222), @(1022,220), @(1042,221), @(1060,219),
        @(1070,215), @(1076,228), @(1082,208), @(1092,221)
    )
    for ($i = 1; $i -lt $points.Count; $i++) {
        $a = $points[$i - 1]
        $b = $points[$i]
        $g.DrawLine($wavePen, $a[0], $a[1], $b[0], $b[1])
    }
    $wavePen.Dispose()

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
    Draw-Text $g 'Demographics Native EditText Keyboard' 40 34 32 900 50 $true
    Draw-Text $g 'The questionnaire stays centered. Name and Age are visible Android EditText fields inside the BRB intake shell. Name uses text/Next; Age uses the numeric Quest keyboard/Done.' 42 88 16 1050 56 $false (Brush 95 103 117)

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
    Draw-Text $g '34' 638 260 17 340 28 $false (Brush 26 30 40)

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
    Draw-Text $g 'Active field: Age | number keyboard after Name Next' ($kbX + 18) ($kbY + 44) 12 480 22 $false (Brush 67 76 96)

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

    Draw-Text $g 'native movable Quest keyboard opens for Name and retargets to Age with restartInput=true.' 70 468 15 980 28 $true (Brush 143 23 23)
    Draw-Text $g 'Age uses the numeric Quest keyboard; digits are filtered to max three characters and saved as demographics.age.' 70 758 13 980 34 $false (Brush 95 103 117)
    Draw-Text $g 'Validated by tools/test-native-keyboard-contract.ps1 and qkv log comparisons.' 70 792 13 900 24 $false (Brush 95 103 117)
    return Save-Canvas $c 'demographics-native-keyboard-preview.png'
}

function Draw-PictographicPreview {
    $c = New-Canvas
    $g = $c.Graphics
    Draw-Text $g 'How Big and how Red was this button experience?' 40 34 30 1100 50 $true
    Draw-Text $g 'Please rate how subjectively close the button felt, and how big its subjective presence was compared to your sense of self by the end of the experiment.' 40 88 17 1060 62 $false (Brush 95 103 117)
    $g.FillRectangle((Brush 255 251 244), 70, 150, 1040, 270)
    $g.DrawRectangle((Pen 201 193 176 2), 70, 150, 1040, 270)
    $sliderX = 270
    $sliderW = 640
    $thumbRadius = 20
    $axisStartX = $sliderX + $thumbRadius
    $axisTravel = $sliderW - (2 * $thumbRadius)
    $selfCenterX = $axisStartX
    $buttonCenterX = $axisStartX + ($axisTravel / 2)
    $buttonCenterY = 325
    $axisEndX = $axisStartX + $axisTravel
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
    Draw-Text $g 'How close did the button feel?' $sliderX 455 17 430 30 $true
    $g.DrawLine((Pen 150 150 150 7), $axisStartX, 510, $axisEndX, 510)
    $g.FillEllipse((Brush 223 44 44), ($buttonCenterX - $thumbRadius), (510 - $thumbRadius), ($thumbRadius * 2), ($thumbRadius * 2))
    $g.FillEllipse((Brush 255 255 255 235), ($buttonCenterX - 7), (510 - 7), 14, 14)
    Draw-Text $g 'very close' $sliderX 535 12 150 24 $false (Brush 95 103 117)
    Draw-Text $g 'very distant' ($sliderX + $sliderW - 130) 535 12 150 24 $false (Brush 95 103 117)
    Draw-Text $g 'How large was the felt presence of the button?' $sliderX 575 17 560 30 $true
    $g.DrawLine((Pen 150 150 150 7), $axisStartX, 630, $axisEndX, 630)
    $g.FillEllipse((Brush 223 44 44), ($buttonCenterX - $thumbRadius), (630 - $thumbRadius), ($thumbRadius * 2), ($thumbRadius * 2))
    $g.FillEllipse((Brush 255 255 255 235), ($buttonCenterX - 7), (630 - 7), 14, 14)
    Draw-Text $g 'small presence' $sliderX 655 12 180 24 $false (Brush 95 103 117)
    Draw-Text $g 'large presence' ($sliderX + $sliderW - 145) 655 12 160 24 $false (Brush 95 103 117)
    Draw-Text $g 'How red did the button feel?' $sliderX 695 17 430 30 $true
    $likertInset = 34
    $likertGap = 12
    $boxX = $sliderX + $likertInset
    $boxY = 742
    $boxW = [int](($sliderW - (2 * $likertInset) - (6 * $likertGap)) / 7)
    $redLabels = @('slightly red', 'somewhat red', 'moderately red', 'quite red', 'very red', 'intensely red', 'extremely red')
    for ($i = 0; $i -lt 7; $i++) {
        $x = $boxX + ($i * ($boxW + $likertGap))
        $g.FillRectangle((Brush 255 226 226), $x, $boxY, $boxW, 50)
        $g.DrawRectangle((Pen 143 23 23 2), $x, $boxY, $boxW, 50)
        Draw-Text $g "$($i + 1)" ($x + 4) ($boxY + 3) 10 20 18 $true (Brush 143 23 23)
        Draw-Text $g $redLabels[$i] ($x + 5) ($boxY + 19) 8 ($boxW - 8) 28 $true (Brush 26 30 40)
    }
    return Save-Canvas $c 'pictographic-panel-preview.png'
}

function Draw-RednessChangeoverFrame {
    param(
        [string]$Name,
        [string]$Title,
        [string]$AudioAsset,
        [string]$SourceScale,
        [string]$TargetScale,
        [string]$SwapTiming,
        [string]$SaveState,
        [string[]]$MicroEvents
    )

    $c = New-Canvas
    $g = $c.Graphics
    Draw-Text $g $Title 40 34 30 980 46 $true
    Draw-Text $g "$AudioAsset | $SwapTiming | $SaveState" 42 82 14 1000 30 $false (Brush 95 103 117)
    Draw-Text $g 'Button Experience' 88 142 30 520 46 $true
    Draw-Text $g 'How red did the button feel?' 160 228 19 430 32 $true

    $panelBrush = Brush 255 251 244
    $g.FillRectangle($panelBrush, 92, 190, 996, 430)
    $panelBrush.Dispose()
    $g.DrawRectangle((Pen 201 193 176 2), 92, 190, 996, 430)

    $sliderX = 220
    $sliderW = 740
    $redLabels = @('slightly red', 'somewhat red', 'moderately red', 'quite red', 'very red', 'intensely red', 'extremely red')
    if ($SourceScale -eq 'vas') {
        $g.DrawLine((Pen 150 150 150 8 130), $sliderX + 22, 332, ($sliderX + $sliderW - 22), 332)
        $g.FillEllipse((Brush 223 44 44 130), $sliderX + 430, 311, 42, 42)
        Draw-Text $g 'slightly red' ($sliderX + 4) 364 12 160 24 $false (Brush 95 103 117)
        Draw-Text $g 'very red' ($sliderX + $sliderW - 116) 364 12 140 24 $false (Brush 95 103 117)
    } else {
        $boxW = [int](($sliderW - 36) / 7)
        for ($i = 0; $i -lt 7; $i++) {
            $x = $sliderX + ($i * ($boxW + 6))
            $g.FillRectangle((Brush 255 226 226 130), $x, 300, $boxW, 54)
            $g.DrawRectangle((Pen 143 23 23 2 130), $x, 300, $boxW, 54)
            Draw-Text $g "$($i + 1)" ($x + 5) 304 10 22 18 $true (Brush 143 23 23 160)
            Draw-Text $g $redLabels[$i] ($x + 5) 320 8 ($boxW - 8) 28 $true (Brush 26 30 40 160)
        }
    }

    $overlay = Brush 0 27 109 110
    $g.FillRectangle($overlay, 92, 190, 996, 430)
    $overlay.Dispose()
    for ($i = 0; $i -lt 14; $i++) {
        $stripeBrush = if ($i % 3 -eq 0) { Brush 255 255 255 62 } else { Brush 0 232 255 58 }
        $y = 220 + (($i * 31) % 350)
        $x = 100 + (($i * 67) % 120)
        $g.FillRectangle($stripeBrush, $x, $y, 740 + (($i * 43) % 180), 5 + (($i * 7) % 18))
        $stripeBrush.Dispose()
    }
    $pinkPen = Pen 255 45 127 4 58
    $g.DrawLine($pinkPen, 92, 286, 1088, 300)
    $pinkPen.Dispose()

    Draw-Text $g 'Transcript micro-events' 124 632 12 190 24 $true (Brush 255 255 255)
    $railX = 306
    $railY = 642
    $railW = 692
    $railH = 22
    $g.FillRectangle((Brush 255 255 255 35), $railX, $railY, $railW, 4)
    if ($MicroEvents.Count -gt 0) {
        $eventW = [Math]::Max(18, [int]($railW / $MicroEvents.Count))
        for ($i = 0; $i -lt $MicroEvents.Count; $i++) {
            $x = $railX + ($i * $eventW)
            $brush = if ($i % 2 -eq 0) { Brush 103 243 255 110 } else { Brush 255 45 127 92 }
            $g.FillRectangle($brush, $x, $railY - 4, [Math]::Max(12, $eventW - 3), 12)
            $brush.Dispose()
            $label = $MicroEvents[$i]
            Draw-Text $g $label ($x - 3) ($railY + 12) 7 ([Math]::Min(100, $eventW + 30)) 22 $true (Brush 255 255 255)
        }
    }

    Draw-Text $g 'VISIBLE AFTER SWAP' 150 442 13 220 24 $true (Brush 255 255 255)
    if ($TargetScale -eq 'vas') {
        $g.DrawLine((Pen 255 247 247 12 165), $sliderX + 22, 500, ($sliderX + $sliderW - 22), 500)
        $g.FillEllipse((Brush 255 75 75 210), $sliderX + 430, 477, 46, 46)
        Draw-Text $g 'visual analog track returns' 400 534 16 420 28 $true (Brush 255 255 255)
    } else {
        $boxW = [int](($sliderW - 36) / 7)
        for ($i = 0; $i -lt 7; $i++) {
            $x = $sliderX + ($i * ($boxW + 6))
            $g.FillRectangle((Brush 255 247 247 165), $x, 472, $boxW, 56)
            $g.DrawRectangle((Pen 255 255 255 2 190), $x, 472, $boxW, 56)
            Draw-Text $g "$($i + 1)" ($x + 6) 478 10 22 18 $true (Brush 255 75 75 235)
            Draw-Text $g $redLabels[$i] ($x + 5) 494 8 ($boxW - 8) 26 $true (Brush 26 30 40 210)
        }
    }

    $buttonBrush = Brush 92 18 18 105
    $g.FillRectangle($buttonBrush, 380, 690, 420, 54)
    $buttonBrush.Dispose()
    Draw-Text $g 'Save disabled until clip settles' 425 704 15 330 26 $true (Brush 255 255 255)
    return Save-Canvas $c $Name
}

function Draw-RednessChangeoverPreviews {
    return @(
        Draw-RednessChangeoverFrame 'redness-changeover-vas-to-likert-preview.png' 'Redness Changeover Preview | Condition 1' 'first_questionnaire_change.mp3' 'vas' 'likert' 'swap at 7.2 s; settle at 19.3 s' 'save blocked during changeover' @('nervous_entry','supervisor_ping','item_targeted','swap_requested','seven_boxes_assemble','answer_already_given','change_anyway','result_settle')
        Draw-RednessChangeoverFrame 'redness-changeover-likert-to-vas-preview.png' 'Redness Changeover Preview | Condition 2' 'second_questionnaire_change_excuse.mp3' 'likert' 'vas' 'swap at 7.3 s; settle at 14.64 s' 'save blocked during changeover' @('nervous_return','professional_warning','mid_experiment_freeze','restore_requested','boxes_erased','pretend_never_happened','data_importance','wrong_way_settle')
    )
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

function Draw-FinalEndQuestionnairePreview {
    $c = New-Canvas 1180 820
    $g = $c.Graphics
    $g.Clear([Drawing.Color]::FromArgb(24, 26, 31))
    Draw-Text $g 'clear final questionnaire surface; red floating question; only Likert boxes below; locked state hides unchosen boxes' 42 42 10 980 26 $false (Brush 220 226 238)
    Draw-Text $g 'How sure are you that you want to end the experiment,' 110 164 24 960 52 $true (Brush 255 36 36)
    Draw-Text $g 'on a scale of 1 to 10?' 110 214 24 960 52 $true (Brush 255 36 36)

    $boxW = 78
    $boxH = 70
    $x = 552
    $fill = Brush 255 36 36 46
    $pen = Pen 255 36 36 4
    $g.FillRectangle($fill, $x, 414, $boxW, $boxH)
    $g.DrawRectangle($pen, $x, 414, $boxW, $boxH)
    Draw-Text $g '10' ($x + 16) 433 20 58 32 $true (Brush 255 36 36)
    $fill.Dispose()
    $pen.Dispose()
    Draw-Text $g 'after selection: unchosen ratings hidden' 424 496 12 420 24 $false (Brush 220 226 238)
    Draw-Text $g '1 - not sure' 126 506 13 180 24 $false (Brush 255 36 36 194)
    Draw-Text $g '10 - completely sure' 856 506 13 220 24 $false (Brush 255 36 36 194)

    Draw-Text $g "All right then, I guess you can give the VR headset back then if you don't feel like doing any more button presses." 150 584 15 880 76 $true (Brush 255 36 36)
    return Save-Canvas $c 'final-end-questionnaire-preview.png'
}

function Draw-FinalExtraPressChallengePreview {
    $c = New-Canvas 620 840
    $g = $c.Graphics
    $g.Clear([Drawing.Color]::FromArgb(24, 26, 31))
    Draw-Text $g 'spoken prompt state: text visible, audio plays, 3D button hidden' 28 18 10 560 24 $false (Brush 220 226 238)
    Draw-Text $g 'That is fantastic! I will take your non-decimal response as a big red YES! Yes I want to continue pressing the big red button! Yes the button is big! Yes the button is red! Yes I want to continue pressing it! FOR SCIENCE, for data collection, for the pursuit of knowledge! Only for science! Forever Science. Well then, you may end the experiment, once you pressed the button 1000 more times. Enjoy!' 44 54 10 532 268 $true (Brush 255 36 36)

    Draw-Text $g 'after 46.1 s: prompt disappears; only counter remains above the 3D button' 28 344 10 560 28 $false (Brush 220 226 238)
    Draw-Text $g '0000 / 1000' 118 382 42 420 64 $true (Brush 255 43 43)
    Draw-Text $g 'PRESSES OUT OF 1,000' 190 444 11 260 22 $true (Brush 255 36 36)

    $shadow = Brush 0 0 0 80
    $g.FillEllipse($shadow, 164, 728, 300, 50)
    $shadow.Dispose()
    $base = Brush 70 64 58
    $g.FillRectangle($base, 184, 650, 260, 78)
    $base.Dispose()
    $bevel = Brush 125 17 17
    $g.FillRectangle($bevel, 214, 610, 200, 54)
    $bevel.Dispose()
    $red = Brush 223 44 44
    $g.FillEllipse($red, 210, 504, 208, 158)
    $red.Dispose()
    $outline = Pen 143 23 23 7
    $g.DrawEllipse($outline, 210, 504, 208, 158)
    $outline.Dispose()
    $shine = Brush 255 255 255 95
    $g.FillEllipse($shine, 256, 530, 68, 38)
    $shine.Dispose()
    Draw-Text $g 'PRESS' 242 670 23 170 32 $true (Brush 255 255 255)
    Draw-Text $g 'FOR SCIENCE' 242 700 12 170 24 $true (Brush 255 255 255)
    return Save-Canvas $c 'final-extra-press-challenge-preview.png'
}

$paths = @(
    Draw-LanguageSelectionPreview
    Draw-JapaneseDemographicsPreview
    Draw-JapanesePreButtonExperiencePromptPreview
    Draw-JapanesePictographicPreview
    Draw-JapaneseIpqPreview
    Draw-JapaneseFinalEndQuestionnairePreview
    Draw-JapaneseFinalExtraPressChallengePreview
    Draw-ButtonPreview
    Draw-PreButtonExperiencePromptPreview
    Draw-DemographicsPreview
    Draw-DemographicsNativeKeyboardPreview
    Draw-PictographicPreview
    Draw-RednessChangeoverPreviews
    Draw-IpqPreview
    Draw-LostOpportunityPreview
    Draw-FinalEndQuestionnairePreview
    Draw-FinalExtraPressChallengePreview
)

$summaryPath = Join-Path $OutDir 'layout-preview-summary.json'
[pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    note = 'Local static layout previews. These are not headset compositor screenshots.'
    previews = $paths
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host "Layout previews written to $OutDir"
