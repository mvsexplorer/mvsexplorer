$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$Operation = [string]$env:mvsd_operation
$Property = [string]$env:mvsd_property
$SourceName = [string]$env:mvsd_source
$TargetName = [string]$env:mvsd_target
$Dump = [string]$env:mvsd_dump
$Caller = [string]$env:mvsd_caller
$ScriptRoot = [string]$env:mvsd_script_root
$Version = [string]$env:mvsd_version

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
    Write-Line ('MVS Explorer Toolkit diagnostic tool ' + $Version)
    if ($Operation -eq 'duplicate') {
        Write-Line ('Usage: ' + $Caller + ' dump-folder')
        Write-Line ('Find duplicate ' + $Property + ' values in ' + $SourceName + '.')
    } else {
        Write-Line ('Usage: ' + $Caller + ' dump-folder')
        Write-Line ('Find ' + $Property + ' values in ' + $SourceName + ' not referenced by ' + $TargetName + '.')
    }
}

function Resolve-DumpFolder {
    param([string]$Name, [string]$Root)
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        $candidates += $Name
        $candidates += (Join-Path (Get-Location).Path $Name)
        if (-not [string]::IsNullOrWhiteSpace($env:MVS_DUMPS_ROOT)) {
            $candidates += (Join-Path $env:MVS_DUMPS_ROOT $Name)
        }
        if (-not [string]::IsNullOrWhiteSpace($Root)) {
            $candidates += (Join-Path $Root $Name)
            $candidates += (Join-Path (Join-Path $Root 'mvs_dumps_archive') $Name)
            $parent = Split-Path -Parent $Root
            if (-not [string]::IsNullOrWhiteSpace($parent)) {
                $candidates += (Join-Path (Join-Path $parent 'mvs_dumps_archive') $Name)
            }
        }
        $candidates += (Join-Path (Join-Path (Get-Location).Path 'mvs_dumps_archive') $Name)
    }
    foreach ($candidate in $candidates) {
        try {
            if (Test-Path -LiteralPath $candidate -PathType Container) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        } catch {
        }
    }
    return $null
}

function Normalize-Title {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    $decoded = [System.Net.WebUtility]::HtmlDecode($Value)
    return ([regex]::Replace($decoded, '\s+', ' ')).Trim()
}

function Convert-NoteHtmlToText {
    param([AllowNull()][AllowEmptyString()][string]$Html)
    if ([string]::IsNullOrEmpty($Html)) { return '' }
    $text = [regex]::Replace($Html, '(?is)<br\s*/?>', ' ')
    $text = [regex]::Replace($text, '(?is)</p\s*>', ' ')
    $text = [regex]::Replace($text, '(?is)</li\s*>', ' ')
    $text = [regex]::Replace($text, '(?is)</div\s*>', ' ')
    $text = [regex]::Replace($text, '(?is)<[^>]+>', ' ')
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    $text = $text.Replace([char]0x00A0, ' ')
    return ([regex]::Replace($text, '\s+', ' ')).Trim()
}

function New-DiagnosticRecord {
    param(
        [string]$Kind,
        [int]$Order,
        [string]$Id,
        [string]$Title,
        [string]$Date,
        [string[]]$RawLines,
        [object[]]$Files,
        [string]$Note
    )
    return [pscustomobject]@{
        kind = $Kind
        order = $Order
        id = $Id
        title = $Title
        date = $Date
        rawLines = @($RawLines)
        files = @($Files)
        note = $Note
    }
}

function Read-SectionRecords {
    param([string]$Path, [string]$Kind)
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
    $records = New-Object System.Collections.ArrayList
    $order = 0
    $i = 0
    while ($i -lt $lines.Count) {
        $line = [string]$lines[$i]
        if ($line -notmatch '^---\s*(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*---\s*$') {
            $i++
            continue
        }
        $order++
        $title = Normalize-Title $Matches.title
        $id = [string][int]$Matches.id
        $raw = New-Object System.Collections.ArrayList
        [void]$raw.Add($line)
        $files = New-Object System.Collections.ArrayList
        $i++
        while ($i -lt $lines.Count) {
            $next = [string]$lines[$i]
            if ([string]::IsNullOrWhiteSpace($next)) {
                $i++
                break
            }
            if ($next -match '^---\s*.*?\[ID:\s*\d+\]\s*---\s*$') {
                break
            }
            [void]$raw.Add($next)
            if ($next -match '^\s*\S+\s+\*(?<filename>.+?)\s*$') {
                [void]$files.Add([pscustomobject]@{
                    filename = $Matches.filename.Trim()
                    rawLine = $next
                })
            }
            $i++
        }
        [void]$records.Add((New-DiagnosticRecord $Kind $order $id $title '' @($raw) @($files) ''))
    }
    return @($records)
}

function Read-DiagnosticRecords {
    param([string]$Path, [string]$Name)
    $records = New-Object System.Collections.ArrayList
    $order = 0

    switch -Regex ($Name) {
        '^mvs_ids\.txt$' {
            foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
                if ($line -match '^(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') {
                    $order++
                    [void]$records.Add((New-DiagnosticRecord 'ids' $order ([string][int]$Matches.id) (Normalize-Title $Matches.title) '' @([string]$line) @() ''))
                }
            }
            break
        }
        '^mvs_dates\.txt$' {
            foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
                if ($line -match '^(?<date>.*?)\s+-\s+(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') {
                    $order++
                    [void]$records.Add((New-DiagnosticRecord 'dates' $order ([string][int]$Matches.id) (Normalize-Title $Matches.title) $Matches.date.Trim() @([string]$line) @() ''))
                }
            }
            break
        }
        '^mvs\.txt$' {
            return @(Read-SectionRecords $Path 'mvs')
        }
        '^mvs_names\.txt$' {
            return @(Read-SectionRecords $Path 'names')
        }
        '^mvs_notes\.html$' {
            $html = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
            foreach ($match in [regex]::Matches($html, '(?is)<h1>(.*?)</h1>(.*?)(?=<h1>|\z)')) {
                $order++
                $heading = Normalize-Title ([regex]::Replace($match.Groups[1].Value, '(?is)<[^>]+>', ' '))
                $id = ''
                if ($heading -match '\[ID:\s*(?<id>\d+)\]') {
                    $id = [string][int]$Matches.id
                }
                $title = Normalize-Title ([regex]::Replace($heading, '\s*\[ID:\s*\d+\]\s*$', ''))
                $note = Convert-NoteHtmlToText $match.Groups[2].Value
                [void]$records.Add((New-DiagnosticRecord 'notes' $order $id $title '' @() @() $note))
            }
            break
        }
        '^mvs\.sha1$' {
            foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
                if ($line -match '^\s*\S+\s+\*(?<filename>.+?)\s*$') {
                    $order++
                    $files = @([pscustomobject]@{ filename=$Matches.filename.Trim(); rawLine=[string]$line })
                    [void]$records.Add((New-DiagnosticRecord 'sha1' $order '' '' '' @([string]$line) $files ''))
                }
            }
            break
        }
        '^mvs\.sha256$' {
            foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
                if ($line -match '^\s*\S+\s+\*(?<filename>.+?)\s*$') {
                    $order++
                    $files = @([pscustomobject]@{ filename=$Matches.filename.Trim(); rawLine=[string]$line })
                    [void]$records.Add((New-DiagnosticRecord 'sha256' $order '' '' '' @([string]$line) $files ''))
                }
            }
            break
        }
        default {
            throw ('Unsupported MVS source file: ' + $Name)
        }
    }
    return @($records)
}

function Normalize-PropertyKey {
    param([string]$Name, [AllowNull()][AllowEmptyString()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    switch ($Name) {
        'id' { return ([string][int]$Value) }
        'title' { return (Normalize-Title $Value).ToLowerInvariant() }
        'date' { return $Value.Trim() }
        'filename' { return $Value.Trim().ToLowerInvariant() }
        default { return $Value.Trim() }
    }
}

function Get-PropertyOccurrences {
    param([object[]]$Records, [string]$Name)
    $items = New-Object System.Collections.ArrayList
    $occurrenceOrder = 0
    foreach ($record in $Records) {
        if ($Name -eq 'filename') {
            foreach ($file in @($record.files)) {
                $value = [string]$file.filename
                $key = Normalize-PropertyKey $Name $value
                if ([string]::IsNullOrEmpty($key)) { continue }
                $occurrenceOrder++
                [void]$items.Add([pscustomobject]@{
                    order=$occurrenceOrder
                    value=$value
                    key=$key
                    record=$record
                    matchedLine=[string]$file.rawLine
                })
            }
            continue
        }

        $value = ''
        switch ($Name) {
            'id' { $value = [string]$record.id }
            'title' { $value = [string]$record.title }
            'date' { $value = [string]$record.date }
        }
        $key = Normalize-PropertyKey $Name $value
        if ([string]::IsNullOrEmpty($key)) { continue }
        $occurrenceOrder++
        [void]$items.Add([pscustomobject]@{
            order=$occurrenceOrder
            value=$value
            key=$key
            record=$record
            matchedLine=''
        })
    }
    return @($items)
}

function Get-PropertyLabel {
    param([string]$Name)
    switch ($Name) {
        'id' { return 'ID' }
        'title' { return 'Title' }
        'date' { return 'Date' }
        'filename' { return 'Filename' }
        default { return $Name }
    }
}

function Write-IndentedLine {
    param([AllowEmptyString()][string]$Text)
    Write-Line ('  ' + $Text)
}

function Write-OccurrenceContext {
    param([object]$Occurrence, [string]$Name)
    $record = $Occurrence.record

    if ($Name -eq 'filename' -and @('mvs','names') -contains $record.kind) {
        Write-IndentedLine ('ID: ' + $record.id)
        Write-IndentedLine ('Title: ' + $record.title)
        Write-IndentedLine ([string]$Occurrence.matchedLine)
        return
    }

    if (@('mvs','names') -contains $record.kind) {
        foreach ($line in @($record.rawLines)) { Write-IndentedLine ([string]$line) }
        return
    }

    if ($record.kind -eq 'notes') {
        if (-not [string]::IsNullOrEmpty([string]$record.id)) { Write-IndentedLine ('ID: ' + $record.id) }
        Write-IndentedLine ('Title: ' + $record.title)
        Write-IndentedLine ('Note: ' + $record.note)
        return
    }

    foreach ($line in @($record.rawLines)) { Write-IndentedLine ([string]$line) }
}

function Find-Duplicates {
    param([object[]]$Occurrences, [string]$Name)
    $groups = @{}
    $order = New-Object System.Collections.ArrayList
    foreach ($item in $Occurrences) {
        if (-not $groups.ContainsKey($item.key)) {
            $groups[$item.key] = New-Object System.Collections.ArrayList
            [void]$order.Add($item.key)
        }
        [void]$groups[$item.key].Add($item)
    }

    $label = Get-PropertyLabel $Name
    foreach ($key in $order) {
        $items = @($groups[$key])
        if ($items.Count -lt 2) { continue }
        Write-Line ('Duplicate ' + $label + ': ' + $items[0].value)
        $n = 0
        foreach ($item in $items) {
            $n++
            Write-Line ('Occurrence ' + $n + ':')
            Write-OccurrenceContext $item $Name
        }
        Write-Line ''
    }
}

function Find-Orphans {
    param([object[]]$SourceOccurrences, [object[]]$TargetOccurrences, [string]$Name, [string]$Source, [string]$Target)
    $targetKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($item in $TargetOccurrences) { [void]$targetKeys.Add([string]$item.key) }

    $label = Get-PropertyLabel $Name
    foreach ($item in $SourceOccurrences) {
        if ($targetKeys.Contains([string]$item.key)) { continue }
        Write-Line ('Orphan ' + $label + ': ' + $item.value)
        Write-Line ('Source: ' + $Source)
        Write-Line ('Target: ' + $Target)
        Write-OccurrenceContext $item $Name
        Write-Line ''
    }
}

if ([string]::IsNullOrWhiteSpace($Dump) -or (@('--help','-h','-?','/h','/?') -contains $Dump)) {
    Show-Usage
    exit 0
}

if (@('duplicate','orphan') -notcontains $Operation) { Fail 2 ('Unsupported operation: ' + $Operation) }
if (@('id','title','date','filename') -notcontains $Property) { Fail 2 ('Unsupported property: ' + $Property) }

$DumpFolder = Resolve-DumpFolder $Dump $ScriptRoot
if ($null -eq $DumpFolder) { Fail 3 ('Dump folder not found: ' + $Dump) }

$sourcePath = Join-Path $DumpFolder $SourceName
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { Fail 4 ('Missing source file: ' + $sourcePath) }

try {
    $sourceRecords = @(Read-DiagnosticRecords $sourcePath $SourceName)
    $sourceOccurrences = @(Get-PropertyOccurrences $sourceRecords $Property)

    if ($Operation -eq 'duplicate') {
        Find-Duplicates $sourceOccurrences $Property
        exit 0
    }

    if ([string]::IsNullOrWhiteSpace($TargetName)) { Fail 2 'Orphan operation requires a target file.' }
    $targetPath = Join-Path $DumpFolder $TargetName
    if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) { Fail 4 ('Missing target file: ' + $targetPath) }
    $targetRecords = @(Read-DiagnosticRecords $targetPath $TargetName)
    $targetOccurrences = @(Get-PropertyOccurrences $targetRecords $Property)
    Find-Orphans $sourceOccurrences $targetOccurrences $Property $SourceName $TargetName
    exit 0
} catch {
    Fail 5 $_.Exception.Message
}
