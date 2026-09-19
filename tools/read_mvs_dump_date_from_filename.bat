@echo off
:setup
REM Scoped because this standalone relationship query embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=0.1.0"
set "app.name=read_mvs_dump_date_from_filename"
set "app.rc=0"
set "app.self=%~f0"
set "mvsr_mode=machine"
set "mvsr_fields=date"
set "mvsr_source=filename"
set "mvsr_dump=%~1"
set "mvsr_search=%~2"
set "mvsr_caller=%~nx0"
set "mvsr_script_root=%~dp0"
set "mvsr_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSRelationship"
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

:_MVSRelationship_start
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$Mode = [string]$env:mvsr_mode
$Fields = @(([string]$env:mvsr_fields).Split(',') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$Source = [string]$env:mvsr_source
$Dump = [string]$env:mvsr_dump
$Search = [string]$env:mvsr_search
$Caller = [string]$env:mvsr_caller
$ScriptRoot = [string]$env:mvsr_script_root
$Version = [string]$env:mvsr_version

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
    Write-Line ('MVS Explorer Toolkit relationship query ' + $Version)
    Write-Line ('Usage: ' + $Caller + ' dump-folder search-value')
    if ($Source -eq 'filename') {
        Write-Line 'Search-value is an exact filename, matched case-insensitively.'
    } else {
        Write-Line 'Search-value is an exact SHA-1 or SHA-256 hash, matched case-insensitively.'
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

function Add-UniqueString {
    param([System.Collections.ArrayList]$List, [System.Collections.Generic.HashSet[string]]$Seen, [string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    if ($Seen.Add($Value)) { [void]$List.Add($Value) }
}

function Read-DatesById {
    param([string]$Path)
    $map = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $map }
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        if ($line -match '^(?<date>.*?)\s+-\s+.*?\[ID:\s*(?<id>\d+)\]\s*$') {
            $id = [string][int]$Matches.id
            if (-not $map.ContainsKey($id)) { $map[$id] = $Matches.date.Trim() }
        }
    }
    return $map
}

function Read-NotesByTitle {
    param([string]$Path)
    $map = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $map }
    $html = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    foreach ($match in [regex]::Matches($html, '(?is)<h1>(.*?)</h1>(.*?)(?=<h1>|\z)')) {
        $heading = Normalize-Title ([regex]::Replace($match.Groups[1].Value, '(?is)<[^>]+>', ' '))
        $note = Convert-NoteHtmlToText $match.Groups[2].Value
        if ([string]::IsNullOrWhiteSpace($heading) -or [string]::IsNullOrWhiteSpace($note)) { continue }
        $key = $heading.ToLowerInvariant()
        if (-not $map.ContainsKey($key)) {
            $map[$key] = New-Object System.Collections.ArrayList
        }
        if (-not $map[$key].Contains($note)) { [void]$map[$key].Add($note) }
    }
    return $map
}

function Add-HashFilename {
    param(
        [hashtable]$HashIndex,
        [System.Collections.ArrayList]$HashOrder,
        [string]$Hash,
        [string]$Filename
    )
    if ($Hash -notmatch '^(?i:[0-9a-f]{40}|[0-9a-f]{64})$') { return }
    if ([string]::IsNullOrWhiteSpace($Filename)) { return }
    $hashKey = $Hash.ToLowerInvariant()
    if (-not $HashIndex.ContainsKey($hashKey)) {
        $HashIndex[$hashKey] = New-Object System.Collections.ArrayList
        [void]$HashOrder.Add($hashKey)
    }
    $filenameKey = $Filename.Trim().ToLowerInvariant()
    foreach ($existing in $HashIndex[$hashKey]) {
        if ($existing.key -eq $filenameKey) { return }
    }
    [void]$HashIndex[$hashKey].Add([pscustomobject]@{
        key = $filenameKey
        filename = $Filename.Trim()
    })
}

function Add-FilenameCatalog {
    param(
        [hashtable]$Catalog,
        [System.Collections.ArrayList]$Order,
        [string]$Filename
    )
    if ([string]::IsNullOrWhiteSpace($Filename)) { return }
    $display = $Filename.Trim()
    $key = $display.ToLowerInvariant()
    if (-not $Catalog.ContainsKey($key)) {
        $Catalog[$key] = $display
        [void]$Order.Add($key)
    }
}

function Read-RelationshipData {
    param([string]$DumpFolder)

    $mvsPath = Join-Path $DumpFolder 'mvs.txt'
    if (-not (Test-Path -LiteralPath $mvsPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new(('Missing required file: ' + $mvsPath))
    }

    $datesPath = Join-Path $DumpFolder 'mvs_dates.txt'
    $notesPath = Join-Path $DumpFolder 'mvs_notes.html'
    $sha1Path = Join-Path $DumpFolder 'mvs.sha1'
    $sha256Path = Join-Path $DumpFolder 'mvs.sha256'

    $dates = Read-DatesById $datesPath
    $notes = Read-NotesByTitle $notesPath

    $ownersByFilename = @{}
    $filenameCatalog = @{}
    $filenameOrder = New-Object System.Collections.ArrayList
    $hashIndex = @{}
    $hashOrder = New-Object System.Collections.ArrayList
    $ownerOrder = 0

    $lines = @(Get-Content -LiteralPath $mvsPath -Encoding UTF8)
    $i = 0
    while ($i -lt $lines.Count) {
        $line = [string]$lines[$i]
        if ($line -notmatch '^---\s*(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*---\s*$') {
            $i++
            continue
        }

        $ownerOrder++
        $id = [string][int]$Matches.id
        $title = Normalize-Title $Matches.title
        $date = if ($dates.ContainsKey($id)) { [string]$dates[$id] } else { '' }
        $noteKey = $title.ToLowerInvariant()
        $note = if ($notes.ContainsKey($noteKey)) {
            (($notes[$noteKey] | ForEach-Object { [string]$_ }) -join ' || ')
        } else { '' }

        $owner = [pscustomobject]@{
            order = $ownerOrder
            id = $id
            title = $title
            date = $date
            note = $note
        }

        $i++
        while ($i -lt $lines.Count) {
            $next = [string]$lines[$i]
            if ([string]::IsNullOrWhiteSpace($next)) {
                $i++
                break
            }
            if ($next -match '^---\s*.*?\[ID:\s*\d+\]\s*---\s*$') { break }

            if ($next -match '^\s*(?<hash>[0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})\s+\*(?<filename>.+?)\s*$') {
                $hash = $Matches.hash
                $filename = $Matches.filename.Trim()
                $filenameKey = $filename.ToLowerInvariant()

                Add-FilenameCatalog $filenameCatalog $filenameOrder $filename
                Add-HashFilename $hashIndex $hashOrder $hash $filename

                if (-not $ownersByFilename.ContainsKey($filenameKey)) {
                    $ownersByFilename[$filenameKey] = New-Object System.Collections.ArrayList
                }

                $already = $false
                foreach ($existingOwner in $ownersByFilename[$filenameKey]) {
                    if ($existingOwner.order -eq $owner.order) { $already = $true; break }
                }
                if (-not $already) { [void]$ownersByFilename[$filenameKey].Add($owner) }
            }
            $i++
        }
    }

    foreach ($manifest in @(
        [pscustomobject]@{ path=$sha1Path; length=40 },
        [pscustomobject]@{ path=$sha256Path; length=64 }
    )) {
        if (-not (Test-Path -LiteralPath $manifest.path -PathType Leaf)) { continue }
        foreach ($line in Get-Content -LiteralPath $manifest.path -Encoding UTF8) {
            $pattern = '^\s*(?<hash>[0-9A-Fa-f]{' + $manifest.length + '})\s+\*(?<filename>.+?)\s*$'
            if ($line -match $pattern) {
                $filename = $Matches.filename.Trim()
                Add-FilenameCatalog $filenameCatalog $filenameOrder $filename
                Add-HashFilename $hashIndex $hashOrder $Matches.hash $filename
            }
        }
    }

    return [pscustomobject]@{
        ownersByFilename = $ownersByFilename
        filenameCatalog = $filenameCatalog
        filenameOrder = @($filenameOrder)
        hashIndex = $hashIndex
        hashOrder = @($hashOrder)
    }
}

function Get-MatchedFilenames {
    param([object]$Data, [string]$SourceName, [string]$SearchValue)

    $matched = New-Object System.Collections.ArrayList
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

    if ($SourceName -eq 'filename') {
        $searchKey = $SearchValue.Trim().ToLowerInvariant()
        if ($Data.filenameCatalog.ContainsKey($searchKey)) {
            $display = [string]$Data.filenameCatalog[$searchKey]
            if ($seen.Add($display)) { [void]$matched.Add($display) }
        }
        return @($matched)
    }

    $hashKey = $SearchValue.Trim().ToLowerInvariant()
    if ($Data.hashIndex.ContainsKey($hashKey)) {
        foreach ($item in $Data.hashIndex[$hashKey]) {
            $display = [string]$item.filename
            if ($seen.Add($display)) { [void]$matched.Add($display) }
        }
    }
    return @($matched)
}

function Get-RelationshipRows {
    param([object]$Data, [string[]]$Filenames)

    $rows = New-Object System.Collections.ArrayList
    foreach ($filename in $Filenames) {
        $key = $filename.ToLowerInvariant()
        if ($Data.ownersByFilename.ContainsKey($key) -and $Data.ownersByFilename[$key].Count -gt 0) {
            foreach ($owner in $Data.ownersByFilename[$key]) {
                [void]$rows.Add([pscustomobject]@{
                    id = [string]$owner.id
                    title = [string]$owner.title
                    date = [string]$owner.date
                    note = [string]$owner.note
                    filename = [string]$filename
                })
            }
        } else {
            [void]$rows.Add([pscustomobject]@{
                id = ''
                title = ''
                date = ''
                note = ''
                filename = [string]$filename
            })
        }
    }
    return @($rows)
}

function Get-FieldLabel {
    param([string]$Field)
    switch ($Field) {
        'id' { return 'ID' }
        'title' { return 'Title' }
        'date' { return 'Date' }
        'note' { return 'Note' }
        'filename' { return 'Filename' }
        default { return $Field }
    }
}

function Emit-ProjectedRows {
    param([object[]]$Rows, [string[]]$Projection, [string]$OutputMode)

    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $emitted = 0

    foreach ($row in $Rows) {
        $values = New-Object System.Collections.ArrayList
        $hasNonEmpty = $false
        foreach ($field in $Projection) {
            $value = Normalize-Scalar ([string]$row.$field)
            if (-not [string]::IsNullOrEmpty($value)) { $hasNonEmpty = $true }
            [void]$values.Add($value)
        }
        if (-not $hasNonEmpty) { continue }

        $keyParts = @()
        foreach ($value in $values) {
            $keyParts += ([string]$value).Length.ToString() + ':' + [string]$value
        }
        $dedupeKey = $keyParts -join [char]0x1F
        if (-not $seen.Add($dedupeKey)) { continue }

        if ($OutputMode -eq 'machine') {
            Write-Line (($values | ForEach-Object { [string]$_ }) -join [char]9)
        } else {
            $parts = @()
            for ($index = 0; $index -lt $Projection.Count; $index++) {
                $value = [string]$values[$index]
                if ([string]::IsNullOrEmpty($value)) { $value = '(none)' }
                $parts += ((Get-FieldLabel $Projection[$index]) + ': ' + $value)
            }
            Write-Line ($parts -join ' | ')
        }
        $emitted++
    }
    return $emitted
}

if ([string]::IsNullOrWhiteSpace($Dump) -or (@('--help','-h','-?','/h','/?') -contains $Dump)) {
    Show-Usage
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Search)) {
    Write-Err 'ERROR: Missing search-value.'
    Show-Usage
    [Environment]::Exit(2)
}

if (@('human','machine') -notcontains $Mode) { Fail 2 ('Unsupported output mode: ' + $Mode) }
if (@('filename','hash') -notcontains $Source) { Fail 2 ('Unsupported relationship source: ' + $Source) }

$allowedFields = @('id','title','date','note','filename')
foreach ($field in $Fields) {
    if ($allowedFields -notcontains $field) { Fail 2 ('Unsupported output field: ' + $field) }
}

$DumpFolder = Resolve-DumpFolder $Dump $ScriptRoot
if ($null -eq $DumpFolder) { Fail 3 ('Dump folder not found: ' + $Dump) }

try {
    $data = Read-RelationshipData $DumpFolder
    $filenames = @(Get-MatchedFilenames $data $Source $Search)
    if ($filenames.Count -eq 0) { [Environment]::Exit(1) }

    $rows = @(Get-RelationshipRows $data $filenames)
    $emitted = Emit-ProjectedRows $rows $Fields $Mode
    if ($emitted -eq 0) { [Environment]::Exit(1) }
    exit 0
} catch [System.IO.FileNotFoundException] {
    Fail 4 $_.Exception.Message
} catch {
    Fail 5 $_.Exception.Message
}
:_MVSRelationship_end
