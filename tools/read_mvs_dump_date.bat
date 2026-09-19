@echo off
:setup
REM Scoped because this standalone tool embeds PowerShell and should not leak state.
setlocal DisableDelayedExpansion
set "app.version=0.2.0"
set "app.name=read_mvs_dump_date"
set "app.rc=0"
set "app.self=%~f0"
set "mvsq_mode=machine"
set "mvsq_fields=date"
set "mvsq_dump=%~1"
set "mvsq_caller=%~nx0"
set "mvsq_script_root=%~dp0"
set "mvsq_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSQuery"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
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
::   1.1.0
::
:: Usage:
::   call :RunPowerShellFromLabel BlockName [arguments...]
::
:: Alternate Usage:
::   set "RunPowerShellFromLabel.function=BlockName"
::   call :RunPowerShellFromLabel [arguments...]
::
:: Persistent Default:
::   set "_RunPowerShellFromLabel.function=BlockName"
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
if defined _rps_rc (set "_rps_rc=" & exit /b %_rps_rc%)
set "rps_self=%~f0" & set "rps_argc=0"
if defined app.self set "rps_self=%app.self%"
if defined RunPowerShellFromLabel.function (set "rps_label=%RunPowerShellFromLabel.function%" & set "RunPowerShellFromLabel.function=" & goto :_RunPowerShellFromLabel_capture)
if defined _RunPowerShellFromLabel.function (set "rps_label=%_RunPowerShellFromLabel.function%" & goto :_RunPowerShellFromLabel_capture)
set "rps_label=%~1"
if not defined rps_label (set "_rps_rc=2" & goto :RunPowerShellFromLabel)
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
if not "%rps_rc%"=="0" (set "_rps_rc=%rps_rc%" & goto :RunPowerShellFromLabel)
exit /b 0

:_MVSQuery_start
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$Mode = [string]$env:mvsq_mode
$FieldsText = [string]$env:mvsq_fields
$Dump = [string]$env:mvsq_dump
$Caller = [string]$env:mvsq_caller
$ScriptRoot = [string]$env:mvsq_script_root
$Version = [string]$env:mvsq_version

function Write-Line {
    param([AllowEmptyString()][string]$Text)
    [Console]::Out.WriteLine($Text)
}

function Write-Err {
    param([string]$Text)
    [Console]::Error.WriteLine($Text)
}

function Show-Usage {
    Write-Line ('MVS Explorer Toolkit tool ' + $Version)
    Write-Line ('Usage: ' + $Caller + ' dump-folder')
    Write-Line ''
    Write-Line 'dump-folder may be:'
    Write-Line '  - an absolute or relative path to an extracted MVS dump folder'
    Write-Line '  - a dump folder name such as mvs_2021-08-17'
    Write-Line ''
    Write-Line 'Named dump folders are searched in the current directory,'
    Write-Line 'MVS_DUMPS_ROOT (if defined), the script directory, and common'
    Write-Line 'mvs_dumps_archive locations adjacent to the script/current directory.'
}

function Fail {
    param([int]$Code, [string]$Message)
    if ($Mode -eq 'machine') {
        Write-Err ('MVS_QUERY_ERROR' + [char]9 + $Code + [char]9 + $Message)
    } else {
        Write-Err ('ERROR: ' + $Message)
    }
    exit $Code
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

if ([string]::IsNullOrWhiteSpace($Mode)) { Show-Usage; exit 2 }
if ([string]::IsNullOrWhiteSpace($FieldsText)) { Show-Usage; exit 2 }
if ([string]::IsNullOrWhiteSpace($Dump) -or (@('--help','-h','-?','/h','/?') -contains $Dump)) { Show-Usage; exit 0 }
if (@('human','machine') -notcontains $Mode) { Fail 2 ('Invalid output mode: ' + $Mode) }

$Fields = @($FieldsText.Split(',') | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
$allowed = @('id','title','date','note')
if ($Fields.Count -eq 0) { Fail 2 'No fields were requested.' }
foreach ($field in $Fields) {
    if ($allowed -notcontains $field) { Fail 2 ('Unsupported field: ' + $field) }
}

$DumpFolder = Resolve-DumpFolder $Dump $ScriptRoot
if ($null -eq $DumpFolder) { Fail 3 ('Dump folder not found: ' + $Dump) }

$idsPath = Join-Path $DumpFolder 'mvs_ids.txt'
$datesPath = Join-Path $DumpFolder 'mvs_dates.txt'
$notesPath = Join-Path $DumpFolder 'mvs_notes.html'
if (-not (Test-Path -LiteralPath $idsPath -PathType Leaf)) { Fail 4 ('Missing required file: ' + $idsPath) }
if (-not (Test-Path -LiteralPath $datesPath -PathType Leaf)) { Fail 4 ('Missing required file: ' + $datesPath) }

$datesById = @{}
foreach ($line in Get-Content -LiteralPath $datesPath -Encoding UTF8) {
    if ($line -match '^(?<date>.*?)\s+-\s+.*?\[ID:\s*(?<id>\d+)\]\s*$') {
        $datesById[[int]$Matches.id] = $Matches.date.Trim()
    }
}

$notesByTitle = @{}
if (Test-Path -LiteralPath $notesPath -PathType Leaf) {
    $html = Get-Content -LiteralPath $notesPath -Raw -Encoding UTF8
    $noteMatches = [regex]::Matches($html, '(?is)<h1>(.*?)</h1>(.*?)(?=<h1>|\z)')
    foreach ($match in $noteMatches) {
        $heading = Normalize-Title ([regex]::Replace($match.Groups[1].Value, '(?is)<[^>]+>', ' '))
        $note = Convert-NoteHtmlToText $match.Groups[2].Value
        if ([string]::IsNullOrWhiteSpace($heading) -or [string]::IsNullOrWhiteSpace($note)) { continue }
        if (-not $notesByTitle.ContainsKey($heading)) {
            $notesByTitle[$heading] = New-Object System.Collections.ArrayList
        }
        if (-not $notesByTitle[$heading].Contains($note)) {
            [void]$notesByTitle[$heading].Add($note)
        }
    }
}

$parsedCount = 0
foreach ($line in Get-Content -LiteralPath $idsPath -Encoding UTF8) {
    if ($line -notmatch '^(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') { continue }
    $parsedCount++
    $id = [int]$Matches.id
    $title = Normalize-Title $Matches.title
    $date = ''
    if ($datesById.ContainsKey($id)) { $date = [string]$datesById[$id] }
    $note = ''
    if ($notesByTitle.ContainsKey($title)) {
        $note = (($notesByTitle[$title] | ForEach-Object { [string]$_ }) -join ' || ')
    }

    $record = @{ id=[string]$id; title=$title; date=$date; note=$note }
    $values = @()
    foreach ($field in $Fields) {
        $value = Normalize-Scalar ([string]$record[$field])
        if ($Mode -eq 'human') {
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

    if ($Mode -eq 'human') {
        Write-Line ($values -join ' | ')
    } else {
        Write-Line ($values -join [char]9)
    }
}

if ($parsedCount -eq 0) { Fail 5 ('No product records parsed from: ' + $idsPath) }
exit 0
:_MVSQuery_end
