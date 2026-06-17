Set-StrictMode -Version Latest

function ConvertTo-BrbRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $base = [IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/')
    $target = [IO.Path]::GetFullPath($Path)
    if ($target.Length -le $base.Length) {
        return ''
    }
    return $target.Substring($base.Length).TrimStart('\', '/') -replace '\\', '/'
}

function Resolve-BrbExportSession {
    param([Parameter(Mandatory = $true)][string]$ExportDir)

    $resolved = (Resolve-Path -LiteralPath $ExportDir).Path
    $manifestAtPath = Join-Path $resolved 'session-manifest.json'
    if (Test-Path -LiteralPath $manifestAtPath) {
        $rootDir = Split-Path -Parent $resolved
        return [pscustomobject]@{
            RootDir = $rootDir
            SessionDir = $resolved
            SessionFolder = Split-Path -Leaf $resolved
            ManifestPath = $manifestAtPath
            IndexPath = Join-Path $rootDir 'session-index.jsonl'
            Source = 'session-folder'
        }
    }

    $indexPath = Join-Path $resolved 'session-index.jsonl'
    if (Test-Path -LiteralPath $indexPath) {
        $lines = @(Get-Content -LiteralPath $indexPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        for ($i = $lines.Count - 1; $i -ge 0; $i -= 1) {
            try {
                $row = $lines[$i] | ConvertFrom-Json
            } catch {
                continue
            }
            $sessionFolder = "$($row.sessionFolder)"
            if ([string]::IsNullOrWhiteSpace($sessionFolder)) {
                continue
            }
            $sessionDir = Join-Path $resolved $sessionFolder
            $manifestPath = Join-Path $sessionDir 'session-manifest.json'
            if (Test-Path -LiteralPath $manifestPath) {
                return [pscustomobject]@{
                    RootDir = $resolved
                    SessionDir = (Resolve-Path -LiteralPath $sessionDir).Path
                    SessionFolder = $sessionFolder
                    ManifestPath = $manifestPath
                    IndexPath = $indexPath
                    Source = 'session-index'
                }
            }
        }
        throw "No valid session folder referenced by $indexPath"
    }

    $sessionDirs =
        @(Get-ChildItem -LiteralPath $resolved -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'session-manifest.json') } |
            Sort-Object LastWriteTime -Descending)
    if ($sessionDirs.Count -gt 0) {
        $session = $sessionDirs[0]
        return [pscustomobject]@{
            RootDir = $resolved
            SessionDir = $session.FullName
            SessionFolder = $session.Name
            ManifestPath = Join-Path $session.FullName 'session-manifest.json'
            IndexPath = $indexPath
            Source = 'latest-manifest-folder'
        }
    }

    return [pscustomobject]@{
        RootDir = $resolved
        SessionDir = $resolved
        SessionFolder = ''
        ManifestPath = ''
        IndexPath = $indexPath
        Source = 'legacy-flat-root'
    }
}

function Get-BrbExportSessionFile {
    param(
        [Parameter(Mandatory = $true)][string]$SessionDir,
        [Parameter(Mandatory = $true)][string]$Filter
    )
    return Get-ChildItem -LiteralPath $SessionDir -Filter $Filter -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Get-BrbRecursiveFileRows {
    param([Parameter(Mandatory = $true)][string]$RootDir)
    $root = (Resolve-Path -LiteralPath $RootDir).Path
    return @(Get-ChildItem -LiteralPath $root -File -Recurse |
        ForEach-Object {
            [pscustomobject]@{
                RelativePath = ConvertTo-BrbRelativePath -BasePath $root -Path $_.FullName
                File = $_
            }
        } |
        Sort-Object RelativePath)
}

function Get-BrbShortExportFileName {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [string]$Prefix = 'brb_first_study_session'
    )
    if ($FileName -in @('session-index.jsonl', 'session-manifest.json')) {
        return $FileName
    }
    $knownSuffixes = @(
        '_summary.csv',
        '_press_events.csv',
        '_ecg_blink_events.csv',
        '_ecg_detector_events.csv',
        '_ecg_timeseries.csv',
        '_external_signal_samples.csv',
        '_final_extra_button_presses.csv',
        '_polar_rr_events.csv'
    )
    foreach ($suffix in $knownSuffixes) {
        if ($FileName.EndsWith($suffix, [StringComparison]::OrdinalIgnoreCase)) {
            return "$Prefix$suffix"
        }
    }
    if ($FileName -match '^brb_first_study_.*\.json$') {
        return "$Prefix.json"
    }
    return $FileName
}

function Update-BrbPulledExportMetadata {
    param(
        [Parameter(Mandatory = $true)][string]$LocalDir,
        [Parameter(Mandatory = $true)][hashtable]$PathMap
    )
    $indexPath = Join-Path $LocalDir 'session-index.jsonl'
    if (Test-Path -LiteralPath $indexPath) {
        $indexRows = @(
            Get-Content -LiteralPath $indexPath |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                ForEach-Object {
                    $row = $_ | ConvertFrom-Json
                    foreach ($propertyName in @(
                        'manifest',
                        'json',
                        'summaryCsv',
                        'pressEventsCsv',
                        'finalExtraButtonPressesCsv',
                        'ecgBlinkEventsCsv',
                        'polarRrEventsCsv',
                        'ecgTimeSeriesCsv',
                        'ecgDetectorEventsCsv',
                        'externalSignalSamplesCsv'
                    )) {
                        if ($row.PSObject.Properties.Name -contains $propertyName) {
                            $oldValue = "$($row.$propertyName)"
                            if ($PathMap.ContainsKey($oldValue)) {
                                $row.$propertyName = $PathMap[$oldValue]
                            }
                        }
                    }
                    $row | ConvertTo-Json -Compress
                }
        )
        $indexRows | Set-Content -LiteralPath $indexPath -Encoding UTF8
    }

    $manifestFiles = @(Get-ChildItem -LiteralPath $LocalDir -Filter 'session-manifest.json' -File -Recurse)
    foreach ($manifestFile in $manifestFiles) {
        $manifest = Get-Content -Raw -LiteralPath $manifestFile.FullName | ConvertFrom-Json
        $folder = "$($manifest.sessionFolder)"
        if ([string]::IsNullOrWhiteSpace($folder)) {
            $folder = Split-Path -Leaf (Split-Path -Parent $manifestFile.FullName)
        }
        $updatedFiles =
            @($manifest.files | ForEach-Object {
                $fileName = "$_"
                $oldRelative = "$folder/$fileName"
                if ($PathMap.ContainsKey($oldRelative)) {
                    Split-Path -Leaf $PathMap[$oldRelative]
                } else {
                    $fileName
                }
            })
        $manifest.files = $updatedFiles
        $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestFile.FullName -Encoding UTF8
    }
}
