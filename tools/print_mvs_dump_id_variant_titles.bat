@echo off
:setup
REM Scoped because this standalone single-dump tool embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=0.1.1"
set "app.name=print_mvs_dump_id_variant_titles"
set "app.rc=0"
set "app.self=%~f0"
set "mvsx_mode=human"
set "mvsx_operation=variant_query"
set "mvsx_fields=id,variant_title"
set "mvsx_search_source="
set "mvsx_algorithm_filter="
set "mvsx_source_file="
set "mvsx_diagnostic_kind="
set "mvsx_dump=%~1"
set "mvsx_search=%~2"
set "mvsx_caller=%~nx0"
set "mvsx_script_root=%~dp0"
set "mvsx_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSSingleDump"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

:: ============================================================
:: :SetErrorLevel
:: Sets the batch return code.
::
:: Version:
::   1.0.0
::
:: Usage: call :SetErrorLevel code
::
:: Arguments:
::   code  integer return code
::
:: Output:
::   None
::
:: Returns:
::   code
:: ============================================================
:SetErrorLevel
exit /b %~1

:: ============================================================
:: :RunPowerShellFromLabel
:: Reads this batch file, extracts PowerShell between
:: :_Block_start and :_Block_end, and executes it.
::
:: Version:
::   1.2.0
::
:: Last Change:
::   Return the powershell.exe exit code directly instead of routing
::   nonzero codes through the function re-entry return carrier.
::
:: Usage:
::   call :RunPowerShellFromLabel BlockName [arguments...]
::
:: Alternate Usage:
::   set "RunPowerShellFromLabel.function=BlockName"
::   call :RunPowerShellFromLabel [arguments...]
::
:: Arguments:
::   BlockName  embedded PowerShell block name
::   arguments  arguments forwarded to the block
::
:: Output:
::   embedded PowerShell stdout/stderr
::
:: Returns:
::   PowerShell exit code
::   2 for invalid arguments
:: ============================================================
:RunPowerShellFromLabel
for /f "tokens=1 delims==" %%v in ('set rps_ 2^>nul') do set "%%v="
set "rps_self=%~f0" & set "rps_argc=0"
if defined app.self set "rps_self=%app.self%"
if defined RunPowerShellFromLabel.function (set "rps_label=%RunPowerShellFromLabel.function%" & set "RunPowerShellFromLabel.function=" & goto :_RunPowerShellFromLabel_capture)
set "rps_label=%~1"
if not defined rps_label exit /b 2
shift
:_RunPowerShellFromLabel_capture
if "%~1"=="" goto :_RunPowerShellFromLabel_run
set "rps_arg%rps_argc%=%~1"
set /a rps_argc+=1
shift
goto :_RunPowerShellFromLabel_capture
:_RunPowerShellFromLabel_run
if "%rps_label:~0,1%"==":" set "rps_label=%rps_label:~1%"
set "rps_start=:_%rps_label%_start" & set "rps_end=:_%rps_label%_end"
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "& { try { $ErrorActionPreference='Stop'; $path=$env:rps_self; $start=$env:rps_start; $end=$env:rps_end; $argc=[int]$env:rps_argc; $lines=@(Get-Content -LiteralPath $path); $s=-1; $e=-1; for($i=0;$i-lt$lines.Count;$i++){ $t=$lines[$i].Trim(); if($s-lt 0-and$t-eq$start){$s=$i;continue}; if($s-ge 0-and$t-eq$end){$e=$i;break} }; if($s-lt 0-or$e-le$s){throw ('Could not find valid PowerShell block: '+$start+' / '+$end)}; $code=if($e-gt($s+1)){$lines[($s+1)..($e-1)]-join[Environment]::NewLine}else{''}; $arguments=@(); for($n=0;$n-lt$argc;$n++){$arguments += [Environment]::GetEnvironmentVariable(('rps_arg{0}' -f $n))}; & ([ScriptBlock]::Create($code)) @arguments; if(-not $?){exit 1}; exit 0 } catch { Write-Error $_; exit 1 } }"
set "rps_rc=%errorlevel%"
exit /b %rps_rc%

:_MVSSingleDump_start
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$Mode = [string]$env:mvsx_mode
$Operation = [string]$env:mvsx_operation
$Fields = @(([string]$env:mvsx_fields).Split(',') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$SearchSource = [string]$env:mvsx_search_source
$AlgorithmFilter = [string]$env:mvsx_algorithm_filter
$SourceFile = [string]$env:mvsx_source_file
$DiagnosticKind = [string]$env:mvsx_diagnostic_kind
$Dump = [string]$env:mvsx_dump
$Search = [string]$env:mvsx_search
$Caller = [string]$env:mvsx_caller
$ScriptRoot = [string]$env:mvsx_script_root
$Version = [string]$env:mvsx_version

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
    Write-Line ('MVS Explorer Toolkit single-dump query ' + $Version)
    if ([string]::IsNullOrEmpty($SearchSource)) {
        Write-Line ('Usage: ' + $Caller + ' dump-folder')
    } else {
        Write-Line ('Usage: ' + $Caller + ' dump-folder search-value')
        Write-Line ('Search source: ' + $SearchSource + ' (exact, case-insensitive)')
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

function Normalize-Scalar {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    return ([regex]::Replace($Value, '[\t\r\n]+', ' ')).Trim()
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

function Get-Algorithm {
    param([string]$Hash)
    if ($Hash.Length -eq 40) { return 'SHA1' }
    if ($Hash.Length -eq 64) { return 'SHA256' }
    return ''
}

function New-ArrayList {
    return (New-Object System.Collections.ArrayList)
}

function Add-Unparsed {
    param([hashtable]$Unparsed, [string]$Source, [int]$Line, [string]$Raw)
    if (-not $Unparsed.ContainsKey($Source)) { $Unparsed[$Source] = New-ArrayList }
    [void]$Unparsed[$Source].Add([pscustomobject]@{ line=$Line; raw=$Raw })
}

function Add-HashRecord {
    param(
        [System.Collections.ArrayList]$List,
        [string]$Source,
        [int]$Line,
        [string]$Id,
        [string]$Title,
        [string]$VariantTitle,
        [string]$Filename,
        [string]$Hash
    )
    [void]$List.Add([pscustomobject]@{
        source = $Source
        line = $Line
        id = $Id
        title = $Title
        variant_title = $VariantTitle
        filename = $Filename
        hash = $Hash.ToLowerInvariant()
        algorithm = Get-Algorithm $Hash
    })
}

function Read-OneLineSource {
    param([string]$Path, [string]$Name, [hashtable]$Unparsed)
    $rows = New-ArrayList
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @($rows) }
    $lineNumber = 0
    foreach ($lineValue in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $lineNumber++
        $line = [string]$lineValue
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($Name -eq 'mvs_ids.txt') {
            if ($line -match '^(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') {
                [void]$rows.Add([pscustomobject]@{
                    line=$lineNumber
                    id=[string][int]$Matches.id
                    title=Normalize-Title $Matches.title
                    date=''
                    raw=$line
                })
            } else {
                Add-Unparsed $Unparsed $Name $lineNumber $line
            }
        } elseif ($Name -eq 'mvs_dates.txt') {
            if ($line -match '^(?<date>.*?)\s+-\s+(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') {
                [void]$rows.Add([pscustomobject]@{
                    line=$lineNumber
                    id=[string][int]$Matches.id
                    title=Normalize-Title $Matches.title
                    date=$Matches.date.Trim()
                    raw=$line
                })
            } else {
                Add-Unparsed $Unparsed $Name $lineNumber $line
            }
        }
    }
    return @($rows)
}

function Read-Manifest {
    param(
        [string]$Path,
        [string]$Name,
        [int]$HashLength,
        [hashtable]$Unparsed,
        [System.Collections.ArrayList]$HashRecords
    )
    $rows = New-ArrayList
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @($rows) }
    $lineNumber = 0
    foreach ($lineValue in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $lineNumber++
        $line = [string]$lineValue
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $pattern = '^\s*(?<hash>[0-9A-Fa-f]{' + $HashLength + '})\s+\*(?<filename>.+?)\s*$'
        if ($line -match $pattern -and -not [string]::IsNullOrWhiteSpace($Matches.filename)) {
            $hash = $Matches.hash.ToLowerInvariant()
            $filename = $Matches.filename.Trim()
            $row = [pscustomobject]@{
                source=$Name
                line=$lineNumber
                id=''
                title=''
                variant_title=''
                filename=$filename
                hash=$hash
                algorithm=Get-Algorithm $hash
            }
            [void]$rows.Add($row)
            [void]$HashRecords.Add($row)
        } else {
            Add-Unparsed $Unparsed $Name $lineNumber $line
        }
    }
    return @($rows)
}

function Read-SectionFile {
    param(
        [string]$Path,
        [string]$Name,
        [hashtable]$Unparsed,
        [System.Collections.ArrayList]$HashRecords
    )

    $sections = New-ArrayList
    $files = New-ArrayList
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ sections=@(); files=@() }
    }

    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
    $section = $null
    $occurrence = 0

    function Complete-Section {
        param([object]$Current, [System.Collections.ArrayList]$SectionList)
        if ($null -ne $Current) { [void]$SectionList.Add($Current) }
    }

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $lineNumber = $index + 1
        $line = [string]$lines[$index]

        $headerMatched = $false
        $headerId = ''
        $headerTitle = ''
        if ($Name -eq 'mvs_names.txt') {
            if ($line -match '^---\s*(?<title>.*?)\s*\[ID:\s*(?<id>[^\]]+?)\s*\]\s*---\s*$') {
                $headerMatched = $true
                $headerId = $Matches.id.Trim()
                $headerTitle = $Matches.title
            }
        } else {
            if ($line -match '^---\s*(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*---\s*$') {
                $headerMatched = $true
                $headerId = [string][int]$Matches.id
                $headerTitle = $Matches.title
            }
        }

        if ($headerMatched) {
            Complete-Section $section $sections
            $occurrence++
            $rawLines = New-ArrayList
            [void]$rawLines.Add([pscustomobject]@{ offset=0; line=$lineNumber; raw=$line })
            $section = [pscustomobject]@{
                occurrence=$occurrence
                id=$headerId
                title=Normalize-Title $headerTitle
                start_line=$lineNumber
                raw_lines=$rawLines
                file_count=0
            }
            continue
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
            Complete-Section $section $sections
            $section = $null
            continue
        }

        if ($null -eq $section) {
            Add-Unparsed $Unparsed $Name $lineNumber $line
            continue
        }

        [void]$section.raw_lines.Add([pscustomobject]@{
            offset=$section.raw_lines.Count
            line=$lineNumber
            raw=$line
        })

        if ($line -match '^\s*(?<hash>[0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})\s+\*(?<filename>.+?)\s*$' -and -not [string]::IsNullOrWhiteSpace($Matches.filename)) {
            $hash = $Matches.hash.ToLowerInvariant()
            $filename = $Matches.filename.Trim()
            $fileRow = [pscustomobject]@{
                source=$Name
                line=$lineNumber
                section_occurrence=$section.occurrence
                id=$section.id
                title=$section.title
                filename=$filename
                hash=$hash
                algorithm=Get-Algorithm $hash
            }
            [void]$files.Add($fileRow)
            $section.file_count++
            if ($Name -eq 'mvs.txt') {
                Add-HashRecord $HashRecords $Name $lineNumber $section.id $section.title '' $filename $hash
            } else {
                Add-HashRecord $HashRecords $Name $lineNumber $section.id '' $section.title $filename $hash
            }
        } else {
            Add-Unparsed $Unparsed $Name $lineNumber $line
        }
    }

    Complete-Section $section $sections
    return [pscustomobject]@{ sections=@($sections); files=@($files) }
}

function Read-Notes {
    param([string]$Path)
    $rows = New-ArrayList
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @($rows) }
    $html = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $occurrence = 0
    foreach ($match in [regex]::Matches($html, '(?is)<h1>(.*?)</h1>(.*?)(?=<h1>|\z)')) {
        $occurrence++
        $title = Normalize-Title ([regex]::Replace($match.Groups[1].Value, '(?is)<[^>]+>', ' '))
        $note = Convert-NoteHtmlToText $match.Groups[2].Value
        [void]$rows.Add([pscustomobject]@{
            occurrence=$occurrence
            title=$title
            note=$note
        })
    }
    return @($rows)
}

function New-MvsModel {
    param([string]$DumpFolder)

    $unparsed = @{}
    foreach ($name in @('mvs.txt','mvs_names.txt','mvs.sha1','mvs.sha256','mvs_ids.txt','mvs_dates.txt')) {
        $unparsed[$name] = New-ArrayList
    }

    $hashRecords = New-ArrayList
    $ids = @(Read-OneLineSource (Join-Path $DumpFolder 'mvs_ids.txt') 'mvs_ids.txt' $unparsed)
    $dates = @(Read-OneLineSource (Join-Path $DumpFolder 'mvs_dates.txt') 'mvs_dates.txt' $unparsed)
    $productData = Read-SectionFile (Join-Path $DumpFolder 'mvs.txt') 'mvs.txt' $unparsed $hashRecords
    $variantData = Read-SectionFile (Join-Path $DumpFolder 'mvs_names.txt') 'mvs_names.txt' $unparsed $hashRecords
    $sha1 = @(Read-Manifest (Join-Path $DumpFolder 'mvs.sha1') 'mvs.sha1' 40 $unparsed $hashRecords)
    $sha256 = @(Read-Manifest (Join-Path $DumpFolder 'mvs.sha256') 'mvs.sha256' 64 $unparsed $hashRecords)
    $notes = @(Read-Notes (Join-Path $DumpFolder 'mvs_notes.html'))

    $dateById = @{}
    foreach ($row in $dates) {
        if (-not $dateById.ContainsKey($row.id)) { $dateById[$row.id] = $row.date }
    }

    $noteByTitle = @{}
    foreach ($row in $notes) {
        if ([string]::IsNullOrWhiteSpace($row.title) -or [string]::IsNullOrWhiteSpace($row.note)) { continue }
        $key = $row.title.ToLowerInvariant()
        if (-not $noteByTitle.ContainsKey($key)) { $noteByTitle[$key] = New-ArrayList }
        if (-not $noteByTitle[$key].Contains($row.note)) { [void]$noteByTitle[$key].Add($row.note) }
    }

    $productSectionByOccurrence = @{}
    foreach ($section in $productData.sections) {
        $date = if ($dateById.ContainsKey($section.id)) { [string]$dateById[$section.id] } else { '' }
        $noteKey = $section.title.ToLowerInvariant()
        $note = if ($noteByTitle.ContainsKey($noteKey)) { (($noteByTitle[$noteKey] | ForEach-Object { [string]$_ }) -join ' || ') } else { '' }
        Add-Member -InputObject $section -NotePropertyName date -NotePropertyValue $date
        Add-Member -InputObject $section -NotePropertyName note -NotePropertyValue $note
        $productSectionByOccurrence[[string]$section.occurrence] = $section
    }

    $productFiles = New-ArrayList
    foreach ($row in $productData.files) {
        $section = $productSectionByOccurrence[[string]$row.section_occurrence]
        [void]$productFiles.Add([pscustomobject]@{
            source=$row.source
            line=$row.line
            section_occurrence=$row.section_occurrence
            id=$row.id
            title=$row.title
            date=$section.date
            note=$section.note
            filename=$row.filename
            hash=$row.hash
            algorithm=$row.algorithm
        })
    }

    $variantSectionsWithFiles = @{}
    $variants = New-ArrayList
    foreach ($row in $variantData.files) {
        $variantSectionsWithFiles[[string]$row.section_occurrence] = $true
        [void]$variants.Add([pscustomobject]@{
            occurrence=$row.section_occurrence
            id=$row.id
            variant_title=$row.title
            filename=$row.filename
            hash=$row.hash
            algorithm=$row.algorithm
            source=$row.source
            line=$row.line
        })
    }
    foreach ($section in $variantData.sections) {
        if (-not $variantSectionsWithFiles.ContainsKey([string]$section.occurrence)) {
            [void]$variants.Add([pscustomobject]@{
                occurrence=$section.occurrence
                id=$section.id
                variant_title=$section.title
                filename=''
                hash=''
                algorithm=''
                source='mvs_names.txt'
                line=$section.start_line
            })
        }
    }
    $variants = @($variants | Sort-Object @{Expression={[int]$_.occurrence}}, @{Expression={[int]$_.line}})

    return [pscustomobject]@{
        root=$DumpFolder
        ids=@($ids)
        dates=@($dates)
        product_sections=@($productData.sections)
        product_files=@($productFiles)
        variant_sections=@($variantData.sections)
        variants=@($variants)
        hash_records=@($hashRecords)
        sha1=@($sha1)
        sha256=@($sha256)
        notes=@($notes)
        unparsed=$unparsed
    }
}

function Get-FieldLabel {
    param([string]$Field)
    switch ($Field) {
        'id' { return 'ID' }
        'title' { return 'Title' }
        'date' { return 'Date' }
        'note' { return 'Note' }
        'filename' { return 'Filename' }
        'hash' { return 'Hash' }
        'algorithm' { return 'Algorithm' }
        'source' { return 'Source' }
        'line' { return 'Line' }
        'raw' { return 'Raw' }
        'occurrence' { return 'Occurrence' }
        'section_occurrence' { return 'Section' }
        'line_offset' { return 'Offset' }
        'variant_title' { return 'Variant' }
        default { return $Field }
    }
}

function Get-PropertyString {
    param([object]$Row, [string]$Field)
    if ($null -eq $Row) { return '' }
    $property = $Row.PSObject.Properties[$Field]
    if ($null -eq $property) { return '' }
    return Normalize-Scalar ([string]$property.Value)
}

function Emit-Rows {
    param(
        [object[]]$Rows,
        [string[]]$Projection,
        [string]$OutputMode,
        [bool]$Dedupe=$true
    )
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $emitted = 0

    foreach ($row in $Rows) {
        $values = New-ArrayList
        $hasNonEmpty = $false
        foreach ($field in $Projection) {
            $value = Get-PropertyString $row $field
            if (-not [string]::IsNullOrEmpty($value)) { $hasNonEmpty = $true }
            [void]$values.Add($value)
        }
        if (-not $hasNonEmpty) { continue }

        if ($Dedupe) {
            $parts = @()
            foreach ($value in $values) { $parts += ([string]$value).Length.ToString() + ':' + [string]$value }
            $key = $parts -join [char]0x1F
            if (-not $seen.Add($key)) { continue }
        }

        if ($OutputMode -eq 'machine') {
            Write-Line (($values | ForEach-Object { [string]$_ }) -join [char]9)
        } else {
            $parts = @()
            for ($i = 0; $i -lt $Projection.Count; $i++) {
                $value = [string]$values[$i]
                if ([string]::IsNullOrEmpty($value)) { $value = '(none)' }
                $parts += ((Get-FieldLabel $Projection[$i]) + ': ' + $value)
            }
            Write-Line ($parts -join ' | ')
        }
        $emitted++
    }
    return $emitted
}

function Matches-Exact {
    param([AllowNull()][string]$Value, [string]$Needle)
    if ($null -eq $Value) { return $false }
    return [string]::Equals($Value.Trim(), $Needle.Trim(), [StringComparison]::OrdinalIgnoreCase)
}

function Get-DetailRows {
    param([object]$Model, [string]$SourceName, [string]$Needle, [string]$Algorithm)

    $seeds = New-ArrayList
    $seedSeen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

    if ($SourceName -eq 'id' -or $SourceName -eq 'title') {
        foreach ($file in $Model.product_files) {
            $match = if ($SourceName -eq 'id') {
                try { ([int64]$file.id -eq [int64]$Needle) } catch { $false }
            } else {
                Matches-Exact $file.title $Needle
            }
            if (-not $match) { continue }
            $seedKey = ([string]$file.section_occurrence) + [char]0x1F + $file.filename
            if ($seedSeen.Add($seedKey)) {
                [void]$seeds.Add([pscustomobject]@{
                    owner=$file
                    filename=$file.filename
                })
            }
        }
    } elseif ($SourceName -eq 'filename') {
        $candidateFilenames = New-ArrayList
        $candidateSeen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($record in $Model.hash_records) {
            if (Matches-Exact $record.filename $Needle) {
                if ($candidateSeen.Add($record.filename)) { [void]$candidateFilenames.Add($record.filename) }
            }
        }
        foreach ($filename in $candidateFilenames) {
            $owners = @($Model.product_files | Where-Object { Matches-Exact $_.filename $filename } |
                Group-Object section_occurrence | ForEach-Object { $_.Group[0] })
            if ($owners.Count -eq 0) {
                [void]$seeds.Add([pscustomobject]@{ owner=$null; filename=$filename })
            } else {
                foreach ($owner in $owners) { [void]$seeds.Add([pscustomobject]@{ owner=$owner; filename=$filename }) }
            }
        }
    } elseif ($SourceName -eq 'hash') {
        $candidateFilenames = New-ArrayList
        $candidateSeen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($record in $Model.hash_records) {
            if (Matches-Exact $record.hash $Needle) {
                if ($candidateSeen.Add($record.filename)) { [void]$candidateFilenames.Add($record.filename) }
            }
        }
        foreach ($filename in $candidateFilenames) {
            $owners = @($Model.product_files | Where-Object { Matches-Exact $_.filename $filename } |
                Group-Object section_occurrence | ForEach-Object { $_.Group[0] })
            if ($owners.Count -eq 0) {
                [void]$seeds.Add([pscustomobject]@{ owner=$null; filename=$filename })
            } else {
                foreach ($owner in $owners) { [void]$seeds.Add([pscustomobject]@{ owner=$owner; filename=$filename }) }
            }
        }
    }

    $rows = New-ArrayList
    foreach ($seed in $seeds) {
        $records = @($Model.hash_records | Where-Object {
            (Matches-Exact $_.filename $seed.filename) -and
            ([string]::IsNullOrEmpty($Algorithm) -or $_.algorithm -eq $Algorithm)
        })

        if ($records.Count -eq 0) {
            [void]$rows.Add([pscustomobject]@{
                id=$(if($null -ne $seed.owner){$seed.owner.id}else{''})
                title=$(if($null -ne $seed.owner){$seed.owner.title}else{''})
                date=$(if($null -ne $seed.owner){$seed.owner.date}else{''})
                note=$(if($null -ne $seed.owner){$seed.owner.note}else{''})
                filename=$seed.filename
                hash=''
                algorithm=''
                source=''
            })
            continue
        }

        foreach ($record in $records) {
            [void]$rows.Add([pscustomobject]@{
                id=$(if($null -ne $seed.owner){$seed.owner.id}else{''})
                title=$(if($null -ne $seed.owner){$seed.owner.title}else{''})
                date=$(if($null -ne $seed.owner){$seed.owner.date}else{''})
                note=$(if($null -ne $seed.owner){$seed.owner.note}else{''})
                filename=$seed.filename
                hash=$record.hash
                algorithm=$record.algorithm
                source=$record.source
            })
        }
    }
    return @($rows)
}

function Get-VariantRows {
    param([object]$Model, [string]$SourceName, [string]$Needle)
    if ([string]::IsNullOrEmpty($SourceName)) { return @($Model.variants) }

    $rows = New-ArrayList
    foreach ($row in $Model.variants) {
        $match = $false
        if ($SourceName -eq 'id') {
            $match = Matches-Exact $row.id $Needle
        } elseif ($SourceName -eq 'filename') {
            $match = Matches-Exact $row.filename $Needle
        } elseif ($SourceName -eq 'hash') {
            $match = Matches-Exact $row.hash $Needle
        }
        if ($match) { [void]$rows.Add($row) }
    }
    return @($rows)
}

function Get-HashRows {
    param([object]$Model, [string]$SourceName, [string]$Needle, [string]$Algorithm)
    $rows = New-ArrayList
    foreach ($row in $Model.hash_records) {
        if (-not [string]::IsNullOrEmpty($Algorithm) -and $row.algorithm -ne $Algorithm) { continue }
        if ($SourceName -eq 'filename' -and -not (Matches-Exact $row.filename $Needle)) { continue }
        if ($SourceName -eq 'hash' -and -not (Matches-Exact $row.hash $Needle)) { continue }
        [void]$rows.Add($row)
    }
    return @($rows)
}

function Get-ProductFileRows {
    param([object]$Model, [string]$SourceName, [string]$Needle)
    if ([string]::IsNullOrEmpty($SourceName)) { return @($Model.product_files) }
    $rows = New-ArrayList
    foreach ($row in $Model.product_files) {
        $match = if ($SourceName -eq 'id') {
            try { ([int64]$row.id -eq [int64]$Needle) } catch { $false }
        } else { Matches-Exact $row.title $Needle }
        if ($match) { [void]$rows.Add($row) }
    }
    return @($rows)
}

function Get-ProductSections {
    param([object]$Model, [string]$SourceName, [string]$Needle)
    if ([string]::IsNullOrEmpty($SourceName)) { return @($Model.product_sections) }
    $rows = New-ArrayList
    foreach ($section in $Model.product_sections) {
        $match = if ($SourceName -eq 'id') {
            try { ([int64]$section.id -eq [int64]$Needle) } catch { $false }
        } else { Matches-Exact $section.title $Needle }
        if ($match) { [void]$rows.Add($section) }
    }
    return @($rows)
}

function Emit-ProductSections {
    param([object[]]$Sections, [string]$OutputMode)
    $count = 0
    foreach ($section in $Sections) {
        if ($OutputMode -eq 'human') {
            if ($count -gt 0) { Write-Line '' }
            foreach ($raw in $section.raw_lines) { Write-Line ([string]$raw.raw) }
            $count++
        } else {
            foreach ($raw in $section.raw_lines) {
                $sectionValues = New-ArrayList
                [void]$sectionValues.Add([string]$section.occurrence)
                [void]$sectionValues.Add([string]$section.id)
                [void]$sectionValues.Add((Normalize-Scalar ([string]$section.title)))
                [void]$sectionValues.Add([string]$raw.offset)
                [void]$sectionValues.Add([string]$raw.line)
                [void]$sectionValues.Add((Normalize-Scalar ([string]$raw.raw)))
                Write-Line (($sectionValues | ForEach-Object { [string]$_ }) -join [char]9)
                $count++
            }
        }
    }
    return $count
}

function Get-NoteRows {
    param([object]$Model, [string]$SourceName, [string]$Needle)
    if ([string]::IsNullOrEmpty($SourceName)) { return @($Model.notes) }
    return @($Model.notes | Where-Object { Matches-Exact $_.title $Needle })
}

function Get-SourceHashRows {
    param([object]$Model, [string]$SourceName, [string]$Algorithm)
    return @($Model.hash_records | Where-Object {
        $_.source -eq $SourceName -and
        ([string]::IsNullOrEmpty($Algorithm) -or $_.algorithm -eq $Algorithm)
    })
}

function Write-HashDiagnostic {
    param([object]$Model, [string]$Kind, [string]$SourceSpec, [string]$Algorithm)

    if ($Kind -eq 'hash_mismatch') {
        $parts = $SourceSpec.Split('|')
        $leftName = $parts[0]
        $rightName = $parts[1]
        $leftRows = @(Get-SourceHashRows $Model $leftName $Algorithm)
        $rightRows = @(Get-SourceHashRows $Model $rightName $Algorithm)

        $leftByFilename = @{}
        $rightByFilename = @{}
        foreach ($row in $leftRows) {
            $key = $row.filename.ToLowerInvariant()
            if (-not $leftByFilename.ContainsKey($key)) { $leftByFilename[$key] = New-ArrayList }
            if (-not $leftByFilename[$key].Contains($row.hash)) { [void]$leftByFilename[$key].Add($row.hash) }
        }
        foreach ($row in $rightRows) {
            $key = $row.filename.ToLowerInvariant()
            if (-not $rightByFilename.ContainsKey($key)) { $rightByFilename[$key] = New-ArrayList }
            if (-not $rightByFilename[$key].Contains($row.hash)) { [void]$rightByFilename[$key].Add($row.hash) }
        }

        foreach ($key in $leftByFilename.Keys | Sort-Object) {
            if (-not $rightByFilename.ContainsKey($key)) { continue }
            $leftSet = @($leftByFilename[$key] | Sort-Object)
            $rightSet = @($rightByFilename[$key] | Sort-Object)
            if (($leftSet -join '|') -eq ($rightSet -join '|')) { continue }
            $display = ($leftRows | Where-Object { $_.filename.ToLowerInvariant() -eq $key } | Select-Object -First 1).filename
            Write-Line ('Hash mismatch for Filename: ' + $display)
            Write-Line ('  ' + $leftName + ': ' + ($leftSet -join ', '))
            Write-Line ('  ' + $rightName + ': ' + ($rightSet -join ', '))
            Write-Line ''
        }
        return
    }

    $rows = @(Get-SourceHashRows $Model $SourceSpec $Algorithm)

    if ($Kind -eq 'duplicate_hash') {
        $groups = @($rows | Group-Object hash | Where-Object { $_.Count -gt 1 })
        foreach ($group in $groups) {
            Write-Line ('Duplicate Hash: ' + $group.Name)
            foreach ($row in $group.Group) {
                Write-Line ('  Source: ' + $row.source + ' | Line: ' + $row.line + ' | Filename: ' + $row.filename)
            }
            Write-Line ''
        }
        return
    }

    if ($Kind -eq 'hash_multiple_filenames') {
        foreach ($group in @($rows | Group-Object hash)) {
            $filenames = @($group.Group | Select-Object -ExpandProperty filename -Unique)
            if ($filenames.Count -lt 2) { continue }
            Write-Line ('Hash with multiple filenames: ' + $group.Name)
            foreach ($filename in $filenames) { Write-Line ('  Filename: ' + $filename) }
            Write-Line ''
        }
        return
    }

    if ($Kind -eq 'filename_multiple_hashes') {
        foreach ($group in @($rows | Group-Object { $_.filename.ToLowerInvariant() })) {
            $hashes = @($group.Group | Select-Object -ExpandProperty hash -Unique)
            if ($hashes.Count -lt 2) { continue }
            $display = $group.Group[0].filename
            Write-Line ('Filename with multiple hashes: ' + $display)
            foreach ($hash in $hashes) { Write-Line ('  Hash: ' + $hash) }
            Write-Line ''
        }
        return
    }
}

function Get-SummaryRows {
    param([object]$Model)

    $rows = New-ArrayList
    function Add-Metric {
        param([string]$Key, [AllowEmptyString()][string]$Value)
        [void]$rows.Add([pscustomobject]@{ key=$Key; value=$Value })
    }

    $present = @{}
    foreach ($name in @('mvs_ids.txt','mvs_dates.txt','mvs.txt','mvs_names.txt','mvs_notes.html','mvs.sha1','mvs.sha256')) {
        $present[$name] = Test-Path -LiteralPath (Join-Path $Model.root $name) -PathType Leaf
        Add-Metric ('source.present.' + $name) ($(if($present[$name]){'1'}else{'0'}))
    }

    Add-Metric 'products.mvs_ids.rows' ([string]$Model.ids.Count)
    Add-Metric 'products.mvs_dates.rows' ([string]$Model.dates.Count)
    Add-Metric 'products.mvs.sections' ([string]$Model.product_sections.Count)
    Add-Metric 'products.mvs.unique_ids' ([string](@($Model.product_sections | Select-Object -ExpandProperty id -Unique).Count))
    Add-Metric 'products.mvs.unique_titles' ([string](@($Model.product_sections | Select-Object -ExpandProperty title -Unique).Count))
    Add-Metric 'product_files.rows' ([string]$Model.product_files.Count)
    Add-Metric 'product_files.unique_filenames' ([string](@($Model.product_files | Select-Object -ExpandProperty filename -Unique).Count))
    Add-Metric 'product_files.unique_hashes' ([string](@($Model.product_files | Select-Object -ExpandProperty hash -Unique).Count))
    Add-Metric 'product_files.sha1_rows' ([string](@($Model.product_files | Where-Object {$_.algorithm -eq 'SHA1'}).Count))
    Add-Metric 'product_files.sha256_rows' ([string](@($Model.product_files | Where-Object {$_.algorithm -eq 'SHA256'}).Count))

    $productIds = @($Model.product_sections | Select-Object -ExpandProperty id -Unique)
    $productFileIds = @($Model.product_files | Select-Object -ExpandProperty id -Unique)
    Add-Metric 'product_files.product_ids_with_files' ([string]$productFileIds.Count)
    Add-Metric 'product_files.product_ids_without_files' ([string](@($productIds | Where-Object { $productFileIds -notcontains $_ }).Count))
    $fileGroupsById = @($Model.product_files | Group-Object id)
    $maxFilesPerId = 0
    foreach ($group in $fileGroupsById) { if ($group.Count -gt $maxFilesPerId) { $maxFilesPerId = $group.Count } }
    Add-Metric 'product_files.max_rows_per_product_id' ([string]$maxFilesPerId)
    Add-Metric 'product_files.reused_filename_groups' ([string](@($Model.product_files | Group-Object { $_.filename.ToLowerInvariant() } | Where-Object {$_.Count -gt 1}).Count))

    $idsNumeric = @($Model.product_sections | ForEach-Object { try { [int64]$_.id } catch {} } | Sort-Object)
    Add-Metric 'products.id_min' ($(if($idsNumeric.Count){[string]$idsNumeric[0]}else{''}))
    Add-Metric 'products.id_max' ($(if($idsNumeric.Count){[string]$idsNumeric[-1]}else{''}))

    $dateRows = @($Model.dates | Where-Object { -not [string]::IsNullOrWhiteSpace($_.date) })
    if ($dateRows.Count -gt 0) {
        $parsed = New-ArrayList
        foreach ($row in $dateRows) {
            try {
                $dto = [DateTimeOffset]::Parse($row.date, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
                [void]$parsed.Add([pscustomobject]@{ ticks=$dto.UtcDateTime.Ticks; raw=$row.date })
            } catch {
            }
        }
        if ($parsed.Count -gt 0) {
            $sorted = @($parsed | Sort-Object ticks)
            Add-Metric 'products.date_min' ([string]$sorted[0].raw)
            Add-Metric 'products.date_max' ([string]$sorted[-1].raw)
        } else {
            Add-Metric 'products.date_min' ''
            Add-Metric 'products.date_max' ''
        }
    } else {
        Add-Metric 'products.date_min' ''
        Add-Metric 'products.date_max' ''
    }

    Add-Metric 'variants.sections' ([string]$Model.variant_sections.Count)
    Add-Metric 'variants.rows' ([string]$Model.variants.Count)
    Add-Metric 'variants.unique_titles' ([string](@($Model.variant_sections | Select-Object -ExpandProperty title -Unique).Count))
    Add-Metric 'variants.unique_filenames' ([string](@($Model.variants | Where-Object {$_.filename} | Select-Object -ExpandProperty filename -Unique).Count))
    $variantIds = @($Model.variant_sections | Select-Object -ExpandProperty id -Unique)
    Add-Metric 'variants.unique_ids' ([string]$variantIds.Count)
    Add-Metric 'variants.ids_matching_product_ids' ([string](@($variantIds | Where-Object { $productIds -contains $_ }).Count))
    Add-Metric 'variants.ids_not_in_product_ids' ([string](@($variantIds | Where-Object { $productIds -notcontains $_ }).Count))
    $variantGroupsById = @($Model.variant_sections | Group-Object id)
    $maxVariantsPerId = 0
    foreach ($group in $variantGroupsById) { if ($group.Count -gt $maxVariantsPerId) { $maxVariantsPerId = $group.Count } }
    Add-Metric 'variants.max_sections_per_id' ([string]$maxVariantsPerId)
    Add-Metric 'variants.repeated_id_groups' ([string](@($variantGroupsById | Where-Object {$_.Count -gt 1}).Count))

    Add-Metric 'notes.records' ([string]$Model.notes.Count)
    Add-Metric 'notes.unique_titles' ([string](@($Model.notes | Select-Object -ExpandProperty title -Unique).Count))
    $noteTitleKeys = @($Model.notes | Where-Object {$_.note} | ForEach-Object {$_.title.ToLowerInvariant()} | Select-Object -Unique)
    $productsWithNotes = @($Model.product_sections | Where-Object { $noteTitleKeys -contains $_.title.ToLowerInvariant() } | Select-Object -ExpandProperty id -Unique)
    Add-Metric 'notes.product_ids_with_notes' ([string]$productsWithNotes.Count)
    Add-Metric 'notes.product_ids_without_notes' ([string](@($productIds | Where-Object { $productsWithNotes -notcontains $_ }).Count))
    Add-Metric 'notes.duplicate_title_groups' ([string](@($Model.notes | Group-Object { $_.title.ToLowerInvariant() } | Where-Object {$_.Count -gt 1}).Count))

    Add-Metric 'sha1.rows' ([string]$Model.sha1.Count)
    Add-Metric 'sha1.unique_hashes' ([string](@($Model.sha1 | Select-Object -ExpandProperty hash -Unique).Count))
    Add-Metric 'sha1.unique_filenames' ([string](@($Model.sha1 | Select-Object -ExpandProperty filename -Unique).Count))
    Add-Metric 'sha256.rows' ([string]$Model.sha256.Count)
    Add-Metric 'sha256.unique_hashes' ([string](@($Model.sha256 | Select-Object -ExpandProperty hash -Unique).Count))
    Add-Metric 'sha256.unique_filenames' ([string](@($Model.sha256 | Select-Object -ExpandProperty filename -Unique).Count))

    Add-Metric 'hash_records.rows' ([string]$Model.hash_records.Count)
    Add-Metric 'hash_records.unique_hashes' ([string](@($Model.hash_records | Select-Object -ExpandProperty hash -Unique).Count))
    Add-Metric 'hash_records.unique_filenames' ([string](@($Model.hash_records | Select-Object -ExpandProperty filename -Unique).Count))
    Add-Metric 'hash_records.unique_sha1' ([string](@($Model.hash_records | Where-Object {$_.algorithm -eq 'SHA1'} | Select-Object -ExpandProperty hash -Unique).Count))
    Add-Metric 'hash_records.unique_sha256' ([string](@($Model.hash_records | Where-Object {$_.algorithm -eq 'SHA256'} | Select-Object -ExpandProperty hash -Unique).Count))

    Add-Metric 'integrity.duplicate_product_ids' ([string](@($Model.product_sections | Group-Object id | Where-Object {$_.Count -gt 1}).Count))
    Add-Metric 'integrity.duplicate_product_titles' ([string](@($Model.product_sections | Group-Object { $_.title.ToLowerInvariant() } | Where-Object {$_.Count -gt 1}).Count))
    Add-Metric 'integrity.duplicate_product_filenames' ([string](@($Model.product_files | Group-Object { $_.filename.ToLowerInvariant() } | Where-Object {$_.Count -gt 1}).Count))

    $idsFromIds = @($Model.ids | Select-Object -ExpandProperty id -Unique)
    $idsFromDates = @($Model.dates | Select-Object -ExpandProperty id -Unique)
    $idsFromMvs = @($Model.product_sections | Select-Object -ExpandProperty id -Unique)
    $idsFromNames = @($Model.variant_sections | Select-Object -ExpandProperty id -Unique)
    Add-Metric 'integrity.orphan_ids_ids_to_dates' ([string](@($idsFromIds | Where-Object {$idsFromDates -notcontains $_}).Count))
    Add-Metric 'integrity.orphan_ids_ids_to_mvs' ([string](@($idsFromIds | Where-Object {$idsFromMvs -notcontains $_}).Count))
    Add-Metric 'cross_domain.product_ids_not_in_mvs_names_ids' ([string](@($idsFromIds | Where-Object {$idsFromNames -notcontains $_}).Count))

    $mvsFilenames = @($Model.product_files | Select-Object -ExpandProperty filename -Unique)
    $nameFilenames = @($Model.variants | Where-Object {$_.filename} | Select-Object -ExpandProperty filename -Unique)
    $sha1Filenames = @($Model.sha1 | Select-Object -ExpandProperty filename -Unique)
    $sha256Filenames = @($Model.sha256 | Select-Object -ExpandProperty filename -Unique)
    Add-Metric 'integrity.orphan_filenames_mvs_to_names' ([string](@($mvsFilenames | Where-Object {$nameFilenames -notcontains $_}).Count))
    Add-Metric 'integrity.orphan_filenames_names_to_mvs' ([string](@($nameFilenames | Where-Object {$mvsFilenames -notcontains $_}).Count))
    Add-Metric 'integrity.orphan_filenames_mvs_to_sha1' ([string](@($mvsFilenames | Where-Object {$sha1Filenames -notcontains $_}).Count))
    Add-Metric 'integrity.orphan_filenames_names_to_sha1' ([string](@($nameFilenames | Where-Object {$sha1Filenames -notcontains $_}).Count))
    Add-Metric 'integrity.orphan_filenames_mvs_to_sha256' ([string](@($mvsFilenames | Where-Object {$sha256Filenames -notcontains $_}).Count))
    Add-Metric 'integrity.orphan_filenames_names_to_sha256' ([string](@($nameFilenames | Where-Object {$sha256Filenames -notcontains $_}).Count))

    $unparsedTotal = 0
    foreach ($name in @('mvs.txt','mvs_names.txt','mvs.sha1','mvs.sha256','mvs_ids.txt','mvs_dates.txt')) {
        $count = @($Model.unparsed[$name]).Count
        $unparsedTotal += $count
        Add-Metric ('integrity.unparsed.' + $name) ([string]$count)
    }
    Add-Metric 'integrity.unparsed.total' ([string]$unparsedTotal)

    return @($rows)
}

function Emit-Summary {
    param([object[]]$Rows, [string]$OutputMode)
    if ($OutputMode -eq 'machine') {
        foreach ($row in $Rows) { Write-Line ($row.key + [char]9 + $row.value) }
    } else {
        foreach ($row in $Rows) { Write-Line ($row.key + ': ' + $row.value) }
    }
    return $Rows.Count
}

if ([string]::IsNullOrWhiteSpace($Dump) -or (@('--help','-h','-?','/h','/?') -contains $Dump)) {
    Show-Usage
    exit 0
}

if (-not [string]::IsNullOrEmpty($SearchSource) -and [string]::IsNullOrWhiteSpace($Search)) {
    Write-Err 'ERROR: Missing search-value.'
    Show-Usage
    [Environment]::Exit(2)
}

$DumpFolder = Resolve-DumpFolder $Dump $ScriptRoot
if ($null -eq $DumpFolder) { Fail 3 ('Dump folder not found: ' + $Dump) }

$requiredFiles = @()
switch ($Operation) {
    'detail_query' { $requiredFiles += 'mvs.txt' }
    'product_file_query' { $requiredFiles += 'mvs.txt' }
    'product_section_query' { $requiredFiles += 'mvs.txt' }
    'variant_query' { $requiredFiles += 'mvs_names.txt' }
    'note_query' { $requiredFiles += 'mvs_notes.html' }
    'unparsed_query' { $requiredFiles += $SourceFile }
    'hash_diagnostic' {
        foreach ($part in $SourceFile.Split('|')) { if ($part) { $requiredFiles += $part } }
    }
}
foreach ($required in $requiredFiles | Select-Object -Unique) {
    if (-not (Test-Path -LiteralPath (Join-Path $DumpFolder $required) -PathType Leaf)) {
        Fail 4 ('Missing required file: ' + (Join-Path $DumpFolder $required))
    }
}

try {
    $model = New-MvsModel $DumpFolder
    $emitted = 0

    switch ($Operation) {
        'detail_query' {
            $rows = @(Get-DetailRows $model $SearchSource $Search $AlgorithmFilter)
            $emitted = Emit-Rows $rows $Fields $Mode $true
            if ($emitted -eq 0) { [Environment]::Exit(1) }
        }
        'variant_query' {
            $rows = @(Get-VariantRows $model $SearchSource $Search)
            $emitted = Emit-Rows $rows $Fields $Mode $true
            if ($emitted -eq 0) { [Environment]::Exit(1) }
        }
        'hash_query' {
            $rows = @(Get-HashRows $model $SearchSource $Search $AlgorithmFilter)
            $emitted = Emit-Rows $rows $Fields $Mode $true
            if ($emitted -eq 0) { [Environment]::Exit(1) }
        }
        'product_file_query' {
            $rows = @(Get-ProductFileRows $model $SearchSource $Search)
            $emitted = Emit-Rows $rows $Fields $Mode $false
            if ($emitted -eq 0) { [Environment]::Exit(1) }
        }
        'product_section_query' {
            $sections = @(Get-ProductSections $model $SearchSource $Search)
            $emitted = Emit-ProductSections $sections $Mode
            if ($emitted -eq 0) { [Environment]::Exit(1) }
        }
        'note_query' {
            $rows = @(Get-NoteRows $model $SearchSource $Search)
            $emitted = Emit-Rows $rows $Fields $Mode $false
            if ($emitted -eq 0) { [Environment]::Exit(1) }
        }
        'unparsed_query' {
            $rows = @($model.unparsed[$SourceFile])
            if ($Mode -eq 'machine') {
                foreach ($row in $rows) { Write-Line ([string]$row.line + [char]9 + (Normalize-Scalar $row.raw)) }
            } else {
                foreach ($row in $rows) { Write-Line ('Line ' + $row.line + ': ' + $row.raw) }
            }
        }
        'hash_diagnostic' {
            Write-HashDiagnostic $model $DiagnosticKind $SourceFile $AlgorithmFilter
        }
        'summary_query' {
            $rows = @(Get-SummaryRows $model)
            [void](Emit-Summary $rows $Mode)
        }
        default {
            Fail 2 ('Unsupported operation: ' + $Operation)
        }
    }
    exit 0
} catch {
    Fail 5 $_.Exception.Message
}
:_MVSSingleDump_end
