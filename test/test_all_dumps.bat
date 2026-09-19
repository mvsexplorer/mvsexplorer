@echo off
:setup
REM Scoped because this standalone archive sweep harness embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=0.1.0"
set "app.name=test_all_dumps"
set "app.rc=0"
set "app.self=%~f0"
set "mvsa_archive_root=%~1"
set "mvsa_output_root=%~2"
set "mvsa_option=%~3"
set "mvsa_caller=%~nx0"
set "mvsa_script_root=%~dp0"
set "mvsa_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSArchiveSweep"
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

:_MVSArchiveSweep_start
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$ArchiveInput = [string]$env:mvsa_archive_root
$OutputInput = [string]$env:mvsa_output_root
$Option = [string]$env:mvsa_option
$Caller = [string]$env:mvsa_caller
$ScriptRoot = ([string]$env:mvsa_script_root).TrimEnd('\','/')
$Version = [string]$env:mvsa_version

function Write-Line {
    param([AllowEmptyString()][string]$Text)
    [Console]::Out.WriteLine($Text)
    if (-not [string]::IsNullOrWhiteSpace($script:ConsoleLog)) {
        [IO.File]::AppendAllText($script:ConsoleLog, $Text + [Environment]::NewLine, $utf8)
    }
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
    Write-Line ('MVS Explorer Toolkit archive-wide tool sweep ' + $Version)
    Write-Line ('Usage: ' + $Caller + ' mvs-dumps-root [results-folder] [--plan-only|--resume]')
    Write-Line 'Runs every public root .bat tool against the archive at its natural scope.'
    Write-Line 'Single-dump tools run once per snapshot; compare tools run on adjacent snapshots.'
    Write-Line 'Archive history/all-ever builders run once against the complete archive.'
    Write-Line 'Return codes 1 and 4 are recorded as NO_RESULT and SOURCE_MISSING, not runtime failures.'
    Write-Line 'Use --plan-only to build the complete invocation plan without launching public tools.'
    Write-Line 'Use --resume with an existing results folder to continue an interrupted matching plan.'
}

function Write-TextUtf8 {
    param([string]$Path, [AllowEmptyString()][string]$Text)
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Add-TextUtf8 {
    param([string]$Path, [AllowEmptyString()][string]$Text)
    [IO.File]::AppendAllText($Path, $Text, $utf8)
}

function Convert-TsvField {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    return $Value.Replace("`t", ' ').Replace("`r", ' ').Replace("`n", ' ')
}

function Resolve-ArchiveRoot {
    param([string]$Name)
    $candidates = New-Object System.Collections.ArrayList
    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        [void]$candidates.Add($Name)
        if (-not [IO.Path]::IsPathRooted($Name)) {
            [void]$candidates.Add((Join-Path (Get-Location).Path $Name))
            if (-not [string]::IsNullOrWhiteSpace($ScriptRoot)) {
                [void]$candidates.Add((Join-Path $ScriptRoot $Name))
                $projectRoot = Split-Path -Parent $ScriptRoot
                if (-not [string]::IsNullOrWhiteSpace($projectRoot)) {
                    [void]$candidates.Add((Join-Path $projectRoot $Name))
                }
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
                if ($wrapped.Count -gt 0) { return (Resolve-Path -LiteralPath $wrapper).Path }
            }
        } catch {
        }
    }
    return $null
}

function Resolve-PathFromCurrent {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    if ([IO.Path]::IsPathRooted($Name)) { return [IO.Path]::GetFullPath($Name) }
    return [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Name))
}

function New-UniqueResultsFolder {
    $base = Join-Path $ScriptRoot ('archive-sweep-results-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $candidate = $base
    $n = 1
    while (Test-Path -LiteralPath $candidate) {
        $candidate = $base + '-' + $n.ToString('D2')
        $n++
    }
    [void](New-Item -ItemType Directory -Path $candidate -Force)
    return $candidate
}

function Resolve-SnapshotDataPath {
    param([string]$SnapshotPath)
    $known = @('mvs.txt','mvs_ids.txt','mvs_dates.txt','mvs_names.txt','mvs_notes.html','mvs.sha1','mvs.sha256')
    foreach ($name in $known) {
        if (Test-Path -LiteralPath (Join-Path $SnapshotPath $name) -PathType Leaf) { return $SnapshotPath }
    }
    $nested = Join-Path $SnapshotPath 'mvs_dmp'
    if (Test-Path -LiteralPath $nested -PathType Container) {
        foreach ($name in $known) {
            if (Test-Path -LiteralPath (Join-Path $nested $name) -PathType Leaf) { return $nested }
        }
    }
    return $SnapshotPath
}

function Normalize-TitleKey {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    $decoded = [System.Net.WebUtility]::HtmlDecode($Value)
    return ([regex]::Replace($decoded, '\s+', ' ')).Trim()
}

function Convert-HeadingToText {
    param([AllowNull()][AllowEmptyString()][string]$Html)
    if ([string]::IsNullOrEmpty($Html)) { return '' }
    $text = [regex]::Replace($Html, '(?is)<[^>]+>', ' ')
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    $text = $text.Replace([char]0x00A0, ' ')
    return ([regex]::Replace($text, '\s+', ' ')).Trim()
}

function Get-SnapshotProfile {
    param([string]$DataPath)
    $profile = [ordered]@{
        product_any_id = ''
        product_any_title = ''
        product_file_id = ''
        product_file_title = ''
        product_filename = ''
        product_hash = ''
        date_id = ''
        date_title = ''
        date_value = ''
        note_title = ''
        note_product_id = ''
        note_product_title = ''
        note_product_date = ''
        variant_any_id = ''
        variant_any_title = ''
        variant_file_id = ''
        variant_file_title = ''
        variant_filename = ''
        variant_hash = ''
        hash_filename = ''
        hash_value = ''
    }

    $mvsPath = Join-Path $DataPath 'mvs.txt'
    if (Test-Path -LiteralPath $mvsPath -PathType Leaf) {
        $currentId = ''
        $currentTitle = ''
        foreach ($lineValue in Get-Content -LiteralPath $mvsPath -Encoding UTF8) {
            $line = [string]$lineValue
            if ($line -match '^---\s*(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*---\s*$') {
                $currentId = [string][int]$Matches.id
                $currentTitle = $Matches.title.Trim()
                if ([string]::IsNullOrEmpty($profile.product_any_id)) {
                    $profile.product_any_id = $currentId
                    $profile.product_any_title = $currentTitle
                }
                continue
            }
            if (-not [string]::IsNullOrEmpty($currentId) -and
                $line -match '^\s*(?<hash>[0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})\s+\*(?<filename>.+?)\s*$') {
                if ([string]::IsNullOrEmpty($profile.product_filename)) {
                    $profile.product_file_id = $currentId
                    $profile.product_file_title = $currentTitle
                    $profile.product_filename = $Matches.filename.Trim()
                    $profile.product_hash = $Matches.hash.ToLowerInvariant()
                }
                if ([string]::IsNullOrEmpty($profile.hash_value)) {
                    $profile.hash_filename = $Matches.filename.Trim()
                    $profile.hash_value = $Matches.hash.ToLowerInvariant()
                }
                if (-not [string]::IsNullOrEmpty($profile.product_filename) -and
                    -not [string]::IsNullOrEmpty($profile.hash_value)) { break }
            }
        }
    }

    $dateRows = New-Object System.Collections.ArrayList
    $datesPath = Join-Path $DataPath 'mvs_dates.txt'
    if (Test-Path -LiteralPath $datesPath -PathType Leaf) {
        foreach ($lineValue in Get-Content -LiteralPath $datesPath -Encoding UTF8) {
            $line = [string]$lineValue
            if ($line -match '^(?<date>.*?)\s+-\s+(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') {
                $row = [pscustomobject]@{
                    id = [string][int]$Matches.id
                    title = $Matches.title.Trim()
                    date = $Matches.date.Trim()
                    title_key = Normalize-TitleKey $Matches.title
                }
                [void]$dateRows.Add($row)
                if ([string]::IsNullOrEmpty($profile.date_id)) {
                    $profile.date_id = $row.id
                    $profile.date_title = $row.title
                    $profile.date_value = $row.date
                }
            }
        }
    }

    $notesPath = Join-Path $DataPath 'mvs_notes.html'
    $noteKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    if (Test-Path -LiteralPath $notesPath -PathType Leaf) {
        $rawNotes = [IO.File]::ReadAllText($notesPath)
        foreach ($match in [regex]::Matches($rawNotes, '(?is)<h1\b[^>]*>(?<title>.*?)</h1>')) {
            $noteTitle = Convert-HeadingToText $match.Groups['title'].Value
            if ([string]::IsNullOrWhiteSpace($noteTitle)) { continue }
            if ([string]::IsNullOrEmpty($profile.note_title)) { $profile.note_title = $noteTitle }
            [void]$noteKeys.Add((Normalize-TitleKey $noteTitle))
        }
    }
    if ($noteKeys.Count -gt 0) {
        foreach ($row in $dateRows) {
            if ($noteKeys.Contains($row.title_key)) {
                $profile.note_product_id = $row.id
                $profile.note_product_title = $row.title
                $profile.note_product_date = $row.date
                break
            }
        }
    }

    $namesPath = Join-Path $DataPath 'mvs_names.txt'
    if (Test-Path -LiteralPath $namesPath -PathType Leaf) {
        $currentId = ''
        $currentTitle = ''
        foreach ($lineValue in Get-Content -LiteralPath $namesPath -Encoding UTF8) {
            $line = [string]$lineValue
            if ($line -match '^---\s*(?<title>.*?)\s*\[ID:\s*(?<id>[^\]]+?)\s*\]\s*---\s*$') {
                $currentId = $Matches.id.Trim()
                $currentTitle = $Matches.title.Trim()
                if ([string]::IsNullOrEmpty($profile.variant_any_id)) {
                    $profile.variant_any_id = $currentId
                    $profile.variant_any_title = $currentTitle
                }
                continue
            }
            if (-not [string]::IsNullOrEmpty($currentId) -and
                $line -match '^\s*(?<hash>[0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})\s+\*(?<filename>.+?)\s*$') {
                $profile.variant_file_id = $currentId
                $profile.variant_file_title = $currentTitle
                $profile.variant_filename = $Matches.filename.Trim()
                $profile.variant_hash = $Matches.hash.ToLowerInvariant()
                break
            }
        }
    }

    if ([string]::IsNullOrEmpty($profile.hash_value)) {
        foreach ($manifest in @('mvs.sha1','mvs.sha256')) {
            $manifestPath = Join-Path $DataPath $manifest
            if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { continue }
            $length = if ($manifest -eq 'mvs.sha1') { 40 } else { 64 }
            foreach ($lineValue in Get-Content -LiteralPath $manifestPath -Encoding UTF8) {
                $line = [string]$lineValue
                $pattern = '^\s*(?<hash>[0-9A-Fa-f]{' + $length + '})\s+\*(?<filename>.+?)\s*$'
                if ($line -match $pattern) {
                    $profile.hash_filename = $Matches.filename.Trim()
                    $profile.hash_value = $Matches.hash.ToLowerInvariant()
                    break
                }
            }
            if (-not [string]::IsNullOrEmpty($profile.hash_value)) { break }
        }
    }

    if ([string]::IsNullOrEmpty($profile.product_file_id)) {
        $profile.product_file_id = $profile.product_any_id
        $profile.product_file_title = $profile.product_any_title
    }
    if ([string]::IsNullOrEmpty($profile.product_filename)) { $profile.product_filename = $profile.hash_filename }
    if ([string]::IsNullOrEmpty($profile.product_hash)) { $profile.product_hash = $profile.hash_value }
    if ([string]::IsNullOrEmpty($profile.variant_file_id)) {
        $profile.variant_file_id = $profile.variant_any_id
        $profile.variant_file_title = $profile.variant_any_title
    }

    return [pscustomobject]$profile
}

function Get-ToolMetadata {
    param([IO.FileInfo]$Tool)
    $name = [IO.Path]::GetFileNameWithoutExtension($Tool.Name)
    $text = [IO.File]::ReadAllText($Tool.FullName)
    $operation = ''
    $searchSource = ''
    $family = 'other'
    $m = [regex]::Match($text, '(?im)^set "mvsx_operation=([^"]*)"')
    if ($m.Success) {
        $family = 'single-complete'
        $operation = $m.Groups[1].Value
        $s = [regex]::Match($text, '(?im)^set "mvsx_search_source=([^"]*)"')
        if ($s.Success) { $searchSource = $s.Groups[1].Value }
    } else {
        $r = [regex]::Match($text, '(?im)^set "mvsr_source=([^"]*)"')
        if ($r.Success) {
            $family = 'relationship'
            $searchSource = $r.Groups[1].Value
        } elseif ($name -match '^lookup_mvs_.+_from_(id|title|date)$') {
            $family = 'lookup'
            $searchSource = $Matches[1]
        } elseif ($name -match '^(?:print|read)_mvs_dump_') {
            $family = 'scalar'
        } elseif ($name -match '^find_mvs_') {
            $family = 'diagnostic'
        }
    }
    return [pscustomobject]@{
        name = $name
        file = $Tool.Name
        path = $Tool.FullName
        family = $family
        operation = $operation
        search_source = $searchSource
    }
}

function New-SearchChoice {
    param([string]$Source, [AllowEmptyString()][string]$Value, [string]$Origin)
    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        return [pscustomobject]@{ source=$Source; value=$Value; origin=$Origin }
    }
    switch ($Source) {
        'hash'     { return [pscustomobject]@{ source=$Source; value=('0' * 40); origin='valid-no-match-fallback' } }
        'filename' { return [pscustomobject]@{ source=$Source; value='__MVS_ARCHIVE_SWEEP_NO_FILENAME__.bin'; origin='valid-no-match-fallback' } }
        'id'       { return [pscustomobject]@{ source=$Source; value='0'; origin='valid-no-match-fallback' } }
        default    { return [pscustomobject]@{ source=$Source; value='__MVS_ARCHIVE_SWEEP_NO_VALUE__'; origin='valid-no-match-fallback' } }
    }
}

function Get-SearchChoice {
    param([object]$Metadata, [object]$Profile)
    $source = [string]$Metadata.search_source
    if ([string]::IsNullOrEmpty($source)) {
        return [pscustomobject]@{ source=''; value=''; origin='' }
    }

    if ($Metadata.family -eq 'lookup') {
        switch -Regex ($Metadata.name) {
            '^lookup_mvs_title_from_id$'    { return New-SearchChoice $source $Profile.date_id 'mvs_dates:first-id' }
            '^lookup_mvs_title_from_date$'  { return New-SearchChoice $source $Profile.date_value 'mvs_dates:first-date' }
            '^lookup_mvs_note_from_id$' {
                if (-not [string]::IsNullOrEmpty($Profile.note_product_id)) { return New-SearchChoice $source $Profile.note_product_id 'note-linked:id' }
                return [pscustomobject]@{ source=$source; value='*'; origin='wildcard-fallback' }
            }
            '^lookup_mvs_note_from_title$' {
                if (-not [string]::IsNullOrEmpty($Profile.note_product_title)) { return New-SearchChoice $source $Profile.note_product_title 'note-linked:title' }
                return [pscustomobject]@{ source=$source; value='*'; origin='wildcard-fallback' }
            }
            '^lookup_mvs_note_from_date$' {
                if (-not [string]::IsNullOrEmpty($Profile.note_product_date)) { return New-SearchChoice $source $Profile.note_product_date 'note-linked:date' }
                return [pscustomobject]@{ source=$source; value='*'; origin='wildcard-fallback' }
            }
            '^lookup_mvs_date_from_id$'      { return New-SearchChoice $source $Profile.date_id 'mvs_dates:first-id' }
            '^lookup_mvs_date_from_title$'   { return New-SearchChoice $source $Profile.date_title 'mvs_dates:first-title' }
        }
    }

    if ($Metadata.family -eq 'relationship') {
        if ($source -eq 'filename') { return New-SearchChoice $source $Profile.product_filename 'mvs.txt:first-product-file' }
        if ($source -eq 'hash') { return New-SearchChoice $source $Profile.product_hash 'mvs.txt:first-product-hash' }
    }

    if ($Metadata.family -eq 'single-complete') {
        if ($Metadata.operation -eq 'variant_query') {
            if ($source -eq 'id') { return New-SearchChoice $source $Profile.variant_file_id 'mvs_names:first-variant-id' }
            if ($source -eq 'filename') { return New-SearchChoice $source $Profile.variant_filename 'mvs_names:first-variant-filename' }
            if ($source -eq 'hash') { return New-SearchChoice $source $Profile.variant_hash 'mvs_names:first-variant-hash' }
        }
        if ($Metadata.operation -eq 'note_query') {
            if ($source -eq 'title') { return New-SearchChoice $source $Profile.note_title 'mvs_notes:first-title' }
        }
        if ($Metadata.operation -eq 'hash_query') {
            if ($source -eq 'filename') { return New-SearchChoice $source $Profile.hash_filename 'first-hash-record:filename' }
            if ($source -eq 'hash') { return New-SearchChoice $source $Profile.hash_value 'first-hash-record:hash' }
        }
        if ($Metadata.operation -eq 'product_section_query') {
            if ($source -eq 'id') { return New-SearchChoice $source $Profile.product_any_id 'mvs.txt:first-section-id' }
            if ($source -eq 'title') { return New-SearchChoice $source $Profile.product_any_title 'mvs.txt:first-section-title' }
        }
        if ($source -eq 'id') { return New-SearchChoice $source $Profile.product_file_id 'mvs.txt:first-file-owner-id' }
        if ($source -eq 'title') { return New-SearchChoice $source $Profile.product_file_title 'mvs.txt:first-file-owner-title' }
        if ($source -eq 'filename') { return New-SearchChoice $source $Profile.product_filename 'mvs.txt:first-product-file' }
        if ($source -eq 'hash') { return New-SearchChoice $source $Profile.product_hash 'mvs.txt:first-product-hash' }
    }

    return New-SearchChoice $source '' 'unclassified-search'
}

function Add-PlanEntry {
    param(
        [System.Collections.ArrayList]$Plan,
        [string]$Scope,
        [string]$Snapshot,
        [string]$NextSnapshot,
        [string]$DataPath,
        [string]$NextDataPath,
        [object]$Tool,
        [object]$Search
    )
    [void]$Plan.Add([pscustomobject]@{
        index = $Plan.Count + 1
        scope = $Scope
        snapshot = $Snapshot
        next_snapshot = $NextSnapshot
        data_path = $DataPath
        next_data_path = $NextDataPath
        tool = $Tool.name
        tool_file = $Tool.file
        tool_path = $Tool.path
        family = $Tool.family
        operation = $Tool.operation
        search_source = $Search.source
        search_value = $Search.value
        search_origin = $Search.origin
    })
}

function Get-PlanText {
    param([System.Collections.ArrayList]$Plan)
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append("index`tscope`tsnapshot`tnext_snapshot`ttool`tfamily`toperation`tsearch_source`tsearch_value`tsearch_origin`n")
    foreach ($entry in $Plan) {
        $fields = @(
            [string]$entry.index,
            $entry.scope,
            $entry.snapshot,
            $entry.next_snapshot,
            $entry.tool,
            $entry.family,
            $entry.operation,
            $entry.search_source,
            $entry.search_value,
            $entry.search_origin
        ) | ForEach-Object { Convert-TsvField ([string]$_) }
        [void]$sb.Append(($fields -join [char]9) + "`n")
    }
    return $sb.ToString()
}

function Get-Sha256Text {
    param([string]$Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $utf8.GetBytes($Text)
        $hash = $sha.ComputeHash($bytes)
        return ([BitConverter]::ToString($hash)).Replace('-','').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-FileByteLength {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 0 }
    return (Get-Item -LiteralPath $Path).Length
}

function Get-RunStatus {
    param([string]$Scope, [int]$Rc)
    if ($Rc -eq 0) { return 'PASS' }
    if ($Scope -ne 'archive' -and $Rc -eq 1) { return 'NO_RESULT' }
    if ($Scope -ne 'archive' -and $Rc -eq 4) { return 'SOURCE_MISSING' }
    return 'FAIL'
}

function Get-FailureStem {
    param([object]$Entry)
    $snapshot = if ([string]::IsNullOrEmpty($Entry.next_snapshot)) { $Entry.snapshot } else { $Entry.snapshot + '_TO_' + $Entry.next_snapshot }
    $safe = ($snapshot + '__' + $Entry.tool) -replace '[^A-Za-z0-9._-]+','_'
    return ('{0:D5}_{1}' -f [int]$Entry.index, $safe)
}

function Save-FailureArtifacts {
    param([object]$Entry, [int]$Rc, [string]$StdoutTemp, [string]$StderrTemp, [string]$FailureFolder)
    $stem = Get-FailureStem $Entry
    $stdoutPath = Join-Path $FailureFolder ($stem + '.stdout.txt')
    $stderrPath = Join-Path $FailureFolder ($stem + '.stderr.txt')
    $metaPath = Join-Path $FailureFolder ($stem + '.meta.txt')
    if (Test-Path -LiteralPath $StdoutTemp -PathType Leaf) { Copy-Item -LiteralPath $StdoutTemp -Destination $stdoutPath -Force }
    else { Write-TextUtf8 $stdoutPath '' }
    if (Test-Path -LiteralPath $StderrTemp -PathType Leaf) { Copy-Item -LiteralPath $StderrTemp -Destination $stderrPath -Force }
    else { Write-TextUtf8 $stderrPath '' }
    $meta = @(
        'Index: ' + $Entry.index,
        'Scope: ' + $Entry.scope,
        'Snapshot: ' + $Entry.snapshot,
        'Next snapshot: ' + $Entry.next_snapshot,
        'Tool: ' + $Entry.tool_file,
        'Search source: ' + $Entry.search_source,
        'Search value: ' + $Entry.search_value,
        'Search origin: ' + $Entry.search_origin,
        'Return code: ' + $Rc
    ) -join [Environment]::NewLine
    Write-TextUtf8 $metaPath ($meta + [Environment]::NewLine)
}

function Add-RunRow {
    param([string]$RunsPath, [object]$Entry, [string]$Status, [int]$Rc, [long]$StdoutBytes, [long]$StderrBytes, [long]$ElapsedMs)
    $fields = @(
        [string]$Entry.index,
        $Entry.scope,
        $Entry.snapshot,
        $Entry.next_snapshot,
        $Entry.tool,
        $Entry.search_source,
        $Entry.search_value,
        $Entry.search_origin,
        $Status,
        [string]$Rc,
        [string]$StdoutBytes,
        [string]$StderrBytes,
        [string]$ElapsedMs
    ) | ForEach-Object { Convert-TsvField ([string]$_) }
    Add-TextUtf8 $RunsPath (($fields -join [char]9) + [Environment]::NewLine)
}

function Invoke-One {
    param([object]$Entry, [string]$ResultsFolder, [string]$ArchiveRoot, [string]$ArchiveOutput, [string]$RunsPath, [string]$FailureFolder)
    $stdoutTemp = Join-Path $ResultsFolder '_current.stdout.tmp'
    $stderrTemp = Join-Path $ResultsFolder '_current.stderr.tmp'
    Remove-Item -LiteralPath $stdoutTemp,$stderrTemp -Force -ErrorAction SilentlyContinue

    $toolArgs = New-Object System.Collections.ArrayList
    if ($Entry.scope -eq 'single') {
        [void]$toolArgs.Add($Entry.data_path)
        if (-not [string]::IsNullOrEmpty($Entry.search_source)) { [void]$toolArgs.Add($Entry.search_value) }
    } elseif ($Entry.scope -eq 'compare') {
        [void]$toolArgs.Add($Entry.data_path)
        [void]$toolArgs.Add($Entry.next_data_path)
    } elseif ($Entry.scope -eq 'archive') {
        [void]$toolArgs.Add($ArchiveRoot)
        [void]$toolArgs.Add($ArchiveOutput)
    } else {
        throw ('Unknown plan scope: ' + $Entry.scope)
    }

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $rc = 5
    try {
        $global:LASTEXITCODE = 0
        $oldPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & $Entry.tool_path @toolArgs 1> $stdoutTemp 2> $stderrTemp
            if ($null -eq $LASTEXITCODE) { $rc = 0 } else { $rc = [int]$LASTEXITCODE }
        } finally {
            $ErrorActionPreference = $oldPreference
        }
    } catch {
        $rc = 5
        Add-TextUtf8 $stderrTemp (($_ | Out-String) + [Environment]::NewLine)
    } finally {
        $sw.Stop()
    }

    $stdoutBytes = Get-FileByteLength $stdoutTemp
    $stderrBytes = Get-FileByteLength $stderrTemp
    $status = Get-RunStatus $Entry.scope $rc
    Add-RunRow $RunsPath $Entry $status $rc $stdoutBytes $stderrBytes $sw.ElapsedMilliseconds
    if ($status -eq 'FAIL') {
        Save-FailureArtifacts $Entry $rc $stdoutTemp $stderrTemp $FailureFolder
        Write-Line ('[FAIL] #' + $Entry.index + ' ' + $Entry.scope + ' ' + $Entry.snapshot + ' ' + $Entry.tool + ' rc=' + $rc)
    }
    Remove-Item -LiteralPath $stdoutTemp,$stderrTemp -Force -ErrorAction SilentlyContinue
    return $status
}

function Get-ExistingRunState {
    param([string]$RunsPath)
    $done = New-Object 'System.Collections.Generic.HashSet[int]'
    $counts = @{ PASS=0; NO_RESULT=0; SOURCE_MISSING=0; FAIL=0 }
    if (-not (Test-Path -LiteralPath $RunsPath -PathType Leaf)) {
        return [pscustomobject]@{ done=$done; counts=$counts }
    }
    foreach ($row in Import-Csv -LiteralPath $RunsPath -Delimiter "`t") {
        $idx = 0
        if ([int]::TryParse([string]$row.index, [ref]$idx)) { [void]$done.Add($idx) }
        $status = [string]$row.status
        if ($counts.ContainsKey($status)) { $counts[$status]++ }
    }
    return [pscustomobject]@{ done=$done; counts=$counts }
}

function Write-Summary {
    param([string]$Path, [string]$Mode, [int]$Snapshots, [int]$SingleTools, [int]$CompareTools, [int]$ArchiveTools, [int]$Planned, [hashtable]$Counts, [int]$Completed)
    $remaining = $Planned - $Completed
    $text = @(
        'MVS Explorer Toolkit archive-wide tool sweep',
        '',
        'Mode: ' + $Mode,
        'Snapshots: ' + $Snapshots,
        'Single-snapshot public tools: ' + $SingleTools,
        'Compare public tools: ' + $CompareTools,
        'Archive public tools: ' + $ArchiveTools,
        'Planned invocations: ' + $Planned,
        'Completed invocations: ' + $Completed,
        'Remaining invocations: ' + $remaining,
        'PASS: ' + $Counts.PASS,
        'NO_RESULT: ' + $Counts.NO_RESULT,
        'SOURCE_MISSING: ' + $Counts.SOURCE_MISSING,
        'FAIL: ' + $Counts.FAIL
    ) -join [Environment]::NewLine
    Write-TextUtf8 $Path ($text + [Environment]::NewLine)
}

if (@('--help','-h','-?','/h','/?') -contains $ArchiveInput) {
    Show-Usage
    [Environment]::Exit(0)
}

if ([string]::IsNullOrWhiteSpace($ArchiveInput)) {
    Show-Usage
    Fail 2 'Missing mvs-dumps-root.'
}

if ($OutputInput -in @('--plan-only','--resume')) {
    if (-not [string]::IsNullOrWhiteSpace($Option)) { Fail 2 'Too many options.' }
    $Option = $OutputInput
    $OutputInput = ''
}
if (-not [string]::IsNullOrWhiteSpace($Option) -and $Option -notin @('--plan-only','--resume')) {
    Fail 2 ('Unknown option: ' + $Option)
}
if ($Option -eq '--resume' -and [string]::IsNullOrWhiteSpace($OutputInput)) {
    Fail 2 '--resume requires an existing results-folder argument.'
}

$ArchiveRoot = Resolve-ArchiveRoot $ArchiveInput
if ([string]::IsNullOrWhiteSpace($ArchiveRoot)) { Fail 3 ('Archive root not found or contains no mvs_* snapshots: ' + $ArchiveInput) }

$ProjectRoot = Split-Path -Parent $ScriptRoot
if ([string]::IsNullOrWhiteSpace($ProjectRoot) -or -not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    Fail 3 'Project root could not be resolved from test script location.'
}

$publicFiles = @(Get-ChildItem -LiteralPath $ProjectRoot -File -Filter '*.bat' -ErrorAction Stop | Sort-Object Name)
if ($publicFiles.Count -eq 0) { Fail 4 'No public root .bat tools found.' }

$singleFiles = @($publicFiles | Where-Object { $_.Name -notlike 'compare_mvs_dump_*.bat' -and $_.Name -notin @('build_mvs_dump_change_history.bat','build_mvs_dump_all_ever.bat') })
$compareFiles = @($publicFiles | Where-Object { $_.Name -like 'compare_mvs_dump_*.bat' })
$archiveFileNames = @('build_mvs_dump_change_history.bat','build_mvs_dump_all_ever.bat')
$archiveFiles = New-Object System.Collections.ArrayList
foreach ($archiveFileName in $archiveFileNames) {
    $candidate = Join-Path $ProjectRoot $archiveFileName
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { [void]$archiveFiles.Add((Get-Item -LiteralPath $candidate)) }
}

$snapshotDirs = @(Get-ChildItem -LiteralPath $ArchiveRoot -Directory -ErrorAction Stop |
    Where-Object { $_.Name -match '^mvs_\d{4}-\d{2}-\d{2}(?:-\d{4})?(?:_\d+)?$' } |
    Sort-Object Name)
if ($snapshotDirs.Count -eq 0) { Fail 3 'No snapshot folders found.' }

if ([string]::IsNullOrWhiteSpace($OutputInput)) {
    $ResultsFolder = New-UniqueResultsFolder
} else {
    $ResultsFolder = Resolve-PathFromCurrent $OutputInput
    if ($Option -eq '--resume') {
        if (-not (Test-Path -LiteralPath $ResultsFolder -PathType Container)) { Fail 3 ('Resume results folder does not exist: ' + $ResultsFolder) }
    } else {
        if (Test-Path -LiteralPath $ResultsFolder) { Fail 2 ('Results folder already exists; use --resume or choose a new folder: ' + $ResultsFolder) }
        [void](New-Item -ItemType Directory -Path $ResultsFolder -Force)
    }
}

$script:ConsoleLog = Join-Path $ResultsFolder 'console.log'
$planPath = Join-Path $ResultsFolder 'plan.tsv'
$planHashPath = Join-Path $ResultsFolder 'plan-sha256.txt'
$runsPath = Join-Path $ResultsFolder 'runs.tsv'
$summaryPath = Join-Path $ResultsFolder 'summary.txt'
$snapshotsPath = Join-Path $ResultsFolder 'snapshots.tsv'
$runInfoPath = Join-Path $ResultsFolder 'run-info.txt'
$failureFolder = Join-Path $ResultsFolder 'failures'
$archiveOutput = Join-Path $ResultsFolder 'archive-output'
if (-not (Test-Path -LiteralPath $failureFolder -PathType Container)) { [void](New-Item -ItemType Directory -Path $failureFolder -Force) }

if ($Option -ne '--resume') {
    Write-TextUtf8 $script:ConsoleLog ''
    $readme = @(
        'MVS Explorer Toolkit Archive Sweep Results',
        '',
        'plan.tsv          Complete deterministic invocation plan.',
        'plan-sha256.txt   SHA-256 of plan.tsv content.',
        'snapshots.tsv     Snapshot names and resolved data directories.',
        'runs.tsv          One row per completed public-tool invocation.',
        'summary.txt       Aggregate status counts.',
        'run-info.txt      Environment and archive/project paths.',
        'console.log       Progress/failure transcript.',
        'failures\         stdout/stderr/meta retained only for FAIL rows.',
        'archive-output\   Change-history and all-ever builder output.',
        '',
        'Status meanings:',
        '  PASS            return code 0.',
        '  NO_RESULT       return code 1 from single/compare scope.',
        '  SOURCE_MISSING  return code 4 from single/compare scope.',
        '  FAIL            any other code, or any nonzero archive-builder code.'
    ) -join [Environment]::NewLine
    Write-TextUtf8 (Join-Path $ResultsFolder 'README.txt') ($readme + [Environment]::NewLine)
}

Write-Line ('Archive: ' + $ArchiveRoot)
Write-Line ('Project: ' + $ProjectRoot)
Write-Line ('Snapshots discovered: ' + $snapshotDirs.Count)
Write-Line ('Public tools: single=' + $singleFiles.Count + ' compare=' + $compareFiles.Count + ' archive=' + $archiveFiles.Count)

$singleMetadata = New-Object System.Collections.ArrayList
foreach ($file in $singleFiles) { [void]$singleMetadata.Add((Get-ToolMetadata $file)) }
$compareMetadata = New-Object System.Collections.ArrayList
foreach ($file in $compareFiles) {
    [void]$compareMetadata.Add([pscustomobject]@{
        name=[IO.Path]::GetFileNameWithoutExtension($file.Name)
        file=$file.Name
        path=$file.FullName
        family='compare'
        operation=''
        search_source=''
    })
}
$archiveMetadata = New-Object System.Collections.ArrayList
foreach ($file in $archiveFiles) {
    [void]$archiveMetadata.Add([pscustomobject]@{
        name=[IO.Path]::GetFileNameWithoutExtension($file.Name)
        file=$file.Name
        path=$file.FullName
        family='archive'
        operation=''
        search_source=''
    })
}

$snapshots = New-Object System.Collections.ArrayList
$snapshotSb = New-Object Text.StringBuilder
[void]$snapshotSb.Append("index`tsnapshot`tsnapshot_path`tdata_path`tnested_mvs_dmp`tmvs.txt`tmvs_ids.txt`tmvs_dates.txt`tmvs_names.txt`tmvs_notes.html`tmvs.sha1`tmvs.sha256`n")
for ($i = 0; $i -lt $snapshotDirs.Count; $i++) {
    $dir = $snapshotDirs[$i]
    $dataPath = Resolve-SnapshotDataPath $dir.FullName
    Write-Line ('Planning snapshot ' + ($i + 1) + '/' + $snapshotDirs.Count + ': ' + $dir.Name)
    $profile = Get-SnapshotProfile $dataPath
    $snapshot = [pscustomobject]@{ name=$dir.Name; snapshot_path=$dir.FullName; data_path=$dataPath; profile=$profile }
    [void]$snapshots.Add($snapshot)
    $nested = if ($dataPath -ne $dir.FullName) { '1' } else { '0' }
    $presence = New-Object System.Collections.ArrayList
    foreach ($sourceName in @('mvs.txt','mvs_ids.txt','mvs_dates.txt','mvs_names.txt','mvs_notes.html','mvs.sha1','mvs.sha256')) {
        [void]$presence.Add($(if (Test-Path -LiteralPath (Join-Path $dataPath $sourceName) -PathType Leaf) { '1' } else { '0' }))
    }
    $snapshotFields = @([string]($i+1),$dir.Name,$dir.FullName,$dataPath,$nested) + @($presence)
    $snapshotFields = $snapshotFields | ForEach-Object { Convert-TsvField ([string]$_) }
    [void]$snapshotSb.Append(($snapshotFields -join [char]9) + "`n")
}
Write-TextUtf8 $snapshotsPath $snapshotSb.ToString()

$plan = New-Object System.Collections.ArrayList
foreach ($snapshot in $snapshots) {
    foreach ($tool in $singleMetadata) {
        $search = Get-SearchChoice $tool $snapshot.profile
        Add-PlanEntry $plan 'single' $snapshot.name '' $snapshot.data_path '' $tool $search
    }
}
for ($i = 0; $i -lt ($snapshots.Count - 1); $i++) {
    $from = $snapshots[$i]
    $to = $snapshots[$i + 1]
    foreach ($tool in $compareMetadata) {
        $search = [pscustomobject]@{ source=''; value=''; origin='' }
        Add-PlanEntry $plan 'compare' $from.name $to.name $from.data_path $to.data_path $tool $search
    }
}
foreach ($tool in $archiveMetadata) {
    $search = [pscustomobject]@{ source=''; value=''; origin='' }
    Add-PlanEntry $plan 'archive' '(archive)' '' $ArchiveRoot '' $tool $search
}

$planText = Get-PlanText $plan
$planHash = Get-Sha256Text $planText
if ($Option -eq '--resume') {
    if (-not (Test-Path -LiteralPath $planHashPath -PathType Leaf)) { Fail 2 'Resume folder has no plan-sha256.txt.' }
    $existingHash = ([IO.File]::ReadAllText($planHashPath)).Trim()
    if ($existingHash -ne $planHash) { Fail 2 'Resume plan does not match the current archive/project/tool set.' }
} else {
    Write-TextUtf8 $planPath $planText
    Write-TextUtf8 $planHashPath ($planHash + [Environment]::NewLine)
}

$runInfo = @(
    'Sweep script: ' + $Caller,
    'Sweep version: ' + $Version,
    'Mode: ' + $(if ($Option -eq '--plan-only') { 'plan-only' } elseif ($Option -eq '--resume') { 'resume' } else { 'execute' }),
    'Archive root: ' + $ArchiveRoot,
    'Project root: ' + $ProjectRoot,
    'Results folder: ' + $ResultsFolder,
    'Computer: ' + $env:COMPUTERNAME,
    'User: ' + $env:USERNAME,
    'OS: ' + [Environment]::OSVersion.VersionString,
    'PowerShell: ' + $PSVersionTable.PSVersion.ToString(),
    'CLR: ' + [Environment]::Version.ToString(),
    'Snapshots: ' + $snapshots.Count,
    'Single tools: ' + $singleFiles.Count,
    'Compare tools: ' + $compareFiles.Count,
    'Archive tools: ' + $archiveFiles.Count,
    'Planned invocations: ' + $plan.Count,
    'Plan SHA-256: ' + $planHash
) -join [Environment]::NewLine
Write-TextUtf8 $runInfoPath ($runInfo + [Environment]::NewLine)

$emptyCounts = @{ PASS=0; NO_RESULT=0; SOURCE_MISSING=0; FAIL=0 }
if ($Option -eq '--plan-only') {
    Write-Summary $summaryPath 'plan-only' $snapshots.Count $singleFiles.Count $compareFiles.Count $archiveFiles.Count $plan.Count $emptyCounts 0
    Write-Line ('Plan-only complete: ' + $plan.Count + ' invocations.')
    Write-Line ('Results: ' + $ResultsFolder)
    [Environment]::Exit(0)
}

if ($Option -ne '--resume') {
    $runsHeader = "index`tscope`tsnapshot`tnext_snapshot`ttool`tsearch_source`tsearch_value`tsearch_origin`tstatus`trc`tstdout_bytes`tstderr_bytes`telapsed_ms`n"
    Write-TextUtf8 $runsPath $runsHeader
}
$state = Get-ExistingRunState $runsPath
$done = $state.done
$counts = $state.counts
$completed = $done.Count

Write-Line ('Planned invocations: ' + $plan.Count)
if ($Option -eq '--resume') { Write-Line ('Already completed: ' + $completed) }

$currentSnapshot = ''
foreach ($entry in $plan) {
    if ($done.Contains([int]$entry.index)) { continue }
    if ($entry.scope -eq 'single' -and $entry.snapshot -ne $currentSnapshot) {
        $currentSnapshot = $entry.snapshot
        Write-Line ('=== Snapshot ' + $currentSnapshot + ' ===')
    } elseif ($entry.scope -eq 'compare' -and ($entry.snapshot + ' -> ' + $entry.next_snapshot) -ne $currentSnapshot) {
        $currentSnapshot = $entry.snapshot + ' -> ' + $entry.next_snapshot
        Write-Line ('=== Compare ' + $currentSnapshot + ' ===')
    } elseif ($entry.scope -eq 'archive' -and $currentSnapshot -ne '(archive)') {
        $currentSnapshot = '(archive)'
        Write-Line '=== Archive builders ==='
        if (-not (Test-Path -LiteralPath $archiveOutput -PathType Container)) { [void](New-Item -ItemType Directory -Path $archiveOutput -Force) }
    }

    $status = Invoke-One $entry $ResultsFolder $ArchiveRoot $archiveOutput $runsPath $failureFolder
    if ($counts.ContainsKey($status)) { $counts[$status]++ }
    [void]$done.Add([int]$entry.index)
    $completed++
    if (($completed % 100) -eq 0 -or $completed -eq $plan.Count) {
        Write-Line ('Progress: ' + $completed + '/' + $plan.Count + ' PASS=' + $counts.PASS + ' NO_RESULT=' + $counts.NO_RESULT + ' SOURCE_MISSING=' + $counts.SOURCE_MISSING + ' FAIL=' + $counts.FAIL)
    }
    Write-Summary $summaryPath $(if ($Option -eq '--resume') { 'resume' } else { 'execute' }) $snapshots.Count $singleFiles.Count $compareFiles.Count $archiveFiles.Count $plan.Count $counts $completed
}

Write-Summary $summaryPath $(if ($Option -eq '--resume') { 'resume' } else { 'execute' }) $snapshots.Count $singleFiles.Count $compareFiles.Count $archiveFiles.Count $plan.Count $counts $completed
Write-Line ('SUMMARY: PASS=' + $counts.PASS + ' NO_RESULT=' + $counts.NO_RESULT + ' SOURCE_MISSING=' + $counts.SOURCE_MISSING + ' FAIL=' + $counts.FAIL)
Write-Line ('Results: ' + $ResultsFolder)
if ($counts.FAIL -gt 0) { [Environment]::Exit(1) }
[Environment]::Exit(0)
:_MVSArchiveSweep_end
