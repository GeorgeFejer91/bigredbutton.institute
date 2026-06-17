[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$studyRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repoRoot = (Resolve-Path (Join-Path $studyRoot '..\..')).Path
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
}

function Test-FileHash {
    param(
        [string]$RelativePath,
        [string]$ExpectedHash
    )
    $path = Join-Path $studyRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        Add-Check "hash $RelativePath" $false 'missing'
        return
    }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    Add-Check "hash $RelativePath" ($hash -eq $ExpectedHash) $hash
}

$nativeDir = Join-Path $studyRoot 'native-quest-mr-study'
$unityDir = Join-Path $studyRoot 'unity-mesmerprism-latest'
$sharedDir = Join-Path $studyRoot 'shared-library'
$audioDir = Join-Path $studyRoot 'audio-assets'
$readme = Join-Path $studyRoot 'README.md'

Add-Check 'native project folder exists' (Test-Path -LiteralPath $nativeDir) $nativeDir
Add-Check 'unity subtree folder exists' (Test-Path -LiteralPath $unityDir) $unityDir
Add-Check 'shared library folder exists' (Test-Path -LiteralPath $sharedDir) $sharedDir
Add-Check 'audio assets folder exists' (Test-Path -LiteralPath $audioDir) $audioDir
Add-Check 'study README exists' (Test-Path -LiteralPath $readme) $readme

foreach ($relative in @(
    'unity-mesmerprism-latest\Assets',
    'unity-mesmerprism-latest\Packages',
    'unity-mesmerprism-latest\ProjectSettings',
    'unity-mesmerprism-latest\README.md',
    'unity-mesmerprism-latest\LICENSE',
    'unity-mesmerprism-latest\THIRD_PARTY_NOTICES.md',
    'unity-mesmerprism-latest\.gitignore'
)) {
    $path = Join-Path $studyRoot $relative
    Add-Check "unity subtree includes $relative" (Test-Path -LiteralPath $path) $relative
}

foreach ($relative in @(
    'shared-library\README.md',
    'shared-library\button-assets.md',
    'shared-library\language-and-tts.md',
    'shared-library\research-and-for-ai.md',
    'shared-library\versioning.md'
)) {
    $path = Join-Path $studyRoot $relative
    Add-Check "shared-library doc $relative" (Test-Path -LiteralPath $path) $relative
}

Test-FileHash 'native-quest-mr-study\app\src\main\assets\models\BigRedButton.glb' '4BA2C479EAE6A103ADCE0B7D0AB70C94A5F21A12435DD90ACD0071F66EF5F52B'
Test-FileHash 'unity-mesmerprism-latest\Assets\Models\BigRedButton.glb' '5B0E13AC4854C8E508BA7EAD8807E7D655EDB169F88FE39A16AFD2BCD4EE8887'
Test-FileHash 'unity-mesmerprism-latest\Assets\StreamingAssets\Models\BigRedButton.glb' '5B0E13AC4854C8E508BA7EAD8807E7D655EDB169F88FE39A16AFD2BCD4EE8887'

$buttonAssetsText = Get-Content -Raw -LiteralPath (Join-Path $sharedDir 'button-assets.md')
$versioningText = Get-Content -Raw -LiteralPath (Join-Path $sharedDir 'versioning.md')
$languageText = Get-Content -Raw -LiteralPath (Join-Path $sharedDir 'language-and-tts.md')
$researchText = Get-Content -Raw -LiteralPath (Join-Path $sharedDir 'research-and-for-ai.md')
$readmeText = Get-Content -Raw -LiteralPath $readme

Add-Check 'README links project families' (
    $readmeText.Contains('native-quest-mr-study') -and
    $readmeText.Contains('unity-mesmerprism-latest') -and
    $readmeText.Contains('shared-library')
) 'native, unity, shared-library'

Add-Check 'button catalogue records MesmerPrism ref and license' (
    $buttonAssetsText.Contains('f94aa66') -and
    $buttonAssetsText.Contains('codex/brb-rusty-morphospace-manifold-example') -and
    $buttonAssetsText.Contains('CC BY 3.0') -and
    $buttonAssetsText.Contains('https://poly.pizza/m/lTyNXwkDgX')
) 'MesmerPrism ref, Poly Pizza source, CC BY attribution'

Add-Check 'button catalogue records native and unity hashes' (
    $buttonAssetsText.Contains('4BA2C479EAE6A103ADCE0B7D0AB70C94A5F21A12435DD90ACD0071F66EF5F52B') -and
    $buttonAssetsText.Contains('5B0E13AC4854C8E508BA7EAD8807E7D655EDB169F88FE39A16AFD2BCD4EE8887')
) 'native and Unity model hashes'

Add-Check 'versioning doc records subtree update command' (
    $versioningText.Contains('git subtree pull --prefix=studies/first-big-red-button-study/unity-mesmerprism-latest') -and
    $versioningText.Contains('mesmerprism-unity') -and
    $versioningText.Contains('f94aa66')
) 'subtree pull command and imported commit'

Add-Check 'language doc preserves trilingual validation command' (
    $languageText.Contains('validate-localized-audio.ps1 -RequireJapaneseAudio -RequireGermanAudio') -and
    $languageText.Contains('de_de') -and
    $languageText.Contains('ja_jp') -and
    $languageText.Contains('en_us')
) 'English, German, Japanese validation'

Add-Check 'research doc preserves contact proof boundaries' (
    $researchText.Contains('controller_contact') -and
    $researchText.Contains('hand_contact') -and
    $researchText.Contains('Predictive preload alone must not count')
) 'controller proof, supplemental hand contact, preload boundary'

$generatedFolders = @(
    'unity-mesmerprism-latest\Library',
    'unity-mesmerprism-latest\Temp',
    'unity-mesmerprism-latest\Obj',
    'unity-mesmerprism-latest\Build',
    'unity-mesmerprism-latest\Builds',
    'unity-mesmerprism-latest\Logs',
    'unity-mesmerprism-latest\UserSettings'
)
$presentGenerated = @()
foreach ($relative in $generatedFolders) {
    if (Test-Path -LiteralPath (Join-Path $studyRoot $relative)) {
        $presentGenerated += $relative
    }
}
Add-Check 'Unity generated folders absent from imported subtree' ($presentGenerated.Count -eq 0) ($presentGenerated -join ',')

$trackedGenerated = @()
try {
    $trackedGenerated = @(
        git -C $repoRoot ls-files |
            Where-Object {
                $_ -match '\.apk$|\.aab$|/Library/|/Temp/|/Obj/|/Builds/|/Logs/|native-quest-mr-study/app/build/|native-quest-mr-study/artifacts/'
            }
    )
} catch {
    $trackedGenerated = @("git ls-files failed: $($_.Exception.Message)")
}
Add-Check 'generated outputs are not tracked' ($trackedGenerated.Count -eq 0) ($trackedGenerated -join ',')

$outDir = Join-Path $studyRoot 'native-quest-mr-study\artifacts\project-library-validation'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$summaryPath = Join-Path $outDir ("project-library-validation-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
$failed = @($checks | Where-Object { -not $_.passed })
$summary = [pscustomobject]@{
    status = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
    generatedAt = (Get-Date).ToString('o')
    studyRoot = $studyRoot
    checks = @($checks.ToArray())
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$checks | Format-Table name, passed, detail -AutoSize | Out-Host
Write-Host "Project library validation summary: $summaryPath"

if ($failed.Count -gt 0) {
    throw "Project library validation failed: $($failed.Count) check(s) failed."
}
