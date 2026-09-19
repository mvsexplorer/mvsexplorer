@echo off
:setup
REM Scoped because this standalone tool embeds PowerShell and should not leak state.
setlocal DisableDelayedExpansion
set "app.version=0.4.1"
set "app.name=lookup_mvs_title_from_id"
set "app.rc=0"
set "app.self=%~f0"
set "mvsl_source=id"
set "mvsl_target=title"
set "mvsl_dump=%~1"
set "mvsl_pattern=%~2"
set "mvsl_caller=%~nx0"
set "mvsl_script_root=%~dp0"
set "mvsl_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSLookup"
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

:_MVSLookup_start
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

function Write-Line {
    param([AllowEmptyString()][string]$Text)
    [Console]::Out.WriteLine($Text)
}

function Write-Err {
    param([string]$Text)
    [Console]::Error.WriteLine($Text)
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

function Get-NaturalKey {
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

function Get-DateTicks {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return [Int64]::MaxValue }
    $dto = [DateTimeOffset]::MinValue
    $styles = [Globalization.DateTimeStyles]::AllowWhiteSpaces -bor [Globalization.DateTimeStyles]::AssumeUniversal
    if ([DateTimeOffset]::TryParse($Value, [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$dto)) {
        return $dto.UtcDateTime.Ticks
    }
    return [Int64]::MaxValue
}

function Sort-Products {
    param([object[]]$Products, [string]$Key)
    switch ($Key) {
        ''      { return @($Products) }
        'id'    { return @($Products | Sort-Object @{Expression={ [int]$_.id }; Ascending=$true}) }
        'title' { return @($Products | Sort-Object @{Expression={ Get-NaturalKey $_.title }; Ascending=$true}, @{Expression={ [int]$_.id }; Ascending=$true}) }
        'date'  { return @($Products | Sort-Object @{Expression={ Get-DateTicks $_.date }; Ascending=$true}, @{Expression={ $_.date }; Ascending=$true}, @{Expression={ [int]$_.id }; Ascending=$true}) }
        default { throw ('Unsupported sort key: ' + $Key) }
    }
}

function New-StarWildcardRegex {
    param([AllowNull()][AllowEmptyString()][string]$Pattern)
    if ($null -eq $Pattern) { $Pattern = '' }
    $escaped = [regex]::Escape($Pattern)
    $escaped = $escaped.Replace('\*', '.*')
    return New-Object System.Text.RegularExpressions.Regex(('^' + $escaped + '$'), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function Read-Products {
    param([string]$DumpFolder)
    $idsPath = Join-Path $DumpFolder 'mvs_ids.txt'
    $datesPath = Join-Path $DumpFolder 'mvs_dates.txt'
    $notesPath = Join-Path $DumpFolder 'mvs_notes.html'

    if (-not (Test-Path -LiteralPath $idsPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new(('Missing required file: ' + $idsPath))
    }
    if (-not (Test-Path -LiteralPath $datesPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new(('Missing required file: ' + $datesPath))
    }

    # Keep the same required files/return-code contract, but parse only
    # enrichment fields that participate in this lookup.
    $sourceField = ([string]$env:mvsl_source).Trim().ToLowerInvariant()
    $targetField = ([string]$env:mvsl_target).Trim().ToLowerInvariant()
    $needsDate = ($sourceField -eq 'date') -or ($targetField -eq 'date')
    $needsNote = ($sourceField -eq 'note') -or ($targetField -eq 'note')

    $datesById = @{}
    if ($needsDate) {
        foreach ($line in Get-Content -LiteralPath $datesPath -Encoding UTF8) {
            if ($line -match '^(?<date>.*?)\s+-\s+.*?\[ID:\s*(?<id>\d+)\]\s*$') {
                $datesById[[int]$Matches.id] = $Matches.date.Trim()
            }
        }
    }

    $notesByTitle = @{}
    if ($needsNote -and (Test-Path -LiteralPath $notesPath -PathType Leaf)) {
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

    $products = New-Object System.Collections.ArrayList
    foreach ($line in Get-Content -LiteralPath $idsPath -Encoding UTF8) {
        if ($line -notmatch '^(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') { continue }
        $id = [int]$Matches.id
        $title = Normalize-Title $Matches.title
        $date = ''
        if ($datesById.ContainsKey($id)) { $date = [string]$datesById[$id] }
        $note = ''
        if ($notesByTitle.ContainsKey($title)) {
            $note = (($notesByTitle[$title] | ForEach-Object { [string]$_ }) -join ' || ')
        }
        [void]$products.Add([pscustomobject]@{
            id = [string]$id
            title = $title
            date = $date
            note = $note
        })
    }
    return @($products)
}

$SourceField = [string]$env:mvsl_source
$TargetField = [string]$env:mvsl_target
$Dump = [string]$env:mvsl_dump
$Pattern = [string]$env:mvsl_pattern
$Caller = [string]$env:mvsl_caller
$ScriptRoot = [string]$env:mvsl_script_root
$Version = [string]$env:mvsl_version

function Show-Usage {
    Write-Line ('MVS Explorer Toolkit lookup tool ' + $Version)
    Write-Line ('Usage: ' + $Caller + ' dump-folder search-value')
    Write-Line ('Search field: ' + $SourceField)
    Write-Line ('Returned field: ' + $TargetField)
    Write-Line 'Wildcard: * matches zero or more characters anywhere in search-value.'
    Write-Line 'Matching is case-insensitive. Quote search values containing spaces.'
}

function Fail {
    param([int]$Code, [string]$Message)
    Write-Err ('ERROR: ' + $Message)
    [Environment]::Exit($Code)
}

if ([string]::IsNullOrWhiteSpace($Dump) -or (@('--help','-h','-?','/h','/?') -contains $Dump)) { Show-Usage; exit 0 }
if ($null -eq $env:mvsl_pattern) { Show-Usage; exit 2 }

$DumpFolder = Resolve-DumpFolder $Dump $ScriptRoot
if ($null -eq $DumpFolder) { Fail 3 ('Dump folder not found: ' + $Dump) }

try {
    $Products = Read-Products $DumpFolder
} catch [System.IO.FileNotFoundException] {
    Fail 4 $_.Exception.Message
} catch {
    Fail 5 $_.Exception.Message
}

if ($Products.Count -eq 0) { Fail 5 ('No product records parsed from: ' + $DumpFolder) }

$regex = New-StarWildcardRegex $Pattern
$matches = @($Products | Where-Object { $regex.IsMatch([string]$_.$SourceField) })
$matches = Sort-Products $matches $SourceField

$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$emitted = 0
foreach ($record in $matches) {
    $value = Normalize-Scalar ([string]$record.$TargetField)
    if ([string]::IsNullOrEmpty($value)) { continue }
    if ($seen.Add($value)) {
        Write-Line $value
        $emitted++
    }
}
if ($emitted -eq 0) { [Environment]::Exit(1) }
exit 0
:_MVSLookup_end
