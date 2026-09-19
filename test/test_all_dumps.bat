@echo off
:setup
REM Scoped because this standalone archive sweep harness embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=0.4.4"
set "app.name=test_all_dumps"
set "app.rc=0"
set "app.self=%~f0"
set "mvsa_archive_root=%~1"
set "mvsa_arg2=%~2"
set "mvsa_arg3=%~3"
set "mvsa_arg4=%~4"
set "mvsa_arg5=%~5"
set "mvsa_arg6=%~6"
set "mvsa_arg7=%~7"
set "mvsa_arg8=%~8"
set "mvsa_arg9=%~9"
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
$RawArgs = @(
    [string]$env:mvsa_arg2,[string]$env:mvsa_arg3,[string]$env:mvsa_arg4,[string]$env:mvsa_arg5,
    [string]$env:mvsa_arg6,[string]$env:mvsa_arg7,[string]$env:mvsa_arg8,[string]$env:mvsa_arg9
)
$OutputInput = ''
$PlanOnly = $false
$Resume = $false
$Executor = 'fast-combined'
$Workers = [Math]::Min(4,[Math]::Max(1,[int][Math]::Ceiling([Environment]::ProcessorCount / 2.0)))
$GenerateReport = $true
$ExclusionsInput = ''
$UseCache = $true
$CacheInput = ''
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
    Write-Line ('Usage: ' + $Caller + ' mvs-dumps-root [results-folder] [--plan-only] [--resume] [--external-tools] [--workers N] [--exclusions FILE] [--no-report] [--cache-folder DIR] [--no-cache]')
    Write-Line 'Default executor: fast-combined (indexed shared parse, logical status validation).'
    Write-Line '--external-tools executes every public .bat wrapper literally.'
    Write-Line '--workers N controls bounded parallel snapshot workers in fast mode (default: auto up to 4).'
    Write-Line '--exclusions FILE supplies non-destructive canonical-analysis exclusions; evidence is still ingested.'
    Write-Line '--no-report skips interactive HTML generation.'
    Write-Line '--cache-folder DIR reuses content-addressed snapshot results across runs; --no-cache disables it.'
    Write-Line 'Single-dump logical checks run once per snapshot; compare checks use adjacent snapshots.'
    Write-Line 'Fast mode builds history/all-ever together in one streaming archive pass; --external-tools runs both public builders literally.'
    Write-Line 'Return codes 1 and 4 are recorded as NO_RESULT and SOURCE_MISSING, not runtime failures.'
    Write-Line '--plan-only writes the deterministic plan without executing checks.'
    Write-Line '--resume requires an existing matching results folder; executor identity is part of the plan hash.'
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
        foreach ($match in [regex]::Matches($rawNotes, '(?is)<h[13]\b[^>]*>(?<title>.*?)</h[13]>')) {
            $noteTitle = Convert-HeadingToText $match.Groups['title'].Value
            if ($noteTitle -match '^(?<title>.*?)\s*\[ID:\s*[^\]]+?\s*\]\s*$') {
                $noteTitle = Convert-HeadingToText $Matches.title
            }
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

    function Get-SetValue {
        param([string]$Variable)
        $m = [regex]::Match($text, '(?im)^set "' + [regex]::Escape($Variable) + '=([^"]*)"')
        if ($m.Success) { return $m.Groups[1].Value }
        return ''
    }

    $operation = ''
    $searchSource = ''
    $family = 'other'
    $fields = ''
    $algorithmFilter = ''
    $sourceFile = ''
    $diagnosticKind = ''
    $targetField = ''

    $operation = Get-SetValue 'mvsx_operation'
    if (-not [string]::IsNullOrEmpty($operation)) {
        $family = 'single-complete'
        $searchSource = Get-SetValue 'mvsx_search_source'
        $fields = Get-SetValue 'mvsx_fields'
        $algorithmFilter = Get-SetValue 'mvsx_algorithm_filter'
        $sourceFile = Get-SetValue 'mvsx_source_file'
        $diagnosticKind = Get-SetValue 'mvsx_diagnostic_kind'
    } else {
        $relationshipSource = Get-SetValue 'mvsr_source'
        if (-not [string]::IsNullOrEmpty($relationshipSource)) {
            $family = 'relationship'
            $searchSource = $relationshipSource
            $fields = Get-SetValue 'mvsr_fields'
        } else {
            $lookupSource = Get-SetValue 'mvsl_source'
            if (-not [string]::IsNullOrEmpty($lookupSource)) {
                $family = 'lookup'
                $searchSource = $lookupSource
                $targetField = Get-SetValue 'mvsl_target'
            } else {
                $scalarFields = Get-SetValue 'mvsq_fields'
                if (-not [string]::IsNullOrEmpty($scalarFields)) {
                    $family = 'scalar'
                    $fields = $scalarFields
                } else {
                    $compareSource = Get-SetValue 'mvsc_source_file'
                    if (-not [string]::IsNullOrEmpty($compareSource)) {
                        $family = 'compare'
                        $sourceFile = $compareSource
                    } else {
                    $diagSource = Get-SetValue 'mvsd_source'
                    if (-not [string]::IsNullOrEmpty($diagSource)) {
                        $family = 'diagnostic'
                        $sourceFile = $diagSource
                        $target = Get-SetValue 'mvsd_target'
                        if (-not [string]::IsNullOrEmpty($target)) {
                            $sourceFile = $sourceFile + '|' + $target
                        }
                        $diagnosticKind = Get-SetValue 'mvsd_operation'
                    }
                    }
                }
            }
        }
    }

    return [pscustomobject]@{
        name = $name
        file = $Tool.Name
        path = $Tool.FullName
        family = $family
        operation = $operation
        search_source = $searchSource
        fields = $fields
        algorithm_filter = $algorithmFilter
        source_file = $sourceFile
        diagnostic_kind = $diagnosticKind
        target_field = $targetField
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
        executor = $Executor
        engine_version = $Version
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
        fields = $Tool.fields
        algorithm_filter = $Tool.algorithm_filter
        source_file = $Tool.source_file
        diagnostic_kind = $Tool.diagnostic_kind
        target_field = $Tool.target_field
        search_source = $Search.source
        search_value = $Search.value
        search_origin = $Search.origin
    })
}

function Get-PlanText {
    param([object[]]$Plan)
    $columns = @(
        'index','executor','engine_version','scope','snapshot','next_snapshot','tool','family','operation',
        'fields','algorithm_filter','source_file','diagnostic_kind','target_field',
        'search_source','search_value','search_origin'
    )
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append(($columns -join [char]9) + "`n")
    foreach ($entry in $Plan) {
        $values = New-Object System.Collections.ArrayList
        foreach ($column in $columns) {
            [void]$values.Add((Convert-TsvField ([string]$entry.$column)))
        }
        [void]$sb.Append((@($values) -join [char]9) + "`n")
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
        $Entry.executor,
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

function Get-ToolArguments {
    param([object]$Entry,[string]$ArchiveRoot,[string]$ArchiveOutput)
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
    return @($toolArgs)
}

function Invoke-OneExternal {
    param([object]$Entry, [string]$ResultsFolder, [string]$ArchiveRoot, [string]$ArchiveOutput, [string]$RunsPath, [string]$FailureFolder)

    $stdoutTemp = Join-Path $ResultsFolder '_current.stdout.tmp'
    $stderrTemp = Join-Path $ResultsFolder '_current.stderr.tmp'
    Remove-Item -LiteralPath $stdoutTemp,$stderrTemp -Force -ErrorAction SilentlyContinue
    $toolArgs = Get-ToolArguments $Entry $ArchiveRoot $ArchiveOutput

    # Fast successful path: do not write potentially tens of megabytes of
    # stdout merely to measure and delete it. stderr is retained long enough
    # to record byte size and diagnose nonzero status.
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $rc = 5
    try {
        $global:LASTEXITCODE = 0
        $oldPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & $Entry.tool_path @toolArgs 1> $null 2> $stderrTemp
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

    $status = Get-RunStatus $Entry.scope $rc
    $stdoutBytes = 0
    $stderrBytes = Get-FileByteLength $stderrTemp

    if ($status -eq 'FAIL') {
        # Rerun only a genuine failure to preserve complete stdout/stderr
        # artifacts. The recorded elapsed time remains the first execution.
        Remove-Item -LiteralPath $stdoutTemp -Force -ErrorAction SilentlyContinue
        $rerunStderr = Join-Path $ResultsFolder '_current.failure.stderr.tmp'
        Remove-Item -LiteralPath $rerunStderr -Force -ErrorAction SilentlyContinue
        try {
            $global:LASTEXITCODE = 0
            $oldPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                & $Entry.tool_path @toolArgs 1> $stdoutTemp 2> $rerunStderr
            } finally {
                $ErrorActionPreference = $oldPreference
            }
        } catch {
            Add-TextUtf8 $rerunStderr (($_ | Out-String) + [Environment]::NewLine)
        }
        if (Test-Path -LiteralPath $rerunStderr -PathType Leaf) {
            Move-Item -LiteralPath $rerunStderr -Destination $stderrTemp -Force
        }
        $stdoutBytes = Get-FileByteLength $stdoutTemp
        $stderrBytes = Get-FileByteLength $stderrTemp
        Save-FailureArtifacts $Entry $rc $stdoutTemp $stderrTemp $FailureFolder
        Write-Line ('[FAIL] #' + $Entry.index + ' ' + $Entry.scope + ' ' + $Entry.snapshot + ' ' + $Entry.tool + ' rc=' + $rc)
    }

    Add-RunRow $RunsPath $Entry $status $rc $stdoutBytes $stderrBytes $sw.ElapsedMilliseconds
    Remove-Item -LiteralPath $stdoutTemp,$stderrTemp -Force -ErrorAction SilentlyContinue
    return $status
}

function Add-FastBatchRow {
    param([string]$Path,[string]$Scope,[string]$Snapshot,[string]$NextSnapshot,[int]$LogicalChecks,[string]$Worker,[long]$ElapsedMs,[int]$Rc)
    $fields=@($Scope,$Snapshot,$NextSnapshot,[string]$LogicalChecks,$Worker,[string]$ElapsedMs,[string]$Rc) |
        ForEach-Object { Convert-TsvField ([string]$_) }
    Add-TextUtf8 $Path (($fields -join [char]9) + [Environment]::NewLine)
}

function Invoke-FastWorker {
    param(
        [object[]]$Entries,
        [string]$WorkerPath,
        [string]$FirstData,
        [string]$SecondData,
        [string]$ResultsFolder,
        [string]$RunsPath,
        [string]$FastBatchesPath,
        [string]$FailureFolder
    )
    if ($Entries.Count -eq 0) { return @() }

    $slicePath=Join-Path $ResultsFolder '_fast.current.plan.tsv'
    $outputPath=Join-Path $ResultsFolder '_fast.current.results.tsv'
    $stderrPath=Join-Path $ResultsFolder '_fast.current.stderr.txt'
    Remove-Item -LiteralPath $slicePath,$outputPath,$stderrPath -Force -ErrorAction SilentlyContinue
    Write-TextUtf8 $slicePath (Get-PlanText $Entries)

    $scope=[string]$Entries[0].scope
    $snapshot=[string]$Entries[0].snapshot
    $nextSnapshot=[string]$Entries[0].next_snapshot
    $workerName=[IO.Path]::GetFileName($WorkerPath)

    $sw=[Diagnostics.Stopwatch]::StartNew()
    $rc=5
    try {
        $global:LASTEXITCODE=0
        $oldPreference=$ErrorActionPreference
        $ErrorActionPreference='Continue'
        try {
            if ($scope -eq 'single') {
                & $WorkerPath $FirstData $slicePath $outputPath 1> $null 2> $stderrPath
            } elseif ($scope -eq 'compare') {
                & $WorkerPath $FirstData $SecondData $slicePath $outputPath 1> $null 2> $stderrPath
            } else {
                throw ('Fast worker cannot execute scope: ' + $scope)
            }
            if ($null -eq $LASTEXITCODE) {$rc=0}else{$rc=[int]$LASTEXITCODE}
        } finally {
            $ErrorActionPreference=$oldPreference
        }
    } catch {
        $rc=5
        Add-TextUtf8 $stderrPath (($_ | Out-String) + [Environment]::NewLine)
    } finally {
        $sw.Stop()
    }

    Add-FastBatchRow $FastBatchesPath $scope $snapshot $nextSnapshot $Entries.Count $workerName $sw.ElapsedMilliseconds $rc

    if ($rc -ne 0 -or -not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        $safe=(($scope + '__' + $snapshot + '__' + $nextSnapshot) -replace '[^A-Za-z0-9._-]+','_')
        $target=Join-Path $FailureFolder ('fast-batch__' + $safe + '.stderr.txt')
        if(Test-Path -LiteralPath $stderrPath -PathType Leaf){Copy-Item -LiteralPath $stderrPath -Destination $target -Force}
        else{Write-TextUtf8 $target ('Fast worker failed with rc ' + $rc + [Environment]::NewLine)}
        Remove-Item -LiteralPath $slicePath,$outputPath,$stderrPath -Force -ErrorAction SilentlyContinue
        Fail 5 ('Fast combined worker failed for ' + $snapshot + $(if($nextSnapshot){' -> ' + $nextSnapshot}else{''}) + '; see ' + $target)
    }

    $rows=@(Import-Csv -LiteralPath $outputPath -Delimiter "`t")
    if($rows.Count -ne $Entries.Count){
        Remove-Item -LiteralPath $slicePath,$outputPath,$stderrPath -Force -ErrorAction SilentlyContinue
        Fail 5 ('Fast worker row count mismatch for ' + $snapshot + ': expected ' + $Entries.Count + ', got ' + $rows.Count)
    }

    $entryByIndex=@{}
    foreach($entry in $Entries){$entryByIndex[[string]$entry.index]=$entry}
    $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $statuses=New-Object System.Collections.ArrayList
    foreach($row in $rows){
        $idx=[string]$row.index
        if(-not $entryByIndex.ContainsKey($idx) -or -not $seen.Add($idx)){
            Remove-Item -LiteralPath $slicePath,$outputPath,$stderrPath -Force -ErrorAction SilentlyContinue
            Fail 5 ('Fast worker returned unexpected/duplicate plan index: ' + $idx)
        }
        $entry=$entryByIndex[$idx]
        $status=[string]$row.status
        $logicalRc=0
        $logicalMs=0L
        if(-not [int]::TryParse([string]$row.rc,[ref]$logicalRc)){Fail 5 ('Invalid fast worker rc for index ' + $idx)}
        if(-not [long]::TryParse([string]$row.elapsed_ms,[ref]$logicalMs)){Fail 5 ('Invalid fast worker elapsed_ms for index ' + $idx)}
        if(@('PASS','NO_RESULT','SOURCE_MISSING','FAIL') -notcontains $status){Fail 5 ('Invalid fast worker status for index ' + $idx + ': ' + $status)}
        Add-RunRow $RunsPath $entry $status $logicalRc 0 0 $logicalMs
        [void]$statuses.Add($status)
    }

    Remove-Item -LiteralPath $slicePath,$outputPath,$stderrPath -Force -ErrorAction SilentlyContinue
    return @($statuses)
}



function Start-FastWorkerJob {
    param(
        [object[]]$Entries,
        [string]$WorkerPath,
        [string]$FirstData,
        [string]$SecondData,
        [string]$ResultsFolder,
        [string]$CacheRoot
    )
    if($Entries.Count -eq 0){return $null}
    $firstIndex=[string]$Entries[0].index
    $scope=[string]$Entries[0].scope
    $snapshot=[string]$Entries[0].snapshot
    $nextSnapshot=[string]$Entries[0].next_snapshot
    $prefix='_fast.'+$scope+'.'+$firstIndex
    $slicePath=Join-Path $ResultsFolder ($prefix+'.plan.tsv')
    $outputPath=Join-Path $ResultsFolder ($prefix+'.results.tsv')
    $stderrPath=Join-Path $ResultsFolder ($prefix+'.stderr.txt')
    Remove-Item -LiteralPath $slicePath,$outputPath,$stderrPath -Force -ErrorAction SilentlyContinue
    Write-TextUtf8 $slicePath (Get-PlanText $Entries)

    $sw=[Diagnostics.Stopwatch]::StartNew()
    $job=Start-Job -ScriptBlock {
        param($Scope,$Worker,$First,$Second,$Slice,$Output,$Stderr,$Cache)
        $ErrorActionPreference='Continue'
        $rc=5
        $message=''
        try{
            $global:LASTEXITCODE=0
            if($Scope -eq 'single'){
                & $Worker $First $Slice $Output $Cache 1> $null 2> $Stderr
            } elseif($Scope -eq 'compare'){
                & $Worker $First $Second $Slice $Output 1> $null 2> $Stderr
            } else {
                throw ('Unsupported fast worker scope: '+$Scope)
            }
            if($null -eq $LASTEXITCODE){$rc=0}else{$rc=[int]$LASTEXITCODE}
        } catch {
            $rc=5
            $message=$_.Exception.Message
            try{[IO.File]::AppendAllText($Stderr,($_ | Out-String)+[Environment]::NewLine,(New-Object System.Text.UTF8Encoding($false)))}catch{}
        }
        [pscustomobject]@{rc=$rc;message=$message}
    } -ArgumentList @($scope,$WorkerPath,$FirstData,$SecondData,$slicePath,$outputPath,$stderrPath,$CacheRoot)

    return [pscustomobject]@{
        job=$job;entries=$Entries;scope=$scope;snapshot=$snapshot;next_snapshot=$nextSnapshot
        worker_path=$WorkerPath;slice_path=$slicePath;output_path=$outputPath;stderr_path=$stderrPath;stopwatch=$sw
    }
}

function Complete-FastWorkerJob {
    param(
        [object]$Context,
        [string]$RunsPath,
        [string]$FastBatchesPath,
        [string]$FailureFolder
    )
    $job=$Context.job
    Wait-Job -Job $job | Out-Null
    $received=@(Receive-Job -Job $job)
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    $Context.stopwatch.Stop()

    $rc=5
    if($received.Count -gt 0){
        $candidate=$received[$received.Count-1]
        $parsed=5
        if($null -ne $candidate.PSObject.Properties['rc'] -and [int]::TryParse([string]$candidate.rc,[ref]$parsed)){$rc=$parsed}
    }
    $workerName=[IO.Path]::GetFileName([string]$Context.worker_path)
    Add-FastBatchRow $FastBatchesPath ([string]$Context.scope) ([string]$Context.snapshot) ([string]$Context.next_snapshot) $Context.entries.Count $workerName $Context.stopwatch.ElapsedMilliseconds $rc

    $slicePath=[string]$Context.slice_path
    $outputPath=[string]$Context.output_path
    $stderrPath=[string]$Context.stderr_path
    if($rc -ne 0 -or -not(Test-Path -LiteralPath $outputPath -PathType Leaf)){
        $safe=((([string]$Context.scope)+'__'+([string]$Context.snapshot)+'__'+([string]$Context.next_snapshot)) -replace '[^A-Za-z0-9._-]+','_')
        $target=Join-Path $FailureFolder ('fast-batch__'+$safe+'.stderr.txt')
        if(Test-Path -LiteralPath $stderrPath -PathType Leaf){Copy-Item -LiteralPath $stderrPath -Destination $target -Force}
        else{Write-TextUtf8 $target ('Fast worker failed with rc '+$rc+[Environment]::NewLine)}
        Remove-Item -LiteralPath $slicePath,$outputPath,$stderrPath -Force -ErrorAction SilentlyContinue
        Fail 5 ('Fast combined worker failed for '+$Context.snapshot+$(if($Context.next_snapshot){' -> '+$Context.next_snapshot}else{''})+'; see '+$target)
    }

    $rows=@(Import-Csv -LiteralPath $outputPath -Delimiter "`t")
    if($rows.Count -ne $Context.entries.Count){
        Remove-Item -LiteralPath $slicePath,$outputPath,$stderrPath -Force -ErrorAction SilentlyContinue
        Fail 5 ('Fast worker row count mismatch for '+$Context.snapshot+': expected '+$Context.entries.Count+', got '+$rows.Count)
    }

    $entryByIndex=@{}
    foreach($entry in $Context.entries){$entryByIndex[[string]$entry.index]=$entry}
    $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $statuses=New-Object System.Collections.ArrayList
    foreach($row in $rows){
        $idx=[string]$row.index
        if(-not $entryByIndex.ContainsKey($idx) -or -not $seen.Add($idx)){
            Remove-Item -LiteralPath $slicePath,$outputPath,$stderrPath -Force -ErrorAction SilentlyContinue
            Fail 5 ('Fast worker returned unexpected/duplicate plan index: '+$idx)
        }
        $entry=$entryByIndex[$idx]
        $status=[string]$row.status
        $logicalRc=0
        $logicalMs=0L
        if(-not [int]::TryParse([string]$row.rc,[ref]$logicalRc)){Fail 5 ('Invalid fast worker rc for index '+$idx)}
        if(-not [long]::TryParse([string]$row.elapsed_ms,[ref]$logicalMs)){Fail 5 ('Invalid fast worker elapsed_ms for index '+$idx)}
        if(@('PASS','NO_RESULT','SOURCE_MISSING','FAIL') -notcontains $status){Fail 5 ('Invalid fast worker status for index '+$idx+': '+$status)}
        Add-RunRow $RunsPath $entry $status $logicalRc 0 0 $logicalMs
        [void]$statuses.Add($status)
    }
    Remove-Item -LiteralPath $slicePath,$outputPath,$stderrPath -Force -ErrorAction SilentlyContinue
    return @($statuses)
}

function Invoke-FastArchiveWorker {
    param(
        [object[]]$Entries,
        [string]$WorkerPath,
        [string]$ArchiveRoot,
        [string]$ArchiveOutput,
        [string]$ResultsFolder,
        [string]$RunsPath,
        [string]$FastBatchesPath,
        [string]$FailureFolder
    )
    if($Entries.Count -eq 0){return @()}

    $stderrPath=Join-Path $ResultsFolder '_fast.archive.stderr.txt'
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    $sw=[Diagnostics.Stopwatch]::StartNew()
    $rc=5
    try{
        $global:LASTEXITCODE=0
        $oldPreference=$ErrorActionPreference
        $ErrorActionPreference='Continue'
        try{
            & $WorkerPath $ArchiveRoot $ArchiveOutput 2> $stderrPath | ForEach-Object { Write-Line ([string]$_) }
            if($null -eq $LASTEXITCODE){$rc=0}else{$rc=[int]$LASTEXITCODE}
        }finally{$ErrorActionPreference=$oldPreference}
    }catch{
        $rc=5
        Add-TextUtf8 $stderrPath (($_ | Out-String)+[Environment]::NewLine)
    }finally{$sw.Stop()}

    Add-FastBatchRow $FastBatchesPath 'archive' '(archive)' '' $Entries.Count ([IO.Path]::GetFileName($WorkerPath)) $sw.ElapsedMilliseconds $rc

    if($rc -ne 0){
        $target=Join-Path $FailureFolder 'fast-batch__archive.stderr.txt'
        if(Test-Path -LiteralPath $stderrPath -PathType Leaf){Copy-Item -LiteralPath $stderrPath -Destination $target -Force}
        else{Write-TextUtf8 $target ('Fast archive worker failed with rc '+$rc+[Environment]::NewLine)}
        Fail 5 ('Fast combined archive worker failed; see '+$target)
    }

    $statuses=New-Object System.Collections.ArrayList
    $first=$true
    foreach($entry in $Entries){
        $logicalMs=if($first){$sw.ElapsedMilliseconds}else{0}
        Add-RunRow $RunsPath $entry 'PASS' 0 0 0 $logicalMs
        [void]$statuses.Add('PASS')
        $first=$false
    }
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    return @($statuses)
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
        ('Mode: ' + $Mode),
        ('Executor: ' + $Executor),
        ('Workers: ' + $Workers),
        ('Exclusions: ' + $ExclusionsPath),
        ('Content cache: ' + $(if($UseCache){$CachePath}else{'disabled'})),
        ('Interactive report: ' + $(if($GenerateReport -and $Executor -eq 'fast-combined'){'enabled'}else{'disabled'})),
        ('Snapshots: ' + $Snapshots),
        ('Single-snapshot public tools: ' + $SingleTools),
        ('Compare public tools: ' + $CompareTools),
        ('Archive public tools: ' + $ArchiveTools),
        ('Planned invocations: ' + $Planned),
        ('Completed invocations: ' + $Completed),
        ('Remaining invocations: ' + $remaining),
        ('PASS: ' + $Counts.PASS),
        ('NO_RESULT: ' + $Counts.NO_RESULT),
        ('SOURCE_MISSING: ' + $Counts.SOURCE_MISSING),
        ('FAIL: ' + $Counts.FAIL)
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

$argsList=New-Object System.Collections.ArrayList
foreach($candidate in $RawArgs){if(-not [string]::IsNullOrWhiteSpace($candidate)){[void]$argsList.Add($candidate)}}
for($argIndex=0;$argIndex-lt$argsList.Count;$argIndex++){
    $arg=[string]$argsList[$argIndex]
    if($arg -eq '--plan-only'){
        if($PlanOnly){Fail 2 'Duplicate --plan-only option.'}
        $PlanOnly=$true
        continue
    }
    if($arg -eq '--resume'){
        if($Resume){Fail 2 'Duplicate --resume option.'}
        $Resume=$true
        continue
    }
    if($arg -eq '--external-tools'){
        if($Executor -eq 'external-public'){Fail 2 'Duplicate --external-tools option.'}
        $Executor='external-public'
        continue
    }
    if($arg -eq '--no-report'){
        $GenerateReport=$false
        continue
    }
    if($arg -eq '--no-cache'){
        $UseCache=$false
        continue
    }
    if($arg -match '^--cache-folder=(?<path>.+)$'){
        $CacheInput=[string]$Matches.path
        continue
    }
    if($arg -eq '--cache-folder'){
        $argIndex++
        if($argIndex-ge$argsList.Count){Fail 2 '--cache-folder requires a directory path.'}
        $CacheInput=[string]$argsList[$argIndex]
        continue
    }
    if($arg -match '^--workers=(?<n>\d+)$'){
        $Workers=[int]$Matches.n
        continue
    }
    if($arg -eq '--workers'){
        $argIndex++
        if($argIndex-ge$argsList.Count){Fail 2 '--workers requires an integer value.'}
        $value=[string]$argsList[$argIndex]
        $parsed=0
        if(-not [int]::TryParse($value,[ref]$parsed)){Fail 2 ('Invalid --workers value: '+$value)}
        $Workers=$parsed
        continue
    }
    if($arg -match '^--exclusions=(?<path>.+)$'){
        $ExclusionsInput=[string]$Matches.path
        continue
    }
    if($arg -eq '--exclusions'){
        $argIndex++
        if($argIndex-ge$argsList.Count){Fail 2 '--exclusions requires a file path.'}
        $ExclusionsInput=[string]$argsList[$argIndex]
        continue
    }
    if($arg.StartsWith('--')){Fail 2 ('Unknown option: '+$arg)}
    if(-not [string]::IsNullOrWhiteSpace($OutputInput)){Fail 2 'More than one results-folder was supplied.'}
    $OutputInput=$arg
}
if($Workers -lt 1 -or $Workers -gt 32){Fail 2 '--workers must be between 1 and 32.'}
if($Executor -eq 'external-public'){$Workers=1}
if ($PlanOnly -and $Resume) { Fail 2 '--plan-only and --resume cannot be combined.' }
if ($Resume -and [string]::IsNullOrWhiteSpace($OutputInput)) {
    Fail 2 '--resume requires an existing results-folder argument.'
}

$ArchiveRoot = Resolve-ArchiveRoot $ArchiveInput
if ([string]::IsNullOrWhiteSpace($ArchiveRoot)) { Fail 3 ('Archive root not found or contains no mvs_* snapshots: ' + $ArchiveInput) }

$ProjectRoot = Split-Path -Parent $ScriptRoot
if ([string]::IsNullOrWhiteSpace($ProjectRoot) -or -not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    Fail 3 'Project root could not be resolved from test script location.'
}

if([string]::IsNullOrWhiteSpace($ExclusionsInput)){
    $ExclusionsPath=Join-Path $ScriptRoot 'archive-exclusions.tsv'
} else {
    $candidate=$ExclusionsInput
    if(-not[IO.Path]::IsPathRooted($candidate)){$candidate=Join-Path (Get-Location).Path $candidate}
    $ExclusionsPath=[IO.Path]::GetFullPath($candidate)
    if(-not(Test-Path -LiteralPath $ExclusionsPath -PathType Leaf)){Fail 2 ('Exclusions file not found: '+$ExclusionsPath)}
}

if($UseCache){
    if([string]::IsNullOrWhiteSpace($CacheInput)){$CachePath=Join-Path $ScriptRoot 'archive-sweep-cache'}
    else{
        $candidate=$CacheInput
        if(-not[IO.Path]::IsPathRooted($candidate)){$candidate=Join-Path (Get-Location).Path $candidate}
        $CachePath=[IO.Path]::GetFullPath($candidate)
    }
    if(-not(Test-Path -LiteralPath $CachePath -PathType Container)){[void](New-Item -ItemType Directory -Path $CachePath -Force)}
} else {$CachePath=''}

$publicFiles = @(Get-ChildItem -LiteralPath $ProjectRoot -File -Filter '*.bat' -ErrorAction Stop | Sort-Object Name)
if ($publicFiles.Count -eq 0) { Fail 4 'No public root .bat tools found.' }

$familyFiles = @($publicFiles | Where-Object {
    $_.Name -in @('build_mvs_product_family_index.bat','build_mvs_product_family_compact_index.bat') -or
    $_.Name -match '^(?:print|read)_mvs_product_'
})
$singleFiles = @($publicFiles | Where-Object {
    $_.Name -notlike 'compare_mvs_dump_*.bat' -and
    $_.Name -notin @('build_mvs_dump_change_history.bat','build_mvs_dump_all_ever.bat') -and
    $_.Name -notin @('build_mvs_product_family_index.bat','build_mvs_product_family_compact_index.bat') -and
    $_.Name -notmatch '^(?:print|read)_mvs_product_'
})
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
    if ($Resume) {
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
$fastBatchesPath = Join-Path $ResultsFolder 'fast-batches.tsv'
$summaryPath = Join-Path $ResultsFolder 'summary.txt'
$snapshotsPath = Join-Path $ResultsFolder 'snapshots.tsv'
$runInfoPath = Join-Path $ResultsFolder 'run-info.txt'
$failureFolder = Join-Path $ResultsFolder 'failures'
$archiveOutput = Join-Path $ResultsFolder 'archive-output'
if (-not (Test-Path -LiteralPath $failureFolder -PathType Container)) { [void](New-Item -ItemType Directory -Path $failureFolder -Force) }

if (-not $Resume) {
    Write-TextUtf8 $script:ConsoleLog ''
    $readme = @(
        'MVS Explorer Toolkit Archive Sweep Results',
        '',
        'plan.tsv          Complete deterministic invocation plan.',
        'plan-sha256.txt   SHA-256 of plan.tsv content.',
        'snapshots.tsv     Snapshot names and resolved data directories.',
        'runs.tsv          One row per completed logical check.',
        'fast-batches.tsv  Combined-worker wall times (fast executor only).',
        'summary.txt       Aggregate status counts.',
        'run-info.txt      Environment and archive/project paths.',
        'console.log       Progress/failure transcript.',
        'failures\         stdout/stderr/meta retained only for FAIL rows.',
        'archive-output\   Change-history and all-ever builder output.',
        '',
        'Executor meanings:',
        '  fast-combined    Shared-parse logical status validation; archive builders share one streaming pass.',
        '  external-public  Literal execution of every public .bat wrapper.',
        '',
        'Status meanings:',
        '  PASS            return code/logical status 0.',
        '  NO_RESULT       return code 1 from single/compare scope.',
        '  SOURCE_MISSING  return code 4 from single/compare scope.',
        '  FAIL            any other code, or any nonzero archive-builder code.'
    ) -join [Environment]::NewLine
    Write-TextUtf8 (Join-Path $ResultsFolder 'README.txt') ($readme + [Environment]::NewLine)
}

Write-Line ('Archive: ' + $ArchiveRoot)
Write-Line ('Project: ' + $ProjectRoot)
Write-Line ('Executor: ' + $Executor)
Write-Line ('Snapshots discovered: ' + $snapshotDirs.Count)
Write-Line ('Public tools: single=' + $singleFiles.Count + ' compare=' + $compareFiles.Count + ' archive=' + $archiveFiles.Count)
if ($familyFiles.Count -gt 0) { Write-Line ('Family tools: ' + $familyFiles.Count + ' (separate archive-level feature; excluded from legacy sweep plan)') }

$singleMetadata = New-Object System.Collections.ArrayList
foreach ($file in $singleFiles) { [void]$singleMetadata.Add((Get-ToolMetadata $file)) }
$compareMetadata = New-Object System.Collections.ArrayList
foreach ($file in $compareFiles) { [void]$compareMetadata.Add((Get-ToolMetadata $file)) }
$archiveMetadata = New-Object System.Collections.ArrayList
foreach ($file in $archiveFiles) {
    [void]$archiveMetadata.Add([pscustomobject]@{
        name=[IO.Path]::GetFileNameWithoutExtension($file.Name)
        file=$file.Name
        path=$file.FullName
        family='archive'
        operation=''
        search_source=''
        fields=''
        algorithm_filter=''
        source_file=''
        diagnostic_kind=''
        target_field=''
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
if ($Resume) {
    if (-not (Test-Path -LiteralPath $planHashPath -PathType Leaf)) { Fail 2 'Resume folder has no plan-sha256.txt.' }
    $existingHash = ([IO.File]::ReadAllText($planHashPath)).Trim()
    if ($existingHash -ne $planHash) { Fail 2 'Resume plan does not match the current archive/project/tool set.' }
} else {
    Write-TextUtf8 $planPath $planText
    Write-TextUtf8 $planHashPath ($planHash + [Environment]::NewLine)
}

$runInfo = @(
    ('Sweep script: ' + $Caller),
    ('Sweep version: ' + $Version),
    ('Mode: ' + $(if ($PlanOnly) { 'plan-only' } elseif ($Resume) { 'resume' } else { 'execute' })),
    ('Executor: ' + $Executor),
    ('Workers: ' + $Workers),
    ('Content cache: ' + $(if($UseCache){$CachePath}else{'disabled'})),
    ('Exclusions: ' + $ExclusionsPath),
    ('Interactive report: ' + $GenerateReport),
    ('Archive root: ' + $ArchiveRoot),
    ('Project root: ' + $ProjectRoot),
    ('Results folder: ' + $ResultsFolder),
    ('Computer: ' + $env:COMPUTERNAME),
    ('User: ' + $env:USERNAME),
    ('OS: ' + [Environment]::OSVersion.VersionString),
    ('PowerShell: ' + $PSVersionTable.PSVersion.ToString()),
    ('CLR: ' + [Environment]::Version.ToString()),
    ('Snapshots: ' + $snapshots.Count),
    ('Single tools: ' + $singleFiles.Count),
    ('Compare tools: ' + $compareFiles.Count),
    ('Archive tools: ' + $archiveFiles.Count),
    ('Planned invocations: ' + $plan.Count),
    ('Plan SHA-256: ' + $planHash)
) -join [Environment]::NewLine
Write-TextUtf8 $runInfoPath ($runInfo + [Environment]::NewLine)

$emptyCounts = @{ PASS=0; NO_RESULT=0; SOURCE_MISSING=0; FAIL=0 }
if ($PlanOnly) {
    Write-Summary $summaryPath 'plan-only' $snapshots.Count $singleFiles.Count $compareFiles.Count $archiveFiles.Count $plan.Count $emptyCounts 0
    Write-Line ('Plan-only complete: ' + $plan.Count + ' invocations.')
    Write-Line ('Results: ' + $ResultsFolder)
    [Environment]::Exit(0)
}

if (-not $Resume) {
    $runsHeader = "index`texecutor`tscope`tsnapshot`tnext_snapshot`ttool`tsearch_source`tsearch_value`tsearch_origin`tstatus`trc`tstdout_bytes`tstderr_bytes`telapsed_ms`n"
    Write-TextUtf8 $runsPath $runsHeader
    Write-TextUtf8 $fastBatchesPath "scope`tsnapshot`tnext_snapshot`tlogical_checks`tworker`telapsed_ms`trc`n"
} elseif (-not (Test-Path -LiteralPath $fastBatchesPath -PathType Leaf)) {
    Write-TextUtf8 $fastBatchesPath "scope`tsnapshot`tnext_snapshot`tlogical_checks`tworker`telapsed_ms`trc`n"
}

$state = Get-ExistingRunState $runsPath
$done = $state.done
$counts = $state.counts
$completed = $done.Count

Write-Line ('Planned invocations: ' + $plan.Count)
if ($Resume) { Write-Line ('Already completed: ' + $completed) }

$summaryMode=$(if($Resume){'resume'}else{'execute'})

if ($Executor -eq 'external-public') {
    $currentSnapshot = ''
    foreach ($entry in $plan) {
        if ($done.Contains([int]$entry.index)) { continue }

        if ($entry.scope -eq 'single' -and $entry.snapshot -ne $currentSnapshot) {
            $currentSnapshot = $entry.snapshot
            Write-Line ('=== Snapshot ' + $currentSnapshot + ' [external-public] ===')
        } elseif ($entry.scope -eq 'compare' -and ($entry.snapshot + ' -> ' + $entry.next_snapshot) -ne $currentSnapshot) {
            $currentSnapshot = $entry.snapshot + ' -> ' + $entry.next_snapshot
            Write-Line ('=== Compare ' + $currentSnapshot + ' [external-public] ===')
        } elseif ($entry.scope -eq 'archive' -and $currentSnapshot -ne '(archive)') {
            $currentSnapshot = '(archive)'
            Write-Line '=== Archive builders [literal] ==='
            if (-not (Test-Path -LiteralPath $archiveOutput -PathType Container)) { [void](New-Item -ItemType Directory -Path $archiveOutput -Force) }
        }

        $status = Invoke-OneExternal $entry $ResultsFolder $ArchiveRoot $archiveOutput $runsPath $failureFolder
        if ($counts.ContainsKey($status)) { $counts[$status]++ }
        [void]$done.Add([int]$entry.index)
        $completed++

        if (($completed % 100) -eq 0 -or $completed -eq $plan.Count -or $status -eq 'FAIL') {
            Write-Line ('Progress: ' + $completed + '/' + $plan.Count + ' PASS=' + $counts.PASS + ' NO_RESULT=' + $counts.NO_RESULT + ' SOURCE_MISSING=' + $counts.SOURCE_MISSING + ' FAIL=' + $counts.FAIL)
            Write-Summary $summaryPath $summaryMode $snapshots.Count $singleFiles.Count $compareFiles.Count $archiveFiles.Count $plan.Count $counts $completed
        }
    }
} else {
    $snapshotWorker = Join-Path (Join-Path $ScriptRoot 'fast') 'run_snapshot_tools_fast.bat'
    $compareWorker = Join-Path (Join-Path $ScriptRoot 'fast') 'run_compare_tools_fast.bat'
    if (-not (Test-Path -LiteralPath $snapshotWorker -PathType Leaf)) { Fail 4 ('Missing fast snapshot worker: ' + $snapshotWorker) }
    if (-not (Test-Path -LiteralPath $compareWorker -PathType Leaf)) { Fail 4 ('Missing fast compare worker: ' + $compareWorker) }

    $snapshotBatches=New-Object System.Collections.ArrayList
    foreach($snapshot in $snapshots){
        $pending=@($plan | Where-Object {
            $_.scope -eq 'single' -and $_.snapshot -eq $snapshot.name -and -not $done.Contains([int]$_.index)
        })
        if($pending.Count -gt 0){
            [void]$snapshotBatches.Add([pscustomobject]@{snapshot=$snapshot;entries=$pending})
        }
    }

    $active=New-Object System.Collections.ArrayList
    $nextBatch=0
    while($nextBatch-lt$snapshotBatches.Count -or $active.Count -gt 0){
        while($nextBatch-lt$snapshotBatches.Count -and $active.Count-lt$Workers){
            $batch=$snapshotBatches[$nextBatch]
            $nextBatch++
            Write-Line ('=== Snapshot '+$batch.snapshot.name+' [fast-combined '+$batch.entries.Count+' checks; worker '+($active.Count+1)+'/'+$Workers+'] ===')
            $ctx=Start-FastWorkerJob $batch.entries $snapshotWorker $batch.snapshot.data_path '' $ResultsFolder $CachePath
            [void]$active.Add($ctx)
        }
        if($active.Count -eq 0){continue}
        $jobList=@($active | ForEach-Object {$_.job})
        $finished=Wait-Job -Job $jobList -Any
        $ctx=$null
        foreach($candidate in @($active)){
            if($candidate.job.Id -eq $finished.Id){$ctx=$candidate;break}
        }
        if($null -eq $ctx){Fail 5 'Could not resolve completed fast worker job.'}
        [void]$active.Remove($ctx)
        $statuses=@(Complete-FastWorkerJob $ctx $runsPath $fastBatchesPath $failureFolder)
        for($n=0;$n-lt$ctx.entries.Count;$n++){
            $status=[string]$statuses[$n]
            if($counts.ContainsKey($status)){$counts[$status]++}
            [void]$done.Add([int]$ctx.entries[$n].index)
            $completed++
        }
        Write-Line ('Completed snapshot '+$ctx.snapshot+'. Progress: '+$completed+'/'+$plan.Count+' PASS='+$counts.PASS+' NO_RESULT='+$counts.NO_RESULT+' SOURCE_MISSING='+$counts.SOURCE_MISSING+' FAIL='+$counts.FAIL)
        Write-Summary $summaryPath $summaryMode $snapshots.Count $singleFiles.Count $compareFiles.Count $archiveFiles.Count $plan.Count $counts $completed
    }

    for($i=0;$i-lt($snapshots.Count-1);$i++){
        $from=$snapshots[$i]
        $to=$snapshots[$i+1]
        $pending=@($plan | Where-Object {
            $_.scope -eq 'compare' -and $_.snapshot -eq $from.name -and $_.next_snapshot -eq $to.name -and -not $done.Contains([int]$_.index)
        })
        if($pending.Count -eq 0){continue}

        Write-Line ('=== Compare ' + $from.name + ' -> ' + $to.name + ' [fast-combined ' + $pending.Count + ' checks] ===')
        $statuses=@(Invoke-FastWorker $pending $compareWorker $from.data_path $to.data_path $ResultsFolder $runsPath $fastBatchesPath $failureFolder)
        for($n=0;$n-lt$pending.Count;$n++){
            $status=[string]$statuses[$n]
            if($counts.ContainsKey($status)){$counts[$status]++}
            [void]$done.Add([int]$pending[$n].index)
            $completed++
        }
        Write-Line ('Progress: ' + $completed + '/' + $plan.Count + ' PASS=' + $counts.PASS + ' NO_RESULT=' + $counts.NO_RESULT + ' SOURCE_MISSING=' + $counts.SOURCE_MISSING + ' FAIL=' + $counts.FAIL)
        Write-Summary $summaryPath $summaryMode $snapshots.Count $singleFiles.Count $compareFiles.Count $archiveFiles.Count $plan.Count $counts $completed
    }

    $archiveEntries=@($plan | Where-Object {$_.scope -eq 'archive' -and -not $done.Contains([int]$_.index)})
    if($archiveEntries.Count -gt 0){
        Write-Line ('=== Archive builders [fast-combined ' + $archiveEntries.Count + ' checks] ===')
        if(-not(Test-Path -LiteralPath $archiveOutput -PathType Container)){[void](New-Item -ItemType Directory -Path $archiveOutput -Force)}
        $archiveWorker=Join-Path (Join-Path $ScriptRoot 'fast') 'run_archive_tools_fast.bat'
        if(-not(Test-Path -LiteralPath $archiveWorker -PathType Leaf)){Fail 4 ('Missing fast archive worker: '+$archiveWorker)}
        $statuses=@(Invoke-FastArchiveWorker $archiveEntries $archiveWorker $ArchiveRoot $archiveOutput $ResultsFolder $runsPath $fastBatchesPath $failureFolder)
        for($n=0;$n-lt$archiveEntries.Count;$n++){
            $status=[string]$statuses[$n]
            if($counts.ContainsKey($status)){$counts[$status]++}
            [void]$done.Add([int]$archiveEntries[$n].index)
            $completed++
        }
        Write-Line ('Progress: ' + $completed + '/' + $plan.Count + ' PASS=' + $counts.PASS + ' NO_RESULT=' + $counts.NO_RESULT + ' SOURCE_MISSING=' + $counts.SOURCE_MISSING + ' FAIL=' + $counts.FAIL)
        Write-Summary $summaryPath $summaryMode $snapshots.Count $singleFiles.Count $compareFiles.Count $archiveFiles.Count $plan.Count $counts $completed
    }
}

Write-Summary $summaryPath $summaryMode $snapshots.Count $singleFiles.Count $compareFiles.Count $archiveFiles.Count $plan.Count $counts $completed

if($GenerateReport -and $Executor -eq 'fast-combined' -and -not $PlanOnly -and $counts.FAIL -eq 0){
    $reportWorker=Join-Path $ScriptRoot 'build_archive_html_report.bat'
    if(-not(Test-Path -LiteralPath $reportWorker -PathType Leaf)){Fail 4 ('Missing interactive report builder: '+$reportWorker)}
    $reportPath=Join-Path $ResultsFolder 'archive-summary.html'
    Write-Line '=== Interactive archive report ==='
    $global:LASTEXITCODE=0
    & $reportWorker $ResultsFolder $reportPath $ExclusionsPath
    $reportRc=if($null-eq$LASTEXITCODE){0}else{[int]$LASTEXITCODE}
    if($reportRc-ne0){Fail 5 ('Interactive report builder failed with rc '+$reportRc)}
}

Write-Line ('SUMMARY: PASS=' + $counts.PASS + ' NO_RESULT=' + $counts.NO_RESULT + ' SOURCE_MISSING=' + $counts.SOURCE_MISSING + ' FAIL=' + $counts.FAIL)
Write-Line ('Results: ' + $ResultsFolder)
if ($counts.FAIL -gt 0) { [Environment]::Exit(1) }
[Environment]::Exit(0)
:_MVSArchiveSweep_end
