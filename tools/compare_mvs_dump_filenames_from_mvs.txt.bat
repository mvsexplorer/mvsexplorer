@echo off
:setup
REM Scoped because this standalone comparison tool embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=0.1.0"
set "app.name=compare_mvs_dump_filenames_from_mvs.txt"
set "app.rc=0"
set "app.self=%~f0"
set "mvsc_property=filename"
set "mvsc_source_file=mvs.txt"
set "mvsc_id_mode="
set "mvsc_first_dump=%~1"
set "mvsc_second_dump=%~2"
set "mvsc_caller=%~nx0"
set "mvsc_script_root=%~dp0"
set "mvsc_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSCompare"
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

:_MVSCompare_start
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$Property = [string]$env:mvsc_property
$SourceFile = [string]$env:mvsc_source_file
$IdMode = [string]$env:mvsc_id_mode
$FirstDump = [string]$env:mvsc_first_dump
$SecondDump = [string]$env:mvsc_second_dump
$Caller = [string]$env:mvsc_caller
$ScriptRoot = [string]$env:mvsc_script_root
$Version = [string]$env:mvsc_version

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
    Write-Line ('MVS Explorer Toolkit dump comparison ' + $Version)
    Write-Line ('Usage: ' + $Caller + ' first-dump-folder second-dump-folder')
    Write-Line ('Property: ' + $Property)
    Write-Line ('Source: ' + $SourceFile)
    Write-Line 'Output: removed values (-) first, then added values (+).'
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

function Normalize-Id {
    param([AllowNull()][AllowEmptyString()][string]$Value, [string]$Mode)
    if ($null -eq $Value) { return '' }
    $text = $Value.Trim()
    if ($Mode -eq 'numeric' -and $text -match '^\d+$') {
        $text = [regex]::Replace($text, '^0+(?=\d)', '')
    }
    return $text
}

function Get-Key {
    param([AllowNull()][AllowEmptyString()][string]$Value, [string]$Kind, [string]$Mode)
    if ($null -eq $Value) { return '' }
    switch ($Kind) {
        'id'       { return (Normalize-Id $Value $Mode).ToLowerInvariant() }
        'title'    { return (Normalize-Title $Value).ToLowerInvariant() }
        'date'     { return $Value.Trim() }
        'sha1'     { return $Value.Trim().ToLowerInvariant() }
        'sha256'   { return $Value.Trim().ToLowerInvariant() }
        'filename' { return $Value.Trim().ToLowerInvariant() }
        default    { return $Value.Trim().ToLowerInvariant() }
    }
}

function Get-DisplayValue {
    param([AllowNull()][AllowEmptyString()][string]$Value, [string]$Kind, [string]$Mode)
    if ($null -eq $Value) { return '' }
    switch ($Kind) {
        'id'       { return Normalize-Id $Value $Mode }
        'title'    { return Normalize-Title $Value }
        'date'     { return $Value.Trim() }
        'sha1'     { return $Value.Trim().ToLowerInvariant() }
        'sha256'   { return $Value.Trim().ToLowerInvariant() }
        'filename' { return $Value.Trim() }
        default    { return $Value.Trim() }
    }
}

function Add-UniqueValue {
    param(
        [System.Collections.ArrayList]$Rows,
        [object]$Seen,
        [AllowNull()][AllowEmptyString()][string]$Value,
        [string]$Kind,
        [string]$Mode
    )
    $display = Get-DisplayValue $Value $Kind $Mode
    if ([string]::IsNullOrWhiteSpace($display)) { return }
    $key = Get-Key $display $Kind $Mode
    if ($Seen.Add($key)) {
        [void]$Rows.Add([pscustomobject]@{ key=$key; value=$display })
    }
}

function Read-SourceValues {
    param([string]$Path, [string]$Name, [string]$Kind, [string]$Mode)
    $rows = New-Object System.Collections.ArrayList
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)

    if ($Name -eq 'mvs_ids.txt') {
        foreach ($lineValue in $lines) {
            $line = [string]$lineValue
            if ($line -match '^(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') {
                if ($Kind -eq 'id') { Add-UniqueValue $rows $seen $Matches.id $Kind $Mode }
                elseif ($Kind -eq 'title') { Add-UniqueValue $rows $seen $Matches.title $Kind $Mode }
            }
        }
        return [pscustomobject]@{ values=$rows }
    }

    if ($Name -eq 'mvs_dates.txt') {
        foreach ($lineValue in $lines) {
            $line = [string]$lineValue
            if ($line -match '^(?<date>.*?)\s+-\s+(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') {
                if ($Kind -eq 'id') { Add-UniqueValue $rows $seen $Matches.id $Kind $Mode }
                elseif ($Kind -eq 'title') { Add-UniqueValue $rows $seen $Matches.title $Kind $Mode }
                elseif ($Kind -eq 'date') { Add-UniqueValue $rows $seen $Matches.date $Kind $Mode }
            }
        }
        return [pscustomobject]@{ values=$rows }
    }

    if ($Name -eq 'mvs.sha1' -or $Name -eq 'mvs.sha256') {
        $hashLength = if ($Name -eq 'mvs.sha1') { 40 } else { 64 }
        foreach ($lineValue in $lines) {
            $line = [string]$lineValue
            $pattern = '^\s*(?<hash>[0-9A-Fa-f]{' + $hashLength + '})\s+\*(?<filename>.+?)\s*$'
            if ($line -match $pattern) {
                if ($Kind -eq 'filename') { Add-UniqueValue $rows $seen $Matches.filename $Kind $Mode }
                elseif (($Kind -eq 'sha1' -and $hashLength -eq 40) -or ($Kind -eq 'sha256' -and $hashLength -eq 64)) {
                    Add-UniqueValue $rows $seen $Matches.hash $Kind $Mode
                }
            }
        }
        return [pscustomobject]@{ values=$rows }
    }

    if ($Name -eq 'mvs.txt' -or $Name -eq 'mvs_names.txt') {
        $inside = $false
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
                if ($Kind -eq 'id') { Add-UniqueValue $rows $seen $Matches.id $Kind $Mode }
                elseif ($Kind -eq 'title') { Add-UniqueValue $rows $seen $Matches.title $Kind $Mode }
                continue
            }

            if ([string]::IsNullOrWhiteSpace($line)) {
                $inside = $false
                continue
            }
            if (-not $inside) { continue }

            if ($line -match '^\s*(?<hash>[0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})\s+\*(?<filename>.+?)\s*$') {
                $hash = $Matches.hash
                if ($Kind -eq 'filename') { Add-UniqueValue $rows $seen $Matches.filename $Kind $Mode }
                elseif ($Kind -eq 'sha1' -and $hash.Length -eq 40) { Add-UniqueValue $rows $seen $hash $Kind $Mode }
                elseif ($Kind -eq 'sha256' -and $hash.Length -eq 64) { Add-UniqueValue $rows $seen $hash $Kind $Mode }
            }
        }
        return [pscustomobject]@{ values=$rows }
    }

    Fail 2 ('Unsupported source file: ' + $Name)
}

function Write-DiffLine {
    param([string]$Prefix, [string]$Value, [System.ConsoleColor]$Color)
    $text = $Prefix + ' ' + $Value
    if ([Console]::IsOutputRedirected) {
        [Console]::Out.WriteLine($text)
        return
    }
    $old = [Console]::ForegroundColor
    try {
        [Console]::ForegroundColor = $Color
        [Console]::Out.WriteLine($text)
    } finally {
        [Console]::ForegroundColor = $old
    }
}

if ([string]::IsNullOrWhiteSpace($FirstDump) -or (@('--help','-h','-?','/h','/?') -contains $FirstDump)) {
    Show-Usage
    exit 0
}
if ([string]::IsNullOrWhiteSpace($SecondDump)) {
    Write-Err 'ERROR: Missing second-dump-folder.'
    Show-Usage
    [Environment]::Exit(2)
}

$supported = @(
    'id|mvs.txt','id|mvs_ids.txt','id|mvs_names.txt','id|mvs_dates.txt',
    'title|mvs.txt','title|mvs_ids.txt','title|mvs_names.txt','title|mvs_dates.txt',
    'date|mvs_dates.txt',
    'sha1|mvs.txt','sha1|mvs_names.txt','sha1|mvs.sha1',
    'sha256|mvs.txt','sha256|mvs_names.txt','sha256|mvs.sha256',
    'filename|mvs.txt','filename|mvs_names.txt','filename|mvs.sha1','filename|mvs.sha256'
)
if ($supported -notcontains ($Property + '|' + $SourceFile)) {
    Fail 2 ('Unsupported comparison configuration: ' + $Property + ' from ' + $SourceFile)
}

$FirstFolder = Resolve-DumpFolder $FirstDump $ScriptRoot
if ($null -eq $FirstFolder) { Fail 3 ('First dump folder not found: ' + $FirstDump) }
$SecondFolder = Resolve-DumpFolder $SecondDump $ScriptRoot
if ($null -eq $SecondFolder) { Fail 3 ('Second dump folder not found: ' + $SecondDump) }

$FirstPath = Join-Path $FirstFolder $SourceFile
$SecondPath = Join-Path $SecondFolder $SourceFile
if (-not (Test-Path -LiteralPath $FirstPath -PathType Leaf)) { Fail 4 ('Missing required file: ' + $FirstPath) }
if (-not (Test-Path -LiteralPath $SecondPath -PathType Leaf)) { Fail 4 ('Missing required file: ' + $SecondPath) }

try {
    $firstModel = Read-SourceValues $FirstPath $SourceFile $Property $IdMode
    $secondModel = Read-SourceValues $SecondPath $SourceFile $Property $IdMode

    $firstKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $secondKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($row in $firstModel.values) { [void]$firstKeys.Add([string]$row.key) }
    foreach ($row in $secondModel.values) { [void]$secondKeys.Add([string]$row.key) }

    foreach ($row in $firstModel.values) {
        if (-not $secondKeys.Contains([string]$row.key)) {
            Write-DiffLine '-' ([string]$row.value) ([System.ConsoleColor]::Red)
        }
    }
    foreach ($row in $secondModel.values) {
        if (-not $firstKeys.Contains([string]$row.key)) {
            Write-DiffLine '+' ([string]$row.value) ([System.ConsoleColor]::Green)
        }
    }
    exit 0
} catch {
    Fail 5 $_.Exception.Message
}
:_MVSCompare_end
