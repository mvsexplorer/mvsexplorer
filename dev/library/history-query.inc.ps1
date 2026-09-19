$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$Mode = [string]$env:mvsh_mode
$ArchiveRootArgument = [string]$env:mvsh_archive_root
$OutputRootArgument = [string]$env:mvsh_output_root
$Caller = [string]$env:mvsh_caller
$ScriptRoot = [string]$env:mvsh_script_root
$Version = [string]$env:mvsh_version

$Domains = @(
@@DOMAIN_ROWS@@
)

$SourceFiles = @(
@@SOURCE_ROWS@@
)

function Write-Line {
    param([AllowEmptyString()][string]$Text)
    [Console]::Out.WriteLine($Text)
}

function Write-Err {
    param([string]$Text)
    [Console]::Error.WriteLine($Text)
}

function Fail {
    param([int]$Code, [string]$Message)
    Write-Err ('ERROR: ' + $Message)
    [Environment]::Exit($Code)
}

function Show-Usage {
    Write-Line ('MVS Explorer Toolkit archive history builder ' + $Version)
    Write-Line ('Usage: ' + $Caller + ' mvs-dumps-root output-folder')
    if ($Mode -eq 'history') {
        Write-Line 'Creates added\ and removed\ TSV ledgers for every comparison domain.'
        Write-Line 'Each row identifies the adjacent from/to dump transition and value.'
        Write-Line 'Missing source files are recorded as coverage gaps, not empty sets.'
    } elseif ($Mode -eq 'all_ever') {
        Write-Line 'Creates all-ever\ TSV unions for every comparison domain.'
        Write-Line 'Values are never removed; first/last observation and observation count are retained.'
    }
}

function Resolve-ArchiveRoot {
    param([string]$Name, [string]$Root)
    $candidates = New-Object System.Collections.ArrayList
    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        [void]$candidates.Add($Name)
        [void]$candidates.Add((Join-Path (Get-Location).Path $Name))
        if (-not [string]::IsNullOrWhiteSpace($env:MVS_DUMPS_ROOT)) {
            [void]$candidates.Add((Join-Path $env:MVS_DUMPS_ROOT $Name))
        }
        if (-not [string]::IsNullOrWhiteSpace($Root)) {
            [void]$candidates.Add((Join-Path $Root $Name))
            $parent = Split-Path -Parent $Root
            if (-not [string]::IsNullOrWhiteSpace($parent)) {
                [void]$candidates.Add((Join-Path $parent $Name))
            }
        }
    }

    foreach ($candidate in $candidates) {
        try {
            if (-not (Test-Path -LiteralPath $candidate -PathType Container)) { continue }
            $resolved = (Resolve-Path -LiteralPath $candidate).Path
            $direct = @(Get-ChildItem -LiteralPath $resolved -Directory -ErrorAction Stop |
                Where-Object { $_.Name -match '^mvs_\d{4}-\d{2}-\d{2}(?:-\d{4})?(?:_\d+)?$' })
            if ($direct.Count -gt 0) { return $resolved }

            $wrapper = Join-Path $resolved 'mvs_dumps_archive'
            if (Test-Path -LiteralPath $wrapper -PathType Container) {
                $wrapped = @(Get-ChildItem -LiteralPath $wrapper -Directory -ErrorAction Stop |
                    Where-Object { $_.Name -match '^mvs_\d{4}-\d{2}-\d{2}(?:-\d{4})?(?:_\d+)?$' })
                if ($wrapped.Count -gt 0) {
                    return (Resolve-Path -LiteralPath $wrapper).Path
                }
            }
        } catch {
        }
    }
    return $null
}

function Resolve-OutputRoot {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    $path = $Name
    if (-not [IO.Path]::IsPathRooted($path)) {
        $path = Join-Path (Get-Location).Path $path
    }
    $full = [IO.Path]::GetFullPath($path)
    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $full -Force)
    }
    return (Resolve-Path -LiteralPath $full).Path
}

function Get-Snapshots {
    param([string]$Root)
    $items = New-Object System.Collections.ArrayList
    foreach ($dir in @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction Stop)) {
        if ($dir.Name -notmatch '^mvs_(?<date>\d{4}-\d{2}-\d{2})(?:-(?<time>\d{4}))?(?:_(?<revision>\d+))?$') {
            continue
        }
        $dateKey = $Matches.date.Replace('-', '')
        $timeKey = if ([string]::IsNullOrWhiteSpace([string]$Matches.time)) { '0000' } else { [string]$Matches.time }
        $revision = 0
        if (-not [string]::IsNullOrWhiteSpace([string]$Matches.revision)) {
            $revision = [int]$Matches.revision
        }
        $sortKey = $dateKey + $timeKey + $revision.ToString('D8') + '|' + $dir.Name.ToLowerInvariant()
        [void]$items.Add([pscustomobject]@{
            name = $dir.Name
            path = $dir.FullName
            sort_key = $sortKey
        })
    }
    return @($items | Sort-Object sort_key, name)
}

function Normalize-Title {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    $decoded = [System.Net.WebUtility]::HtmlDecode($Value)
    return ([regex]::Replace($decoded, '\s+', ' ')).Trim()
}

function Normalize-Id {
    param([AllowNull()][AllowEmptyString()][string]$Value, [string]$IdMode)
    if ($null -eq $Value) { return '' }
    $text = $Value.Trim()
    if ($IdMode -eq 'numeric' -and $text -match '^\d+$') {
        $text = [regex]::Replace($text, '^0+(?=\d)', '')
    }
    return $text
}

function Get-Key {
    param([AllowNull()][AllowEmptyString()][string]$Value, [string]$Kind, [string]$IdMode)
    if ($null -eq $Value) { return '' }
    switch ($Kind) {
        'id'       { return (Normalize-Id $Value $IdMode).ToLowerInvariant() }
        'title'    { return (Normalize-Title $Value).ToLowerInvariant() }
        'date'     { return $Value.Trim() }
        'sha1'     { return $Value.Trim().ToLowerInvariant() }
        'sha256'   { return $Value.Trim().ToLowerInvariant() }
        'filename' { return $Value.Trim().ToLowerInvariant() }
        default    { return $Value.Trim().ToLowerInvariant() }
    }
}

function Get-DisplayValue {
    param([AllowNull()][AllowEmptyString()][string]$Value, [string]$Kind, [string]$IdMode)
    if ($null -eq $Value) { return '' }
    switch ($Kind) {
        'id'       { return Normalize-Id $Value $IdMode }
        'title'    { return Normalize-Title $Value }
        'date'     { return $Value.Trim() }
        'sha1'     { return $Value.Trim().ToLowerInvariant() }
        'sha256'   { return $Value.Trim().ToLowerInvariant() }
        'filename' { return $Value.Trim() }
        default    { return $Value.Trim() }
    }
}

function New-ValueSet {
    $rows = New-Object System.Collections.ArrayList
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    return [pscustomobject]@{
        rows = $rows
        seen = $seen
    }
}

function New-SourceModel {
    $sets = @{}
    foreach ($kind in @('id','title','date','sha1','sha256','filename')) {
        $sets[$kind] = New-ValueSet
    }
    return [pscustomobject]@{ sets = $sets }
}

function Add-ModelValue {
    param(
        [object]$Model,
        [string]$Kind,
        [AllowNull()][AllowEmptyString()][string]$Value,
        [string]$IdMode
    )
    $display = Get-DisplayValue $Value $Kind $IdMode
    if ([string]::IsNullOrWhiteSpace($display)) { return }
    $key = Get-Key $display $Kind $IdMode
    $set = $Model.sets[$Kind]
    if ($set.seen.Add($key)) {
        [void]$set.rows.Add([pscustomobject]@{ key=$key; value=$display })
    }
}

function Read-SourceModel {
    param([string]$Path, [string]$Name)

    $model = New-SourceModel
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)

    if ($Name -eq 'mvs_ids.txt') {
        foreach ($lineValue in $lines) {
            $line = [string]$lineValue
            if ($line -match '^(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') {
                Add-ModelValue $model 'id' $Matches.id 'numeric'
                Add-ModelValue $model 'title' $Matches.title ''
            }
        }
        return $model
    }

    if ($Name -eq 'mvs_dates.txt') {
        foreach ($lineValue in $lines) {
            $line = [string]$lineValue
            if ($line -match '^(?<date>.*?)\s+-\s+(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') {
                Add-ModelValue $model 'id' $Matches.id 'numeric'
                Add-ModelValue $model 'title' $Matches.title ''
                Add-ModelValue $model 'date' $Matches.date ''
            }
        }
        return $model
    }

    if ($Name -eq 'mvs.sha1' -or $Name -eq 'mvs.sha256') {
        $hashLength = if ($Name -eq 'mvs.sha1') { 40 } else { 64 }
        foreach ($lineValue in $lines) {
            $line = [string]$lineValue
            $pattern = '^\s*(?<hash>[0-9A-Fa-f]{' + $hashLength + '})\s+\*(?<filename>.+?)\s*$'
            if ($line -match $pattern) {
                $kind = if ($hashLength -eq 40) { 'sha1' } else { 'sha256' }
                Add-ModelValue $model $kind $Matches.hash ''
                Add-ModelValue $model 'filename' $Matches.filename ''
            }
        }
        return $model
    }

    if ($Name -eq 'mvs.txt' -or $Name -eq 'mvs_names.txt') {
        $inside = $false
        $idMode = if ($Name -eq 'mvs_names.txt') { 'text' } else { 'numeric' }

        foreach ($lineValue in $lines) {
            $line = [string]$lineValue
            $headerMatched = $false

            if ($Name -eq 'mvs_names.txt') {
                if ($line -match '^---\s*(?<title>.*?)\s*\[ID:\s*(?<id>[^\]]+?)\s*\]\s*---\s*$') {
                    $headerMatched = $true
                }
            } else {
                if ($line -match '^---\s*(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*---\s*$') {
                    $headerMatched = $true
                }
            }

            if ($headerMatched) {
                $inside = $true
                Add-ModelValue $model 'id' $Matches.id $idMode
                Add-ModelValue $model 'title' $Matches.title ''
                continue
            }

            if ([string]::IsNullOrWhiteSpace($line)) {
                $inside = $false
                continue
            }
            if (-not $inside) { continue }

            if ($line -match '^\s*(?<hash>[0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})\s+\*(?<filename>.+?)\s*$') {
                $hash = [string]$Matches.hash
                Add-ModelValue $model 'filename' $Matches.filename ''
                if ($hash.Length -eq 40) {
                    Add-ModelValue $model 'sha1' $hash ''
                } elseif ($hash.Length -eq 64) {
                    Add-ModelValue $model 'sha256' $hash ''
                }
            }
        }
        return $model
    }

    throw ('Unsupported source file: ' + $Name)
}

function Get-SnapshotSourcePath {
    param([object]$Snapshot, [string]$SourceFile)

    $direct = Join-Path ([string]$Snapshot.path) $SourceFile
    if (Test-Path -LiteralPath $direct -PathType Leaf) {
        return $direct
    }

    $nestedRoot = Join-Path ([string]$Snapshot.path) 'mvs_dmp'
    $nested = Join-Path $nestedRoot $SourceFile
    if (Test-Path -LiteralPath $nested -PathType Leaf) {
        return $nested
    }

    return $null
}

$script:SourceCache = @{}

function Get-CachedSourceModel {
    param([object]$Snapshot, [string]$SourceFile)
    $cacheKey = [string]$Snapshot.path + '|' + $SourceFile
    if ($script:SourceCache.ContainsKey($cacheKey)) {
        return $script:SourceCache[$cacheKey]
    }

    $path = Get-SnapshotSourcePath $Snapshot $SourceFile
    if ($null -eq $path) {
        return $null
    }

    $model = Read-SourceModel $path $SourceFile
    $script:SourceCache[$cacheKey] = $model
    return $model
}

function New-OrdinalSet {
    return ,(New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal))
}

function New-OrdinalDictionary {
    return ,(New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal))
}

function Convert-TsvField {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    return $Value.Replace("`t", ' ').Replace("`r", ' ').Replace("`n", ' ')
}

function Write-Table {
    param(
        [string]$Path,
        [string[]]$Columns,
        [object[]]$Rows
    )
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append(($Columns -join [char]9))
    [void]$builder.Append([Environment]::NewLine)
    foreach ($row in @($Rows)) {
        $values = New-Object System.Collections.ArrayList
        foreach ($column in $Columns) {
            [void]$values.Add((Convert-TsvField ([string]$row.$column)))
        }
        [void]$builder.Append((@($values) -join [char]9))
        [void]$builder.Append([Environment]::NewLine)
    }
    [IO.File]::WriteAllText($Path, $builder.ToString(), $utf8)
}

function Reset-Directory {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    [void](New-Item -ItemType Directory -Path $Path -Force)
}

function Write-SnapshotTable {
    param([string]$Path, [object[]]$Snapshots)
    $rows = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $Snapshots.Count; $i++) {
        [void]$rows.Add([pscustomobject]@{
            index = [string]($i + 1)
            dump = [string]$Snapshots[$i].name
        })
    }
    Write-Table $Path @('index','dump') @($rows)
}

function Build-History {
    param([string]$OutputRoot, [object[]]$Snapshots)

    $addedRoot = Join-Path $OutputRoot 'added'
    $removedRoot = Join-Path $OutputRoot 'removed'
    Reset-Directory $addedRoot
    Reset-Directory $removedRoot

    $added = @{}
    $removed = @{}
    foreach ($domain in $Domains) {
        $added[[string]$domain.name] = New-Object System.Collections.ArrayList
        $removed[[string]$domain.name] = New-Object System.Collections.ArrayList
    }

    $coverage = New-Object System.Collections.ArrayList
    $addedCount = 0
    $removedCount = 0

    for ($i = 0; $i -lt ($Snapshots.Count - 1); $i++) {
        $first = $Snapshots[$i]
        $second = $Snapshots[$i + 1]

        foreach ($sourceFile in $SourceFiles) {
            $firstPresent = $null -ne (Get-SnapshotSourcePath $first $sourceFile)
            $secondPresent = $null -ne (Get-SnapshotSourcePath $second $sourceFile)
            $status = if ($firstPresent -and $secondPresent) {
                'compared'
            } elseif ($firstPresent) {
                'missing-second'
            } elseif ($secondPresent) {
                'missing-first'
            } else {
                'missing-both'
            }
            [void]$coverage.Add([pscustomobject]@{
                from_dump = [string]$first.name
                to_dump = [string]$second.name
                source_file = [string]$sourceFile
                status = $status
            })
        }

        foreach ($domain in $Domains) {
            $firstModel = Get-CachedSourceModel $first ([string]$domain.source_file)
            $secondModel = Get-CachedSourceModel $second ([string]$domain.source_file)
            if ($null -eq $firstModel -or $null -eq $secondModel) {
                continue
            }

            $firstRows = @($firstModel.sets[[string]$domain.property].rows)
            $secondRows = @($secondModel.sets[[string]$domain.property].rows)
            $firstKeys = New-OrdinalSet
            $secondKeys = New-OrdinalSet
            foreach ($row in $firstRows) { [void]$firstKeys.Add([string]$row.key) }
            foreach ($row in $secondRows) { [void]$secondKeys.Add([string]$row.key) }

            foreach ($row in $firstRows) {
                if (-not $secondKeys.Contains([string]$row.key)) {
                    [void]$removed[[string]$domain.name].Add([pscustomobject]@{
                        from_dump = [string]$first.name
                        to_dump = [string]$second.name
                        value = [string]$row.value
                    })
                    $removedCount++
                }
            }

            foreach ($row in $secondRows) {
                if (-not $firstKeys.Contains([string]$row.key)) {
                    [void]$added[[string]$domain.name].Add([pscustomobject]@{
                        from_dump = [string]$first.name
                        to_dump = [string]$second.name
                        value = [string]$row.value
                    })
                    $addedCount++
                }
            }
        }
    }

    foreach ($domain in $Domains) {
        $name = [string]$domain.name + '.tsv'
        Write-Table (Join-Path $addedRoot $name) @('from_dump','to_dump','value') @($added[[string]$domain.name])
        Write-Table (Join-Path $removedRoot $name) @('from_dump','to_dump','value') @($removed[[string]$domain.name])
    }

    Write-SnapshotTable (Join-Path $OutputRoot 'history-snapshots.tsv') $Snapshots
    Write-Table (Join-Path $OutputRoot 'history-coverage.tsv') @('from_dump','to_dump','source_file','status') @($coverage)

    Write-Line ('History complete: ' + $Snapshots.Count + ' snapshots, ' + ($Snapshots.Count - 1) + ' transitions, ' + $Domains.Count + ' domains.')
    Write-Line ('Added records: ' + $addedCount)
    Write-Line ('Removed records: ' + $removedCount)
    Write-Line ('Output: ' + $OutputRoot)
}

function Build-AllEver {
    param([string]$OutputRoot, [object[]]$Snapshots)

    $allRoot = Join-Path $OutputRoot 'all-ever'
    Reset-Directory $allRoot

    $unions = @{}
    foreach ($domain in $Domains) {
        $unions[[string]$domain.name] = [pscustomobject]@{
            map = New-OrdinalDictionary
            rows = New-Object System.Collections.ArrayList
        }
    }

    $coverage = New-Object System.Collections.ArrayList

    foreach ($snapshot in $Snapshots) {
        foreach ($sourceFile in $SourceFiles) {
            $present = $null -ne (Get-SnapshotSourcePath $snapshot $sourceFile)
            [void]$coverage.Add([pscustomobject]@{
                dump = [string]$snapshot.name
                source_file = [string]$sourceFile
                present = if ($present) { '1' } else { '0' }
            })
        }

        foreach ($domain in $Domains) {
            $model = Get-CachedSourceModel $snapshot ([string]$domain.source_file)
            if ($null -eq $model) { continue }

            $union = $unions[[string]$domain.name]
            $dictionary = $union.map
            foreach ($row in @($model.sets[[string]$domain.property].rows)) {
                $key = [string]$row.key
                if (-not $dictionary.ContainsKey($key)) {
                    $entry = [pscustomobject]@{
                        first_seen_dump = [string]$snapshot.name
                        last_seen_dump = [string]$snapshot.name
                        observed_snapshots = 1
                        value = [string]$row.value
                    }
                    $dictionary.Add($key, $entry)
                    [void]$union.rows.Add($entry)
                } else {
                    $entry = $dictionary[$key]
                    $entry.last_seen_dump = [string]$snapshot.name
                    $entry.observed_snapshots = [int]$entry.observed_snapshots + 1
                }
            }
        }
    }

    $total = 0
    foreach ($domain in $Domains) {
        $union = $unions[[string]$domain.name]
        $rows = @($union.rows)
        $total += $rows.Count
        Write-Table (Join-Path $allRoot ([string]$domain.name + '.tsv')) @('first_seen_dump','last_seen_dump','observed_snapshots','value') $rows
    }

    Write-SnapshotTable (Join-Path $OutputRoot 'all-ever-snapshots.tsv') $Snapshots
    Write-Table (Join-Path $OutputRoot 'all-ever-coverage.tsv') @('dump','source_file','present') @($coverage)

    Write-Line ('All-ever complete: ' + $Snapshots.Count + ' snapshots, ' + $Domains.Count + ' domains.')
    Write-Line ('Unique source-local records: ' + $total)
    Write-Line ('Output: ' + $OutputRoot)
}

if ([string]::IsNullOrWhiteSpace($ArchiveRootArgument) -or (@('--help','-h','-?','/h','/?') -contains $ArchiveRootArgument)) {
    Show-Usage
    exit 0
}

if ([string]::IsNullOrWhiteSpace($OutputRootArgument)) {
    Write-Err 'ERROR: Missing output-folder.'
    Show-Usage
    [Environment]::Exit(2)
}

if (@('history','all_ever') -notcontains $Mode) {
    Fail 2 ('Unsupported history mode: ' + $Mode)
}

$ArchiveRoot = Resolve-ArchiveRoot $ArchiveRootArgument $ScriptRoot
if ($null -eq $ArchiveRoot) {
    Fail 3 ('MVS dumps root not found or contains no recognized snapshot folders: ' + $ArchiveRootArgument)
}

try {
    $Snapshots = @(Get-Snapshots $ArchiveRoot)
    $minimum = if ($Mode -eq 'history') { 2 } else { 1 }
    if ($Snapshots.Count -lt $minimum) {
        Fail 4 ('Insufficient recognized snapshots: found ' + $Snapshots.Count + ', need ' + $minimum)
    }

    $OutputRoot = Resolve-OutputRoot $OutputRootArgument
    if ($null -eq $OutputRoot) {
        Fail 2 'Invalid output-folder.'
    }

    if ($Mode -eq 'history') {
        Build-History $OutputRoot $Snapshots
    } else {
        Build-AllEver $OutputRoot $Snapshots
    }
    exit 0
} catch {
    Fail 5 $_.Exception.Message
}
