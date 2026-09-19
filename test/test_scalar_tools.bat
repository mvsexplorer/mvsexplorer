@echo off
:setup
REM Scoped because this standalone test embeds PowerShell and must not leak state.
setlocal DisableDelayedExpansion
set "app.version=0.1.0"
set "app.name=test_scalar_tools"
set "app.rc=0"
set "app.self=%~f0"
set "mvst_mode=scalar"
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

function Write-Line {
    param([AllowEmptyString()][string]$Text)
    [Console]::Out.WriteLine($Text)
}

function Write-Pass {
    param([string]$Name)
    $script:Passed++
    Write-Line ('[PASS] ' + $Name)
}

function Write-Skip {
    param([string]$Name, [string]$Reason)
    $script:Skipped++
    Write-Line ('[SKIP] ' + $Name + ' - ' + $Reason)
}

function Write-Fail {
    param([string]$Name, [string]$Reason)
    $script:Failed++
    Write-Line ('[FAIL] ' + $Name + ' - ' + $Reason)
}

function Show-Usage {
    Write-Line ('MVS Explorer Toolkit test ' + $Version)
    if ($Mode -eq 'structure') {
        Write-Line ('Usage: ' + $Caller + ' [dump-folder]')
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
    [void]$process.Start()
    $outTask = $process.StandardOutput.ReadToEndAsync()
    $errTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    return [pscustomobject]@{
        rc = $process.ExitCode
        stdout = Normalize-CapturedText $outTask.Result
        stderr = Normalize-CapturedText $errTask.Result
    }
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
    if ($reasons.Count -eq 0) { Write-Pass $Name } else { Write-Fail $Name ($reasons -join '; ') }
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

function Test-Structure {
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

    $actual = @(Get-ChildItem -LiteralPath $Root -Filter '*.bat' -File | Select-Object -ExpandProperty Name)
    if ($actual.Count -eq 127) { Write-Pass 'root public .bat count = 127' } else { Write-Fail 'root public .bat count' ('expected 127, got ' + $actual.Count) }

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
        if (-not $text.Contains(':_MVSQuery_start') -and -not $text.Contains(':_MVSLookup_start')) { [void]$problems.Add('missing injected PowerShell block') }
        if ($text.Contains('dev\library') -or $text.Contains('generate_tools.py')) { [void]$problems.Add('development runtime dependency reference') }
        if ($problems.Count -eq 0) { Write-Pass ('standalone ' + $name) } else { Write-Fail ('standalone ' + $name) ($problems -join ', ') }
    }
}

function Test-Scalar {
    param([object[]]$Products)
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
                $run = Invoke-PublicTool $path $DumpArgument $null $false
                Compare-Run $name $run 0 $expected
            }
        }
    }
}

function Test-OneLookupPattern {
    param([object[]]$Products, [object]$Lookup, [string]$Pattern, [string]$CaseName)
    $expected = Get-LookupExpected $Products $Lookup.source $Lookup.target $Pattern
    $path = Join-Path $Root ($Lookup.name + '.bat')
    $run = Invoke-PublicTool $path $DumpArgument $Pattern $true
    Compare-Run ($Lookup.name + ' [' + $CaseName + ': ' + $Pattern + ']') $run $expected.rc $expected.stdout
}

function Test-Lookups {
    param([object[]]$Products)
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

if (@('all','structure','scalar','lookup') -notcontains $Mode) {
    Show-Usage
    exit 2
}

if ($Mode -ne 'structure') {
    if ([string]::IsNullOrWhiteSpace($DumpArgument)) { Show-Usage; exit 2 }
    $DumpFolder = Resolve-TestDump $DumpArgument
    if ($null -eq $DumpFolder) {
        Write-Fail 'dump folder' ('not found: ' + $DumpArgument)
        Write-Line ('SUMMARY: passed=' + $script:Passed + ' failed=' + $script:Failed + ' skipped=' + $script:Skipped)
        exit 1
    }
    try {
        $Products = Read-TestProducts $DumpFolder
    } catch {
        Write-Fail 'parse dump' $_.Exception.Message
        Write-Line ('SUMMARY: passed=' + $script:Passed + ' failed=' + $script:Failed + ' skipped=' + $script:Skipped)
        exit 1
    }
    if ($Products.Count -eq 0) {
        Write-Fail 'parse dump' 'zero products'
        Write-Line ('SUMMARY: passed=' + $script:Passed + ' failed=' + $script:Failed + ' skipped=' + $script:Skipped)
        exit 1
    }
    Write-Line ('Dump: ' + $DumpFolder)
    Write-Line ('Products parsed for expectations: ' + $Products.Count)
}

if ($Mode -eq 'all' -or $Mode -eq 'structure') { Test-Structure }
if ($Mode -eq 'all' -or $Mode -eq 'scalar') { Test-Scalar $Products }
if ($Mode -eq 'all' -or $Mode -eq 'lookup') { Test-Lookups $Products }

Write-Line ''
Write-Line ('SUMMARY: passed=' + $script:Passed + ' failed=' + $script:Failed + ' skipped=' + $script:Skipped)
if ($script:Failed -gt 0) { exit 1 }
exit 0
:_MVSTest_end
