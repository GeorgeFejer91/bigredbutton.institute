[CmdletBinding()]
param(
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$studyRoot = (Resolve-Path (Join-Path $projectRoot '..')).Path
$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail
    )
    $checks.Add([pscustomobject]@{
        name = $Name
        passed = $Passed
        detail = $Detail
    })
    if ($Passed) {
        Write-Host "PASS $Name - $Detail"
    } else {
        Write-Host "FAIL $Name - $Detail"
    }
}

function Get-GlbJson {
    param([string]$Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    $magic = [Text.Encoding]::ASCII.GetString($bytes, 0, 4)
    if ($magic -ne 'glTF') {
        throw "$Path is not a GLB file."
    }
    $version = [BitConverter]::ToUInt32($bytes, 4)
    if ($version -ne 2) {
        throw "$Path is GLB version $version, expected 2."
    }
    $jsonLength = [BitConverter]::ToUInt32($bytes, 12)
    $jsonType = [Text.Encoding]::ASCII.GetString($bytes, 16, 4)
    if ($jsonType -ne 'JSON') {
        throw "$Path first chunk is $jsonType, expected JSON."
    }
    $json = [Text.Encoding]::UTF8.GetString($bytes, 20, $jsonLength).Trim([char]0, [char]32)
    return $json | ConvertFrom-Json
}

function Get-GlbPositionBounds {
    param($Glb)
    [double[]]$mins = @(1e9, 1e9, 1e9)
    [double[]]$maxs = @(-1e9, -1e9, -1e9)
    foreach ($mesh in @($Glb.meshes)) {
        foreach ($primitive in @($mesh.primitives)) {
            $positionAccessorIndex = $primitive.attributes.POSITION
            $accessor = @($Glb.accessors)[$positionAccessorIndex]
            if ($accessor.type -ne 'VEC3' -or -not $accessor.min -or -not $accessor.max) {
                continue
            }
            for ($i = 0; $i -lt 3; $i++) {
                $mins[$i] = [Math]::Min([double]$mins[$i], [double]$accessor.min[$i])
                $maxs[$i] = [Math]::Max([double]$maxs[$i], [double]$accessor.max[$i])
            }
        }
    }
    return [pscustomobject]@{
        min = $mins
        max = $maxs
        range = @(
            ([double]$maxs[0] - [double]$mins[0]),
            ([double]$maxs[1] - [double]$mins[1]),
            ([double]$maxs[2] - [double]$mins[2])
        )
    }
}

function Get-KotlinFloatConst {
    param(
        [string]$Text,
        [string]$Name
    )
    $pattern = "private const val\s+$([regex]::Escape($Name))\s*=\s*([0-9]+(?:\.[0-9]+)?)f"
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        return $null
    }
    return [double]::Parse($match.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
}

$manifest = Join-Path $projectRoot 'app\src\main\AndroidManifest.xml'
$buildGradle = Join-Path $projectRoot 'app\build.gradle.kts'
$activity = Join-Path $projectRoot 'app\src\main\java\org\bigredbutton\firststudy\BigRedButtonStudyActivity.kt'
$audio1 = Join-Path $studyRoot 'audio-assets\final\first-big-red-button-vr-study-instructions-final.mp3'
$audio2 = Join-Path $studyRoot 'audio-assets\final\first-big-red-button-vr-study-instructions-second-instructions-5-final.mp3'
$buttonModel = Join-Path $projectRoot 'app\src\main\assets\models\BigRedButton.glb'
$buttonThumbnail = Join-Path $projectRoot 'app\src\main\res\drawable-nodpi\big_red_button_model_thumbnail.png'
$questionnaireIntroGlitch = Join-Path $projectRoot 'app\src\main\res\raw\questionnaire_intro_glitch.mp3'
$questionnaireOutroGlitch = Join-Path $projectRoot 'app\src\main\res\raw\questionnaire_outro_glitch.mp3'
$firstQuestionnaireChange = Join-Path $projectRoot 'app\src\main\res\raw\first_questionnaire_change.mp3'
$secondQuestionnaireChange = Join-Path $projectRoot 'app\src\main\res\raw\second_questionnaire_change_excuse.mp3'
$firstQuestionnaireChangeSource = Join-Path $projectRoot '..\audio-assets\questionnaire\first-questionnaire-change.mp3'
$secondQuestionnaireChangeSource = Join-Path $projectRoot '..\audio-assets\questionnaire\second-questionnaire-change-excuse.mp3'
$questionnaireChoiceSound = Join-Path $projectRoot 'app\src\main\res\raw\ui_choice_blip.wav'
$questionnaireNavigationSound = Join-Path $projectRoot 'app\src\main\res\raw\ui_navigation_blip.wav'
$priorButtonExperienceQuestionSound = Join-Path $projectRoot 'app\src\main\res\raw\prior_button_experience_question.mp3'
$priorButtonExperienceYesSound = Join-Path $projectRoot 'app\src\main\res\raw\prior_button_experience_yes.mp3'
$priorButtonExperienceNoSound = Join-Path $projectRoot 'app\src\main\res\raw\prior_button_experience_no.mp3'
$priorButtonExperiencePreStartSound = Join-Path $projectRoot 'app\src\main\res\raw\pre_start_instructions.mp3'
$finalEndConfirmationQuestionSound = Join-Path $projectRoot 'app\src\main\res\raw\final_end_confirmation_question_prompt.mp3'
$finalEndConfirmation10FeedbackSound = Join-Path $projectRoot 'app\src\main\res\raw\final_end_confirmation_10_feedback.mp3'
$finalExtraPressPromptSound = Join-Path $projectRoot 'app\src\main\res\raw\final_extra_presses_prompt.mp3'
$buttonPressSound = Join-Path $projectRoot 'app\src\main\assets\sfx\button-press-placeholder-kenney-bong.ogg'
$simulatedRrAsset = Join-Path $projectRoot 'app\src\main\assets\ecg\neurokit2_simulated_rr_intervals_ms.csv'
$polarClient = Join-Path $projectRoot 'app\src\main\java\org\bigredbutton\firststudy\PolarH10HeartRateClient.kt'
$glowVariantGenerator = Join-Path $projectRoot 'tools\create-button-glow-variants.py'

Add-Check 'manifest exists' (Test-Path $manifest) $manifest
Add-Check 'activity exists' (Test-Path $activity) $activity
Add-Check 'condition 1 audio exists' (Test-Path $audio1) $audio1
Add-Check 'condition 2 audio exists' (Test-Path $audio2) $audio2
Add-Check 'Big Red Button model exists' (Test-Path $buttonModel) $buttonModel
Add-Check 'pictographic button thumbnail exists' (Test-Path $buttonThumbnail) $buttonThumbnail
Add-Check 'questionnaire intro glitch sound exists' (Test-Path $questionnaireIntroGlitch) $questionnaireIntroGlitch
Add-Check 'questionnaire outro glitch sound exists' (Test-Path $questionnaireOutroGlitch) $questionnaireOutroGlitch
Add-Check 'questionnaire choice sound exists' (Test-Path $questionnaireChoiceSound) $questionnaireChoiceSound
Add-Check 'questionnaire navigation sound exists' (Test-Path $questionnaireNavigationSound) $questionnaireNavigationSound
Add-Check 'prior button experience question sound exists' (Test-Path $priorButtonExperienceQuestionSound) $priorButtonExperienceQuestionSound
Add-Check 'prior button experience yes feedback sound exists' (Test-Path $priorButtonExperienceYesSound) $priorButtonExperienceYesSound
Add-Check 'prior button experience no feedback sound exists' (Test-Path $priorButtonExperienceNoSound) $priorButtonExperienceNoSound
Add-Check 'pre-start instructions sound exists' (Test-Path $priorButtonExperiencePreStartSound) $priorButtonExperiencePreStartSound
Add-Check 'final end confirmation question prompt sound exists' (Test-Path $finalEndConfirmationQuestionSound) $finalEndConfirmationQuestionSound
Add-Check 'final end confirmation 10 feedback sound exists' (Test-Path $finalEndConfirmation10FeedbackSound) $finalEndConfirmation10FeedbackSound
Add-Check 'final extra presses prompt sound exists' (Test-Path $finalExtraPressPromptSound) $finalExtraPressPromptSound
Add-Check 'button press sound placeholder exists' (Test-Path $buttonPressSound) $buttonPressSound
Add-Check 'simulated NeuroKit2 RR asset exists' (Test-Path $simulatedRrAsset) $simulatedRrAsset
Add-Check 'Polar H10 BLE client exists' (Test-Path $polarClient) $polarClient
Add-Check 'button glow variant generator exists' (Test-Path $glowVariantGenerator) $glowVariantGenerator

if (Test-Path $audio1) {
    Add-Check 'condition 1 audio nonempty' ((Get-Item $audio1).Length -gt 100000) ((Get-Item $audio1).Length.ToString())
    Add-Check 'condition 1 audio hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $audio1).Hash -eq 'A3767727AE935BE2455282F52C4765833DA9C04F95EDA81BA0354C7E1CE4F0C6') 'original final MP3 SHA256'
}
if (Test-Path $audio2) {
    Add-Check 'condition 2 audio nonempty' ((Get-Item $audio2).Length -gt 100000) ((Get-Item $audio2).Length.ToString())
    Add-Check 'condition 2 audio hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $audio2).Hash -eq 'E52E53640DF5398FEC3DFE328877CBE429EDD3F5D3AB60E5A19FB1C6EBAD48A7') 'original final MP3 SHA256'
}
if (Test-Path $buttonModel) {
    Add-Check 'Big Red Button model hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $buttonModel).Hash -eq '4BA2C479EAE6A103ADCE0B7D0AB70C94A5F21A12435DD90ACD0071F66EF5F52B') 'smooth realistic BigRedButton.glb SHA256'
    $buttonGlb = Get-GlbJson $buttonModel
    $meshCount = @($buttonGlb.meshes).Count
    $materialCount = @($buttonGlb.materials).Count
    $animationNames = @($buttonGlb.animations | ForEach-Object { $_.name })
    $nodeNames = @($buttonGlb.nodes | ForEach-Object { $_.name })
    $indexAccessorIndices = New-Object System.Collections.Generic.List[int]
    foreach ($mesh in @($buttonGlb.meshes)) {
        foreach ($primitive in @($mesh.primitives)) {
            $indexAccessorIndices.Add([int]$primitive.indices)
        }
    }
    $triangleCount = 0
    foreach ($indexAccessorIndex in $indexAccessorIndices) {
        $triangleCount += [int](@($buttonGlb.accessors)[$indexAccessorIndex].count / 3)
    }
    $vertexCount = 0
    foreach ($mesh in @($buttonGlb.meshes)) {
        foreach ($primitive in @($mesh.primitives)) {
            $vertexCount += [int](@($buttonGlb.accessors)[$primitive.attributes.POSITION].count)
        }
    }
    $bounds = Get-GlbPositionBounds $buttonGlb
    $scaledHeight = [Math]::Round([double]$bounds.range[1] * 16.0, 3)
    $scaledDiameter = [Math]::Round([Math]::Max([double]$bounds.range[0], [double]$bounds.range[2]) * 16.0, 3)
    Add-Check 'Big Red Button GLB has smooth model detail' ($meshCount -ge 4 -and $vertexCount -ge 1500 -and $triangleCount -ge 2500) "meshes=$meshCount vertices=$vertexCount triangles=$triangleCount"
    Add-Check 'Big Red Button GLB has realistic materials' ($materialCount -ge 4 -and ($buttonGlb.materials | ConvertTo-Json -Compress -Depth 5).Contains('glossy_red_button_cap')) "materials=$materialCount"
    Add-Check 'Big Red Button GLB pressed animation exists' ($animationNames -contains 'pressed' -and $nodeNames -contains 'button') "animations=$($animationNames -join ',') nodes=$($nodeNames -join ',')"
    Add-Check 'Big Red Button GLB dimensions fit collider envelope' ($scaledHeight -ge 0.25 -and $scaledHeight -le 0.35 -and $scaledDiameter -ge 0.25 -and $scaledDiameter -le 0.35) "scaledHeight=${scaledHeight}m scaledDiameter=${scaledDiameter}m"
}
if (Test-Path $buttonThumbnail) {
    Add-Check 'pictographic button thumbnail hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $buttonThumbnail).Hash -eq 'F551A4F469984301FB87B4E59B1094AD27FA3B0F14930A353C17AFC881A69B90') 'rendered from smooth BigRedButton.glb'
}
if (Test-Path $questionnaireIntroGlitch) {
    Add-Check 'questionnaire intro glitch sound hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $questionnaireIntroGlitch).Hash -eq '3B78AE610233BBCA731BE13E50E33F5C50D697E0A7170522C38E87923347F087') 'intro.mp3 supplied from AssistantVideos'
    Add-Check 'questionnaire intro glitch sound nonempty' ((Get-Item $questionnaireIntroGlitch).Length -gt 10000) ((Get-Item $questionnaireIntroGlitch).Length.ToString())
}
if (Test-Path $questionnaireOutroGlitch) {
    Add-Check 'questionnaire outro glitch sound hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $questionnaireOutroGlitch).Hash -eq 'B57A15DA2E1CC9D93A8D915696663E8BABE293FD53A0E8FDD8604D51A931292F') 'outro.mp3 supplied from AssistantVideos'
    Add-Check 'questionnaire outro glitch sound nonempty' ((Get-Item $questionnaireOutroGlitch).Length -gt 10000) ((Get-Item $questionnaireOutroGlitch).Length.ToString())
}
if ((Test-Path $firstQuestionnaireChange) -and (Test-Path $firstQuestionnaireChangeSource)) {
    Add-Check 'first redness questionnaire-change sound hash preserved' (
        (Get-FileHash -Algorithm SHA256 -LiteralPath $firstQuestionnaireChange).Hash -eq 'F49538CB8B41959C95B760F6A7CF5B63D2BDC9D979C40739A10DA2AAED50570D' -and
        (Get-FileHash -Algorithm SHA256 -LiteralPath $firstQuestionnaireChangeSource).Hash -eq 'F49538CB8B41959C95B760F6A7CF5B63D2BDC9D979C40739A10DA2AAED50570D'
    ) 'first-questionnaire-change.mp3 recovered from Gmail raw MIME and packaged byte-identically'
    Add-Check 'first redness questionnaire-change sound nonempty' ((Get-Item $firstQuestionnaireChange).Length -gt 300000) ((Get-Item $firstQuestionnaireChange).Length.ToString())
} else {
    Add-Check 'first redness questionnaire-change sound exists' $false 'source audio-assets/questionnaire and app raw resource must both exist'
}
if ((Test-Path $secondQuestionnaireChange) -and (Test-Path $secondQuestionnaireChangeSource)) {
    Add-Check 'second redness questionnaire-change sound hash preserved' (
        (Get-FileHash -Algorithm SHA256 -LiteralPath $secondQuestionnaireChange).Hash -eq 'E008B68E8C158A4CD86D89E695A38AB8FC71573F1507051EEBDCFB1C7C796CDC' -and
        (Get-FileHash -Algorithm SHA256 -LiteralPath $secondQuestionnaireChangeSource).Hash -eq 'E008B68E8C158A4CD86D89E695A38AB8FC71573F1507051EEBDCFB1C7C796CDC'
    ) 'second-questionnaire-change-excuse.mp3 recovered from Gmail raw MIME and packaged byte-identically'
    Add-Check 'second redness questionnaire-change sound nonempty' ((Get-Item $secondQuestionnaireChange).Length -gt 250000) ((Get-Item $secondQuestionnaireChange).Length.ToString())
} else {
    Add-Check 'second redness questionnaire-change sound exists' $false 'source audio-assets/questionnaire and app raw resource must both exist'
}
if (Test-Path $questionnaireChoiceSound) {
    Add-Check 'questionnaire choice sound hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $questionnaireChoiceSound).Hash -eq '5005D0A634AAC456D3D495824C057ED14CF58D21EFC16C06772B48520436F8A4') 'short UI choice cue SHA256'
}
if (Test-Path $questionnaireNavigationSound) {
    Add-Check 'questionnaire navigation sound hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $questionnaireNavigationSound).Hash -eq 'DEF7603B0786070F01F0EFEACEA74F321F946EF217F0E11EA45B34990BF46F51') 'short UI navigation cue SHA256'
}
if (Test-Path $priorButtonExperienceQuestionSound) {
    Add-Check 'prior button experience question sound hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $priorButtonExperienceQuestionSound).Hash -eq '735ACE7698E8D085A693B29FB231A21718E364FE61F09B643EA03C37F80FDCFB') 'supplied prior button experience question MP3 SHA256'
    Add-Check 'prior button experience question sound nonempty' ((Get-Item $priorButtonExperienceQuestionSound).Length -gt 100000) ((Get-Item $priorButtonExperienceQuestionSound).Length.ToString())
}
if (Test-Path $priorButtonExperienceYesSound) {
    Add-Check 'prior button experience yes feedback sound hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $priorButtonExperienceYesSound).Hash -eq '3867345F273BE83B7AB769961286A90F4E22EAA48730CA0B31C13BEEAA21DFEE') 'supplied prior button experience yes MP3 SHA256'
    Add-Check 'prior button experience yes feedback sound nonempty' ((Get-Item $priorButtonExperienceYesSound).Length -gt 50000) ((Get-Item $priorButtonExperienceYesSound).Length.ToString())
}
if (Test-Path $priorButtonExperienceNoSound) {
    Add-Check 'prior button experience no feedback sound hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $priorButtonExperienceNoSound).Hash -eq '30BE2B59158189DF8EFC7F2DFD1B4BD9CABDFC13400EE6F79227CFE0D2F508E9') 'supplied prior button experience no MP3 SHA256'
    Add-Check 'prior button experience no feedback sound nonempty' ((Get-Item $priorButtonExperienceNoSound).Length -gt 50000) ((Get-Item $priorButtonExperienceNoSound).Length.ToString())
}
if (Test-Path $priorButtonExperiencePreStartSound) {
    Add-Check 'pre-start instructions sound hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $priorButtonExperiencePreStartSound).Hash -eq '82E4F551785BF893D3686258F8072E3F46B8B4BF675CD21898BD790C70C13C27') 'supplied pre-start instructions MP3 SHA256'
    Add-Check 'pre-start instructions sound nonempty' ((Get-Item $priorButtonExperiencePreStartSound).Length -gt 500000) ((Get-Item $priorButtonExperiencePreStartSound).Length.ToString())
}
if (Test-Path $finalEndConfirmationQuestionSound) {
    Add-Check 'final end confirmation question prompt sound hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $finalEndConfirmationQuestionSound).Hash -eq '52CFEF284158C760771C20F8126816C0DFD451EE34639998CEFF4143CDB85F6A') 'supplied final end confirmation question prompt MP3 SHA256'
    Add-Check 'final end confirmation question prompt sound nonempty' ((Get-Item $finalEndConfirmationQuestionSound).Length -gt 50000) ((Get-Item $finalEndConfirmationQuestionSound).Length.ToString())
}
if (Test-Path $finalEndConfirmation10FeedbackSound) {
    Add-Check 'final end confirmation 10 feedback sound hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $finalEndConfirmation10FeedbackSound).Hash -eq 'C119CD2DA25693DA58ECDF90B7A50F13597DE979A469D5AD2D154F8911B8A29F') 'supplied final end confirmation feedback MP3 SHA256'
    Add-Check 'final end confirmation 10 feedback sound nonempty' ((Get-Item $finalEndConfirmation10FeedbackSound).Length -gt 100000) ((Get-Item $finalEndConfirmation10FeedbackSound).Length.ToString())
}
if (Test-Path $finalExtraPressPromptSound) {
    Add-Check 'final extra presses prompt sound hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $finalExtraPressPromptSound).Hash -eq '2D8BA3229E920770A8C31C946787A1CCA06D5D6063FD7FC7881ACE8D6988DF35') 'supplied final extra presses prompt MP3 SHA256'
    Add-Check 'final extra presses prompt sound nonempty' ((Get-Item $finalExtraPressPromptSound).Length -gt 500000) ((Get-Item $finalExtraPressPromptSound).Length.ToString())
}
if (Test-Path $buttonPressSound) {
    Add-Check 'button press sound placeholder hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $buttonPressSound).Hash -eq 'D21D0F0B782445DB579D11E2506B24CD1AC9D664EE33AEAF807761AA7B6FD710') 'Kenney CC0 bong_001.ogg placeholder SHA256'
}
if (Test-Path $simulatedRrAsset) {
    $rrLines = @(Get-Content -LiteralPath $simulatedRrAsset)
    Add-Check 'simulated NeuroKit2 RR asset hash preserved' ((Get-FileHash -Algorithm SHA256 -LiteralPath $simulatedRrAsset).Hash -eq '80D612CEC91C511471F19347C0B76A997FAF0E4AB785E2003B10179C819801C1') 'NeuroKit2-generated RR interval CSV SHA256'
    Add-Check 'simulated NeuroKit2 RR asset has intervals' ($rrLines.Count -gt 800 -and $rrLines[0].Contains('index') -and $rrLines[0].Contains('rr_interval_ms')) "lines=$($rrLines.Count)"
}
if (Test-Path $glowVariantGenerator) {
    $glowVariantGeneratorText = Get-Content -Raw -LiteralPath $glowVariantGenerator
    Add-Check 'button glow variant generator uses opaque material emission' (
        $glowVariantGeneratorText.Contains('CAP_PEAK_EMISSION') -and
        $glowVariantGeneratorText.Contains('BEZEL_PEAK_EMISSION') -and
        $glowVariantGeneratorText.Contains('BASE_PEAK_EMISSION') -and
        $glowVariantGeneratorText.Contains('emissiveFactor') -and
        $glowVariantGeneratorText.Contains('baseColorFactor') -and
        $glowVariantGeneratorText.Contains('BigRedButtonGlowLevel') -and
        $glowVariantGeneratorText.Contains('default=32') -and
        -not $glowVariantGeneratorText.Contains('AlphaMode.TRANSLUCENT') -and
        -not $glowVariantGeneratorText.Contains('SpatialBlendMode.ADDITIVE')
    ) 'generator writes 32 GLB material variants with cap emission plus subtle bezel warmth while preserving the dark base, rather than transparent overlay geometry'
}
if (Test-Path $polarClient) {
    $polarClientText = Get-Content -Raw -LiteralPath $polarClient
    Add-Check 'Polar H10 client uses standard Heart Rate Service' (
        $polarClientText.Contains('0000180d-0000-1000-8000-00805f9b34fb') -and
        $polarClientText.Contains('00002a37-0000-1000-8000-00805f9b34fb') -and
        $polarClientText.Contains('rrIntervalsMs') -and
        $polarClientText.Contains('raw * 1000.0 / 1024.0')
    ) 'standard BLE HR measurement with RR interval decoding'
    Add-Check 'Polar H10 client reports validity status' (
        $polarClientText.Contains('BRB_POLAR_H10_STATUS') -and
        $polarClientText.Contains('missing_permissions') -and
        $polarClientText.Contains('streaming')
    ) 'status snapshots drive first-menu PMD ECG-ready check'
}

if (Test-Path $manifest) {
    $manifestText = Get-Content -Raw -LiteralPath $manifest
    Add-Check 'VR launch category' ($manifestText.Contains('com.oculus.intent.category.VR')) 'com.oculus.intent.category.VR'
    Add-Check 'passthrough feature declared' ($manifestText.Contains('com.oculus.feature.PASSTHROUGH')) 'com.oculus.feature.PASSTHROUGH'
    Add-Check 'Quest 3 support declared' ($manifestText.Contains('quest3')) 'quest3|quest3s'
    Add-Check 'Quest virtual keyboard declared' ($manifestText.Contains('com.oculus.feature.VIRTUAL_KEYBOARD') -and $manifestText.Contains('oculus.software.overlay_keyboard') -and $manifestText.Contains('stateAlwaysVisible|adjustNothing')) 'virtual keyboard feature and soft input mode'
    Add-Check 'Quest high-frequency hand tracking declared' (
        $manifestText.Contains('horizonos.permission.HAND_TRACKING') -and
        $manifestText.Contains('com.oculus.permission.HAND_TRACKING') -and
        $manifestText.Contains('com.oculus.handtracking.frequency') -and
        $manifestText.Contains('HIGH')
    ) 'high-frequency hand tracking metadata and permissions for hand-only contact attempts'
    Add-Check 'BLE permissions declared for Polar H10' (
        $manifestText.Contains('android.permission.BLUETOOTH_SCAN') -and
        $manifestText.Contains('android.permission.BLUETOOTH_CONNECT') -and
        $manifestText.Contains('android.permission.ACCESS_FINE_LOCATION')
    ) 'runtime BLE scan/connect permissions'
}

if (Test-Path $buildGradle) {
    $buildText = Get-Content -Raw -LiteralPath $buildGradle
    Add-Check 'native Quest package' ($buildText.Contains('applicationId = "org.bigredbutton.firststudy"')) 'org.bigredbutton.firststudy'
}

if (Test-Path $activity) {
    $activityText = Get-Content -Raw -LiteralPath $activity
    $ipqItemCount = ([regex]::Matches($activityText, 'PresenceItem\s*\(')).Count - 1
    Add-Check 'adapted IPQ item count' ($ipqItemCount -eq 14) "count=$ipqItemCount"
    Add-Check 'passthrough enabled in scene' ($activityText.Contains('scene.enablePassthrough(true)')) 'scene.enablePassthrough(true)'
    Add-Check 'condition 1 audio asset reference' ($activityText.Contains('first-big-red-button-vr-study-instructions-final.mp3')) 'condition 1 final MP3'
    Add-Check 'condition 2 audio asset reference' ($activityText.Contains('first-big-red-button-vr-study-instructions-second-instructions-5-final.mp3')) 'condition 2 final MP3'
    Add-Check 'media completion ends condition' ($activityText.Contains('setOnCompletionListener { endConditionFromAudio() }')) 'MediaPlayer completion gate'
    Add-Check 'model-backed 3D button visual' ($activityText.Contains('buttonVisual=model-asset') -and $activityText.Contains('BUTTON_MODEL_ASSET_URI = "apk:///models/BigRedButton.glb"')) 'BigRedButton.glb model marker'
    Add-Check 'model material not flattened' (-not $activityText.Contains('defaultShaderOverride = SceneMaterial.UNLIT_SHADER')) 'model uses embedded/material PBR path instead of forced unlit shader'
    Add-Check 'model press animation named' ($activityText.Contains('BUTTON_MODEL_PRESS_ANIMATION = "pressed"') -and $activityText.Contains('animationName = BUTTON_MODEL_PRESS_ANIMATION')) 'GLB pressed animation track'
    Add-Check 'model press animation clamps' ($activityText.Contains('PlaybackType.CLAMP')) 'Meta Spatial SDK clamp playback for one-shot press'
    Add-Check 'controller contact collider' (
        $activityText.Contains('IsdkBoxCollider') -and
        $activityText.Contains('shape=multi_box_cap') -and
        $activityText.Contains('buttonContactTargets') -and
        $activityText.Contains('BUTTON_CONTACT_RING_BOX_COUNT = 6') -and
        $activityText.Contains('COLLIDER_HOVER_CONTACT_ACTUATE')
    ) 'seven-box ISDK cap contact target accepts controller contact'
    Add-Check 'controller contact latch' (
        $activityText.Contains('ButtonContactLatch') -and
        $activityText.Contains('BUTTON_CONTACT_LATCH_FORCE_REARM_MS') -and
        $activityText.Contains('BRB_BUTTON_CONTACT_LATCH') -and
        $activityText.Contains('reason=latched')
    ) 'source-level latch prevents held or sliding controller contact from over-counting'
    Add-Check 'controller contact input source' ($activityText.Contains('PRESS_SOURCE_CONTROLLER_CONTACT = "controller_contact"') -and $activityText.Contains('inputSource = inputSource')) 'press event provenance'
    Add-Check 'transparent hit target over model' ($activityText.Contains('buttonPanel=transparent-hit-target') -and $activityText.Contains('MutableInteractionSource')) '2D panel is input surface, not visible button'
    Add-Check 'procedural fallback disabled' ($activityText.Contains('USE_PROCEDURAL_BUTTON_FALLBACK = false')) 'fallback is not participant-facing'
    Add-Check 'native scene dome fallback retained' ($activityText.Contains('SceneMesh.dome')) 'SceneMesh.dome fallback only'
    Add-Check 'button view origin reset' ($activityText.Contains('scene.setViewOrigin(0f, 0f, 0f, 0f)')) 'condition recenter/view-origin reset'
    Add-Check 'button distance matches source repo' ($activityText.Contains('BUTTON_DISTANCE_FROM_HEAD_METERS = 0.48f')) '0.48m from existing button runtime'
    $buttonDistanceM = Get-KotlinFloatConst $activityText 'BUTTON_DISTANCE_FROM_HEAD_METERS'
    $buttonCapCenterY = Get-KotlinFloatConst $activityText 'BUTTON_CONTACT_COLLIDER_Y_METERS'
    $nominalEyeY = Get-KotlinFloatConst $activityText 'BUTTON_NOMINAL_SEATED_EYE_HEIGHT_METERS'
    $buttonVisualDiameterM = Get-KotlinFloatConst $activityText 'BUTTON_VISUAL_DIAMETER_METERS'
    $minDownwardAngleDeg = Get-KotlinFloatConst $activityText 'BUTTON_ERGONOMIC_MIN_DOWNWARD_ANGLE_DEGREES'
    $maxDownwardAngleDeg = Get-KotlinFloatConst $activityText 'BUTTON_ERGONOMIC_MAX_DOWNWARD_ANGLE_DEGREES'
    $minAngularDiameterDeg = Get-KotlinFloatConst $activityText 'BUTTON_ERGONOMIC_MIN_ANGULAR_DIAMETER_DEGREES'
    $maxAngularDiameterDeg = Get-KotlinFloatConst $activityText 'BUTTON_ERGONOMIC_MAX_ANGULAR_DIAMETER_DEGREES'
    $hasButtonLayoutConstants =
        $null -ne $buttonDistanceM -and
        $null -ne $buttonCapCenterY -and
        $null -ne $nominalEyeY -and
        $null -ne $buttonVisualDiameterM -and
        $null -ne $minDownwardAngleDeg -and
        $null -ne $maxDownwardAngleDeg -and
        $null -ne $minAngularDiameterDeg -and
        $null -ne $maxAngularDiameterDeg
    if ($hasButtonLayoutConstants) {
        $downwardAngleDeg = [Math]::Atan(($nominalEyeY - $buttonCapCenterY) / $buttonDistanceM) * 180.0 / [Math]::PI
        $angularDiameterDeg = 2.0 * [Math]::Atan(($buttonVisualDiameterM / 2.0) / $buttonDistanceM) * 180.0 / [Math]::PI
        $downwardAngleText = $downwardAngleDeg.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
        $angularDiameterText = $angularDiameterDeg.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
        Add-Check 'button faces participant at ergonomic visual angle' (
            $downwardAngleDeg -ge $minDownwardAngleDeg -and
            $downwardAngleDeg -le $maxDownwardAngleDeg -and
            $angularDiameterDeg -ge $minAngularDiameterDeg -and
            $angularDiameterDeg -le $maxAngularDiameterDeg
        ) "downwardAngleDeg=$downwardAngleText angularDiameterDeg=$angularDiameterText distanceM=$buttonDistanceM capCenterY=$buttonCapCenterY nominalEyeY=$nominalEyeY"
    } else {
        Add-Check 'button faces participant at ergonomic visual angle' $false 'missing one or more button spatial layout constants'
    }
    Add-Check 'button spatial layout runtime marker' ($activityText.Contains('BRB_BUTTON_SPATIAL_LAYOUT') -and $activityText.Contains('facingParticipant=$angleOk')) 'runtime log captures computed human-facing placement'
    Add-Check 'press startup suppression' ($activityText.Contains('STARTUP_CONTACT_SUPPRESSION_MS = 350L')) '350 ms startup suppression'
    Add-Check 'press cooldown' ($activityText.Contains('BUTTON_PRESS_COOLDOWN_MS = 180L')) '180 ms press cooldown'
    Add-Check 'button press logging marker' ($activityText.Contains('BRB_BUTTON_PRESS')) 'BRB_BUTTON_PRESS'
    Add-Check 'button press suppression marker' ($activityText.Contains('BRB_BUTTON_PRESS_SUPPRESSED')) 'BRB_BUTTON_PRESS_SUPPRESSED'
    Add-Check 'condition press source summary marker' ($activityText.Contains('BRB_CONDITION_PRESS_SOURCES') -and $activityText.Contains('controllerContact=') -and $activityText.Contains('handContact=') -and $activityText.Contains('autoValidation=')) 'condition-end log reports source-specific press counts, including hand contact attempts'
    Add-Check 'missing Polar H10 warns but does not block participant start' (
        $activityText.Contains('BRB_POLAR_START_WARNING') -and
        $activityText.Contains('continuing=true participantPhysiologyEvidenceRequired=true') -and
        $activityText.Contains('missingPolarStartWarningText') -and
        $activityText.Contains('participantPhysiologyEvidenceExpected()') -and
        -not $activityText.Contains('BRB_POLAR_START_BLOCKED')
    ) 'participant/manual start logs a warning and continues when Polar H10 is not ready; final hardware validators still enforce live-H10 evidence'
    Add-Check 'Quest autorun validation extra' ($activityText.Contains('AUTO_VALIDATION_EXTRA = "brb.autoValidation"')) 'brb.autoValidation launch extra'
    Add-Check 'Quest validation language override extra' (
        $activityText.Contains('STUDY_LANGUAGE_EXTRA = "brb.studyLanguage"') -and
        $activityText.Contains('studyLanguageFromIntent') -and
        $activityText.Contains('launchLanguage ?: StudyLanguage.English')
    ) 'brb.studyLanguage launch extra lets headset validation exercise English or Japanese without removing the participant-facing selector'
    Add-Check 'Quest physical press validation extra' ($activityText.Contains('PHYSICAL_PRESS_VALIDATION_EXTRA = "brb.physicalPressValidation"')) 'brb.physicalPressValidation launch extra'
    Add-Check 'Quest panel smoke validation extra' ($activityText.Contains('PANEL_SMOKE_EXTRA = "brb.panelSmoke"') -and $activityText.Contains('BRB_PANEL_SMOKE_PICTOGRAPHIC_READY')) 'brb.panelSmoke launch extra'
    Add-Check 'fast controller flow validation extra' ($activityText.Contains('FAST_CONTROLLER_FLOW_EXTRA = "brb.fastControllerFlow"') -and $activityText.Contains('BRB_FAST_CONTROLLER_FLOW_COMPLETE')) 'brb.fastControllerFlow launch extra'
    Add-Check 'keyevent questionnaire validation extra' ($activityText.Contains('KEYEVENT_VALIDATION_EXTRA = "brb.keyeventValidation"') -and $activityText.Contains('keyeventValidationEnabled')) 'brb.keyeventValidation launch extra'
    Add-Check 'prior button experience XR prompt before block 1' (
        $activityText.Contains('PreButtonExperienceQuestion') -and
        $activityText.Contains('PRIOR_BUTTON_EXPERIENCE_QUESTION') -and
        $activityText.Contains('Do you have any experience with pressing big red buttons?') -and
        $activityText.Contains('PriorBigRedButtonExperiencePrompt') -and
        $activityText.Contains('PriorExperienceCheckbox') -and
        $activityText.Contains('displayLocation=button_counter_panel') -and
        $activityText.Contains('buttonModelVisible=false condition=1 onlyOnce=true') -and
        $activityText.Contains('setPreButtonExperienceQuestionVisible(true)') -and
        $activityText.Contains('buttonModelEntity?.setComponent(Visible(false))') -and
        $activityText.Contains('buttonContactTargets.forEach { target -> target.entity.setComponent(InteractivityInput(false)) }') -and
        $activityText.Contains('startExperimentFromPriorButtonExperienceQuestion') -and
        $activityText.Contains('beginCondition(1)')
    ) 'after demographics, the transparent counter panel asks the one-time yes/no prior button-press experience question while the 3D model/collider remain hidden'
    Add-Check 'Quest panel smoke does not start audio' ($activityText.Contains('noAudio=true noExport=true') -and -not $activityText.Contains('beginCondition(1, panelSmoke')) 'panel smoke only shows panels/glitch transitions'
    Add-Check 'Quest autorun completion marker' ($activityText.Contains('BRB_VALIDATION_AUTORUN_COMPLETE')) 'BRB_VALIDATION_AUTORUN_COMPLETE'
    Add-Check 'Quest physical press completion marker' ($activityText.Contains('BRB_PHYSICAL_VALIDATION_COMPLETE')) 'BRB_PHYSICAL_VALIDATION_COMPLETE'
    Add-Check 'JSON export directory' ($activityText.Contains('BigRedButtonFirstStudyExports')) 'BigRedButtonFirstStudyExports'
    Add-Check 'SideQuest experiment results directory' ($activityText.Contains('EXPERIMENT_RESULTS_DIR_NAME = "ExperimentResults"') -and $activityText.Contains('BRB_EXPERIMENT_RESULTS_FOLDER')) 'app external files/ExperimentResults mirror export'
    Add-Check 'summary CSV button variable' ($activityText.Contains('button_press_count') -and $activityText.Contains('condition_${condition}_hand_contact_press_count')) 'condition_N_button_press_count plus source-specific hand_contact count'
    Add-Check 'prior button experience logged variable' (
        $activityText.Contains('priorBigRedButtonExperienceJson') -and
        $activityText.Contains('priorBigRedButtonExperience') -and
        $activityText.Contains('prior_big_red_button_experience') -and
        $activityText.Contains('prior_big_red_button_experience_bool') -and
        $activityText.Contains('prior_big_red_button_experience_timestamp_iso') -and
        $activityText.Contains('BRB_PRIOR_BUTTON_EXPERIENCE_SAVED')
    ) 'prior yes/no big-red-button experience response is written to JSON and summary CSV with timestamp'
    Add-Check 'final end-confirmation and 1000-press branch' (
        $activityText.Contains('FinalEndQuestionnaire') -and
        $activityText.Contains('FinalExtraPresses') -and
        $activityText.Contains('FINAL_END_CONFIRMATION_QUESTION') -and
        $activityText.Contains('How sure are you that you want to end the experiment, on a scale of 1 to 10?') -and
        $activityText.Contains('FINAL_EXTRA_BUTTON_PRESS_REQUIREMENT = 1000') -and
        $activityText.Contains('FinalEndQuestionnaireScreen') -and
        $activityText.Contains('setFinalEndLikert') -and
        $activityText.Contains('submitFinalEndConfirmationSelection') -and
        $activityText.Contains('finalEndSelectionLockedState') -and
        $activityText.Contains('finalEndQuestionAudioReadyState') -and
        $activityText.Contains('BRB_FINAL_END_CONFIRMATION_OPTIONS_READY') -and
        $activityText.Contains('BRB_FINAL_END_CONFIRMATION_SELECTION_BLOCKED') -and
        $activityText.Contains('BRB_FINAL_END_CONFIRMATION_SUBMIT_BLOCKED') -and
        $activityText.Contains('optionsVisible=false questionAudio=final_end_confirmation_question_prompt.mp3') -and
        $activityText.Contains('optionsVisible=true answerLocked=false') -and
        $activityText.Contains('FINAL_END_CONFIRMATION_QUESTION_HOLD_MS = 5400L') -and
        $activityText.Contains('if (optionsReady || selectionLocked)') -and
        $activityText.Contains('(1..10).filter { value -> !selectionLocked || value == selected }') -and
        $activityText.Contains('transparentCounterQuestionnaire = stage == StudyStage.FinalEndQuestionnaire') -and
        $activityText.Contains('FinalEndQuestionnaireScreen') -and
        $activityText.Contains('color = CounterDigitRed') -and
        $activityText.Contains('R.raw.final_end_confirmation_question_prompt') -and
        $activityText.Contains('BRB_FINAL_END_CONFIRMATION_QUESTION_CUE') -and
        $activityText.Contains('FINAL_END_CONFIRMATION_QUESTION_AUDIO_DURATION_MS = 5146L') -and
        $activityText.Contains('R.raw.final_end_confirmation_10_feedback') -and
        $activityText.Contains('BRB_FINAL_END_CONFIRMATION_FEEDBACK_CUE') -and
        $activityText.Contains('FINAL_END_CONFIRMATION_10_FEEDBACK_AUDIO_DURATION_MS = 16274L') -and
        $activityText.Contains('FINAL_END_CONFIRMATION_FEEDBACK_HOLD_MS = 16550L') -and
        $activityText.Contains('BRB_FINAL_END_CONFIRMATION_SHOWN') -and
        $activityText.Contains('BRB_FINAL_END_CONFIRMATION_SAVED') -and
        $activityText.Contains('BRB_FINAL_EXTRA_BUTTON_CHALLENGE_START') -and
        $activityText.Contains('That is fantastic! I will take your non-decimal response as a big red YES!') -and
        $activityText.Contains('R.raw.final_extra_presses_prompt') -and
        $activityText.Contains('BRB_FINAL_EXTRA_PROMPT_CUE') -and
        $activityText.Contains('FINAL_EXTRA_PRESSES_PROMPT_AUDIO_DURATION_MS = 45636L') -and
        $activityText.Contains('FINAL_EXTRA_PRESSES_PROMPT_HOLD_MS = 46100L') -and
        $activityText.Contains('finalExtraPromptVisibleState') -and
        $activityText.Contains('setFinalExtraPromptPanelVisible(true)') -and
        $activityText.Contains('buttonModelVisible=false') -and
        $activityText.Contains('BRB_FINAL_EXTRA_PROMPT_HIDDEN') -and
        $activityText.Contains('counterOnly=true') -and
        $activityText.Contains('reason=prompt_audio_active') -and
        $activityText.Contains('BRB_FINAL_EXTRA_BUTTON_PRESS_COMPLETE') -and
        $activityText.Contains('recordFinalExtraButtonPress') -and
        $activityText.Contains('FinalExtraPressPrompt') -and
        $activityText.Contains('PRESSES OUT OF 1,000')
    ) 'after condition 2, a 10-point final question either ends on rating 10 or returns the button until 1000 extra presses are counted'
    Add-Check 'final end-confirmation export fields' (
        $activityText.Contains('finalEndConfirmationJson') -and
        $activityText.Contains('finalEndConfirmation') -and
        $activityText.Contains('final_extra_button_press_requirement') -and
        $activityText.Contains('final_extra_button_press_count') -and
        $activityText.Contains('final_extra_button_press_completed') -and
        $activityText.Contains('_final_extra_button_presses.csv') -and
        $activityText.Contains('finalExtraPressEventsCsvText') -and
        $activityText.Contains('finalExtraButtonPressesCsv')
    ) 'final 10-point decision and optional 1000 extra press events are exported to JSON, summary CSV, session index, and a dedicated event CSV'
    Add-Check 'summary CSV ECG variables' ($activityText.Contains('ecg_assignment_order') -and $activityText.Contains('condition_${condition}_ecg_source') -and $activityText.Contains('condition_${condition}_feedback_source') -and $activityText.Contains('condition_${condition}_physiology_source') -and $activityText.Contains('condition_${condition}_ecg_blink_count') -and $activityText.Contains('condition_${condition}_ecg_timeseries_sample_count') -and $activityText.Contains('condition_${condition}_real_ecg_timeseries_sample_count') -and $activityText.Contains('condition_${condition}_polar_rr_event_count') -and $activityText.Contains('condition_${condition}_ecg_detector_event_count') -and $activityText.Contains('condition_${condition}_external_signal_sample_count') -and $activityText.Contains('condition_${condition}_ecg_capture_duration_ns') -and $activityText.Contains('condition_${condition}_ecg_audio_window_end_ms')) 'counterbalanced feedback source, real physiology source, blink count, raw time-series count, Polar RR count, detector count, optional external signal count, and exact audio-window columns'
    Add-Check 'ECG blink events CSV export' ($activityText.Contains('_ecg_blink_events.csv') -and $activityText.Contains('ecgBlinkEventsCsvText') -and $activityText.Contains('ecgBlinkEventsCsv') -and $activityText.Contains('"pulse_intensity_0_1"') -and $activityText.Contains('"detector"')) 'SideQuest-readable ECG blink event CSV with pulse metadata'
    Add-Check 'ECG raw time-series CSV export' ($activityText.Contains('_ecg_timeseries.csv') -and $activityText.Contains('ecgTimeSeriesCsvText') -and $activityText.Contains('ecgTimeSeriesCsv') -and $activityText.Contains('"elapsed_ns"') -and $activityText.Contains('"audio_window_duration_ms"')) 'SideQuest-readable raw 130 Hz ECG time-series CSV with nanosecond elapsed and audio-window fields'
    Add-Check 'Polar RR events CSV export' ($activityText.Contains('_polar_rr_events.csv') -and $activityText.Contains('polarRrEventsCsvText') -and $activityText.Contains('polarRrEventsCsv') -and $activityText.Contains('"used_for_feedback"')) 'SideQuest-readable real Polar RR event CSV with feedback-use flag'
    Add-Check 'ECG detector events CSV export' ($activityText.Contains('_ecg_detector_events.csv') -and $activityText.Contains('ecgDetectorEventsCsvText') -and $activityText.Contains('BRB_ECG_RPEAK_DETECTED') -and $activityText.Contains('native_threshold_uv800')) 'native threshold R-peak detector diagnostics are exported separately from the raw ECG stream'
    Add-Check 'questionnaire protocol metadata and lifecycle markers' (
        $activityText.Contains('questionnaireProtocolJson') -and
        $activityText.Contains('bigredbutton.questionnaire_flow.v1') -and
        $activityText.Contains('transport", "in_process_spatial_panel"') -and
        $activityText.Contains('productCommunication", "app_internal"') -and
        $activityText.Contains('QUESTIONNAIRE_STAGE_SEQUENCE') -and
        $activityText.Contains('BRB_QUESTIONNAIRE_CONTRACT') -and
        $activityText.Contains('BRB_QUESTIONNAIRE_STAGE_OPEN') -and
        $activityText.Contains('BRB_QUESTIONNAIRE_STAGE_COMPLETE') -and
        $activityText.Contains('answersLogged=false')
    ) 'in-process questionnaire flow exports a versioned contract and answer-free lifecycle markers'
    Add-Check 'optional LSL external signal scaffold' (
        $activityText.Contains('LSL_INPUT_ENABLED = false') -and
        $activityText.Contains('LSL_ROLE_DIAGNOSTIC_ONLY = "diagnostic_only"') -and
        $activityText.Contains('LSL_DEFAULT_STREAM_NAME = "HRV_Biofeedback"') -and
        $activityText.Contains('LSL_DEFAULT_STREAM_TYPE = "HRV"') -and
        $activityText.Contains('LSL_TRIGGER_THRESHOLD_01 = 0.5f') -and
        $activityText.Contains('LSL_MINIMUM_TRIGGER_INTERVAL_MS = 250L') -and
        $activityText.Contains('externalSignalProtocolJson') -and
        $activityText.Contains('BRB_LSL status=disabled') -and
        $activityText.Contains('contaminatesPressCounts=false') -and
        $activityText.Contains('nativeLibraryPackaged=false') -and
        $activityText.Contains('jniEnabled=false') -and
        $activityText.Contains('drivesHeartbeatBlink=false') -and
        $activityText.Contains('drivesButtonPresses=false') -and
        $activityText.Contains('_external_signal_samples.csv') -and
        $activityText.Contains('externalSignalSamplesCsvText') -and
        -not (Test-Path (Join-Path $projectRoot 'app\src\main\jniLibs\arm64-v8a\liblsl.so')) -and
        -not $activityText.Contains('System.loadLibrary("lsl")')
    ) 'disabled-by-default Unity-compatible LSL/external signal schema is present without adding an untested JNI dependency'
    Add-Check 'pictographic distance variable' ($activityText.Contains('self_button_distance_units')) 'self_button_distance_units'
    Add-Check 'pictographic radius variable' ($activityText.Contains('button_presence_radius_units')) 'button_presence_radius_units'
    Add-Check 'lost opportunity variable' ($activityText.Contains('lost_opportunity_for_better_results_quotient')) 'lost_opportunity_for_better_results_quotient'
    Add-Check 'pictographic uses model thumbnail' ($activityText.Contains('ImageBitmap.imageResource(id = R.drawable.big_red_button_model_thumbnail)') -and $activityText.Contains('drawImage(') -and -not $activityText.Contains('drawCircle(BrbRed, radius = 34f, center = Offset(buttonX')) 'same-button thumbnail replaces generic red oval'
    Add-Check 'pictographic button centered in presence circle' ($activityText.Contains('buttonX - buttonImageSize / 2f') -and $activityText.Contains('y - buttonImageSize / 2f')) 'thumbnail dstOffset centers on circle center'
    Add-Check 'pictographic distance slider calibrated to self axis' (
        $activityText.Contains('private const val PICTOGRAPHIC_VAS_AXIS_WIDTH_DP = 640') -and
        $activityText.Contains('private const val PICTOGRAPHIC_VAS_THUMB_RADIUS_DP = 20') -and
        $activityText.Contains('Modifier.width(PICTOGRAPHIC_VAS_AXIS_WIDTH_DP.dp).align(Alignment.CenterHorizontally)') -and
        $activityText.Contains('val selfX = scaleStartX + scaleThumbRadiusPx') -and
        $activityText.Contains('val buttonX = selfX + buttonDistancePx') -and
        $activityText.Contains('end = Offset(selfX + maxButtonDistancePx, y)') -and
        $activityText.Contains('val thumbX = trackStartX + trackTravel * (boundedValue / 100f)') -and
        $activityText.Contains('value = 100f - closeness') -and
        $activityText.Contains('onChange = { activity.pictographicClosenessState.floatValue = 100f - it }') -and
        $activityText.Contains('left = activity.t("very_close")') -and
        $activityText.Contains('right = activity.t("very_distant")') -and
        $activityText.Contains('PICTOGRAPHIC_SELF_BUTTON_TRAVEL_UNITS.toFloat() / 100f')
    ) 'visible VAS minimum aligns to the self pictogram, and the closeness thumb/button marker share one horizontal coordinate'
    Add-Check 'pictographic presence endpoint labels' (
        $activityText.Contains('left = activity.t("small_presence")') -and
        $activityText.Contains('right = activity.t("large_presence")')
    ) 'presence VAS is labelled small presence to large presence'
    Add-Check 'redness VAS/Likert conversion task' (
        $activityText.Contains('RednessResponseControl') -and
        $activityText.Contains('How red did the button feel?') -and
        $activityText.Contains('REDNESS_LIKERT_DESCRIPTORS') -and
        $activityText.Contains('slightly red') -and
        $activityText.Contains('extremely red') -and
        $activityText.Contains('convertRednessVasToLikert') -and
        $activityText.Contains('convertRednessLikertToVas') -and
        $activityText.Contains('BRB_REDNESS_SCALE_CONVERSION') -and
        $activityText.Contains('BRB_REDNESS_SCALE_CONVERSION_CHOREOGRAPHY') -and
        $activityText.Contains('RednessConversionMicroEvent') -and
        $activityText.Contains('BRB_REDNESS_SCALE_CONVERSION_MICRO_EVENT') -and
        $activityText.Contains('RednessConversionChoreographyOverlay') -and
        $activityText.Contains('drawRednessMicroEventVisual') -and
        $activityText.Contains('recordRednessPostConversionEdit') -and
        $activityText.Contains('rednessFinalMatchesCarriedForward') -and
        $activityText.Contains('BRB_REDNESS_POST_CONVERSION_EDIT') -and
        $activityText.Contains('Modifier.fillMaxWidth().padding(horizontal = 28.dp)') -and
        $activityText.Contains('Arrangement.spacedBy(10.dp)') -and
        $activityText.Contains('R.raw.first_questionnaire_change') -and
        $activityText.Contains('R.raw.second_questionnaire_change_excuse') -and
        $activityText.Contains('placeholder=false') -and
        -not $activityText.Contains('redness_scale_conversion_pending_apology')
    ) 'third redness control flips VAS to Likert in block 1 and Likert to VAS in block 2, with real questionnaire-change audio and timed visual choreography'
    Add-Check 'redness changeover transcript micro-events' (
        $activityText.Contains('supervisor_ping') -and
        $activityText.Contains('seven_boxes_assemble') -and
        $activityText.Contains('professional_warning') -and
        $activityText.Contains('boxes_erased') -and
        $activityText.Contains('wrong_way_settle') -and
        $activityText.Contains('microTimeline=') -and
        $activityText.Contains('participantCaption') -and
        $activityText.Contains('spokenCue') -and
        $activityText.Contains('visualCue')
    ) 'questionnaire-change clips expose transcript-synced micro-events in source and runtime logs'
    Add-Check 'redness export fields' (
        $activityText.Contains('rednessVas0To100') -and
        $activityText.Contains('rednessLikert1To7') -and
        $activityText.Contains('rednessLikertDescriptor') -and
        $activityText.Contains('rednessScaleOrder') -and
        $activityText.Contains('rednessCarriedForwardVas0To100') -and
        $activityText.Contains('rednessCarriedForwardLikert1To7') -and
        $activityText.Contains('rednessPostConversionEdited') -and
        $activityText.Contains('rednessChangedAfterConversion') -and
        $activityText.Contains('rednessFinalMatchesCarriedForward') -and
        $activityText.Contains('condition_${condition}_redness_vas_0_100') -and
        $activityText.Contains('condition_${condition}_redness_likert_1_7') -and
        $activityText.Contains('condition_${condition}_redness_carried_forward_vas_0_100') -and
        $activityText.Contains('condition_${condition}_redness_changed_after_conversion')
    ) 'both final redness values, carried-forward closest analogues, and post-conversion change flags are written to JSON, logcat, and summary CSV'
    Add-Check 'pictographic circle boundaries thickened' (
        ([regex]::Matches($activityText, 'style = Stroke\(width = 9f\)')).Count -ge 2
    ) 'self boundary and button-presence boundary use thicker 9 px strokes'
    Add-Check 'website-style intake header' ($activityText.Contains('IntakeWebsiteHeader') -and $activityText.Contains('Brush.linearGradient') -and $activityText.Contains('Big Red Button Institute | Intake')) 'demographics page mirrors BRB website header treatment'
    Add-Check 'participant-facing start experiment label' (
        ($activityText.Contains('PrimaryActionButton("Start experiment"') -or
            $activityText.Contains('PrimaryActionButton(activity.t("start_experiment")')) -and
        -not $activityText.Contains('Start condition 1')
    ) 'demographics CTA avoids condition numbering'
    Add-Check 'participant ID assigned under hood' ($activityText.Contains('participantIdSource=${if (participantIdOverride.isNullOrBlank()) "generated" else "validation_override"}') -and -not $activityText.Contains('LabeledTextField("Participant ID"')) 'participant ID is generated or validation-overridden, not typed by participant'
    Add-Check 'gender four-choice' ($activityText.Contains('GenderChoice') -and $activityText.Contains('"male" to activity.t("male")') -and $activityText.Contains('"female" to activity.t("female")') -and $activityText.Contains('"other" to activity.t("other")') -and $activityText.Contains('"prefer_not_to_say" to activity.t("prefer_not_to_say")')) 'Male/Female/Other/Prefer not to say choice buttons'
    Add-Check 'handedness tri-choice' ($activityText.Contains('HandednessChoice') -and $activityText.Contains('"left" to activity.t("left")') -and $activityText.Contains('"right" to activity.t("right")') -and $activityText.Contains('"ambidextrous" to activity.t("ambidextrous")')) 'Left/Right/Ambidextrous choice buttons'
    Add-Check 'visible Android EditText demographics keyboard hooks' (
        $activityText.Contains('AndroidView(') -and
        $activityText.Contains('EditText(context).apply') -and
        $activityText.Contains('fieldId = "name"') -and
        $activityText.Contains('fieldId = "age"') -and
        $activityText.Contains('InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_WORDS') -and
        $activityText.Contains('InputType.TYPE_CLASS_NUMBER') -and
        $activityText.Contains('EditorInfo.IME_ACTION_NEXT') -and
        $activityText.Contains('EditorInfo.IME_ACTION_DONE') -and
        $activityText.Contains('DEMOGRAPHICS_NAME_MAX_CHARS = 80') -and
        $activityText.Contains('DEMOGRAPHICS_AGE_MAX_DIGITS = 3') -and
        $activityText.Contains('normalizeAgeInput(raw)') -and
        $activityText.Contains('InputFilter.LengthFilter(maxChars)') -and
        $activityText.Contains('requestDemographicsTextInputFocus("age", "name_submit_next")') -and
        $activityText.Contains('requestDemographicsTextInputFocus("age", "name_valid_auto_advance")') -and
        $activityText.Contains('hideSoftKeyboardForReason("field_age_done")') -and
        $activityText.Contains('focus_request_retry_') -and
        $activityText.Contains('requiredTextField') -and
        $activityText.Contains('isRequired = requiredTextField == "name"') -and
        $activityText.Contains('isRequired = requiredTextField == "age"') -and
        $activityText.Contains('isGuidedField = isFocused || isRequired') -and
        $activityText.Contains('.height(72.dp)') -and
        $activityText.Contains('demographicsFocusRequestSourceState') -and
        $activityText.Contains('singlePath=true') -and
        $activityText.Contains('fullCellHitbox=true') -and
        $activityText.Contains('tap_hitbox') -and
        $activityText.Contains('demographicsDraftNameState') -and
        $activityText.Contains('demographicsDraftAgeState') -and
        $activityText.Contains('demographicsFocusedFieldState') -and
        $activityText.Contains('onNewIntent(intent: Intent)') -and
        $activityText.Contains('handleDemographicsKeyboardValidationIntent') -and
        $activityText.Contains('DEMOGRAPHICS_KEYBOARD_VALIDATION_COMMAND_EXTRA') -and
        $activityText.Contains('DEMOGRAPHICS_KEYBOARD_VALIDATION_TEXT_EXTRA') -and
        $activityText.Contains('DEMOGRAPHICS_KEYBOARD_VALIDATION_SESSION_EXTRA') -and
        $activityText.Contains('BRB_DEMOGRAPHICS_VALIDATION_SESSION') -and
        $activityText.Contains('reason=session_mismatch') -and
        $activityText.Contains('BRB_DEMOGRAPHICS_VALIDATION_COMMAND') -and
        $activityText.Contains('BRB_DEMOGRAPHICS_VALIDATION_TEXT_APPLIED') -and
        $activityText.Contains('sameSanitizer=true') -and
        $activityText.Contains('"focus_age"') -and
        $activityText.Contains('"set_age"') -and
        $activityText.Contains('"age_done"') -and
        $activityText.Contains('platformControl=EditText') -and
        $activityText.Contains('inputOwner=androidViewEditText') -and
        $activityText.Contains('visibleControl=androidViewEditText') -and
        $activityText.Contains('focusedView=EditText') -and
        $activityText.Contains('restartInput=true') -and
        $activityText.Contains('inputMethodManager.restartInput(editText)') -and
        $activityText.Contains('BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT') -and
        $activityText.Contains('BRB_DEMOGRAPHICS_TEXT_VALUE') -and
        $activityText.Contains('BRB_DEMOGRAPHICS_TEXT_EDITOR_ACTION') -and
        $activityText.Contains('BRB_DEMOGRAPHICS_EDITTEXT_FOCUS') -and
        $activityText.Contains('DEMOGRAPHICS_KEYBOARD_VALIDATION_EXTRA = "brb.demographicsKeyboardValidation"') -and
        $activityText.Contains('BRB_SOFT_KEYBOARD_REQUEST') -and
        $activityText.Contains('BRB_SOFT_KEYBOARD_SWITCH') -and
        $activityText.Contains('failSafeRetarget=true') -and
        $activityText.Contains('movablePanel=true') -and
        $activityText.Contains('closeToParticipant=system_managed') -and
        -not $activityText.Contains('SpatialTextField') -and
        -not $activityText.Contains('AgeTriggerDial') -and
        -not $activityText.Contains('AgeDialStepButton') -and
        -not $activityText.Contains('ComposeTriggerDial') -and
        -not $activityText.Contains('keyboardTarget=false') -and
        -not $activityText.Contains('demographicsInputBridge') -and
        -not $activityText.Contains('demographicsBridgeActiveFieldId') -and
        -not $activityText.Contains('BRB_DEMOGRAPHICS_WINDOW_EDITTEXT') -and
        -not $activityText.Contains('BRB_DEMOGRAPHICS_INPUT_BRIDGE_READY') -and
        -not $activityText.Contains('useLooseKeyboard') -and
        -not $activityText.Contains('requestLooseKeyboard') -and
        -not $activityText.Contains('LooseKeyboard') -and
        -not $activityText.Contains('BRB_LOOSE_KEYBOARD') -and
        -not $activityText.Contains('R.id.loose_keyboard_panel') -and
        -not ($activityText.Contains('DemographicsInlineKeyboard') -or $activityText.Contains('requestInlineKeyboard'))
    ) 'Name and Age use visible AndroidView(EditText) controls as the single IME owners, with Name text/Next and Age number/Done contracts'
    Add-Check 'demographics validation can smoke prior audio prompt' (
        $activityText.Contains('"submit_demographics" ->') -and
        $activityText.Contains('safeCommand == "prior_answer_yes"') -and
        $activityText.Contains('safeCommand == "prior_answer_no"') -and
        $activityText.Contains('BRB_DEMOGRAPHICS_VALIDATION_SUBMIT accepted=true') -and
        $activityText.Contains('BRB_PRIOR_BUTTON_EXPERIENCE_VALIDATION_ANSWER') -and
        $activityText.Contains('priorAudioSmoke=true') -and
        $activityText.Contains('route=submitDemographics')
    ) 'validation-only demographics submit and prior-answer commands smoke the participant prior-experience audio prompt without adding visible UI'
    Add-Check 'audio rig stress validation commands' (
        $activityText.Contains('AUDIO_RIG_STRESS_EXTRA = "brb.audioRigStress"') -and
        $activityText.Contains('AUDIO_RIG_STRESS_COMMAND_EXTRA = "brb.audioRigStressCommand"') -and
        $activityText.Contains('handleAudioRigStressIntent') -and
        $activityText.Contains('BRB_AUDIO_RIG_STRESS_COMMAND') -and
        $activityText.Contains('show_prior_prompt') -and
        $activityText.Contains('show_final_end') -and
        $activityText.Contains('final_answer_') -and
        $activityText.Contains('final_extra_press_attempt') -and
        $activityText.Contains('play_short_cues') -and
        $activityText.Contains('redness_vas_then_likert') -and
        $activityText.Contains('redness_likert_then_vas') -and
        $activityText.Contains('condition_1_audio_probe') -and
        $activityText.Contains('condition_2_audio_probe') -and
        $activityText.Contains('BRB_AUDIO_RIG_STRESS_CONDITION_AUDIO_PROBE') -and
        $activityText.Contains('BRB_CONDITION_START condition=$conditionNumber audio=${run.audioAssetPath}') -and
        $activityText.Contains('audioId=${run.audioId}') -and
        $activityText.Contains('audioLocale=${run.audioLocaleCode}') -and
        $activityText.Contains('localizedFallback=${run.audioFallbackToEnglish}') -and
        $activityText.Contains('durationMs=${run.audioDurationMs} isPlaying=${mediaPlayer?.isPlaying == true}')
    ) 'hidden Quest stress commands can drive real audio-linked prompt gates and cue playback without visible participant shortcuts'
    Add-Check 'demographics panel compact no-scroll layout' (
        $activityText.Contains('BRB_DEMOGRAPHICS_LAYOUT noScroll=true compact=true signaturePadHeightDp=142 startButtonHeightDp=48') -and
        $activityText.Contains('modifier = Modifier.fillMaxSize()') -and
        $activityText.Contains('.height(142.dp)') -and
        ($activityText.Contains('PrimaryActionButton("Start experiment", canSubmit, height = 48.dp)') -or $activityText.Contains('PrimaryActionButton(activity.t("start_experiment"), canSubmit, height = 48.dp)')) -and
        -not [regex]::IsMatch($activityText, 'private fun ConsentDemographicsScreen(?s:(?!@Composable\s+private fun PolarH10ValidityPanel).)*verticalScroll')
    ) 'intake page fits the 1180x820 Quest panel without requiring scroll'
    Add-Check 'questionnaire panel spawns in gaze line' ($activityText.Contains('BRB_QUESTIONNAIRE_PANEL_LAYOUT') -and $activityText.Contains('placement=current-gaze-line') -and $activityText.Contains('QUESTIONNAIRE_PANEL_Y_METERS = 1.52f') -and $activityText.Contains('QUESTIONNAIRE_PANEL_Z_METERS = 1.55f')) 'view-origin reset and gaze-line panel placement marker'
    Add-Check 'questionnaire intro/outro glitch cues' (
        $activityText.Contains('R.raw.questionnaire_intro_glitch') -and
        $activityText.Contains('R.raw.questionnaire_outro_glitch') -and
        $activityText.Contains('BRB_QUESTIONNAIRE_${mode.uppercase(Locale.US)}_CUE') -and
        $activityText.Contains('mode = "intro"') -and
        $activityText.Contains('mode = "outro"') -and
        $activityText.Contains('AudioAttributes.CONTENT_TYPE_SONIFICATION') -and
        $activityText.Contains('durationMs=${player.duration} isPlaying=${player.isPlaying} audioUsage=media contentType=sonification volume=1.0') -and
        $activityText.Contains('reason=open_raw_resource_fd_returned_null')
    ) 'intro/outro MP3s drive panel transitions through explicit raw-resource playback with runtime evidence'
    Add-Check 'blue failure glitch overlay' (
        $activityText.Contains('BlueFailureGlitchOverlay') -and
        $activityText.Contains('BRB_PANEL_GLITCH') -and
        $activityText.Contains('Color(0xFF012B7F)') -and
        $activityText.Contains('style=phased_system_failure comfortSafe=true')
    ) 'blue software-failure style transition overlay with comfort-safe phased timing'
    Add-Check 'comfort-safe phased glitch treatment' (
        $activityText.Contains('panelGlitchProgress') -and
        $activityText.Contains('panelGlitchEnvelope') -and
        $activityText.Contains('panelGlitchPhase') -and
        $activityText.Contains('drawPhasedFailureWash') -and
        $activityText.Contains('drawScanlineTears') -and
        $activityText.Contains('drawMacroblockCorruption') -and
        $activityText.Contains('drawColorBreakupTears') -and
        $activityText.Contains('drawPanelBorderDesync') -and
        $activityText.Contains('GlitchPanelFrameOverlay') -and
        $activityText.Contains('drawInterruptedPanelContour') -and
        $activityText.Contains('panelGlitchShellJitter') -and
        $activityText.Contains('panelGlitchShellRotation') -and
        $activityText.Contains('BlendMode.Clear') -and
        $activityText.Contains('graphicsLayer') -and
        $activityText.Contains('PANEL_GLITCH_FRAME_MS = 70L')
    ) 'intro/outro overlay uses phased acquisition/dropout/collapse, whole-panel wobble, interrupted contours, dynamic edge tears, macroblocks, color breakup, stripes, and border desynchronization'
    Add-Check 'glitched buffer loading cues' (
        $activityText.Contains('drawGlitchedBufferSpinner') -and
        $activityText.Contains('bufferSpinner=true') -and
        $activityText.Contains('drawOnlineOfflineCues') -and
        $activityText.Contains('onlineOfflineCues=true') -and
        $activityText.Contains('drawNoiseBursts') -and
        $activityText.Contains('StrokeCap.Round') -and
        $activityText.Contains('dead_screen') -and
        $activityText.Contains('dropout')
    ) 'panel transitions include a corrupted loading spinner, buffer ticks, and non-textual online/offline system-failure cues'
    Add-Check 'digital press counter above button' ($activityText.Contains('DigitalPressCounter') -and $activityText.Contains('displayValue') -and $activityText.Contains('PRESSES') -and $activityText.Contains('buttonPressCountState')) 'old digital display counter increments from accepted presses'
    Add-Check 'prior button experience prompt uses transparent counter panel' (
        $activityText.Contains('ButtonStimulusPanel') -and
        $activityText.Contains('stage == StudyStage.PreButtonExperienceQuestion') -and
        $activityText.Contains('PriorBigRedButtonExperiencePrompt') -and
        $activityText.Contains('background(Color.Transparent)') -and
        $activityText.Contains('CounterFloatingAction(') -and
        $activityText.Contains('color = CounterDigitRed') -and
        $activityText.Contains('fontFamily = BrbMono') -and
        $activityText.Contains('.border(2.dp, checkboxBorder, RoundedCornerShape(2.dp))') -and
        $activityText.Contains('priorBigRedButtonExperienceOptionsReadyState') -and
        $activityText.Contains('priorBigRedButtonExperienceFeedbackReadyState') -and
        $activityText.Contains('priorBigRedButtonExperiencePreStartReadyState') -and
        $activityText.Contains('R.raw.prior_button_experience_question') -and
        $activityText.Contains('R.raw.prior_button_experience_yes') -and
        $activityText.Contains('R.raw.prior_button_experience_no') -and
        $activityText.Contains('R.raw.pre_start_instructions') -and
        $activityText.Contains('BRB_PRIOR_BUTTON_EXPERIENCE_QUESTION_CUE') -and
        $activityText.Contains('BRB_PRIOR_BUTTON_EXPERIENCE_OPTIONS_READY') -and
        $activityText.Contains('BRB_PRIOR_BUTTON_EXPERIENCE_FEEDBACK_CUE') -and
        $activityText.Contains('BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_CUE') -and
        $activityText.Contains('BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_READY') -and
        $activityText.Contains('BRB_PRIOR_BUTTON_EXPERIENCE_START_CLICK') -and
        $activityText.Contains('PRIOR_BUTTON_EXPERIENCE_QUESTION_AUDIO_DURATION_MS = 10527L') -and
        $activityText.Contains('PRIOR_BUTTON_EXPERIENCE_YES_AUDIO_DURATION_MS = 5251L') -and
        $activityText.Contains('PRIOR_BUTTON_EXPERIENCE_NO_AUDIO_DURATION_MS = 4284L') -and
        $activityText.Contains('PRIOR_BUTTON_EXPERIENCE_PRE_START_AUDIO_DURATION_MS = 34273L') -and
        $activityText.Contains('reason=question_audio_active') -and
        $activityText.Contains('reason=answer_locked') -and
        $activityText.Contains('otherOptionsHidden=true') -and
        $activityText.Contains('reason=feedback_audio_active') -and
        $activityText.Contains('reason=pre_start_instructions_active') -and
        $activityText.Contains('No? Well than you are in for a treat!') -and
        $activityText.Contains('An experienced user, just the type of participant we need.') -and
        $activityText.Contains('Start experiment') -and
        -not $activityText.Contains('.border(1.dp, if (checked) CounterDigitRed else Color.White.copy(alpha = 0.72f), RoundedCornerShape(7.dp))')
    ) 'counter location shows a frameless clear-background XR prompt with red counter-style lettering and only answer boxes before the 3D button appears'
    Add-Check 'digital press counter red transparent passthrough styling' (
        $activityText.Contains('CounterDigitRed') -and
        $activityText.Contains('Color(0xFFFF2424)') -and
        $activityText.Contains('background(Color.Transparent)') -and
        $activityText.Contains('Shadow(') -and
        -not $activityText.Contains('Color(0xFF110606).copy(alpha = 0.90f)') -and
        -not $activityText.Contains('Color(0xFF3D0A0A)')
    ) 'counter digits/label are red and the counter has no filled backing panel, so passthrough remains visible behind it'
    Add-Check 'questionnaire UI sound cues wired' ($activityText.Contains('playQuestionnaireChoiceCue') -and $activityText.Contains('R.raw.ui_choice_blip') -and $activityText.Contains('playQuestionnaireNavigationCue') -and $activityText.Contains('R.raw.ui_navigation_blip')) 'multiple-choice and navigation feedback sounds'
    Add-Check 'raw speech cue playback uses explicit audio attributes' (
        $activityText.Contains('resources.openRawResourceFd(resourceId)') -and
        $activityText.Contains('AudioAttributes.Builder()') -and
        $activityText.Contains('AudioAttributes.USAGE_MEDIA') -and
        $activityText.Contains('AudioAttributes.CONTENT_TYPE_SPEECH') -and
        $activityText.Contains('setVolume(1.0f, 1.0f)') -and
        $activityText.Contains('durationMs=${player.duration} isPlaying=${player.isPlaying}') -and
        $activityText.Contains('what=$what extra=$extra')
    ) 'raw packaged prompt MP3s are played through an explicit MediaPlayer path with auditable runtime errors'
    Add-Check 'button press sound cue wired' (
        $activityText.Contains('playButtonPressCue()') -and
        $activityText.Contains('BUTTON_PRESS_SFX_ASSET') -and
        $activityText.Contains('BRB_SFX_PLAY cue=$cueName audioId=$audioId asset=$assetPath')
    ) 'accepted button press plays swappable asset sound'
    Add-Check 'signature pad stores temporal stroke data' ($activityText.Contains('ConsentSignaturePad') -and $activityText.Contains('detectDragGestures') -and $activityText.Contains('brb_signature_strokes_v1') -and $activityText.Contains('tMs') -and $activityText.Contains('.height(142.dp)')) 'trigger/pointer signature pad replaces text signature field inside the compact no-scroll intake layout'
    Add-Check 'Polar H10 validity panel in first menu' (
        $activityText.Contains('PolarH10ValidityPanel') -and
        $activityText.Contains('PolarEcgWaveform') -and
        $activityText.Contains('polarEcgPreviewSamplesState') -and
        $activityText.Contains('Polar H10 ECG ready') -and
        $activityText.Contains('status.streaming') -and
        $activityText.Contains('status.pmdReady') -and
        $activityText.Contains('status.ecgStreaming') -and
        $activityText.Contains('status.ecgSampleCount > 0') -and
        $activityText.Contains('status.ecgSampleRateHz == 130') -and
        $activityText.Contains('\u2713')
    ) 'first menu green-check status now requires HR/RR plus PMD ECG samples at 130 Hz'
    Add-Check 'counterbalanced ECG assignment' ($activityText.Contains('priorEcgAssignmentCounts') -and $activityText.Contains('ECG_ORDER_REAL_THEN_SIMULATED') -and $activityText.Contains('ECG_ORDER_SIMULATED_THEN_REAL') -and $activityText.Contains('BRB_ECG_ASSIGNMENT')) 'previous exports balance real-first vs simulated-first order'
    Add-Check 'real and simulated ECG blink drivers' ($activityText.Contains('onPolarRrMeasurement') -and $activityText.Contains('scheduleNextSimulatedRPeak') -and $activityText.Contains('triggerEcgBlink') -and $activityText.Contains('BRB_ECG_BLINK')) 'button blink can be driven by Polar RR or simulated RR intervals'
    Add-Check 'Polar PMD raw ECG stream client' ($polarClientText.Contains('PMD_SERVICE') -and $polarClientText.Contains('fb005c80-02e7-f387-1cad-8acd2d8df0c8') -and $polarClientText.Contains('PMD_DATA') -and $polarClientText.Contains('PMD_COMMAND_START_MEASUREMENT') -and $polarClientText.Contains('readSigned24LittleEndian') -and $polarClientText.Contains('estimatedElapsedRealtimeNs') -and $polarClientText.Contains('onPolarEcgMeasurement')) 'Polar PMD service streams raw 3-byte ECG samples with nanosecond sample timing'
    Add-Check 'Polar low-latency ECG BLE settings' ($polarClientText.Contains('CONNECTION_PRIORITY_HIGH') -and $polarClientText.Contains('POLAR_LOW_LATENCY_MTU = 70') -and $polarClientText.Contains('strategy=minimum_mtu_low_latency_ecg') -and $polarClientText.Contains('BRB_POLAR_H10_LOW_LATENCY_CONFIG')) 'connection priority and minimum MTU requested for low-latency ECG readout'
    Add-Check 'Polar PMD ECG uses highest available settings' ($polarClientText.Contains('settings.sampleRates.maxOrNull()') -and $polarClientText.Contains('settings.resolutions.maxOrNull()') -and $polarClientText.Contains('strategy=highest_available_pmd_ecg_settings')) 'PMD ECG start command selects the highest advertised sample rate and resolution before falling back to H10 defaults'
    Add-Check 'condition ECG capture window markers' ($activityText.Contains('BRB_ECG_CAPTURE_START') -and $activityText.Contains('BRB_ECG_CAPTURE_END') -and $activityText.Contains('ecgCaptureDurationMs') -and $activityText.Contains('ecgCaptureDurationNs') -and $activityText.Contains('ecgCaptureStartedElapsedNs') -and $activityText.Contains('audioWindowStartMs=0') -and $activityText.Contains('audioWindowEndMs=${run.audioDurationMs}') -and $activityText.Contains('audioDurationMs')) 'raw ECG capture window is tied to each instruction-audio duration with exact nanosecond window metadata'
    Add-Check 'condition ECG anchor precedes MediaPlayer start' ([regex]::IsMatch($activityText, 'val conditionStartNs = SystemClock\.elapsedRealtimeNanos\(\)(?s:.*?)BRB_CONDITION_AUDIO_START_ANCHOR(?s:.*?)^\s*start\(\)', [System.Text.RegularExpressions.RegexOptions]::Multiline) -and $activityText.Contains('anchor=pre_media_player_start')) 'condition clock is anchored before MediaPlayer.start so no early audio samples are missed'
    $glowVariantAssetsPresent = $true
    foreach ($level in 1..32) {
        $variantPath = Join-Path $projectRoot ('app\src\main\assets\models\glow\BigRedButtonGlowLevel{0:D2}.glb' -f $level)
        if (-not (Test-Path -LiteralPath $variantPath)) {
            $glowVariantAssetsPresent = $false
        }
    }
    Add-Check 'warm heartbeat GLB material variant swap' (
        $glowVariantAssetsPresent -and
        $activityText.Contains('createButtonGlowModelEntities') -and
        $activityText.Contains('BUTTON_GLOW_MODEL_LEVEL_COUNT = 32') -and
        $activityText.Contains('buttonGlowModelAssetUri') -and
        $activityText.Contains('BUTTON_GLOW_MODEL_ASSET_PATTERN') -and
        $activityText.Contains('surfaceGeometry=false') -and
        $activityText.Contains('transparentHalo=false') -and
        $activityText.Contains('pulseDurationMs=$HEARTBEAT_PULSE_DURATION_MS') -and
        $activityText.Contains('pulseCurve=unity_ease_in_out_1_to_0') -and
        $activityText.Contains('HEARTBEAT_PULSE_DURATION_MS = 320L') -and
        $activityText.Contains('HEARTBEAT_PULSE_REFRACTORY_MS = 250L') -and
        $activityText.Contains('SceneLight.createPointLight') -and
        $activityText.Contains('UNITY_BUTTON_IDLE_RED') -and
        $activityText.Contains('UNITY_BUTTON_BLINK_RED') -and
        $activityText.Contains('UNITY_BUTTON_BLINK_EMISSION_RED') -and
        $activityText.Contains('NATIVE_BUTTON_GLOW_PEAK_RED') -and
        $activityText.Contains('NATIVE_BUTTON_GLOW_PEAK_EMISSION_RED') -and
        $activityText.Contains('nativePeakTint=') -and
        $activityText.Contains('nativePeakEmission=') -and
        $activityText.Contains('BRB_BUTTON_GLOW_MODEL_VARIANTS_READY') -and
        $activityText.Contains('HeartbeatPulseDriver') -and
        $activityText.Contains('modelGlow=glb_material_variant_swap') -and
        $activityText.Contains('actualGlowPath=glb_material_variant_swap') -and
        $activityText.Contains('MODEL_GLOW_PANEL_FALLBACK_ENABLED = false') -and
        $activityText.Contains('buttonHeartbeatFlashState') -and
        $activityText.Contains('BRB_HEARTBEAT_FLASH') -and
        -not $activityText.Contains('BRB_BUTTON_GLOW_SHELL_READY') -and
        -not $activityText.Contains('modelGlow=cap_shell') -and
        -not $activityText.Contains('AlphaMode.TRANSLUCENT') -and
        -not $activityText.Contains('SpatialBlendMode.ADDITIVE')
    ) 'heartbeat flash follows the MesmerPrism Unity material-tint/emission approach by swapping GLB material variants with brighter/emissive cap materials plus small native lights, with no transparent halo/canopy geometry'
    Add-Check 'heartbeat glow does not animate button geometry' (
        $activityText.Contains('target=idle_model') -and
        $activityText.Contains('heartbeatGlowMotion=false') -and
        -not $activityText.Contains('buttonGlowModelEntities.forEach { entity -> playButtonPressedAnimation(entity) }')
    ) 'ECG/RR heartbeat feedback may change glow/material/light intensity, but button model motion is reserved for accepted button presses'
    Add-Check 'dual hand and controller contact route' (
        $activityText.Contains('PRESS_SOURCE_HAND_CONTACT = "hand_contact"') -and
        $activityText.Contains('getHandForPointerEvent') -and
        $activityText.Contains('BRB_BUTTON_HAND_CONTACT_SELECT') -and
        $activityText.Contains('COLLIDER_HOVER_SIGNAL_ACTUATE') -and
        $activityText.Contains('target=${contactTarget.spec.name}') -and
        $activityText.Contains('source=dual_controller_hand_contact') -and
        $activityText.Contains('condition_${condition}_hand_contact_press_count')
    ) 'button contact path accepts controller contact and records hand-tracked collider selects as a separate provenance source'
    Add-Check 'controller direction questionnaire handler' ($activityText.Contains('handleControllerDirection') -and $activityText.Contains('BRB_CONTROLLER_DIRECTION') -and $activityText.Contains('KEYCODE_DPAD_LEFT') -and $activityText.Contains('KEYCODE_DPAD_RIGHT') -and $activityText.Contains('KEYCODE_DPAD_UP') -and $activityText.Contains('KEYCODE_DPAD_DOWN')) 'up/down/left/right questionnaire command route'
    Add-Check 'controller enter questionnaire submit handler' ($activityText.Contains('submitCurrentControllerStage') -and $activityText.Contains('KEYCODE_DPAD_CENTER') -and $activityText.Contains('KEYCODE_ENTER') -and $activityText.Contains('KEYCODE_BUTTON_A') -and $activityText.Contains('BRB_CONTROLLER_SUBMIT_REPLAY') -and $activityText.Contains('direction=enter')) 'enter/A button submit route is logged in fast replay evidence'
    Add-Check 'fast validation skips full audio wait' ($activityText.Contains('FAST_CONDITION_AUDIO_SHORTCUT_MS') -and $activityText.Contains('BRB_FAST_CONDITION_AUDIO_SHORTCUT')) 'fast controller flow reads MP3 duration but shortcuts wait'
    Add-Check 'participant-facing questionnaire names hidden' (-not ($activityText.Contains('BrandKicker("Post-condition $condition | Adapted IPQ")') -or $activityText.Contains('PanelTitle("Adapted Presence Questionnaire")' ) -or $activityText.Contains('PanelTitle("Lost Opportunity For Better Results Quotient")') -or $activityText.Contains('PanelTitle("Self-Button Pictographic Scale")'))) 'participant panels use neutral task titles'
    Add-Check 'participant-facing variable text hidden' (-not $activityText.Contains('Logged variables:')) 'research variable labels stay out of participant UI'
    Add-Check 'participant-facing rating instructions' ($activityText.Contains('where 0 means not at all and 6 means very much')) 'neutral response-set instruction'
}

Add-Check 'Quest autorun validation script' (Test-Path (Join-Path $projectRoot 'tools\run-quest-autovalidation.ps1')) 'tools\run-quest-autovalidation.ps1'
$physicalValidationScript = Join-Path $projectRoot 'tools\run-quest-physical-press-validation.ps1'
Add-Check 'Quest physical press validation script' (Test-Path $physicalValidationScript) 'tools\run-quest-physical-press-validation.ps1'
if (Test-Path $physicalValidationScript) {
    $physicalValidationText = Get-Content -Raw -LiteralPath $physicalValidationScript
    Add-Check 'Quest physical validation uses reusable evidence validator' (
        $physicalValidationText.Contains('validate-physical-press-evidence.ps1') -and
        $physicalValidationText.Contains('physical-press-evidence-validation.json')
    ) 'final headset script revalidates pulled exports/logcat with reusable physical evidence validator'
    Add-Check 'Quest physical validation rejects automated button presses' (
        $physicalValidationText.Contains('jsonAutomatedPresses') -and
        $physicalValidationText.Contains('csvAutomatedPresses') -and
        $physicalValidationText.Contains('logAutomatedPressMarkers') -and
        $physicalValidationText.Contains('validationAutomation=true')
    ) 'physical gate fails if button presses are auto_validation or automation-marked'
    Add-Check 'Quest physical validation writes operator checklist' (
        $physicalValidationText.Contains('Write-OperatorChecklist') -and
        $physicalValidationText.Contains('operator-checklist.txt')
    ) 'artifact folder includes human operator checklist'
    Add-Check 'Quest physical validation reports live condition press counts' (
        $physicalValidationText.Contains('c1Controller=') -and
        $physicalValidationText.Contains('c2Controller=') -and
        $physicalValidationText.Contains('BRB_CONDITION_PRESS_SOURCES')
    ) 'final headset script prints per-condition controller_contact progress while waiting'
    Add-Check 'Quest physical validation runs live Polar precheck' (
        $physicalValidationText.Contains('SkipPolarPrecheck') -and
        $physicalValidationText.Contains('PolarPrecheckTimeoutSeconds') -and
        $physicalValidationText.Contains('run-quest-polar-h10-live-smoke.ps1') -and
        $physicalValidationText.Contains('Full physical validation was not started') -and
        $physicalValidationText.Contains('polarPrecheckSummary') -and
        $physicalValidationText.Contains('Update-LatestPolarPrecheckSummary') -and
        $physicalValidationText.Contains('if ($LASTEXITCODE -ne 0)') -and
        $physicalValidationText.Contains('Update-LatestPolarPrecheckSummary') -and
        $physicalValidationText.Contains('if ([string]::IsNullOrWhiteSpace($script:polarPrecheckSummaryPath))')
    ) 'slow physical gate verifies live PMD ECG before starting the full audio run unless explicitly skipped'
    Add-Check 'Quest physical validation writes failure summary' (
        $physicalValidationText.Contains('Write-PhysicalValidationSummary') -and
        $physicalValidationText.Contains("Write-PhysicalValidationSummary -Status 'fail'") -and
        $physicalValidationText.Contains('quest-physical-press-validation-summary.json') -and
        $physicalValidationText.Contains('apkSha256') -and
        $physicalValidationText.Contains('error = $ErrorMessage')
    ) 'failed full physical attempts still leave structured APK-tied evidence'
    Add-Check 'Quest physical validation checks ExperimentResults mirror' (
        $physicalValidationText.Contains('deviceExperimentResultsDir') -and
        $physicalValidationText.Contains('pulledExperimentResultsRoot') -and
        $physicalValidationText.Contains('experiment-results-schema-validation.txt') -and
        $physicalValidationText.Contains('physical-press-evidence-validation-experiment-results.json') -and
        $physicalValidationText.Contains('physicalEvidenceValidationExperimentResults') -and
        $physicalValidationText.Contains('Invoke-Adb shell rm -rf $deviceExperimentResultsDir')
    ) 'final physical gate also validates the SideQuest-readable ExperimentResults folder'
    Add-Check 'Quest physical validation proves export mirror equality' (
        $physicalValidationText.Contains('Compare-ExportMirror') -and
        $physicalValidationText.Contains('export-mirror-comparison.json') -and
        $physicalValidationText.Contains('exportMirrorMatched') -and
        $physicalValidationText.Contains('primarySha256') -and
        $physicalValidationText.Contains('mirrorSha256')
    ) 'final physical gate compares BigRedButtonFirstStudyExports and ExperimentResults byte-for-byte'
}
Add-Check 'physical press evidence validator script' (Test-Path (Join-Path $projectRoot 'tools\validate-physical-press-evidence.ps1')) 'tools\validate-physical-press-evidence.ps1'
Add-Check 'physical press evidence validator tests' (Test-Path (Join-Path $projectRoot 'tools\test-physical-press-evidence-validator.ps1')) 'tools\test-physical-press-evidence-validator.ps1'
$physicalEvidenceValidator = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'tools\validate-physical-press-evidence.ps1')
Add-Check 'physical evidence validator requires accepted contact select' (
    $physicalEvidenceValidator.Contains('BRB_BUTTON_CONTROLLER_CONTACT_SELECT accepted=true') -and
    $physicalEvidenceValidator.Contains('acceptedContactSelects')
) 'final evidence requires accepted controller-contact select markers'
Add-Check 'physical evidence validator requires source summaries' (
    $physicalEvidenceValidator.Contains('BRB_CONDITION_PRESS_SOURCES condition=') -and
    $physicalEvidenceValidator.Contains('sourceSummaryCondition1ControllerPresses') -and
    $physicalEvidenceValidator.Contains('sourceSummaryCondition2ControllerPresses')
) 'final evidence requires condition-end source summary markers matching exports'
Add-Check 'physical evidence validator requires real Polar ECG export evidence' (
    $physicalEvidenceValidator.Contains('*_ecg_timeseries.csv') -and
    $physicalEvidenceValidator.Contains('*_polar_rr_events.csv') -and
    $physicalEvidenceValidator.Contains('real_polar_h10') -and
    $physicalEvidenceValidator.Contains('feedbackSource') -and
    $physicalEvidenceValidator.Contains('physiologySource') -and
    $physicalEvidenceValidator.Contains('conditionRealPolarEvidence') -and
    $physicalEvidenceValidator.Contains('MinRealPolarEcgCoverageRatio') -and
    $physicalEvidenceValidator.Contains('csvRealPolarTimeSeriesRows') -and
    $physicalEvidenceValidator.Contains('csvPolarRrRows') -and
    $physicalEvidenceValidator.Contains('ecgCaptureDurationNs') -and
    $physicalEvidenceValidator.Contains('elapsed_ns') -and
    $physicalEvidenceValidator.Contains('nearest_ecg_delta_ns') -and
    $physicalEvidenceValidator.Contains('MaxPressEcgAlignmentDeltaMs') -and
    $physicalEvidenceValidator.Contains('audio_window_end_ms') -and
    $physicalEvidenceValidator.Contains('BRB_ECG_CAPTURE_START') -and
    $physicalEvidenceValidator.Contains('BRB_ECG_CAPTURE_END') -and
    $physicalEvidenceValidator.Contains('realPolarRowsWithInvalidSampleIndex') -and
    $physicalEvidenceValidator.Contains('realPolarRowsWithNonMonotonicElapsedNs') -and
    $physicalEvidenceValidator.Contains('realPolarMedianSampleDeltaNs') -and
    $physicalEvidenceValidator.Contains('MaxRealPolarEcgMedianDeltaErrorRatio') -and
    $physicalEvidenceValidator.Contains('MaxRealPolarEcgSampleGapMs')
) 'final evidence requires both conditions to contain real Polar H10 ECG/RR physiology, feedback counterbalance metadata, and press-to-ECG alignment fields'
Add-Check 'physical evidence validator requires real Polar blink and low-latency markers' (
    $physicalEvidenceValidator.Contains('*_ecg_blink_events.csv') -and
    $physicalEvidenceValidator.Contains('MinRealPolarBlinkEvents') -and
    $physicalEvidenceValidator.Contains('csvRealPolarBlinkRows') -and
    $physicalEvidenceValidator.Contains('BRB_POLAR_H10_LOW_LATENCY_CONFIG') -and
    $physicalEvidenceValidator.Contains('requestedMtu=70') -and
    $physicalEvidenceValidator.Contains('requested MTU 70') -and
    $physicalEvidenceValidator.Contains('minimum_mtu_low_latency_ecg')
) 'final evidence requires Polar RR blink rows and the minimum-MTU low-latency PMD ECG setup marker'
$physicalEvidenceValidatorTests = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'tools\test-physical-press-evidence-validator.ps1')
Add-Check 'physical evidence validator tests cover real Polar failures' (
    $physicalEvidenceValidatorTests.Contains('missing-real-ecg-samples') -and
    $physicalEvidenceValidatorTests.Contains('only-one-real-polar-condition') -and
    $physicalEvidenceValidatorTests.Contains('sham-filled-with-simulated-ecg') -and
    $physicalEvidenceValidatorTests.Contains('missing-press-elapsed-ns') -and
    $physicalEvidenceValidatorTests.Contains('missing-nearest-ecg-linkage') -and
    $physicalEvidenceValidatorTests.Contains('nonmonotonic-ecg-timing') -and
    $physicalEvidenceValidatorTests.Contains('oversized-press-ecg-gap') -and
    $physicalEvidenceValidatorTests.Contains('missing-polar-rr') -and
    $physicalEvidenceValidatorTests.Contains('missing-low-latency-config')
) 'synthetic pass/fail tests reject missing, simulated, non-monotonic, or misaligned real Polar physiology evidence'
Add-Check 'local preflight script' (Test-Path (Join-Path $projectRoot 'tools\run-local-preflight.ps1')) 'tools\run-local-preflight.ps1'
$exportSchemaScript = Join-Path $projectRoot 'tools\validate-export-schema.ps1'
Add-Check 'export schema validator covers ECG detector and external signal exports' (
    (Test-Path $exportSchemaScript) -and
    ((Get-Content -Raw -LiteralPath $exportSchemaScript).Contains('requiredEcgDetectorColumns')) -and
    ((Get-Content -Raw -LiteralPath $exportSchemaScript).Contains('requiredExternalSignalColumns')) -and
    ((Get-Content -Raw -LiteralPath $exportSchemaScript).Contains('questionnaireProtocol')) -and
    ((Get-Content -Raw -LiteralPath $exportSchemaScript).Contains('externalSignalProtocol')) -and
    ((Get-Content -Raw -LiteralPath $exportSchemaScript).Contains('HRV_Biofeedback')) -and
    ((Get-Content -Raw -LiteralPath $exportSchemaScript).Contains('*_ecg_detector_events.csv')) -and
    ((Get-Content -Raw -LiteralPath $exportSchemaScript).Contains('*_external_signal_samples.csv'))
) 'synthetic and pulled export schema validation includes detector, optional external signal CSVs, and native integration protocol metadata'
Add-Check 'export schema validator covers final end-confirmation branch' (
    (Test-Path $exportSchemaScript) -and
    ((Get-Content -Raw -LiteralPath $exportSchemaScript).Contains('requiredFinalExtraPressColumns')) -and
    ((Get-Content -Raw -LiteralPath $exportSchemaScript).Contains('*_final_extra_button_presses.csv')) -and
    ((Get-Content -Raw -LiteralPath $exportSchemaScript).Contains('finalEndConfirmation')) -and
    ((Get-Content -Raw -LiteralPath $exportSchemaScript).Contains('Extra press branch must require 1000 presses')) -and
    ((Get-Content -Raw -LiteralPath $exportSchemaScript).Contains('Immediate end requires rating 10'))
) 'synthetic and pulled export schema validation includes final 10-point end confirmation plus optional 1000-press branch'
$readinessReportScript = Join-Path $projectRoot 'tools\write-readiness-report.ps1'
Add-Check 'readiness report script' (Test-Path $readinessReportScript) 'tools\write-readiness-report.ps1'
if (Test-Path $readinessReportScript) {
    $readinessReportText = Get-Content -Raw -LiteralPath $readinessReportScript
    Add-Check 'readiness report requires Quest keyevent data gate' (
        $readinessReportText.Contains('artifacts\qkv') -and
        $readinessReportText.Contains('quest-keyevent-questionnaire-validation-summary.json') -and
        $readinessReportText.Contains('questKeyeventQuestionnaireValidationPass') -and
        $readinessReportText.Contains('questKeyeventQuestionnaireApkHashMatchesCurrent') -and
        $readinessReportText.Contains('questKeyeventExperimentResultsPulled')
    ) 'current readiness must include directional questionnaire/export validation on the current APK'
    Add-Check 'readiness report uses latest local validation artifact' (
        $readinessReportText.Contains('Get-LatestArtifactFile') -and
        $readinessReportText.Contains("artifacts\local-validation") -and
        $readinessReportText.Contains("validation-*.json") -and
        $readinessReportText.Contains('$localValidationPath')
    ) 'current readiness must cite the newest standalone/static local validation artifact when available'
    Add-Check 'readiness report requires Quest export mirror equality' (
        $readinessReportText.Contains('questKeyeventExportMirrorMatched') -and
        $readinessReportText.Contains('questKeyeventExportMirrorComparison') -and
        $readinessReportText.Contains('exportMirrorMatched') -and
        $readinessReportText.Contains('exportMirrorComparison') -and
        $readinessReportText.Contains('Quest export mirror byte match')
    ) 'current readiness must require BigRedButtonFirstStudyExports and ExperimentResults to match byte-for-byte'
    Add-Check 'readiness report requires Quest ECG audio-window equality' (
        $readinessReportText.Contains('questKeyeventEcgAudioWindowMatched') -and
        $readinessReportText.Contains('condition 1 ECG capture duration equals audio') -and
        $readinessReportText.Contains('condition 2 ECG capture duration equals audio') -and
        $readinessReportText.Contains('condition 1 ECG audio window end equals audio') -and
        $readinessReportText.Contains('condition 2 ECG audio window end equals audio') -and
        $readinessReportText.Contains('condition 1 ECG capture ns duration equals audio') -and
        $readinessReportText.Contains('condition 2 ECG capture ns duration equals audio') -and
        $readinessReportText.Contains('condition 1 ECG sample rate') -and
        $readinessReportText.Contains('condition 2 ECG sample rate') -and
        $readinessReportText.Contains('Quest ECG audio-window match')
    ) 'current readiness must require qkv ECG capture windows to equal instruction-audio durations at 130 Hz'
    Add-Check 'readiness report requires Quest feedback blink proof' (
        $readinessReportText.Contains('questKeyeventEcgBlinkMatched') -and
        $readinessReportText.Contains('feedback sources counterbalanced complement') -and
        $readinessReportText.Contains('simulated ECG blink count exported') -and
        $readinessReportText.Contains('simulated ECG blink rows match JSON count') -and
        $readinessReportText.Contains('simulated ECG blink runtime marker observed') -and
        $readinessReportText.Contains('simulated heartbeat visual flash observed') -and
        $readinessReportText.Contains('simulated feedback excluded from real ECG time-series') -and
        $readinessReportText.Contains('press elapsed_ns exported') -and
        $readinessReportText.Contains('press alignment columns exported') -and
        $readinessReportText.Contains('Quest feedback counterbalance/sham blink match') -and
        $readinessReportText.Contains('$questKeyeventEcgBlinkMatched -and')
    ) 'current readiness must require qkv feedback counterbalance, sham blink rows, press timing columns, and runtime flash proof'
    Add-Check 'readiness report requires Quest keyboard and enter replay proof' (
        $readinessReportText.Contains('questKeyeventKeyboardLifecycleMatched') -and
        $readinessReportText.Contains('questKeyeventEnterSubmitMatched') -and
        $readinessReportText.Contains('native keyboard request observed') -and
        $readinessReportText.Contains('native keyboard name text mode observed') -and
        $readinessReportText.Contains('native keyboard age number mode observed') -and
        $readinessReportText.Contains('native keyboard movable panel contract observed') -and
        $readinessReportText.Contains('age is numeric IME target') -and
        $readinessReportText.Contains('startup native keyboard request uses text mode') -and
        $readinessReportText.Contains('panel-exit keyboard hide before condition 1 observed') -and
        $readinessReportText.Contains('panel-exit keyboard hide before condition 2 observed') -and
        $readinessReportText.Contains('enter submit replay observed') -and
        $readinessReportText.Contains('controller submit replay observed') -and
        $readinessReportText.Contains('$questKeyeventKeyboardLifecycleMatched -and') -and
        $readinessReportText.Contains('$questKeyeventEnterSubmitMatched -and') -and
        $readinessReportText.Contains('Quest keyboard EditText lifecycle match') -and
        $readinessReportText.Contains('Quest Enter-submit replay match')
    ) 'current readiness must require qkv Name text keyboard, Age numeric keyboard, panel-exit keyboard hide, and Enter-submit replay evidence'
    Add-Check 'readiness report requires Quest redness conversion proof' (
        $readinessReportText.Contains('questKeyeventRednessMatched') -and
        $readinessReportText.Contains('redness conversion cue observed') -and
        $readinessReportText.Contains('condition 1 redness VAS') -and
        $readinessReportText.Contains('condition 1 redness Likert') -and
        $readinessReportText.Contains('condition 1 redness order') -and
        $readinessReportText.Contains('condition 2 redness VAS') -and
        $readinessReportText.Contains('condition 2 redness Likert') -and
        $readinessReportText.Contains('condition 2 redness order') -and
        $readinessReportText.Contains('$questKeyeventRednessMatched -and') -and
        $readinessReportText.Contains('Quest redness conversion match')
    ) 'current readiness must require qkv evidence for VAS/Likert redness conversions and exports'
    Add-Check 'readiness report includes human hardware gate attempts' (
        $readinessReportText.Contains('artifacts\qcs') -and
        $readinessReportText.Contains('quest-controller-contact-smoke-summary.json') -and
        $readinessReportText.Contains('questControllerContactSmokePass') -and
        $readinessReportText.Contains('artifacts\qpv') -and
        $readinessReportText.Contains('quest-physical-press-validation-summary.json') -and
        $readinessReportText.Contains('questPhysicalPressValidationPass')
    ) 'current readiness surfaces latest controller-contact and full physical validation attempt state'
    Add-Check 'readiness report recommends final hardware wrapper' (
        $readinessReportText.Contains('run-final-hardware-gates.ps1') -and
        $readinessReportText.Contains('Recommended ordered final hardware wrapper')
    ) 'remaining hard gate points operators at the ordered wrapper, not only the lower-level physical script'
    Add-Check 'readiness report records final hardware wrapper dry run evidence' (
        $readinessReportText.Contains('artifacts\final-hardware-gates') -and
        $readinessReportText.Contains('final-hardware-gates-summary.json') -and
        $readinessReportText.Contains('FinalHardwareGateSummaryPath') -and
        $readinessReportText.Contains('Get-LatestFinalHardwareDryRunSummary') -and
        $readinessReportText.Contains('Get-LatestValidatedFinalHardwareDryRunSummary') -and
        $readinessReportText.Contains('Test-FinalHardwareSummaryHasPassingValidation') -and
        $readinessReportText.Contains("(Get-JsonPropertyValue `$json 'status') -eq 'dry_run'") -and
        $readinessReportText.Contains("(Get-JsonPropertyValue `$postRunAudit 'status') -eq 'pass'") -and
        $readinessReportText.Contains('finalHardwareGateWrapperDryRunPass') -and
        $readinessReportText.Contains('finalHardwareGateWrapperApkHashMatchesCurrent') -and
        $readinessReportText.Contains('$finalHardwareGateDryRunPass -and') -and
        $readinessReportText.Contains('Final hardware wrapper dry run')
    ) 'readiness report includes selected ordered-wrapper dry-run evidence, supports explicit wrapper binding, and ignores unvalidated in-progress or failed wrapper folders'
    Add-Check 'readiness report requires final hardware post-run audit validator behavioral test' (
        $readinessReportText.Contains('finalHardwarePostRunAuditValidatorTestPass') -and
        $readinessReportText.Contains('finalHardwarePostRunAuditValidatorTest') -and
        $readinessReportText.Contains('$finalHardwarePostRunAuditValidatorTestPass -and') -and
        $readinessReportText.Contains('Final hardware post-run audit validator behavioral test')
    ) 'software readiness cites the behavioral tests for final-wrapper readiness/goal-audit binding'
    Add-Check 'readiness report requires final hardware post-run audit binding validation' (
        $readinessReportText.Contains('finalHardwarePostRunAuditValidationPass') -and
        $readinessReportText.Contains('finalHardwarePostRunAuditValidation') -and
        $readinessReportText.Contains('$finalHardwarePostRunAuditValidationPass -and') -and
        $readinessReportText.Contains('Final hardware post-run audit binding validation') -and
        $readinessReportText.Contains('Same-Path')
    ) 'software readiness cites the latest post-run binding verifier artifact and ties it to the final-wrapper summary'
    Add-Check 'readiness report can represent final completion' (
        $readinessReportText.Contains("'complete'") -and
        $readinessReportText.Contains('$polarLiveSmokePass -and $physicalPressValidationPass') -and
        $readinessReportText.Contains('ready_except_physical_gate') -and
        $readinessReportText.Contains('ready_except_physical_and_live_polar_gates')
    ) 'readiness status becomes complete only when live Polar and final physical export gates both pass'
}
$goalCompletionAuditScript = Join-Path $projectRoot 'tools\write-goal-completion-audit.ps1'
Add-Check 'goal completion audit script' (Test-Path $goalCompletionAuditScript) 'tools\write-goal-completion-audit.ps1'
if (Test-Path $goalCompletionAuditScript) {
    $goalCompletionAuditText = Get-Content -Raw -LiteralPath $goalCompletionAuditScript
    Add-Check 'goal completion audit accepts explicit readiness source' (
        $goalCompletionAuditText.Contains('[string]$ReadinessJson') -and
        $goalCompletionAuditText.Contains('Get-LatestReadinessJson') -and
        $goalCompletionAuditText.Contains('$ReadinessJson = (Resolve-Path $ReadinessJson).Path') -and
        $goalCompletionAuditText.Contains('readinessJson = $ReadinessJson')
    ) 'goal audit can be tied to a specific readiness report instead of racing against latest-file discovery'
    Add-Check 'goal completion audit blocks premature completion' (
        $goalCompletionAuditText.Contains('completionAllowed') -and
        $goalCompletionAuditText.Contains('softwareRequirementsProven') -and
        $goalCompletionAuditText.Contains('externalHardwareRequirementsProven') -and
        $goalCompletionAuditText.Contains("Get-PropertyValue `$readiness 'status'") -and
        $goalCompletionAuditText.Contains("'complete'") -and
        $goalCompletionAuditText.Contains('RequireComplete')
    ) 'completionAllowed is false unless software, hardware, and readiness complete status all agree'
    Add-Check 'goal completion audit enumerates external hardware gates' (
        $goalCompletionAuditText.Contains('live_polar_h10_streaming') -and
        $goalCompletionAuditText.Contains('human_controller_contact_smoke') -and
        $goalCompletionAuditText.Contains('full_physical_live_h10_export') -and
        $goalCompletionAuditText.Contains('external_hardware') -and
        $goalCompletionAuditText.Contains('run-final-hardware-gates.ps1')
    ) 'goal audit keeps live H10 and human physical controller-contact as explicit missing external evidence'
    Add-Check 'goal completion audit records core software/headset gates' (
        $goalCompletionAuditText.Contains('standalone_apk') -and
        $goalCompletionAuditText.Contains('native_keyboard_questionnaire_input') -and
        $goalCompletionAuditText.Contains('quest_visual_passthrough_button') -and
        $goalCompletionAuditText.Contains('quest_panel_glitch_layout') -and
        $goalCompletionAuditText.Contains('audio_timing_and_ecg_window') -and
        $goalCompletionAuditText.Contains('sidequest_exports') -and
        $goalCompletionAuditText.Contains('simulated_ecg_blink_exports')
    ) 'goal audit converts readiness facts into requirement-level rows'
    Add-Check 'goal completion audit records final hardware post-run audit chain gate' (
        $goalCompletionAuditText.Contains('final_hardware_postrun_audit_chain') -and
        $goalCompletionAuditText.Contains('finalHardwarePostRunAuditValidatorTestPass') -and
        $goalCompletionAuditText.Contains('finalHardwarePostRunAuditValidationPass') -and
        $goalCompletionAuditText.Contains('finalHardwarePostRunAuditValidatorTest') -and
        $goalCompletionAuditText.Contains('finalHardwarePostRunAuditValidation')
    ) 'goal audit requires the final-wrapper audit behavioral test plus binding verifier before software requirements are proven'
}
$keyeventValidationScript = Join-Path $projectRoot 'tools\run-quest-keyevent-questionnaire-validation.ps1'
Add-Check 'Quest keyevent questionnaire validation script' (Test-Path $keyeventValidationScript) 'tools\run-quest-keyevent-questionnaire-validation.ps1'
if (Test-Path $keyeventValidationScript) {
    $keyeventValidationText = Get-Content -Raw -LiteralPath $keyeventValidationScript
    Add-Check 'Quest keyevent validation records APK identity' (
        $keyeventValidationText.Contains('apkSha256') -and
        $keyeventValidationText.Contains('apkSizeBytes') -and
        $keyeventValidationText.Contains('Get-FileHash -Algorithm SHA256')
    ) 'directional questionnaire/export evidence is tied to the installed APK'
    Add-Check 'Quest keyevent validation pulls ExperimentResults exports' (
        $keyeventValidationText.Contains('brb.keyeventValidation') -and
        $keyeventValidationText.Contains('ExperimentResults') -and
        $keyeventValidationText.Contains('expected-vs-observed.csv') -and
        $keyeventValidationText.Contains('brb_first_study_keyevent_final_extra_button_presses.csv') -and
        $keyeventValidationText.Contains('ecgTimeSeriesCsv') -and
        $keyeventValidationText.Contains('brb_first_study_keyevent_ecg_detector_events.csv') -and
        $keyeventValidationText.Contains('brb_first_study_keyevent_external_signal_samples.csv')
    ) 'fast replay validates SideQuest-readable JSON/CSV data outputs'
    Add-Check 'Quest keyevent validation proves export mirror equality' (
        $keyeventValidationText.Contains('Compare-ExportMirror') -and
        $keyeventValidationText.Contains('export-mirror-comparison.json') -and
        $keyeventValidationText.Contains('exportMirrorMatched') -and
        $keyeventValidationText.Contains('primarySha256') -and
        $keyeventValidationText.Contains('mirrorSha256')
    ) 'fast replay checks BigRedButtonFirstStudyExports and ExperimentResults are byte-identical after pull'
    Add-Check 'Quest keyevent validation proves native integration protocols' (
        $keyeventValidationText.Contains('BRB_QUESTIONNAIRE_CONTRACT schema=bigredbutton.questionnaire_flow.v1') -and
        $keyeventValidationText.Contains('questionnaire protocol schema') -and
        $keyeventValidationText.Contains('questionnaire lifecycle markers observed') -and
        $keyeventValidationText.Contains('external signal protocol disabled diagnostic') -and
        $keyeventValidationText.Contains('external signal diagnostic marker observed') -and
        $keyeventValidationText.Contains('HRV_Biofeedback') -and
        $keyeventValidationText.Contains('drivesButtonPresses')
    ) 'fast replay validates in-process questionnaire contract metadata and disabled diagnostic-only external signal defaults'
    Add-Check 'Quest keyevent validation proves keyboard and enter lifecycle' (
        $keyeventValidationText.Contains('native keyboard name text mode observed') -and
        $keyeventValidationText.Contains('native keyboard age number mode observed') -and
        $keyeventValidationText.Contains('native keyboard movable panel contract observed') -and
        $keyeventValidationText.Contains('age is numeric IME target') -and
        $keyeventValidationText.Contains('startup native keyboard request uses text mode') -and
        $keyeventValidationText.Contains('panel-exit keyboard hide before condition 1 observed') -and
        $keyeventValidationText.Contains('panel-exit keyboard hide before condition 2 observed') -and
        $keyeventValidationText.Contains('enter submit replay observed') -and
        $keyeventValidationText.Contains('controller submit replay observed')
    ) 'fast replay now fails without Name text keyboard, Age numeric keyboard, panel-exit hide, and enter-submit markers'
    Add-Check 'Quest keyevent validation proves prior button experience prompt' (
        $keyeventValidationText.Contains('BRB_PRIOR_BUTTON_EXPERIENCE_SHOWN') -and
        $keyeventValidationText.Contains('prior big-red-button experience JSON answer') -and
        $keyeventValidationText.Contains('prior big-red-button experience summary answer') -and
        $keyeventValidationText.Contains('prior big-red-button experience prompt shown once') -and
        $keyeventValidationText.Contains('prior big-red-button experience not repeated in condition 2') -and
        $keyeventValidationText.Contains('BRB_CONTROLLER_SUBMIT_REPLAY condition=1 stage=pre_button_experience submitted=true')
    ) 'fast replay now selects the new one-time XR prior-experience question, starts condition 1, and checks JSON/CSV/log evidence'
    Add-Check 'Quest keyevent validation proves final end-confirmation branch' (
        $keyeventValidationText.Contains('BRB_FINAL_END_CONFIRMATION_SHOWN') -and
        $keyeventValidationText.Contains('BRB_KEYEVENT_REPLAY_STEP condition=0 stage=final_end_confirmation direction=right') -and
        $keyeventValidationText.Contains('BRB_CONTROLLER_SUBMIT_REPLAY condition=0 stage=final_end_confirmation submitted=true') -and
        $keyeventValidationText.Contains('BRB_FINAL_END_CONFIRMATION_SAVED rating=10 immediateEnd=true') -and
        $keyeventValidationText.Contains('final end confirmation JSON rating') -and
        $keyeventValidationText.Contains('final end confirmation JSON immediate end') -and
        $keyeventValidationText.Contains('final extra button press CSV exists') -and
        $keyeventValidationText.Contains('final extra button press CSV rows') -and
        $keyeventValidationText.Contains('final end confirmation controller replay observed')
    ) 'fast replay chooses option 10 on the final 10-point scale and verifies JSON, summary, dedicated CSV, and controller replay evidence'
    Add-Check 'Quest keyevent validation proves redness conversion export' (
        $keyeventValidationText.Contains('condition 1 redness VAS') -and
        $keyeventValidationText.Contains('condition 1 redness Likert') -and
        $keyeventValidationText.Contains('condition 1 redness order') -and
        $keyeventValidationText.Contains('condition 1 redness carried VAS') -and
        $keyeventValidationText.Contains('condition 1 redness changed after conversion') -and
        $keyeventValidationText.Contains('condition 1 redness final matches carried') -and
        $keyeventValidationText.Contains('condition 2 redness VAS') -and
        $keyeventValidationText.Contains('condition 2 redness Likert') -and
        $keyeventValidationText.Contains('condition 2 redness order') -and
        $keyeventValidationText.Contains('condition 2 redness carried VAS') -and
        $keyeventValidationText.Contains('condition 2 redness changed after conversion') -and
        $keyeventValidationText.Contains('condition 2 redness final matches carried') -and
        $keyeventValidationText.Contains('redness conversion cue observed') -and
        $keyeventValidationText.Contains('microTimeline=.*supervisor_ping.*seven_boxes_assemble') -and
        $keyeventValidationText.Contains('microTimeline=.*professional_warning.*boxes_erased')
    ) 'fast replay now fails unless redness conversion markers, transcript micro-timelines, final values, and carried-forward/change audit fields are present'
    Add-Check 'Quest keyevent validation proves feedback blink and flash path' (
        $keyeventValidationText.Contains('feedback sources counterbalanced complement') -and
        $keyeventValidationText.Contains('feedback assignment order matches condition feedback sources') -and
        $keyeventValidationText.Contains('simulated ECG blink count exported') -and
        $keyeventValidationText.Contains('simulated ECG blink rows match JSON count') -and
        $keyeventValidationText.Contains('simulated ECG blink runtime marker observed') -and
        $keyeventValidationText.Contains('simulated heartbeat visual flash observed') -and
        $keyeventValidationText.Contains('simulated feedback excluded from real ECG time-series') -and
        $keyeventValidationText.Contains('press elapsed_ns exported') -and
        $keyeventValidationText.Contains('press alignment columns exported') -and
        $keyeventValidationText.Contains('BRB_HEARTBEAT_FLASH condition=$simulatedConditionNumber source=simulated_neurokit2')
    ) 'fast replay now fails unless feedback counterbalance, sham RR blink/flash markers, and press timing columns export correctly'
    Add-Check 'Quest keyevent validation recovers foreground focus' (
        $keyeventValidationText.Contains('Ensure-TargetForeground') -and
        $keyeventValidationText.Contains('foreground-after-launch.txt') -and
        $keyeventValidationText.Contains('foreground-after-relaunch.txt') -and
        $keyeventValidationText.Contains('force-stopping it once before relaunching')
    ) 'fast qkv validation force-stops a stale non-Oculus foreground OpenXR app and relaunches the study once before waiting for markers'
}
$controllerContactSmokeScript = Join-Path $projectRoot 'tools\run-quest-controller-contact-smoke.ps1'
Add-Check 'Quest controller contact smoke script' (Test-Path $controllerContactSmokeScript) 'tools\run-quest-controller-contact-smoke.ps1'
if (Test-Path $controllerContactSmokeScript) {
    $controllerContactSmokeText = Get-Content -Raw -LiteralPath $controllerContactSmokeScript
    Add-Check 'Quest controller contact smoke writes failure summary' (
        $controllerContactSmokeText.Contains('Write-ControllerContactSummary') -and
        $controllerContactSmokeText.Contains("Write-ControllerContactSummary -Status 'fail'") -and
        $controllerContactSmokeText.Contains('quest-controller-contact-smoke-summary.json') -and
        $controllerContactSmokeText.Contains('apkSha256') -and
        $controllerContactSmokeText.Contains('pressDetected')
    ) 'failed controller-contact smoke attempts still leave structured APK-tied evidence'
}
if (Test-Path (Join-Path $projectRoot 'tools\run-quest-polar-h10-live-smoke.ps1')) {
    $polarLiveSmokeText = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'tools\run-quest-polar-h10-live-smoke.ps1')
    Add-Check 'Quest Polar H10 live smoke script' (
        $polarLiveSmokeText.Contains('BRB_POLAR_H10_STATUS') -and
        $polarLiveSmokeText.Contains('ecgStreaming=true') -and
        $polarLiveSmokeText.Contains('ecgSamples') -and
        $polarLiveSmokeText.Contains('ecgHz') -and
        $polarLiveSmokeText.Contains('expected 130 Hz') -and
        $polarLiveSmokeText.Contains('expectedRequestedMtu = 70') -and
        $polarLiveSmokeText.Contains('requestedMtu=70') -and
        $polarLiveSmokeText.Contains('minimum_mtu_low_latency_ecg')
    ) 'tools\run-quest-polar-h10-live-smoke.ps1 proves live PMD ECG sample delivery with the minimum ECG MTU'
    Add-Check 'Quest Polar H10 live smoke writes failure evidence' (
        $polarLiveSmokeText.Contains('Write-PolarSummary') -and
        $polarLiveSmokeText.Contains("Write-PolarSummary -Status 'fail'") -and
        $polarLiveSmokeText.Contains('quest-polar-h10-live-smoke-summary.json') -and
        $polarLiveSmokeText.Contains('error = $ErrorMessage')
    ) 'failed H10 detection attempts still leave a structured summary for readiness and handoff'
} else {
    Add-Check 'Quest Polar H10 live smoke script' $false 'tools\run-quest-polar-h10-live-smoke.ps1'
}
$finalHardwareGatesScript = Join-Path $projectRoot 'tools\run-final-hardware-gates.ps1'
Add-Check 'final hardware gate wrapper script' (Test-Path $finalHardwareGatesScript) 'tools\run-final-hardware-gates.ps1 sequences live H10, fast contact smoke, and full physical export validation'
if (Test-Path $finalHardwareGatesScript) {
    $finalHardwareGatesText = Get-Content -Raw -LiteralPath $finalHardwareGatesScript
    Add-Check 'final hardware gate wrapper enforces order' (
        $finalHardwareGatesText.Contains('run-quest-polar-h10-live-smoke.ps1') -and
        $finalHardwareGatesText.Contains('run-quest-controller-contact-smoke.ps1') -and
        $finalHardwareGatesText.Contains('run-quest-physical-press-validation.ps1') -and
        $finalHardwareGatesText.Contains('-SkipPolarPrecheck') -and
        $finalHardwareGatesText.Contains('final-hardware-gates-summary.json') -and
        $finalHardwareGatesText.Contains('DryRun')
    ) 'wrapper runs standalone live Polar smoke before same-session physical validation and writes a combined summary'
    Add-Check 'final hardware gate wrapper refreshes readiness and goal audit' (
        $finalHardwareGatesText.Contains('SkipPostRunAudit') -and
        $finalHardwareGatesText.Contains('Invoke-PostRunAudit') -and
        $finalHardwareGatesText.Contains('write-readiness-report.ps1') -and
        $finalHardwareGatesText.Contains('-FinalHardwareGateSummaryPath $summaryPath') -and
        $finalHardwareGatesText.Contains('write-goal-completion-audit.ps1') -and
        $finalHardwareGatesText.Contains('-ReadinessJson $script:postRunReadinessReport') -and
        $finalHardwareGatesText.Contains('$readinessExitCode = $LASTEXITCODE') -and
        $finalHardwareGatesText.Contains('produced a readiness JSON for wrapper binding') -and
        $finalHardwareGatesText.Contains('no fresh readiness-report.json was found') -and
        $finalHardwareGatesText.Contains('postRunAudit') -and
        $finalHardwareGatesText.Contains('goalCompletionAudit') -and
        $finalHardwareGatesText.Contains('readinessReport')
    ) 'wrapper refreshes readiness and the machine-readable goal audit after dry runs, failures, and real hardware runs'
    Add-Check 'final hardware gate wrapper runs pre-run operator handoff' (
        $finalHardwareGatesText.Contains('SkipPreRunHandoff') -and
        $finalHardwareGatesText.Contains('Invoke-PreRunHandoff') -and
        $finalHardwareGatesText.Contains('write-final-hardware-operator-handoff.ps1') -and
        $finalHardwareGatesText.Contains('preRunHandoff') -and
        $finalHardwareGatesText.Contains('final-operator-handoff.json') -and
        $finalHardwareGatesText.Contains('-CheckAdb') -and
        $finalHardwareGatesText.Contains('if (-not $DryRun)')
    ) 'wrapper writes an APK/readiness/goal-audit handoff before attempting live H10 or controller-contact gates'
}
$finalOperatorHandoffScript = Join-Path $projectRoot 'tools\write-final-hardware-operator-handoff.ps1'
Add-Check 'final hardware operator handoff script' (Test-Path $finalOperatorHandoffScript) 'tools\write-final-hardware-operator-handoff.ps1'
if (Test-Path $finalOperatorHandoffScript) {
    $finalOperatorHandoffText = Get-Content -Raw -LiteralPath $finalOperatorHandoffScript
    Add-Check 'final hardware operator handoff aggregates current audit chain' (
        $finalOperatorHandoffText.Contains('write-readiness-report.ps1') -and
        $finalOperatorHandoffText.Contains('write-goal-completion-audit.ps1') -and
        $finalOperatorHandoffText.Contains('final_hardware_postrun_audit_chain') -and
        $finalOperatorHandoffText.Contains('apkHashMatchesReadinessAndGoalAudit') -and
        $finalOperatorHandoffText.Contains('goalAuditBoundToSelectedReadiness') -and
        $finalOperatorHandoffText.Contains('ready_for_operator_external_gates') -and
        $finalOperatorHandoffText.Contains('final-operator-handoff.json')
    ) 'operator handoff proves the APK/readiness/goal-audit chain is coherent before the human hardware run'
    Add-Check 'final hardware operator handoff preserves external gate boundary' (
        $finalOperatorHandoffText.Contains('remainingExternalGates') -and
        $finalOperatorHandoffText.Contains('run-final-hardware-gates.ps1') -and
        $finalOperatorHandoffText.Contains('This handoff does not prove live Polar H10 streaming or human controller-contact pressing') -and
        $finalOperatorHandoffText.Contains('RequireReady')
    ) 'operator handoff lists missing live-H10/controller gates but does not count itself as hardware evidence'
}
$finalHardwarePostRunAuditValidatorScript = Join-Path $projectRoot 'tools\validate-final-hardware-postrun-audit.ps1'
Add-Check 'final hardware post-run audit validator script' (Test-Path $finalHardwarePostRunAuditValidatorScript) 'tools\validate-final-hardware-postrun-audit.ps1'
if (Test-Path $finalHardwarePostRunAuditValidatorScript) {
    $finalHardwarePostRunAuditValidatorText = Get-Content -Raw -LiteralPath $finalHardwarePostRunAuditValidatorScript
    Add-Check 'final hardware post-run audit validator checks binding' (
        $finalHardwarePostRunAuditValidatorText.Contains('goal audit readiness matches postrun readiness') -and
        $finalHardwarePostRunAuditValidatorText.Contains('goal audit status matches readiness') -and
        $finalHardwarePostRunAuditValidatorText.Contains('Test-GoalStatusMatchesReadiness') -and
        $finalHardwarePostRunAuditValidatorText.Contains('incomplete_software_or_headset_gates') -and
        $finalHardwarePostRunAuditValidatorText.Contains('readiness points back to final wrapper summary') -and
        $finalHardwarePostRunAuditValidatorText.Contains('dry run cannot allow completion') -and
        $finalHardwarePostRunAuditValidatorText.Contains('completion allowed requires complete real wrapper') -and
        $finalHardwarePostRunAuditValidatorText.Contains('final-hardware-postrun-audit-validation.json')
    ) 'verifier confirms the wrapper summary, readiness report, and goal audit form one consistent evidence chain'
}
$finalHardwarePostRunAuditValidatorTestScript = Join-Path $projectRoot 'tools\test-final-hardware-postrun-audit-validator.ps1'
Add-Check 'final hardware post-run audit validator test script' (Test-Path $finalHardwarePostRunAuditValidatorTestScript) 'tools\test-final-hardware-postrun-audit-validator.ps1'
if (Test-Path $finalHardwarePostRunAuditValidatorTestScript) {
    $finalHardwarePostRunAuditValidatorTestText = Get-Content -Raw -LiteralPath $finalHardwarePostRunAuditValidatorTestScript
    Add-Check 'final hardware post-run audit validator behavioral tests' (
        $finalHardwarePostRunAuditValidatorTestText.Contains('valid-dry-run') -and
        $finalHardwarePostRunAuditValidatorTestText.Contains('valid-real-pass') -and
        $finalHardwarePostRunAuditValidatorTestText.Contains('valid-incomplete-bootstrap') -and
        $finalHardwarePostRunAuditValidatorTestText.Contains('reject-goal-readiness-mismatch') -and
        $finalHardwarePostRunAuditValidatorTestText.Contains('reject-dry-run-completion-allowed') -and
        $finalHardwarePostRunAuditValidatorTestText.Contains('reject-incomplete-readiness-completion-allowed') -and
        $finalHardwarePostRunAuditValidatorTestText.Contains('reject-goal-status-mismatch') -and
        $finalHardwarePostRunAuditValidatorTestText.Contains('reject-readiness-apk-mismatch') -and
        $finalHardwarePostRunAuditValidatorTestText.Contains('reject-goal-apk-mismatch') -and
        $finalHardwarePostRunAuditValidatorTestText.Contains('reject-postrun-status-fail') -and
        $finalHardwarePostRunAuditValidatorTestText.Contains('final-hardware-postrun-audit-validator-test-summary.json')
    ) 'local test proves the post-run binding verifier accepts valid chains and rejects stale/mismatched audit chains'
}
Add-Check 'Quest panel glitch smoke script' (Test-Path (Join-Path $projectRoot 'tools\run-quest-panel-smoke.ps1')) 'tools\run-quest-panel-smoke.ps1'
Add-Check 'Quest visual layout smoke script' (Test-Path (Join-Path $projectRoot 'tools\run-quest-visual-layout-smoke.ps1')) 'tools\run-quest-visual-layout-smoke.ps1'
if (Test-Path (Join-Path $projectRoot 'tools\run-quest-visual-layout-smoke.ps1')) {
    $visualLayoutSmokeText = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'tools\run-quest-visual-layout-smoke.ps1')
    Add-Check 'Quest visual layout smoke preserves logcat fallback evidence' (
        $visualLayoutSmokeText.Contains('logcat-full.txt') -and
        $visualLayoutSmokeText.Contains('logcat-filtered.txt') -and
        $visualLayoutSmokeText.Contains('[string]::IsNullOrWhiteSpace($logText)') -and
        $visualLayoutSmokeText.Contains('Set-Content -LiteralPath $filteredLogPath')
    ) 'visual smoke always writes filtered logcat and falls back to full logcat before parsing spatial markers'
}
Add-Check 'Quest audio rig stress script' (Test-Path (Join-Path $projectRoot 'tools\run-quest-audio-rig-stress.ps1')) 'tools\run-quest-audio-rig-stress.ps1'
if (Test-Path (Join-Path $projectRoot 'tools\run-quest-audio-rig-stress.ps1')) {
    $audioRigStressText = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'tools\run-quest-audio-rig-stress.ps1')
    Add-Check 'Quest audio rig stress covers gated prompt timing' (
        $audioRigStressText.Contains('BRB_PRIOR_BUTTON_EXPERIENCE_ANSWER_BLOCKED answer=yes') -and
        $audioRigStressText.Contains('BRB_PRIOR_BUTTON_EXPERIENCE_OPTIONS_READY') -and
        $audioRigStressText.Contains('BRB_PRIOR_BUTTON_EXPERIENCE_FEEDBACK_READY answer=yes') -and
        $audioRigStressText.Contains('BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_READY answer=yes') -and
        $audioRigStressText.Contains('cue=pre_start_instructions') -and
        $audioRigStressText.Contains('BRB_FINAL_END_CONFIRMATION_SELECTION_BLOCKED rating=10') -and
        $audioRigStressText.Contains('BRB_FINAL_END_CONFIRMATION_OPTIONS_READY') -and
        $audioRigStressText.Contains('BRB_FINAL_EXTRA_BUTTON_PRESS_SUPPRESSED reason=prompt_audio_active') -and
        $audioRigStressText.Contains('BRB_FINAL_EXTRA_PROMPT_HIDDEN reason=audio_complete') -and
        $audioRigStressText.Contains('"condition_${condition}_audio_probe"') -and
        $audioRigStressText.Contains('foreach ($condition in 1, 2)') -and
        $audioRigStressText.Contains('Add-TimeWindowComparison') -and
        $audioRigStressText.Contains('quest-audio-rig-stress-summary.json')
    ) 'headset stress script proves audio-linked answer visibility and cue playback timing with logcat deltas'
}
Add-Check 'Quest short smoke suite script' (Test-Path (Join-Path $projectRoot 'tools\run-quest-smoke-suite.ps1')) 'tools\run-quest-smoke-suite.ps1'
Add-Check 'realistic button model generator' (Test-Path (Join-Path $projectRoot 'tools\create-realistic-button-model.ps1')) 'tools\create-realistic-button-model.ps1'
Add-Check 'pictographic button thumbnail generator' (Test-Path (Join-Path $projectRoot 'tools\create-pictographic-button-thumbnail.ps1')) 'tools\create-pictographic-button-thumbnail.ps1'
Add-Check 'retired panel chime generator retained' (Test-Path (Join-Path $projectRoot 'tools\create-retro-startup-chime.ps1')) 'legacy helper kept for provenance; active panel transitions use supplied intro/outro glitch MP3s'
Add-Check 'press sound plan documentation' (Test-Path (Join-Path $projectRoot 'docs\button-press-sound-and-motion.md')) 'docs\button-press-sound-and-motion.md'
Add-Check 'physical validation operator guide' (Test-Path (Join-Path $projectRoot 'docs\physical-validation-operator-guide.md')) 'docs\physical-validation-operator-guide.md'
Add-Check 'native keyboard contract test script' (Test-Path (Join-Path $projectRoot 'tools\test-native-keyboard-contract.ps1')) 'tools\test-native-keyboard-contract.ps1'
$demographicsKeyboardValidationScript = Join-Path $projectRoot 'tools\run-quest-demographics-keyboard-entry-validation.ps1'
Add-Check 'Quest demographics keyboard entry validation script' (Test-Path $demographicsKeyboardValidationScript) 'tools\run-quest-demographics-keyboard-entry-validation.ps1'
if (Test-Path $demographicsKeyboardValidationScript) {
    $demographicsKeyboardValidationText = Get-Content -Raw -LiteralPath $demographicsKeyboardValidationScript
    Add-Check 'Quest demographics keyboard validation covers EditText Name/Age route' (
        $demographicsKeyboardValidationText.Contains('BRB_DEMOGRAPHICS_EDITTEXT_FOCUS_REQUEST') -and
        $demographicsKeyboardValidationText.Contains('actual name EditText focus marker') -and
        $demographicsKeyboardValidationText.Contains('age number keyboard request after retarget') -and
        $demographicsKeyboardValidationText.Contains('BRB_SOFT_KEYBOARD_REQUEST reason=field_age') -and
        $demographicsKeyboardValidationText.Contains('platformControl=EditText') -and
        $demographicsKeyboardValidationText.Contains('Invoke-DemographicsValidationCommand') -and
        $demographicsKeyboardValidationText.Contains('brb.demographicsKeyboardValidationCommand') -and
        $demographicsKeyboardValidationText.Contains('brb.demographicsKeyboardValidationSession') -and
        $demographicsKeyboardValidationText.Contains('source=validation_intent') -and
        $demographicsKeyboardValidationText.Contains("Invoke-DemographicsValidationCommand 'set_age' 'a1234'") -and
        $demographicsKeyboardValidationText.Contains('BRB_DEMOGRAPHICS_AGE_FILTER source=validation_intent rawLength=5 digitCount=4 cleanedLength=3 stripped=true truncated=true') -and
        $demographicsKeyboardValidationText.Contains("Invoke-DemographicsValidationCommand 'clear_age'") -and
        $demographicsKeyboardValidationText.Contains("Invoke-DemographicsValidationCommand 'set_age' '34'") -and
        $demographicsKeyboardValidationText.Contains("Invoke-DemographicsValidationCommand 'age_done'") -and
        -not $demographicsKeyboardValidationText.Contains('SpatialTextField') -and
        -not $demographicsKeyboardValidationText.Contains('trigger dial') -and
        -not $demographicsKeyboardValidationText.Contains('input text')
    ) 'focused Quest smoke proves visible AndroidView(EditText) Name text/Next and Age number/Done contracts, mixed-input cleanup, then exact George/34 values'
}

$localPreflightScript = Join-Path $projectRoot 'tools\run-local-preflight.ps1'
if (Test-Path $localPreflightScript) {
    $localPreflightText = Get-Content -Raw -LiteralPath $localPreflightScript
    Add-Check 'local preflight runs native keyboard contract test' (
        $localPreflightText.Contains('test-native-keyboard-contract') -and
        $localPreflightText.Contains('nativeKeyboardValidation')
    ) 'local preflight includes name/age native keyboard switching validation artifact'
    Add-Check 'local preflight runs final hardware post-run audit validator when available' (
        $localPreflightText.Contains('validate-final-hardware-postrun-audit.ps1') -and
        $localPreflightText.Contains('validate-final-hardware-postrun-audit') -and
        $localPreflightText.Contains('finalHardwarePostRunAuditValidation') -and
        $localPreflightText.Contains('final-hardware-postrun-audit-validation.json') -and
        $localPreflightText.Contains('final-hardware-gates-summary.json')
    ) 'local preflight carries the final-wrapper readiness/goal-audit binding verifier when wrapper evidence exists'
    Add-Check 'local preflight runs final hardware post-run audit validator tests' (
        $localPreflightText.Contains('test-final-hardware-postrun-audit-validator.ps1') -and
        $localPreflightText.Contains('test-final-hardware-postrun-audit-validator') -and
        $localPreflightText.Contains('finalHardwarePostRunAuditValidatorTest') -and
        $localPreflightText.Contains('final-hardware-postrun-audit-validator-test-summary.json')
    ) 'local preflight proves the final-wrapper audit verifier rejects stale or mismatched chains'
}

$layoutPreviewScript = Join-Path $projectRoot 'tools\render-layout-previews.ps1'
if (Test-Path $layoutPreviewScript) {
    $layoutPreviewText = Get-Content -Raw -LiteralPath $layoutPreviewScript
    Add-Check 'layout preview uses actual IPQ items' ($layoutPreviewText.Contains('Get-IpqItemsFromSource') -and $layoutPreviewText.Contains('Expected 14 IPQ items')) 'previews parse actual Kotlin questionnaire text'
    Add-Check 'layout preview uses neutral participant labels' (-not ($layoutPreviewText.Contains('Self-Button Pictographic Scale') -or $layoutPreviewText.Contains('Adapted Presence Questionnaire') -or $layoutPreviewText.Contains('Lost Opportunity For Better Results Quotient'))) 'preview labels match participant UI'
    Add-Check 'layout preview uses start experiment label' ($layoutPreviewText.Contains("'Start experiment'") -and -not $layoutPreviewText.Contains("'Start condition 1'")) 'preview CTA avoids condition numbering'
    Add-Check 'layout preview hides participant ID field' (-not $layoutPreviewText.Contains("'Participant ID'")) 'preview reflects background participant ID assignment'
    Add-Check 'layout preview shows gender choices' ($layoutPreviewText.Contains("'Male'") -and $layoutPreviewText.Contains("'Female'") -and $layoutPreviewText.Contains("'Other'") -and $layoutPreviewText.Contains("'Prefer not to say'")) 'preview reflects gender four-choice'
    Add-Check 'layout preview shows handedness choices' ($layoutPreviewText.Contains("'Left'") -and $layoutPreviewText.Contains("'Right'") -and $layoutPreviewText.Contains("'Ambidextrous'")) 'preview reflects handedness tri-choice'
    Add-Check 'layout preview centers model thumbnail' ($layoutPreviewText.Contains('big_red_button_model_thumbnail.png') -and $layoutPreviewText.Contains('$buttonCenterX - 62') -and $layoutPreviewText.Contains('$buttonCenterY - 62')) 'preview thumbnail centered inside circle'
    Add-Check 'layout preview shows website intake aesthetic' ($layoutPreviewText.Contains('BIG RED BUTTON INSTITUTE | INTAKE') -and $layoutPreviewText.Contains('Participant details')) 'preview mirrors intake page styling'
    Add-Check 'layout preview shows Polar validity panel' (
        $layoutPreviewText.Contains('Polar H10 ECG ready') -and
        $layoutPreviewText.Contains('ECG 520 samples @ 130 Hz') -and
        $layoutPreviewText.Contains('$waveRect')
    ) 'preview includes first-menu PMD ECG-ready status strip with a live ECG trace area'
    Add-Check 'layout preview shows digital press counter' ($layoutPreviewText.Contains("'012'") -and $layoutPreviewText.Contains("'PRESSES'")) 'button preview includes old digital counter above model'
    Add-Check 'layout preview shows prior button experience prompt' (
        $layoutPreviewText.Contains('Draw-PreButtonExperiencePromptPreview') -and
        $layoutPreviewText.Contains('pre-button-experience-prompt-preview.png') -and
        $layoutPreviewText.Contains('Do you have any experience with') -and
        $layoutPreviewText.Contains('pressing big red buttons?') -and
        $layoutPreviewText.Contains('red floating question; start appears only after all audio') -and
        $layoutPreviewText.Contains('An experienced user, just the type') -and
        $layoutPreviewText.Contains('of participant we need.') -and
        $layoutPreviewText.Contains('pre-start instructions clip plays') -and
        $layoutPreviewText.Contains('START EXPERIMENT') -and
        -not $layoutPreviewText.Contains('$g.FillRectangle((Brush 223 44 44), 54, 402, 412, 54)')
    ) 'preview documents the one-time transparent XR prompt as floating red counter-style text with bare answer boxes'
    Add-Check 'layout preview shows transparent red counter' (
        $layoutPreviewText.Contains('transparent counter overlay; no filled backing panel') -and
        $layoutPreviewText.Contains('Brush 255 43 43') -and
        -not $layoutPreviewText.Contains('$counterBg')
    ) 'button preview reflects the transparent passthrough counter with red digits'
    Add-Check 'layout preview shows warm heartbeat glow' (
        $layoutPreviewText.Contains('warm surface emission glow, not flat halo') -and
        $layoutPreviewText.Contains('Brush 255 110 22') -and
        -not $layoutPreviewText.Contains('$pulse = Pen 255 16 16 5 70')
    ) 'button preview reflects the new warm emission treatment instead of a flat halo'
    Add-Check 'layout preview shows compact no-scroll demographics' (
        $layoutPreviewText.Contains('No-scroll compact intake') -and
        $layoutPreviewText.Contains('Start experiment')
    ) 'preview labels the intake panel as compact/no-scroll with all controls visible'
    Add-Check 'layout preview shows native demographics keyboard' (
        $layoutPreviewText.Contains('Draw-DemographicsNativeKeyboardPreview') -and
        $layoutPreviewText.Contains('demographics-native-keyboard-preview.png') -and
        $layoutPreviewText.Contains('native movable Quest keyboard') -and
        $layoutPreviewText.Contains('Age uses the numeric Quest keyboard')
    ) 'preview documents the native movable Quest keyboard for Name and Age'
    Add-Check 'layout preview shows calibrated pictographic axis' (
        $layoutPreviewText.Contains('How Big and how Red was this button experience?') -and
        $layoutPreviewText.Contains('Please rate how subjectively close the button felt') -and
        $layoutPreviewText.Contains('$sliderW = 640') -and
        $layoutPreviewText.Contains('$thumbRadius = 20') -and
        $layoutPreviewText.Contains('$axisStartX = $sliderX + $thumbRadius') -and
        $layoutPreviewText.Contains('very close') -and
        $layoutPreviewText.Contains('very distant') -and
        $layoutPreviewText.Contains('small presence') -and
        $layoutPreviewText.Contains('large presence') -and
        $layoutPreviewText.Contains('How large was the felt presence of the button?') -and
        $layoutPreviewText.Contains('$likertInset = 34') -and
        $layoutPreviewText.Contains('$likertGap = 12') -and
        $layoutPreviewText.Contains('Pen 223 44 44 9')
    ) 'preview shows equal-width sliders, a self-origin distance axis, and thicker circle boundaries'
    Add-Check 'layout preview shows redness scale' (
        $layoutPreviewText.Contains('How red did the button feel?') -and
        $layoutPreviewText.Contains('slightly red') -and
        $layoutPreviewText.Contains('extremely red')
    ) 'preview includes the third redness response scale'
    Add-Check 'layout preview shows redness changeover choreography' (
        $layoutPreviewText.Contains('Draw-RednessChangeoverPreviews') -and
        $layoutPreviewText.Contains('redness-changeover-vas-to-likert-preview.png') -and
        $layoutPreviewText.Contains('redness-changeover-likert-to-vas-preview.png') -and
        $layoutPreviewText.Contains('first_questionnaire_change.mp3') -and
        $layoutPreviewText.Contains('second_questionnaire_change_excuse.mp3') -and
        $layoutPreviewText.Contains('swap at 7.2 s') -and
        $layoutPreviewText.Contains('swap at 7.3 s') -and
        $layoutPreviewText.Contains('supervisor_ping') -and
        $layoutPreviewText.Contains('seven_boxes_assemble') -and
        $layoutPreviewText.Contains('professional_warning') -and
        $layoutPreviewText.Contains('boxes_erased')
    ) 'previews document the two timed redness-format changeover states with transcript micro-event rails'
    Add-Check 'layout preview shows final end-confirmation branch' (
        $layoutPreviewText.Contains('Draw-FinalEndQuestionnairePreview') -and
        $layoutPreviewText.Contains('final-end-questionnaire-preview.png') -and
        $layoutPreviewText.Contains('How sure are you that you want to end the experiment,') -and
        $layoutPreviewText.Contains('on a scale of 1 to 10?') -and
        $layoutPreviewText.Contains('red floating question; only Likert boxes below') -and
        $layoutPreviewText.Contains("if you don't feel like doing any more button presses") -and
        $layoutPreviewText.Contains('Draw-FinalExtraPressChallengePreview') -and
        $layoutPreviewText.Contains('final-extra-press-challenge-preview.png') -and
        $layoutPreviewText.Contains('That is fantastic! I will take your non-decimal response as a big red YES!') -and
        $layoutPreviewText.Contains('text visible, audio plays, 3D button hidden') -and
        $layoutPreviewText.Contains('after 46.1 s: prompt disappears; only counter remains above the 3D button') -and
        $layoutPreviewText.Contains('0000 / 1000') -and
        $layoutPreviewText.Contains('PRESSES OUT OF 1,000')
    ) 'previews document the final 10-point end question and the transparent 1000 extra-press counter branch'
}

if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot 'build-apk.ps1')
    Add-Check 'debug APK built' (Test-Path (Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk')) 'app\build\outputs\apk\debug\app-debug.apk'
}

$failed = @($checks | Where-Object { -not $_.passed })
$outRoot = Join-Path $projectRoot 'artifacts\local-validation'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$summaryPath = Join-Path $outRoot ("validation-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
$summary = [pscustomobject]@{
    projectRoot = $projectRoot
    generatedAt = (Get-Date).ToString('o')
    status = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
    checks = $checks
}
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Host "Validation summary: $summaryPath"

if ($failed.Count -gt 0) {
    throw "Validation failed: $($failed.Count) check(s) failed."
}
