@echo off
:setup
REM Scoped because this standalone test embeds PowerShell and must not leak state.
setlocal DisableDelayedExpansion
set "app.version=0.11.2"
set "app.name=test_structure"
set "app.rc=0"
set "app.self=%~f0"
set "mvst_mode=structure"
set "mvst_dump=%~1"
set "mvst_caller=%~nx0"
set "mvst_version=%app.version%"
for %%I in ("%~dp0..") do set "mvst_root=%%~fI"
:main
set "RunPowerShellFromLabel.function=MVSTest"
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

:_MVSTest_start
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$Mode = [string]$env:mvst_mode
$Root = [string]$env:mvst_root
$DumpArgument = [string]$env:mvst_dump
$Caller = [string]$env:mvst_caller
$Version = [string]$env:mvst_version

$script:Passed = 0
$script:Failed = 0
$script:Skipped = 0
$script:CurrentScope = 'general'
$script:ResultsFolder = $null
$script:ConsoleLog = $null
$script:AllResults = $null
$script:ScopeFiles = @{}
$script:FailuresFolder = $null
$script:CaseIndex = 0
$script:RunStart = Get-Date
$script:DumpForTools = $DumpArgument

function Convert-TsvField {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    return $Value.Replace("`t", ' ').Replace("`r", ' ').Replace("`n", ' ')
}

function Write-TextUtf8 {
    param([string]$Path, [AllowEmptyString()][string]$Text)
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Add-TextUtf8 {
    param([string]$Path, [AllowEmptyString()][string]$Text)
    [IO.File]::AppendAllText($Path, $Text, $utf8)
}

function New-ResultsFolder {
    $testRoot = Join-Path $Root 'test'
    if (-not (Test-Path -LiteralPath $testRoot -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $testRoot -Force)
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $candidate = Join-Path $testRoot ('test-results-' + $stamp)
    $n = 1
    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $testRoot ('test-results-' + $stamp + '-' + $n.ToString('D2'))
        $n++
    }
    [void](New-Item -ItemType Directory -Path $candidate)
    $script:ResultsFolder = $candidate
    $script:FailuresFolder = Join-Path $candidate 'failures'
    [void](New-Item -ItemType Directory -Path $script:FailuresFolder)
    $script:ConsoleLog = Join-Path $candidate 'console.log'
    $script:AllResults = Join-Path $candidate 'all-results.tsv'
    $script:ScopeFiles = @{
        general = Join-Path $candidate 'general-results.tsv'
        structure = Join-Path $candidate 'structure-results.tsv'
        scalar = Join-Path $candidate 'scalar-results.tsv'
        lookup = Join-Path $candidate 'lookup-results.tsv'
        diagnostic = Join-Path $candidate 'diagnostic-results.tsv'
        relationship = Join-Path $candidate 'relationship-results.tsv'
        single_dump = Join-Path $candidate 'single-dump-results.tsv'
        compare = Join-Path $candidate 'compare-results.tsv'
        history = Join-Path $candidate 'history-results.tsv'
        family = Join-Path $candidate 'family-results.tsv'
    }
    Write-TextUtf8 $script:ConsoleLog ''
    $header = "index`tscope`tstatus`tcase`treason`texpected_rc`tactual_rc`telapsed_ms`n"
    Write-TextUtf8 $script:AllResults $header
    foreach ($resultPath in $script:ScopeFiles.Values) { Write-TextUtf8 $resultPath $header }
    $readme = @'
MVS Explorer Toolkit Test Results

Files:
  run-info.txt           Test mode, paths, platform, PowerShell version.
  console.log            Complete test-harness console transcript.
  summary.txt            Final pass/fail/skip totals.
  all-results.tsv        Every assertion in execution order.
  general-results.tsv    General/setup assertions.
  structure-results.tsv  Standalone/public-file assertions.
  scalar-results.tsv     Scalar behavioral assertions.
  lookup-results.tsv     Lookup behavioral assertions.
  diagnostic-results.tsv Duplicate/orphan diagnostic assertions.
  relationship-results.tsv Filename/hash relationship assertions.
  single-dump-results.tsv Single-dump completeness assertions.
  compare-results.tsv     Two-dump comparison assertions.
  history-results.tsv     Archive-history/all-ever assertions.
  family-results.tsv      Product-family feature regression wrapper assertion.
  failures\              Full expected/actual/stderr/meta files for
                         behavioral failures. Empty when none fail.
'@
    Write-TextUtf8 (Join-Path $candidate 'README.txt') $readme
}

function Write-Line {
    param([AllowEmptyString()][string]$Text)
    [Console]::Out.WriteLine($Text)
    if ($null -ne $script:ConsoleLog) {
        Add-TextUtf8 $script:ConsoleLog ($Text + [Environment]::NewLine)
    }
}

function Add-Result {
    param([string]$Status, [string]$Name, [AllowEmptyString()][string]$Reason, [AllowEmptyString()][string]$ExpectedRc, [AllowEmptyString()][string]$ActualRc, [AllowEmptyString()][string]$ElapsedMs='')
    $script:CaseIndex++
    $fields = @([string]$script:CaseIndex,$script:CurrentScope,$Status,$Name,$Reason,$ExpectedRc,$ActualRc,$ElapsedMs) | ForEach-Object { Convert-TsvField ([string]$_) }
    $line = ($fields -join [char]9) + [Environment]::NewLine
    Add-TextUtf8 $script:AllResults $line
    $scopePath = $script:ScopeFiles[$script:CurrentScope]
    if ($null -eq $scopePath) { $scopePath = $script:ScopeFiles['general'] }
    Add-TextUtf8 $scopePath $line
}

function Write-Pass {
    param([string]$Name, [AllowEmptyString()][string]$ExpectedRc='', [AllowEmptyString()][string]$ActualRc='', [AllowEmptyString()][string]$ElapsedMs='')
    $script:Passed++
    Add-Result 'PASS' $Name '' $ExpectedRc $ActualRc $ElapsedMs
    Write-Line ('[PASS] ' + $Name)
}

function Write-Skip {
    param([string]$Name, [string]$Reason)
    $script:Skipped++
    Add-Result 'SKIP' $Name $Reason '' '' ''
    Write-Line ('[SKIP] ' + $Name + ' - ' + $Reason)
}

function Write-Fail {
    param([string]$Name, [string]$Reason, [AllowEmptyString()][string]$ExpectedRc='', [AllowEmptyString()][string]$ActualRc='', [AllowEmptyString()][string]$ElapsedMs='')
    $script:Failed++
    Add-Result 'FAIL' $Name $Reason $ExpectedRc $ActualRc $ElapsedMs
    Write-Line ('[FAIL] ' + $Name + ' - ' + $Reason)
}

function Write-RunInfo {
    param([AllowNull()][string]$ResolvedDump)
    $info = @(
        'MVS Explorer Toolkit test run',
        ('Started: ' + $script:RunStart.ToString('o')),
        ('Test script: ' + $Caller),
        ('Test version: ' + $Version),
        ('Mode: ' + $Mode),
        ('Project root: ' + $Root),
        ('Original dump argument: ' + $DumpArgument),
        ('Resolved dump: ' + [string]$ResolvedDump),
        ('Current directory: ' + (Get-Location).Path),
        ('Computer: ' + $env:COMPUTERNAME),
        ('User: ' + $env:USERNAME),
        ('OS: ' + [Environment]::OSVersion.VersionString),
        ('PowerShell: ' + $PSVersionTable.PSVersion.ToString()),
        ('CLR: ' + [Environment]::Version.ToString()),
        ('Diagnostic fixture: ' + (Join-Path (Join-Path $Root 'test') 'test-mvs-dump-diagnostics')),
        ('Relationship fixture: ' + (Join-Path (Join-Path $Root 'test') 'test-mvs-dump-relationships')),
        ('Single-dump fixture: ' + (Join-Path (Join-Path $Root 'test') 'test-mvs-dump-single-complete')),
        ('Compare fixture: ' + (Join-Path (Join-Path $Root 'test') 'test-mvs-dump-compare')),
        ('History fixture: ' + (Join-Path (Join-Path $Root 'test') 'test-mvs-dump-history')),
        ('Result folder: ' + $script:ResultsFolder)
    )
    Write-TextUtf8 (Join-Path $script:ResultsFolder 'run-info.txt') (($info -join [Environment]::NewLine) + [Environment]::NewLine)
}

function Write-Summary {
    $end = Get-Date
    $summary = @(
        'MVS Explorer Toolkit Test Summary',
        ('Started: ' + $script:RunStart.ToString('o')),
        ('Finished: ' + $end.ToString('o')),
        ('Duration: ' + (($end - $script:RunStart).ToString())),
        ('Mode: ' + $Mode),
        ('Passed: ' + $script:Passed),
        ('Failed: ' + $script:Failed),
        ('Skipped: ' + $script:Skipped),
        ('Total assertions: ' + ($script:Passed + $script:Failed + $script:Skipped)),
        ('Diagnostic fixture: ' + (Join-Path (Join-Path $Root 'test') 'test-mvs-dump-diagnostics')),
        ('Relationship fixture: ' + (Join-Path (Join-Path $Root 'test') 'test-mvs-dump-relationships')),
        ('Single-dump fixture: ' + (Join-Path (Join-Path $Root 'test') 'test-mvs-dump-single-complete')),
        ('Compare fixture: ' + (Join-Path (Join-Path $Root 'test') 'test-mvs-dump-compare')),
        ('History fixture: ' + (Join-Path (Join-Path $Root 'test') 'test-mvs-dump-history')),
        ('Result folder: ' + $script:ResultsFolder)
    )
    Write-TextUtf8 (Join-Path $script:ResultsFolder 'summary.txt') (($summary -join [Environment]::NewLine) + [Environment]::NewLine)
}

function Show-Usage {
    Write-Line ('MVS Explorer Toolkit test ' + $Version)
    if (@('structure','diagnostic','relationship','single_dump','compare','history') -contains $Mode) {
        Write-Line ('Usage: ' + $Caller)
    } else {
        Write-Line ('Usage: ' + $Caller + ' dump-folder')
    }
}

function Resolve-TestDump {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    $candidates = @(
        $Name,
        (Join-Path (Get-Location).Path $Name),
        (Join-Path $Root $Name),
        (Join-Path (Join-Path $Root 'mvs_dumps_archive') $Name),
        (Join-Path (Join-Path (Split-Path -Parent $Root) 'mvs_dumps_archive') $Name)
    )
    if (-not [string]::IsNullOrWhiteSpace($env:MVS_DUMPS_ROOT)) {
        $candidates += (Join-Path $env:MVS_DUMPS_ROOT $Name)
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

function Convert-TestNoteHtmlToText {
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

function Read-TestProducts {
    param([string]$DumpFolder)
    $idsPath = Join-Path $DumpFolder 'mvs_ids.txt'
    $datesPath = Join-Path $DumpFolder 'mvs_dates.txt'
    $notesPath = Join-Path $DumpFolder 'mvs_notes.html'
    if (-not (Test-Path -LiteralPath $idsPath -PathType Leaf)) { throw ('Missing ' + $idsPath) }
    if (-not (Test-Path -LiteralPath $datesPath -PathType Leaf)) { throw ('Missing ' + $datesPath) }

    $dates = @{}
    foreach ($line in Get-Content -LiteralPath $datesPath -Encoding UTF8) {
        if ($line -match '^(?<date>.*?)\s+-\s+.*?\[ID:\s*(?<id>\d+)\]\s*$') {
            $dates[[int]$Matches.id] = $Matches.date.Trim()
        }
    }

    $notes = @{}
    if (Test-Path -LiteralPath $notesPath -PathType Leaf) {
        $html = Get-Content -LiteralPath $notesPath -Raw -Encoding UTF8
        foreach ($match in [regex]::Matches($html, '(?is)<h1>(.*?)</h1>(.*?)(?=<h1>|\z)')) {
            $heading = Normalize-Title ([regex]::Replace($match.Groups[1].Value, '(?is)<[^>]+>', ' '))
            $note = Convert-TestNoteHtmlToText $match.Groups[2].Value
            if ([string]::IsNullOrWhiteSpace($heading) -or [string]::IsNullOrWhiteSpace($note)) { continue }
            if (-not $notes.ContainsKey($heading)) { $notes[$heading] = New-Object System.Collections.ArrayList }
            if (-not $notes[$heading].Contains($note)) { [void]$notes[$heading].Add($note) }
        }
    }

    $products = New-Object System.Collections.ArrayList
    foreach ($line in Get-Content -LiteralPath $idsPath -Encoding UTF8) {
        if ($line -notmatch '^(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') { continue }
        $id = [int]$Matches.id
        $title = Normalize-Title $Matches.title
        $date = if ($dates.ContainsKey($id)) { [string]$dates[$id] } else { '' }
        $note = if ($notes.ContainsKey($title)) { (($notes[$title] | ForEach-Object { [string]$_ }) -join ' || ') } else { '' }
        [void]$products.Add([pscustomobject]@{ id=[string]$id; title=$title; date=$date; note=$note })
    }
    return @($products)
}

function Get-TestNaturalKey {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    $text = $Value.ToLowerInvariant()
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator]{
        param($Match)
        $digits = $Match.Value
        if ($digits.Length -lt 32) { return $digits.PadLeft(32, '0') }
        return ('~' + $digits.Length.ToString('D6') + ':' + $digits)
    }
    return [regex]::Replace($text, '\d+', $evaluator)
}

function Get-TestDateTicks {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return [Int64]::MaxValue }
    $dto = [DateTimeOffset]::MinValue
    $styles = [Globalization.DateTimeStyles]::AllowWhiteSpaces -bor [Globalization.DateTimeStyles]::AssumeUniversal
    if ([DateTimeOffset]::TryParse($Value, [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$dto)) {
        return $dto.UtcDateTime.Ticks
    }
    return [Int64]::MaxValue
}

function Sort-TestProducts {
    param([object[]]$Products, [string]$Key)
    switch ($Key) {
        ''      { return @($Products) }
        'id'    { return @($Products | Sort-Object @{Expression={ [int]$_.id }; Ascending=$true}) }
        'title' { return @($Products | Sort-Object @{Expression={ Get-TestNaturalKey $_.title }; Ascending=$true}, @{Expression={ [int]$_.id }; Ascending=$true}) }
        'date'  { return @($Products | Sort-Object @{Expression={ Get-TestDateTicks $_.date }; Ascending=$true}, @{Expression={ $_.date }; Ascending=$true}, @{Expression={ [int]$_.id }; Ascending=$true}) }
        default { throw ('Bad test sort key: ' + $Key) }
    }
}

function Get-Projections {
    return @(
        [pscustomobject]@{name='id'; fields=@('id')},
        [pscustomobject]@{name='id_title'; fields=@('id','title')},
        [pscustomobject]@{name='id_date'; fields=@('id','date')},
        [pscustomobject]@{name='id_note'; fields=@('id','note')},
        [pscustomobject]@{name='id_title_date'; fields=@('id','title','date')},
        [pscustomobject]@{name='id_title_note'; fields=@('id','title','note')},
        [pscustomobject]@{name='id_title_date_note'; fields=@('id','title','date','note')},
        [pscustomobject]@{name='title'; fields=@('title')},
        [pscustomobject]@{name='title_date'; fields=@('title','date')},
        [pscustomobject]@{name='title_note'; fields=@('title','note')},
        [pscustomobject]@{name='title_date_note'; fields=@('title','date','note')},
        [pscustomobject]@{name='date'; fields=@('date')},
        [pscustomobject]@{name='note'; fields=@('note')},
        [pscustomobject]@{name='date_note'; fields=@('date','note')},
        [pscustomobject]@{name='id_date_note'; fields=@('id','date','note')}
    )
}

function Get-Lookups {
    return @(
        [pscustomobject]@{name='lookup_mvs_title_from_id'; source='id'; target='title'},
        [pscustomobject]@{name='lookup_mvs_title_from_date'; source='date'; target='title'},
        [pscustomobject]@{name='lookup_mvs_note_from_id'; source='id'; target='note'},
        [pscustomobject]@{name='lookup_mvs_note_from_title'; source='title'; target='note'},
        [pscustomobject]@{name='lookup_mvs_note_from_date'; source='date'; target='note'},
        [pscustomobject]@{name='lookup_mvs_date_from_id'; source='id'; target='date'},
        [pscustomobject]@{name='lookup_mvs_date_from_title'; source='title'; target='date'}
    )
}

function Get-Diagnostics {
    return @(
        'find_mvs_duplicate_id_in_mvs.txt',
        'find_mvs_duplicate_id_in_mvs_dates.txt',
        'find_mvs_duplicate_id_in_mvs_ids.txt',
        'find_mvs_duplicate_id_in_mvs_names.txt',
        'find_mvs_duplicate_id_in_mvs_notes.html',
        'find_mvs_duplicate_title_in_mvs.txt',
        'find_mvs_duplicate_title_in_mvs_dates.txt',
        'find_mvs_duplicate_title_in_mvs_ids.txt',
        'find_mvs_duplicate_title_in_mvs_names.txt',
        'find_mvs_duplicate_title_in_mvs_notes.html',
        'find_mvs_duplicate_date_in_mvs_date.txt',
        'find_mvs_duplicate_date_in_mvs_dates.txt',
        'find_mvs_duplicate_filename_in_mvs_names.txt',
        'find_mvs_duplicate_filename_in_mvs.txt',
        'find_mvs_orphan_id_from_mvs_ids.txt_in_mvs.txt',
        'find_mvs_orphan_id_from_mvs_ids.txt_in_mvs_dates.txt',
        'find_mvs_orphan_id_from_mvs_ids.txt_in_mvs_names.txt',
        'find_mvs_orphan_title_from_mvs_ids.txt_in_mvs.txt',
        'find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_dates.txt',
        'find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_names.txt',
        'find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_notes.html',
        'find_mvs_orphan_id_from_mvs_dates.txt_in_mvs.txt',
        'find_mvs_orphan_id_from_mvs_dates.txt_in_mvs_ids.txt',
        'find_mvs_orphan_id_from_mvs_dates.txt_in_mvs_names.txt',
        'find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs.txt',
        'find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs_ids.txt',
        'find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs_names.txt',
        'find_mvs_orphan_id_from_mvs.txt_in_mvs_ids.txt',
        'find_mvs_orphan_id_from_mvs.txt_in_mvs_dates.txt',
        'find_mvs_orphan_id_from_mvs.txt_in_mvs_names.txt',
        'find_mvs_orphan_titles_from_mvs.txt_in_mvs_ids.txt',
        'find_mvs_orphan_titles_from_mvs.txt_in_mvs_dates.txt',
        'find_mvs_orphan_titles_from_mvs.txt_in_mvs_names.txt',
        'find_mvs_orphan_id_from_mvs_names.txt_in_mvs.txt',
        'find_mvs_orphan_id_from_mvs_names.txt_in_mvs_ids.txt',
        'find_mvs_orphan_id_from_mvs_names.txt_in_mvs_dates.txt',
        'find_mvs_orphan_titles_from_mvs_names.txt_in_mvs.txt',
        'find_mvs_orphan_titles_from_mvs_names.txt_in_mvs_ids.txt',
        'find_mvs_orphan_titles_from_mvs_names.txt_in_mvs_dates.txt',
        'find_mvs_orphan_filenames_from_mvs.txt_in_mvs_names.txt',
        'find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.txt',
        'find_mvs_orphan_filenames_from_mvs.txt_in_mvs.sha1',
        'find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.sha1',
        'find_mvs_orphan_filenames_from_mvs.txt_in_mvs.sha256',
        'find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.sha256'
    )
}

function Get-Relationships {
    return @(
        'print_mvs_dump_id_from_filename',
        'read_mvs_dump_id_from_filename',
        'print_mvs_dump_id_from_hash',
        'read_mvs_dump_id_from_hash',
        'print_mvs_dump_title_from_filename',
        'read_mvs_dump_title_from_filename',
        'print_mvs_dump_title_from_hash',
        'read_mvs_dump_title_from_hash',
        'print_mvs_dump_date_from_filename',
        'read_mvs_dump_date_from_filename',
        'print_mvs_dump_date_from_hash',
        'read_mvs_dump_date_from_hash',
        'print_mvs_dump_note_from_filename',
        'read_mvs_dump_note_from_filename',
        'print_mvs_dump_note_from_hash',
        'read_mvs_dump_note_from_hash',
        'print_mvs_dump_filenames_from_filename',
        'read_mvs_dump_filenames_from_filename',
        'print_mvs_dump_filenames_from_hash',
        'read_mvs_dump_filenames_from_hash',
        'print_mvs_dump_id_title_from_filename',
        'read_mvs_dump_id_title_from_filename',
        'print_mvs_dump_id_title_from_hash',
        'read_mvs_dump_id_title_from_hash',
        'print_mvs_dump_id_date_from_filename',
        'read_mvs_dump_id_date_from_filename',
        'print_mvs_dump_id_date_from_hash',
        'read_mvs_dump_id_date_from_hash',
        'print_mvs_dump_id_title_date_from_filename',
        'read_mvs_dump_id_title_date_from_filename',
        'print_mvs_dump_id_title_date_from_hash',
        'read_mvs_dump_id_title_date_from_hash',
        'print_mvs_dump_id_title_note_from_filename',
        'read_mvs_dump_id_title_note_from_filename',
        'print_mvs_dump_id_title_note_from_hash',
        'read_mvs_dump_id_title_note_from_hash',
        'print_mvs_dump_id_title_date_note_from_filename',
        'read_mvs_dump_id_title_date_note_from_filename',
        'print_mvs_dump_id_title_date_note_from_hash',
        'read_mvs_dump_id_title_date_note_from_hash',
        'print_mvs_dump_title_date_from_filename',
        'read_mvs_dump_title_date_from_filename',
        'print_mvs_dump_title_date_from_hash',
        'read_mvs_dump_title_date_from_hash',
        'print_mvs_dump_title_note_from_filename',
        'read_mvs_dump_title_note_from_filename',
        'print_mvs_dump_title_note_from_hash',
        'read_mvs_dump_title_note_from_hash',
        'print_mvs_dump_title_date_note_from_filename',
        'read_mvs_dump_title_date_note_from_filename',
        'print_mvs_dump_title_date_note_from_hash',
        'read_mvs_dump_title_date_note_from_hash',
        'print_mvs_dump_date_note_from_filename',
        'read_mvs_dump_date_note_from_filename',
        'print_mvs_dump_date_note_from_hash',
        'read_mvs_dump_date_note_from_hash',
        'print_mvs_dump_id_title_filenames_from_filename',
        'read_mvs_dump_id_title_filenames_from_filename',
        'print_mvs_dump_id_title_filenames_from_hash',
        'read_mvs_dump_id_title_filenames_from_hash',
        'print_mvs_dump_id_date_filenames_from_filename',
        'read_mvs_dump_id_date_filenames_from_filename',
        'print_mvs_dump_id_date_filenames_from_hash',
        'read_mvs_dump_id_date_filenames_from_hash',
        'print_mvs_dump_id_title_date_filenames_from_filename',
        'read_mvs_dump_id_title_date_filenames_from_filename',
        'print_mvs_dump_id_title_date_filenames_from_hash',
        'read_mvs_dump_id_title_date_filenames_from_hash',
        'print_mvs_dump_id_title_note_filenames_from_filename',
        'read_mvs_dump_id_title_note_filenames_from_filename',
        'print_mvs_dump_id_title_note_filenames_from_hash',
        'read_mvs_dump_id_title_note_filenames_from_hash',
        'print_mvs_dump_id_title_date_note_filenames_from_filename',
        'read_mvs_dump_id_title_date_note_filenames_from_filename',
        'print_mvs_dump_id_title_date_note_filenames_from_hash',
        'read_mvs_dump_id_title_date_note_filenames_from_hash',
        'print_mvs_dump_title_filenames_from_filename',
        'read_mvs_dump_title_filenames_from_filename',
        'print_mvs_dump_title_filenames_from_hash',
        'read_mvs_dump_title_filenames_from_hash',
        'print_mvs_dump_title_date_filenames_from_filename',
        'read_mvs_dump_title_date_filenames_from_filename',
        'print_mvs_dump_title_date_filenames_from_hash',
        'read_mvs_dump_title_date_filenames_from_hash',
        'print_mvs_dump_title_note_filenames_from_filename',
        'read_mvs_dump_title_note_filenames_from_filename',
        'print_mvs_dump_title_note_filenames_from_hash',
        'read_mvs_dump_title_note_filenames_from_hash',
        'print_mvs_dump_title_date_note_filenames_from_filename',
        'read_mvs_dump_title_date_note_filenames_from_filename',
        'print_mvs_dump_title_date_note_filenames_from_hash',
        'read_mvs_dump_title_date_note_filenames_from_hash',
        'print_mvs_dump_date_note_filenames_from_filename',
        'read_mvs_dump_date_note_filenames_from_filename',
        'print_mvs_dump_date_note_filenames_from_hash',
        'read_mvs_dump_date_note_filenames_from_hash'
    )
}

function Get-SingleDumpTools {
    return @(
        [pscustomobject]@{name='print_mvs_dump_filenames_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_filenames_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_hashes_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_hashes_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_filename_hashes_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_filename_hashes_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_filename_hash_algorithm_source_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_filename_hash_algorithm_source_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_id_title_filenames_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_id_title_filenames_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_id_title_filenames_hashes_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_id_title_filenames_hashes_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_title_filenames_hashes_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_title_filenames_hashes_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_id_title_date_note_filenames_hashes_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_id_title_date_note_filenames_hashes_from_id'; operation='detail_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_filenames_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='read_mvs_dump_filenames_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='print_mvs_dump_hashes_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='read_mvs_dump_hashes_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='print_mvs_dump_filename_hashes_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='read_mvs_dump_filename_hashes_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='print_mvs_dump_filename_hash_algorithm_source_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='read_mvs_dump_filename_hash_algorithm_source_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='print_mvs_dump_id_title_filenames_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='read_mvs_dump_id_title_filenames_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='print_mvs_dump_id_title_filenames_hashes_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='read_mvs_dump_id_title_filenames_hashes_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='print_mvs_dump_title_filenames_hashes_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='read_mvs_dump_title_filenames_hashes_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='print_mvs_dump_id_title_date_note_filenames_hashes_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='read_mvs_dump_id_title_date_note_filenames_hashes_from_title'; operation='detail_query'; search_source='title'},
        [pscustomobject]@{name='print_mvs_dump_hashes_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='read_mvs_dump_hashes_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='print_mvs_dump_filename_hashes_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='read_mvs_dump_filename_hashes_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='print_mvs_dump_filename_hash_algorithm_source_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='read_mvs_dump_filename_hash_algorithm_source_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='print_mvs_dump_id_title_filenames_hashes_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='read_mvs_dump_id_title_filenames_hashes_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='print_mvs_dump_title_filenames_hashes_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='read_mvs_dump_title_filenames_hashes_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='print_mvs_dump_id_title_date_note_filenames_hashes_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='read_mvs_dump_id_title_date_note_filenames_hashes_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='print_mvs_dump_sha1_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='read_mvs_dump_sha1_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='print_mvs_dump_sha256_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='read_mvs_dump_sha256_from_filename'; operation='detail_query'; search_source='filename'},
        [pscustomobject]@{name='print_mvs_dump_filename_hashes_from_hash'; operation='detail_query'; search_source='hash'},
        [pscustomobject]@{name='read_mvs_dump_filename_hashes_from_hash'; operation='detail_query'; search_source='hash'},
        [pscustomobject]@{name='print_mvs_dump_filename_hash_algorithm_source_from_hash'; operation='detail_query'; search_source='hash'},
        [pscustomobject]@{name='read_mvs_dump_filename_hash_algorithm_source_from_hash'; operation='detail_query'; search_source='hash'},
        [pscustomobject]@{name='print_mvs_dump_id_title_filenames_hashes_from_hash'; operation='detail_query'; search_source='hash'},
        [pscustomobject]@{name='read_mvs_dump_id_title_filenames_hashes_from_hash'; operation='detail_query'; search_source='hash'},
        [pscustomobject]@{name='print_mvs_dump_title_filenames_hashes_from_hash'; operation='detail_query'; search_source='hash'},
        [pscustomobject]@{name='read_mvs_dump_title_filenames_hashes_from_hash'; operation='detail_query'; search_source='hash'},
        [pscustomobject]@{name='print_mvs_dump_id_title_date_note_filenames_hashes_from_hash'; operation='detail_query'; search_source='hash'},
        [pscustomobject]@{name='read_mvs_dump_id_title_date_note_filenames_hashes_from_hash'; operation='detail_query'; search_source='hash'},
        [pscustomobject]@{name='print_mvs_dump_variants'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_variants'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_variant_titles'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_variant_titles'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_variant_filenames'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_variant_filenames'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_variant_hashes'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_variant_hashes'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_id_variant_titles'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_id_variant_titles'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_id_variant_filenames'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_id_variant_filenames'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_id_variant_hashes'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_id_variant_hashes'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_id_variant_title_filename_hashes'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_id_variant_title_filename_hashes'; operation='variant_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_variants_from_id'; operation='variant_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_variants_from_id'; operation='variant_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_variant_titles_from_id'; operation='variant_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_variant_titles_from_id'; operation='variant_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_variant_filenames_from_id'; operation='variant_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_variant_filenames_from_id'; operation='variant_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_variant_hashes_from_id'; operation='variant_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_variant_hashes_from_id'; operation='variant_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_id_variant_title_filename_hashes_from_id'; operation='variant_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_id_variant_title_filename_hashes_from_id'; operation='variant_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_variants_from_filename'; operation='variant_query'; search_source='filename'},
        [pscustomobject]@{name='read_mvs_dump_variants_from_filename'; operation='variant_query'; search_source='filename'},
        [pscustomobject]@{name='print_mvs_dump_id_variant_title_filename_hashes_from_filename'; operation='variant_query'; search_source='filename'},
        [pscustomobject]@{name='read_mvs_dump_id_variant_title_filename_hashes_from_filename'; operation='variant_query'; search_source='filename'},
        [pscustomobject]@{name='print_mvs_dump_variants_from_hash'; operation='variant_query'; search_source='hash'},
        [pscustomobject]@{name='read_mvs_dump_variants_from_hash'; operation='variant_query'; search_source='hash'},
        [pscustomobject]@{name='print_mvs_dump_id_variant_title_filename_hashes_from_hash'; operation='variant_query'; search_source='hash'},
        [pscustomobject]@{name='read_mvs_dump_id_variant_title_filename_hashes_from_hash'; operation='variant_query'; search_source='hash'},
        [pscustomobject]@{name='print_mvs_dump_hash_records'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_hash_records'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_hash_records_from_filename'; operation='hash_query'; search_source='filename'},
        [pscustomobject]@{name='read_mvs_dump_hash_records_from_filename'; operation='hash_query'; search_source='filename'},
        [pscustomobject]@{name='print_mvs_dump_hash_records_from_hash'; operation='hash_query'; search_source='hash'},
        [pscustomobject]@{name='read_mvs_dump_hash_records_from_hash'; operation='hash_query'; search_source='hash'},
        [pscustomobject]@{name='print_mvs_dump_sha1'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_sha1'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_sha256'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_sha256'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_sha1_filename'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_sha1_filename'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_sha256_filename'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_sha256_filename'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_filename_sha1'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_filename_sha1'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_filename_sha256'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_filename_sha256'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_filename_hash_algorithm_source'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_filename_hash_algorithm_source'; operation='hash_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_product_files'; operation='product_file_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_product_files'; operation='product_file_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_product_files_from_id'; operation='product_file_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_product_files_from_id'; operation='product_file_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_product_files_from_title'; operation='product_file_query'; search_source='title'},
        [pscustomobject]@{name='read_mvs_dump_product_files_from_title'; operation='product_file_query'; search_source='title'},
        [pscustomobject]@{name='print_mvs_dump_product_sections'; operation='product_section_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_product_sections'; operation='product_section_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_product_sections_from_id'; operation='product_section_query'; search_source='id'},
        [pscustomobject]@{name='read_mvs_dump_product_sections_from_id'; operation='product_section_query'; search_source='id'},
        [pscustomobject]@{name='print_mvs_dump_product_sections_from_title'; operation='product_section_query'; search_source='title'},
        [pscustomobject]@{name='read_mvs_dump_product_sections_from_title'; operation='product_section_query'; search_source='title'},
        [pscustomobject]@{name='print_mvs_dump_note_records'; operation='note_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_note_records'; operation='note_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_note_records_from_title'; operation='note_query'; search_source='title'},
        [pscustomobject]@{name='read_mvs_dump_note_records_from_title'; operation='note_query'; search_source='title'},
        [pscustomobject]@{name='find_mvs_unparsed_lines_in_mvs.txt'; operation='unparsed_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_unparsed_lines_in_mvs.txt'; operation='unparsed_query'; search_source=''},
        [pscustomobject]@{name='find_mvs_unparsed_lines_in_mvs_names.txt'; operation='unparsed_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_unparsed_lines_in_mvs_names.txt'; operation='unparsed_query'; search_source=''},
        [pscustomobject]@{name='find_mvs_unparsed_lines_in_mvs.sha1'; operation='unparsed_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_unparsed_lines_in_mvs.sha1'; operation='unparsed_query'; search_source=''},
        [pscustomobject]@{name='find_mvs_unparsed_lines_in_mvs.sha256'; operation='unparsed_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_unparsed_lines_in_mvs.sha256'; operation='unparsed_query'; search_source=''},
        [pscustomobject]@{name='find_mvs_unparsed_lines_in_mvs_ids.txt'; operation='unparsed_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_unparsed_lines_in_mvs_ids.txt'; operation='unparsed_query'; search_source=''},
        [pscustomobject]@{name='find_mvs_unparsed_lines_in_mvs_dates.txt'; operation='unparsed_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_unparsed_lines_in_mvs_dates.txt'; operation='unparsed_query'; search_source=''},
        [pscustomobject]@{name='find_mvs_duplicate_sha1_in_mvs.sha1'; operation='hash_diagnostic'; search_source=''},
        [pscustomobject]@{name='find_mvs_duplicate_sha256_in_mvs.sha256'; operation='hash_diagnostic'; search_source=''},
        [pscustomobject]@{name='find_mvs_duplicate_hash_in_mvs.txt'; operation='hash_diagnostic'; search_source=''},
        [pscustomobject]@{name='find_mvs_duplicate_hash_in_mvs_names.txt'; operation='hash_diagnostic'; search_source=''},
        [pscustomobject]@{name='find_mvs_hash_with_multiple_filenames_in_mvs.sha1'; operation='hash_diagnostic'; search_source=''},
        [pscustomobject]@{name='find_mvs_hash_with_multiple_filenames_in_mvs.sha256'; operation='hash_diagnostic'; search_source=''},
        [pscustomobject]@{name='find_mvs_filename_with_multiple_hashes_in_mvs.txt'; operation='hash_diagnostic'; search_source=''},
        [pscustomobject]@{name='find_mvs_filename_with_multiple_hashes_in_mvs_names.txt'; operation='hash_diagnostic'; search_source=''},
        [pscustomobject]@{name='find_mvs_hash_mismatch_for_filename_between_mvs.txt_and_mvs.sha1'; operation='hash_diagnostic'; search_source=''},
        [pscustomobject]@{name='find_mvs_hash_mismatch_for_filename_between_mvs.txt_and_mvs.sha256'; operation='hash_diagnostic'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_summary'; operation='summary_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_summary'; operation='summary_query'; search_source=''},
        [pscustomobject]@{name='print_mvs_dump_statistics'; operation='summary_query'; search_source=''},
        [pscustomobject]@{name='read_mvs_dump_statistics'; operation='summary_query'; search_source=''}
    )
}


function Get-CompareTools {
    return @(
        [pscustomobject]@{name='compare_mvs_dump_id_from_mvs.txt'; property='id'; source_file='mvs.txt'},
        [pscustomobject]@{name='compare_mvs_dump_id_from_mvs_ids.txt'; property='id'; source_file='mvs_ids.txt'},
        [pscustomobject]@{name='compare_mvs_dump_id_from_mvs_names.txt'; property='id'; source_file='mvs_names.txt'},
        [pscustomobject]@{name='compare_mvs_dump_id_from_mvs_dates.txt'; property='id'; source_file='mvs_dates.txt'},
        [pscustomobject]@{name='compare_mvs_dump_title_from_mvs.txt'; property='title'; source_file='mvs.txt'},
        [pscustomobject]@{name='compare_mvs_dump_title_from_mvs_ids.txt'; property='title'; source_file='mvs_ids.txt'},
        [pscustomobject]@{name='compare_mvs_dump_title_from_mvs_names.txt'; property='title'; source_file='mvs_names.txt'},
        [pscustomobject]@{name='compare_mvs_dump_title_from_mvs_dates.txt'; property='title'; source_file='mvs_dates.txt'},
        [pscustomobject]@{name='compare_mvs_dump_dates_from_mvs_dates.txt'; property='date'; source_file='mvs_dates.txt'},
        [pscustomobject]@{name='compare_mvs_dump_sha1_from_mvs.txt'; property='sha1'; source_file='mvs.txt'},
        [pscustomobject]@{name='compare_mvs_dump_sha1_from_mvs_names.txt'; property='sha1'; source_file='mvs_names.txt'},
        [pscustomobject]@{name='compare_mvs_dump_sha1_from_mvs.sha1'; property='sha1'; source_file='mvs.sha1'},
        [pscustomobject]@{name='compare_mvs_dump_sha256_from_mvs.txt'; property='sha256'; source_file='mvs.txt'},
        [pscustomobject]@{name='compare_mvs_dump_sha256_from_mvs_names.txt'; property='sha256'; source_file='mvs_names.txt'},
        [pscustomobject]@{name='compare_mvs_dump_sha256_from_mvs.sha256'; property='sha256'; source_file='mvs.sha256'},
        [pscustomobject]@{name='compare_mvs_dump_filenames_from_mvs.txt'; property='filename'; source_file='mvs.txt'},
        [pscustomobject]@{name='compare_mvs_dump_filenames_from_mvs_names.txt'; property='filename'; source_file='mvs_names.txt'},
        [pscustomobject]@{name='compare_mvs_dump_filenames_from_mvs.sha1'; property='filename'; source_file='mvs.sha1'},
        [pscustomobject]@{name='compare_mvs_dump_filenames_from_mvs.sha256'; property='filename'; source_file='mvs.sha256'}
    )
}

function Normalize-CapturedText {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return '' }
    return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Build-ExpectedText {
    param([string[]]$Lines)
    if ($null -eq $Lines -or $Lines.Count -eq 0) { return '' }
    return (($Lines -join "`n") + "`n")
}

function Short-Text {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return '' }
    $clean = $Text.Replace("`r", '\r').Replace("`n", '\n').Replace("`t", '\t')
    if ($clean.Length -gt 320) { return $clean.Substring(0,320) + '...' }
    return $clean
}

function Invoke-PublicTool {
    param([string]$ToolPath, [string]$DumpValue, [AllowNull()][string]$SearchValue, [bool]$HasSearch)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = if ([string]::IsNullOrWhiteSpace($env:ComSpec)) { 'cmd.exe' } else { $env:ComSpec }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.EnvironmentVariables['MVS_TEST_TOOL'] = $ToolPath
    $psi.EnvironmentVariables['MVS_TEST_DUMP'] = $DumpValue
    if ($HasSearch) {
        $psi.EnvironmentVariables['MVS_TEST_ARG'] = [string]$SearchValue
        $psi.Arguments = '/d /s /c ""%MVS_TEST_TOOL%" "%MVS_TEST_DUMP%" "%MVS_TEST_ARG%""'
    } else {
        $psi.Arguments = '/d /s /c ""%MVS_TEST_TOOL%" "%MVS_TEST_DUMP%""'
    }
    if ($psi.PSObject.Properties.Name -contains 'StandardOutputEncoding') {
        $psi.StandardOutputEncoding = $utf8
        $psi.StandardErrorEncoding = $utf8
    }
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $sw=[Diagnostics.Stopwatch]::StartNew()
    [void]$process.Start()
    $outTask = $process.StandardOutput.ReadToEndAsync()
    $errTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $sw.Stop()
    return [pscustomobject]@{
        rc = $process.ExitCode
        stdout = Normalize-CapturedText $outTask.Result
        stderr = Normalize-CapturedText $errTask.Result
        elapsed_ms = $sw.ElapsedMilliseconds
    }
}


function Invoke-ComparePublicTool {
    param([string]$ToolPath, [string]$FirstDump, [string]$SecondDump)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = if ([string]::IsNullOrWhiteSpace($env:ComSpec)) { 'cmd.exe' } else { $env:ComSpec }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.EnvironmentVariables['MVS_TEST_TOOL'] = $ToolPath
    $psi.EnvironmentVariables['MVS_TEST_FIRST'] = $FirstDump
    $psi.EnvironmentVariables['MVS_TEST_SECOND'] = $SecondDump
    $psi.Arguments = '/d /s /c ""%MVS_TEST_TOOL%" "%MVS_TEST_FIRST%" "%MVS_TEST_SECOND%""'
    if ($psi.PSObject.Properties.Name -contains 'StandardOutputEncoding') {
        $psi.StandardOutputEncoding = $utf8
        $psi.StandardErrorEncoding = $utf8
    }
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $sw=[Diagnostics.Stopwatch]::StartNew()
    [void]$process.Start()
    $outTask = $process.StandardOutput.ReadToEndAsync()
    $errTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $sw.Stop()
    return [pscustomobject]@{
        rc = $process.ExitCode
        stdout = Normalize-CapturedText $outTask.Result
        stderr = Normalize-CapturedText $errTask.Result
        elapsed_ms = $sw.ElapsedMilliseconds
    }
}

function Get-SafeCaseName {
    param([string]$Name)
    $safe = [regex]::Replace($Name, '[^A-Za-z0-9._-]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = 'case' }
    if ($safe.Length -gt 120) { $safe = $safe.Substring(0,120) }
    return ($script:CaseIndex.ToString('D4') + '-' + $safe)
}

function Save-FailureArtifacts {
    param([string]$Name, [object]$Run, [int]$ExpectedRc, [string]$ExpectedStdout, [string]$Reason)
    $base = Get-SafeCaseName $Name
    Write-TextUtf8 (Join-Path $script:FailuresFolder ($base + '.expected.txt')) $ExpectedStdout
    Write-TextUtf8 (Join-Path $script:FailuresFolder ($base + '.actual.txt')) $Run.stdout
    Write-TextUtf8 (Join-Path $script:FailuresFolder ($base + '.stderr.txt')) $Run.stderr
    $meta = @(
        ('Case: ' + $Name),
        ('Scope: ' + $script:CurrentScope),
        ('Reason: ' + $Reason),
        ('Expected return code: ' + $ExpectedRc),
        ('Actual return code: ' + $Run.rc)
    )
    Write-TextUtf8 (Join-Path $script:FailuresFolder ($base + '.meta.txt')) (($meta -join [Environment]::NewLine) + [Environment]::NewLine)
}

function Compare-Run {
    param([string]$Name, [object]$Run, [int]$ExpectedRc, [string]$ExpectedStdout)
    $reasons = New-Object System.Collections.ArrayList
    if ($Run.rc -ne $ExpectedRc) { [void]$reasons.Add(('rc expected ' + $ExpectedRc + ', got ' + $Run.rc)) }
    if ($Run.stdout -cne $ExpectedStdout) {
        [void]$reasons.Add(('stdout differs; expected=' + (Short-Text $ExpectedStdout) + '; actual=' + (Short-Text $Run.stdout)))
    }
    if (-not [string]::IsNullOrEmpty($Run.stderr)) {
        [void]$reasons.Add(('stderr=' + (Short-Text $Run.stderr)))
    }
    if ($reasons.Count -eq 0) {
        Write-Pass $Name ([string]$ExpectedRc) ([string]$Run.rc) ([string]$Run.elapsed_ms)
    } else {
        $reason = $reasons -join '; '
        Write-Fail $Name $reason ([string]$ExpectedRc) ([string]$Run.rc) ([string]$Run.elapsed_ms)
        Save-FailureArtifacts $Name $Run $ExpectedRc $ExpectedStdout $reason
    }
}

function Get-ScalarExpected {
    param([object[]]$Products, [string[]]$Fields, [string]$ModeName)
    $lines = New-Object System.Collections.ArrayList
    foreach ($record in $Products) {
        $values = @()
        foreach ($field in $Fields) {
            $value = Normalize-Scalar ([string]$record.$field)
            if ($ModeName -eq 'human') {
                if ([string]::IsNullOrEmpty($value)) { $value = '(none)' }
                $label = switch ($field) {
                    'id' { 'ID' }
                    'title' { 'Title' }
                    'date' { 'Date' }
                    'note' { 'Note' }
                }
                $values += ($label + ': ' + $value)
            } else {
                $values += $value
            }
        }
        if ($ModeName -eq 'human') {
            [void]$lines.Add(($values -join ' | '))
        } else {
            [void]$lines.Add(($values -join [char]9))
        }
    }
    return Build-ExpectedText @($lines)
}

function New-TestWildcardRegex {
    param([string]$Pattern)
    $escaped = [regex]::Escape($Pattern).Replace('\*', '.*')
    return New-Object System.Text.RegularExpressions.Regex(('^' + $escaped + '$'), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function Get-LookupExpected {
    param([object[]]$Products, [string]$Source, [string]$Target, [string]$Pattern)
    $regex = New-TestWildcardRegex $Pattern
    $matches = @($Products | Where-Object { $regex.IsMatch([string]$_.$Source) })
    $matches = Sort-TestProducts $matches $Source
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $lines = New-Object System.Collections.ArrayList
    foreach ($record in $matches) {
        $value = Normalize-Scalar ([string]$record.$Target)
        if ([string]::IsNullOrEmpty($value)) { continue }
        if ($seen.Add($value)) { [void]$lines.Add($value) }
    }
    return [pscustomobject]@{
        rc = if ($lines.Count -gt 0) { 0 } else { 1 }
        stdout = Build-ExpectedText @($lines)
    }
}

function Get-ProductFamilyToolNames {
    $bases = @(
        'product_titles_from_family',
        'product_families_from_title',
        'product_ids_from_family',
        'product_families_from_id',
        'product_dates_from_family',
        'product_families_from_date',
        'product_filenames_from_family',
        'product_families_from_filename',
        'product_hashes_from_family',
        'product_families_from_hash',
        'product_snapshots_from_family',
        'product_families_from_snapshot',
        'product_family_parents_from_family',
        'product_family_children_from_family',
        'product_notes_from_family',
        'product_releases_from_family'
    )
    $names = New-Object System.Collections.ArrayList
    [void]$names.Add('build_mvs_product_family_index')
    [void]$names.Add('build_mvs_product_family_compact_index')
    foreach ($base in $bases) {
        [void]$names.Add('print_mvs_'+$base)
        [void]$names.Add('read_mvs_'+$base)
    }
    return @($names)
}

function Test-Structure {
    $script:CurrentScope = 'structure'
    Write-Line '=== Structure tests ==='
    $expected = New-Object System.Collections.ArrayList
    foreach ($projection in Get-Projections) {
        foreach ($prefix in @('print','read')) {
            $base = $prefix + '_mvs_dump_' + $projection.name
            [void]$expected.Add($base + '.bat')
            foreach ($key in @('id','title','date')) { [void]$expected.Add($base + '_sorted_by_' + $key + '.bat') }
        }
    }
    foreach ($lookup in Get-Lookups) { [void]$expected.Add($lookup.name + '.bat') }
    foreach ($diagnostic in Get-Diagnostics) { [void]$expected.Add($diagnostic + '.bat') }
    foreach ($relationship in Get-Relationships) { [void]$expected.Add($relationship + '.bat') }
    foreach ($single in Get-SingleDumpTools) { [void]$expected.Add($single.name + '.bat') }
    foreach ($compare in Get-CompareTools) { [void]$expected.Add($compare.name + '.bat') }
    foreach ($historyTool in @('build_mvs_dump_change_history','build_mvs_dump_all_ever')) { [void]$expected.Add($historyTool + '.bat') }
    foreach ($familyTool in Get-ProductFamilyToolNames) { [void]$expected.Add($familyTool + '.bat') }

    $actual = @(Get-ChildItem -LiteralPath $Root -Filter '*.bat' -File | Select-Object -ExpandProperty Name)
    if ($actual.Count -eq 477) { Write-Pass 'root public .bat count = 477' } else { Write-Fail 'root public .bat count' ('expected 477, got ' + $actual.Count) }

    foreach ($name in $expected) {
        $path = Join-Path $Root $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Write-Fail ('exists ' + $name) 'file missing'; continue }
        $bytes = [IO.File]::ReadAllBytes($path)
        $text = [Text.Encoding]::UTF8.GetString($bytes)
        $problems = New-Object System.Collections.ArrayList
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { [void]$problems.Add('UTF-8 BOM present') }
        foreach ($label in @(':setup',':main',':end',':SetErrorLevel',':RunPowerShellFromLabel')) {
            if (-not $text.Contains($label)) { [void]$problems.Add('missing ' + $label) }
        }
        if (-not $text.Contains(':_MVSQuery_start') -and -not $text.Contains(':_MVSLookup_start') -and -not $text.Contains(':_MVSDiagnostic_start') -and -not $text.Contains(':_MVSRelationship_start') -and -not $text.Contains(':_MVSSingleDump_start') -and -not $text.Contains(':_MVSCompare_start') -and -not $text.Contains(':_MVSHistory_start') -and -not $text.Contains(':_MVSProductFamily_start') -and -not $text.Contains(':_MVSProductFamilyCompact_start') -and -not $text.Contains(':_MVSProductFamilyQuery_start')) { [void]$problems.Add('missing injected PowerShell block') }
        if ($text.Contains('dev\library') -or $text.Contains('generate_tools.py')) { [void]$problems.Add('development runtime dependency reference') }
        if ($text.Contains(':_MVSSingleDump_start') -and -not $text.Contains('return ,(New-Object System.Collections.ArrayList)')) {
            [void]$problems.Add('single-dump New-ArrayList can collapse empty collection to null')
        }
        if ($problems.Count -eq 0) { Write-Pass ('standalone ' + $name) } else { Write-Fail ('standalone ' + $name) ($problems -join ', ') }
    }
}

function Test-Scalar {
    param([object[]]$Products)
    $script:CurrentScope = 'scalar'
    Write-Line '=== Scalar tool tests ==='
    foreach ($projection in Get-Projections) {
        foreach ($family in @(
            [pscustomobject]@{prefix='print'; mode='human'},
            [pscustomobject]@{prefix='read'; mode='machine'}
        )) {
            $base = $family.prefix + '_mvs_dump_' + $projection.name
            foreach ($sortKey in @('','id','title','date')) {
                $name = if ($sortKey -eq '') { $base } else { $base + '_sorted_by_' + $sortKey }
                $path = Join-Path $Root ($name + '.bat')
                $ordered = Sort-TestProducts $Products $sortKey
                $expected = Get-ScalarExpected $ordered $projection.fields $family.mode
                $run = Invoke-PublicTool $path $script:DumpForTools $null $false
                Compare-Run $name $run 0 $expected
            }
        }
    }
}

function Test-OneLookupPattern {
    param([object[]]$Products, [object]$Lookup, [string]$Pattern, [string]$CaseName)
    $expected = Get-LookupExpected $Products $Lookup.source $Lookup.target $Pattern
    $path = Join-Path $Root ($Lookup.name + '.bat')
    $run = Invoke-PublicTool $path $script:DumpForTools $Pattern $true
    Compare-Run ($Lookup.name + ' [' + $CaseName + ': ' + $Pattern + ']') $run $expected.rc $expected.stdout
}

function Test-Lookups {
    param([object[]]$Products)
    $script:CurrentScope = 'lookup'
    Write-Line '=== Lookup tool tests ==='
    foreach ($lookup in Get-Lookups) {
        $candidate = @($Products | Where-Object {
            -not [string]::IsNullOrEmpty([string]$_.$($lookup.source)) -and
            -not [string]::IsNullOrEmpty((Normalize-Scalar ([string]$_.$($lookup.target))))
        } | Select-Object -First 1)
        if ($candidate.Count -gt 0) {
            Test-OneLookupPattern $Products $lookup ([string]$candidate[0].$($lookup.source)) 'exact'
        } else {
            Write-Skip ($lookup.name + ' exact') ('dump has no non-empty ' + $lookup.target + ' associated with ' + $lookup.source)
        }
        Test-OneLookupPattern $Products $lookup '*' 'wildcard-all'
        Test-OneLookupPattern $Products $lookup '__MVS_TEST_NO_MATCH_9E3779B97F4A7C15__' 'no-match'
    }

    $idLookup = (Get-Lookups | Where-Object { $_.name -eq 'lookup_mvs_title_from_id' })
    $idCandidate = @($Products | Where-Object { $_.id.Length -ge 2 -and -not [string]::IsNullOrEmpty($_.title) } | Select-Object -First 1)
    if ($idCandidate.Count -eq 0) { $idCandidate = @($Products | Select-Object -First 1) }
    if ($idCandidate.Count -gt 0) {
        $id = [string]$idCandidate[0].id
        $first = $id.Substring(0,1)
        $last = $id.Substring($id.Length-1,1)
        $midIndex = [int][Math]::Floor(($id.Length-1)/2)
        $mid = $id.Substring($midIndex,1)
        Test-OneLookupPattern $Products $idLookup ($first + '*') 'prefix-wildcard'
        Test-OneLookupPattern $Products $idLookup ('*' + $last) 'suffix-wildcard'
        Test-OneLookupPattern $Products $idLookup ('*' + $mid + '*') 'contains-wildcard'
    }
}


function Test-Diagnostics {
    $script:CurrentScope = 'diagnostic'
    Write-Line '=== Duplicate/orphan diagnostic tests ==='

    $fixture = Join-Path (Join-Path $Root 'test') 'test-mvs-dump-diagnostics'
    $expectedRoot = Join-Path (Join-Path $Root 'test') 'expected-diagnostics'

    if (-not (Test-Path -LiteralPath $fixture -PathType Container)) {
        Write-Fail 'diagnostic synthetic dump' ('missing fixture: ' + $fixture)
        return
    }
    if (-not (Test-Path -LiteralPath $expectedRoot -PathType Container)) {
        Write-Fail 'diagnostic expected outputs' ('missing expected folder: ' + $expectedRoot)
        return
    }
    Write-Pass 'diagnostic synthetic dump present'

    foreach ($name in Get-Diagnostics) {
        $toolPath = Join-Path $Root ($name + '.bat')
        $expectedPath = Join-Path $expectedRoot ($name + '.expected.txt')
        if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) {
            Write-Fail $name ('missing expected output: ' + $expectedPath)
            continue
        }
        $expected = Normalize-CapturedText (Get-Content -LiteralPath $expectedPath -Raw -Encoding UTF8)
        if ([string]::IsNullOrEmpty($expected)) {
            Write-Fail $name 'synthetic fixture expected output is empty; positive finding was required'
            continue
        }
        $run = Invoke-PublicTool $toolPath $fixture $null $false
        Compare-Run $name $run 0 $expected
    }
}



function Read-TestValueFile {
    param([string]$Path)
    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        if ($line -match '^(?<key>[^=]+)=(?<value>.*)$') {
            $values[$Matches.key.Trim()] = $Matches.value.Trim()
        }
    }
    return $values
}

function Test-RelationshipCase {
    param(
        [string]$ToolName,
        [string]$Fixture,
        [string]$ExpectedRoot,
        [string]$CaseName,
        [string]$SearchValue
    )
    $toolPath = Join-Path $Root ($ToolName + '.bat')
    $expectedPath = Join-Path $ExpectedRoot ($ToolName + '__' + $CaseName + '.expected.txt')
    if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) {
        Write-Fail ($ToolName + ' [' + $CaseName + ']') ('missing expected output: ' + $expectedPath)
        return
    }
    $expected = Normalize-CapturedText (Get-Content -LiteralPath $expectedPath -Raw -Encoding UTF8)
    $run = Invoke-PublicTool $toolPath $Fixture $SearchValue $true
    Compare-Run ($ToolName + ' [' + $CaseName + ']') $run 0 $expected
}

function Test-Relationships {
    $script:CurrentScope = 'relationship'
    Write-Line '=== Filename/hash relationship tests ==='

    $fixture = Join-Path (Join-Path $Root 'test') 'test-mvs-dump-relationships'
    $expectedRoot = Join-Path (Join-Path $Root 'test') 'expected-relationships'
    $valuePath = Join-Path $fixture 'TEST-VALUES.txt'

    if (-not (Test-Path -LiteralPath $fixture -PathType Container)) {
        Write-Fail 'relationship synthetic dump' ('missing fixture: ' + $fixture)
        return
    }
    if (-not (Test-Path -LiteralPath $expectedRoot -PathType Container)) {
        Write-Fail 'relationship expected outputs' ('missing expected folder: ' + $expectedRoot)
        return
    }
    if (-not (Test-Path -LiteralPath $valuePath -PathType Leaf)) {
        Write-Fail 'relationship test values' ('missing file: ' + $valuePath)
        return
    }

    $values = Read-TestValueFile $valuePath
    foreach ($required in @('filename','sha1','sha256','mvs_txt_hash')) {
        if (-not $values.ContainsKey($required) -or [string]::IsNullOrWhiteSpace([string]$values[$required])) {
            Write-Fail 'relationship test values' ('missing key: ' + $required)
            return
        }
    }

    Write-Pass 'relationship synthetic dump present'

    foreach ($name in Get-Relationships) {
        if ($name.EndsWith('_from_filename')) {
            Test-RelationshipCase $name $fixture $expectedRoot 'filename' ([string]$values.filename)
        } elseif ($name.EndsWith('_from_hash')) {
            Test-RelationshipCase $name $fixture $expectedRoot 'sha1' ([string]$values.sha1)
            Test-RelationshipCase $name $fixture $expectedRoot 'sha256' ([string]$values.sha256)
        } else {
            Write-Fail $name 'relationship tool has no recognized source suffix'
        }
    }

    foreach ($name in @('print_mvs_dump_filenames_from_hash','read_mvs_dump_filenames_from_hash')) {
        Test-RelationshipCase $name $fixture $expectedRoot 'mvs-txt' ([string]$values.mvs_txt_hash)
    }

    foreach ($name in @('print_mvs_dump_filenames_from_filename','read_mvs_dump_filenames_from_filename')) {
        $toolPath = Join-Path $Root ($name + '.bat')
        $run = Invoke-PublicTool $toolPath $fixture '__MVS_REL_NO_SUCH_FILENAME__' $true
        Compare-Run ($name + ' [no-result]') $run 1 ''
    }

    foreach ($name in @('print_mvs_dump_filenames_from_hash','read_mvs_dump_filenames_from_hash')) {
        $toolPath = Join-Path $Root ($name + '.bat')
        $run = Invoke-PublicTool $toolPath $fixture '0000000000000000000000000000000000000000' $true
        Compare-Run ($name + ' [no-result]') $run 1 ''
    }
}


function Get-SingleDumpSearchValue {
    param([object]$Tool, [hashtable]$Values)

    if ([string]::IsNullOrEmpty([string]$Tool.search_source)) { return $null }

    if ($Tool.operation -eq 'variant_query') {
        if ($Tool.search_source -eq 'id') { return [string]$Values.variant_id }
        if ($Tool.search_source -eq 'filename') { return [string]$Values.variant_filename }
        if ($Tool.search_source -eq 'hash') { return [string]$Values.variant_hash }
    }
    if ($Tool.operation -eq 'note_query') { return [string]$Values.note_title }

    $key = [string]$Tool.search_source
    return [string]$Values[$key]
}

function Test-SingleDumpNoResult {
    param([string]$Name, [string]$Fixture, [string]$SearchValue)
    $toolPath = Join-Path $Root ($Name + '.bat')
    $run = Invoke-PublicTool $toolPath $Fixture $SearchValue $true
    Compare-Run ($Name + ' [no-result]') $run 1 ''
}

function Test-SingleDumpTools {
    $script:CurrentScope = 'single_dump'
    Write-Line '=== Single-dump completeness tests ==='

    $fixture = Join-Path (Join-Path $Root 'test') 'test-mvs-dump-single-complete'
    $expectedRoot = Join-Path (Join-Path $Root 'test') 'expected-single-dump'
    $valuePath = Join-Path $fixture 'TEST-VALUES.txt'

    if (-not (Test-Path -LiteralPath $fixture -PathType Container)) {
        Write-Fail 'single-dump synthetic dump' ('missing fixture: ' + $fixture)
        return
    }
    if (-not (Test-Path -LiteralPath $expectedRoot -PathType Container)) {
        Write-Fail 'single-dump expected outputs' ('missing expected folder: ' + $expectedRoot)
        return
    }
    if (-not (Test-Path -LiteralPath $valuePath -PathType Leaf)) {
        Write-Fail 'single-dump test values' ('missing file: ' + $valuePath)
        return
    }

    $values = Read-TestValueFile $valuePath
    foreach ($required in @('id','title','filename','hash','variant_id','variant_filename','variant_hash','note_title')) {
        if (-not $values.ContainsKey($required) -or [string]::IsNullOrWhiteSpace([string]$values[$required])) {
            Write-Fail 'single-dump test values' ('missing key: ' + $required)
            return
        }
    }

    Write-Pass 'single-dump synthetic dump present'

    foreach ($tool in Get-SingleDumpTools) {
        $name = [string]$tool.name
        $expectedPath = Join-Path $expectedRoot ($name + '.expected.txt')
        if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) {
            Write-Fail $name ('missing expected output: ' + $expectedPath)
            continue
        }

        $expected = Normalize-CapturedText (Get-Content -LiteralPath $expectedPath -Raw -Encoding UTF8)
        $search = Get-SingleDumpSearchValue $tool $values
        $hasSearch = -not [string]::IsNullOrEmpty([string]$tool.search_source)
        $run = Invoke-PublicTool (Join-Path $Root ($name + '.bat')) $fixture $search $hasSearch
        Compare-Run $name $run 0 $expected
    }

    foreach ($name in @('print_mvs_dump_filenames_from_id','read_mvs_dump_filenames_from_id')) {
        Test-SingleDumpNoResult $name $fixture '999999'
    }
    foreach ($name in @('print_mvs_dump_variants_from_id','read_mvs_dump_variants_from_id')) {
        Test-SingleDumpNoResult $name $fixture '999999'
    }
    foreach ($name in @('print_mvs_dump_hash_records_from_hash','read_mvs_dump_hash_records_from_hash')) {
        Test-SingleDumpNoResult $name $fixture '0000000000000000000000000000000000000000'
    }
    foreach ($name in @('print_mvs_dump_product_files_from_id','read_mvs_dump_product_files_from_id')) {
        Test-SingleDumpNoResult $name $fixture '999999'
    }
    foreach ($name in @('print_mvs_dump_product_sections_from_id','read_mvs_dump_product_sections_from_id')) {
        Test-SingleDumpNoResult $name $fixture '999999'
    }
    foreach ($name in @('print_mvs_dump_note_records_from_title','read_mvs_dump_note_records_from_title')) {
        Test-SingleDumpNoResult $name $fixture '__MVS_NO_SUCH_NOTE_TITLE__'
    }
}


function Test-CompareTools {
    $script:CurrentScope = 'compare'
    Write-Line '=== Two-dump comparison tests ==='

    $fixtureRoot = Join-Path (Join-Path $Root 'test') 'test-mvs-dump-compare'
    $before = Join-Path $fixtureRoot 'before'
    $after = Join-Path $fixtureRoot 'after'
    $expectedRoot = Join-Path (Join-Path $Root 'test') 'expected-compare'

    if (-not (Test-Path -LiteralPath $before -PathType Container) -or
        -not (Test-Path -LiteralPath $after -PathType Container)) {
        Write-Fail 'comparison synthetic dumps' ('missing before/after fixture under: ' + $fixtureRoot)
        return
    }
    if (-not (Test-Path -LiteralPath $expectedRoot -PathType Container)) {
        Write-Fail 'comparison expected outputs' ('missing expected folder: ' + $expectedRoot)
        return
    }

    Write-Pass 'comparison synthetic dumps present'

    foreach ($tool in Get-CompareTools) {
        $name = [string]$tool.name
        $expectedPath = Join-Path $expectedRoot ($name + '.expected.txt')
        if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) {
            Write-Fail $name ('missing expected output: ' + $expectedPath)
            continue
        }
        $expected = Normalize-CapturedText (Get-Content -LiteralPath $expectedPath -Raw -Encoding UTF8)
        $run = Invoke-ComparePublicTool (Join-Path $Root ($name + '.bat')) $before $after
        Compare-Run $name $run 0 $expected
    }

    foreach ($tool in Get-CompareTools) {
        $name = [string]$tool.name
        $run = Invoke-ComparePublicTool (Join-Path $Root ($name + '.bat')) $before $before
        Compare-Run ($name + ' [no-change]') $run 0 ''
    }
}

function Test-HistoryFile {
    param([string]$Name, [string]$ExpectedPath, [string]$ActualPath)
    if (-not (Test-Path -LiteralPath $ExpectedPath -PathType Leaf)) {
        Write-Fail $Name ('missing expected file: ' + $ExpectedPath)
        return
    }
    if (-not (Test-Path -LiteralPath $ActualPath -PathType Leaf)) {
        Write-Fail $Name ('missing actual file: ' + $ActualPath)
        return
    }
    $expected = Normalize-CapturedText (Get-Content -LiteralPath $ExpectedPath -Raw -Encoding UTF8)
    $actual = Normalize-CapturedText (Get-Content -LiteralPath $ActualPath -Raw -Encoding UTF8)
    $run = [pscustomobject]@{ rc=0; stdout=$actual; stderr='' }
    Compare-Run $Name $run 0 $expected
}

function Test-HistoryBuilderRun {
    param([string]$Name, [object]$Run)
    $reasons = New-Object System.Collections.ArrayList
    if ($Run.rc -ne 0) { [void]$reasons.Add(('rc expected 0, got ' + $Run.rc)) }
    if (-not [string]::IsNullOrEmpty($Run.stderr)) { [void]$reasons.Add(('stderr=' + (Short-Text $Run.stderr))) }
    if ($reasons.Count -eq 0) {
        Write-Pass $Name '0' ([string]$Run.rc) ([string]$Run.elapsed_ms)
    } else {
        $reason = $reasons -join '; '
        Write-Fail $Name $reason '0' ([string]$Run.rc) ([string]$Run.elapsed_ms)
        Save-FailureArtifacts $Name $Run 0 '' $reason
    }
}

function Test-HistoryTools {
    $script:CurrentScope = 'history'
    Write-Line '=== Archive change-history/all-ever tests ==='

    $fixture = Join-Path (Join-Path $Root 'test') 'test-mvs-dump-history'
    $expectedRoot = Join-Path (Join-Path $Root 'test') 'expected-history'
    if (-not (Test-Path -LiteralPath $fixture -PathType Container)) {
        Write-Fail 'history synthetic archive' ('missing fixture: ' + $fixture)
        return
    }
    if (-not (Test-Path -LiteralPath $expectedRoot -PathType Container)) {
        Write-Fail 'history expected outputs' ('missing expected folder: ' + $expectedRoot)
        return
    }
    Write-Pass 'history synthetic archive present'

    $outputRoot = Join-Path $script:ResultsFolder 'history-generated'
    if (Test-Path -LiteralPath $outputRoot) { Remove-Item -LiteralPath $outputRoot -Recurse -Force }

    $historyRun = Invoke-ComparePublicTool (Join-Path $Root 'build_mvs_dump_change_history.bat') $fixture $outputRoot
    Test-HistoryBuilderRun 'build_mvs_dump_change_history' $historyRun

    $historyExpected = Join-Path $expectedRoot 'history'
    foreach ($relative in @('history-snapshots.tsv','history-coverage.tsv')) {
        Test-HistoryFile ('history file ' + $relative) (Join-Path $historyExpected $relative) (Join-Path $outputRoot $relative)
    }
    foreach ($tool in Get-CompareTools) {
        $domain = ([string]$tool.name).Substring('compare_mvs_dump_'.Length)
        foreach ($kind in @('added','removed')) {
            $relative = Join-Path $kind ($domain + '.tsv')
            Test-HistoryFile ('history file ' + ($relative -replace '\\','/')) (Join-Path $historyExpected $relative) (Join-Path $outputRoot $relative)
        }
    }

    $allEverRun = Invoke-ComparePublicTool (Join-Path $Root 'build_mvs_dump_all_ever.bat') $fixture $outputRoot
    Test-HistoryBuilderRun 'build_mvs_dump_all_ever' $allEverRun

    $everExpected = Join-Path $expectedRoot 'all-ever'
    foreach ($relative in @('all-ever-snapshots.tsv','all-ever-coverage.tsv')) {
        Test-HistoryFile ('all-ever file ' + $relative) (Join-Path $everExpected $relative) (Join-Path $outputRoot $relative)
    }
    foreach ($tool in Get-CompareTools) {
        $domain = ([string]$tool.name).Substring('compare_mvs_dump_'.Length)
        $relative = Join-Path 'all-ever' ($domain + '.tsv')
        Test-HistoryFile ('all-ever file ' + ($relative -replace '\\','/')) (Join-Path $everExpected $relative) (Join-Path $outputRoot $relative)
    }

    # The second builder must coexist with, rather than erase, the first builder's ledgers.
    $preserved = $true
    foreach ($tool in Get-CompareTools) {
        $domain = ([string]$tool.name).Substring('compare_mvs_dump_'.Length)
        if (-not (Test-Path -LiteralPath (Join-Path (Join-Path $outputRoot 'added') ($domain + '.tsv')) -PathType Leaf)) { $preserved = $false }
        if (-not (Test-Path -LiteralPath (Join-Path (Join-Path $outputRoot 'removed') ($domain + '.tsv')) -PathType Leaf)) { $preserved = $false }
    }
    if ($preserved) { Write-Pass 'all-ever preserves history ledgers' } else { Write-Fail 'all-ever preserves history ledgers' 'history files disappeared after all-ever build' }
}

function Test-ProductFamilyFeature {
    $script:CurrentScope = 'family'
    Write-Line '=== Product-family hierarchy/query tests ==='
    $path = Join-Path (Join-Path $Root 'test') 'test_product_family_tools.bat'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Fail 'product-family regression' ('missing: ' + $path)
        return
    }
    $run = Invoke-PublicTool $path '' $null $false
    if ($run.rc -eq 0 -and [string]::IsNullOrWhiteSpace($run.stderr) -and $run.stdout -match 'SUMMARY: passed=106 failed=0') {
        Write-Pass 'product-family regression 106 assertions' '0' ([string]$run.rc) ([string]$run.elapsed_ms)
    } else {
        $reason = 'rc=' + $run.rc + '; stdout=' + (Short-Text $run.stdout) + '; stderr=' + (Short-Text $run.stderr)
        Write-Fail 'product-family regression 106 assertions' $reason '0' ([string]$run.rc) ([string]$run.elapsed_ms)
        Save-FailureArtifacts 'product-family regression' $run 0 'SUMMARY: passed=106 failed=0' $reason
    }
}

New-ResultsFolder
Write-Line ('Test results: ' + $script:ResultsFolder)

if (@('all','structure','scalar','lookup','diagnostic','relationship','single_dump','compare','history') -notcontains $Mode) {
    $script:CurrentScope = 'general'
    Show-Usage
    Write-Fail 'test mode' ('unsupported mode: ' + $Mode)
    Write-RunInfo $null
    Write-Summary
    [Environment]::Exit(2)
}

$DumpFolder = $null
if (@('all','scalar','lookup') -contains $Mode) {
    if ([string]::IsNullOrWhiteSpace($DumpArgument)) {
        $script:CurrentScope = 'general'
        Show-Usage
        Write-Fail 'dump folder' 'missing required dump argument'
        Write-RunInfo $null
        Write-Summary
        [Environment]::Exit(2)
    }
    $DumpFolder = Resolve-TestDump $DumpArgument
    if ($null -eq $DumpFolder) {
        $script:CurrentScope = 'general'
        Write-Fail 'dump folder' ('not found: ' + $DumpArgument)
        Write-RunInfo $null
        Write-Summary
        [Environment]::Exit(1)
    }
    $script:DumpForTools = $DumpFolder
    try {
        $Products = Read-TestProducts $DumpFolder
    } catch {
        $script:CurrentScope = 'general'
        Write-Fail 'parse dump' $_.Exception.Message
        Write-RunInfo $DumpFolder
        Write-Summary
        [Environment]::Exit(1)
    }
    if ($Products.Count -eq 0) {
        $script:CurrentScope = 'general'
        Write-Fail 'parse dump' 'zero products'
        Write-RunInfo $DumpFolder
        Write-Summary
        [Environment]::Exit(1)
    }
    Write-Line ('Dump: ' + $DumpFolder)
    Write-Line ('Products parsed for expectations: ' + $Products.Count)
}

Write-RunInfo $DumpFolder

if ($Mode -eq 'all' -or $Mode -eq 'structure') { Test-Structure }
if ($Mode -eq 'all' -or $Mode -eq 'scalar') { Test-Scalar $Products }
if ($Mode -eq 'all' -or $Mode -eq 'lookup') { Test-Lookups $Products }
if ($Mode -eq 'all' -or $Mode -eq 'diagnostic') { Test-Diagnostics }
if ($Mode -eq 'all' -or $Mode -eq 'relationship') { Test-Relationships }
if ($Mode -eq 'all' -or $Mode -eq 'single_dump') { Test-SingleDumpTools }
if ($Mode -eq 'all' -or $Mode -eq 'compare') { Test-CompareTools }
if ($Mode -eq 'all' -or $Mode -eq 'history') { Test-HistoryTools }
if ($Mode -eq 'all') { Test-ProductFamilyFeature }

Write-Line ''
Write-Line ('SUMMARY: passed=' + $script:Passed + ' failed=' + $script:Failed + ' skipped=' + $script:Skipped)
Write-Line ('Results: ' + $script:ResultsFolder)
Write-Summary

if ($script:Failed -gt 0) { [Environment]::Exit(1) }
exit 0
:_MVSTest_end
