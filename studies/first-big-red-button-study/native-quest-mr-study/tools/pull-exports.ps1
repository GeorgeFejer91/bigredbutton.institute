[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$OutDir = '',
    [string]$AdbPath = 'adb'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $projectRoot ('artifacts\exports\p-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$package = 'org.bigredbutton.firststudy'
$deviceRoots = @(
    @{ DeviceDir = "/sdcard/Android/data/$package/files/BigRedButtonFirstStudyExports"; LocalName = 'BigRedButtonFirstStudyExports' },
    @{ DeviceDir = "/sdcard/Android/data/$package/files/ExperimentResults"; LocalName = 'ExperimentResults' }
)

$shortPullRoot = Join-Path $env:TEMP ('brb-export-pull-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
if (Test-Path $shortPullRoot) {
    Remove-Item -Recurse -Force -LiteralPath $shortPullRoot
}
New-Item -ItemType Directory -Force -Path $shortPullRoot | Out-Null
try {
    foreach ($root in $deviceRoots) {
        $deviceDir = $root.DeviceDir
        $localExportRoot = Join-Path $OutDir $root.LocalName
        New-Item -ItemType Directory -Force -Path $localExportRoot | Out-Null
        $deviceFilesRaw = & $AdbPath -s $Serial shell find $deviceDir -type f
        if ($LASTEXITCODE -ne 0) {
            throw "adb export listing failed. Confirm the experiment has completed and exports exist at $deviceDir"
        }
        $deviceFiles = @(
            $deviceFilesRaw |
                ForEach-Object { "$_".Trim() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch '^total\s+' }
        )
        if ($deviceFiles.Count -eq 0) {
            throw "No export files found at $deviceDir"
        }
        $fileIndex = 0
        foreach ($remoteFile in $deviceFiles) {
            $fileIndex += 1
            $shortLocalFile = Join-Path $shortPullRoot ("$($root.LocalName)-$fileIndex.tmp")
            $relative = "$remoteFile"
            if ($relative.StartsWith($deviceDir, [StringComparison]::Ordinal)) {
                $relative = $relative.Substring($deviceDir.Length).TrimStart('/')
            } else {
                $relative = Split-Path -Leaf $relative
            }
            $localFile = Join-Path $localExportRoot ($relative -replace '/', '\')
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $localFile) | Out-Null
            & $AdbPath -s $Serial pull $remoteFile $shortLocalFile | Out-Host
            if ($LASTEXITCODE -ne 0) {
                throw "adb export pull failed for $remoteFile with exit code $LASTEXITCODE"
            }
            Move-Item -LiteralPath $shortLocalFile -Destination $localFile -Force
        }
    }
} finally {
    if (Test-Path $shortPullRoot) {
        Remove-Item -Recurse -Force -LiteralPath $shortPullRoot
    }
}

Write-Host "Pulled exports to $OutDir"
