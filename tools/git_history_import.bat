@echo off
:setup
set "app.version=0.3.5"
set "app.name=git_history_import"
set "app.self=%~f0"
set "app.rc=0"
:main
set "RunPowerShellFromLabel.function=GitHistoryImport"
call :RunPowerShellFromLabel %*
set "app.rc=%errorlevel%"
:end
call :SetErrorLevel %app.rc%
GoTo :EOF

:: ============================================================
:: :SetErrorLevel
:: Restores the intended application return code.
::
:: Version:
::   1.0.0
::
:: Usage: call :SetErrorLevel returnCode
::
:: Arguments:
::   returnCode  integer process return code
::
:: Output:
::   None
::
:: Returns:
::   returnCode
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
::   Run PowerShell interactively so importer prompts and CTRL+G input work.
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
powershell.exe -NoLogo -NoProfile -Command "& { try { $ErrorActionPreference='Stop'; $path=$env:rps_self; $start=$env:rps_start; $end=$env:rps_end; $argc=[int]$env:rps_argc; $lines=@(Get-Content -LiteralPath $path); $s=-1; $e=-1; for($i=0;$i-lt$lines.Count;$i++){ $t=$lines[$i].Trim(); if($s-lt 0-and$t-eq$start){$s=$i;continue}; if($s-ge 0-and$t-eq$end){$e=$i;break} }; if($s-lt 0-or$e-le$s){throw ('Could not find valid PowerShell block: '+$start+' / '+$end)}; $code=if($e-gt($s+1)){$lines[($s+1)..($e-1)]-join[Environment]::NewLine}else{''}; $arguments=@(); for($n=0;$n-lt$argc;$n++){$arguments += [Environment]::GetEnvironmentVariable(('rps_arg{0}'-f$n))}; & ([ScriptBlock]::Create($code)) @arguments; if(-not $?){exit 1}; exit 0 } catch { Write-Error $_; exit 1 } }"
set "rps_rc=%errorlevel%"
if not "%rps_rc%"=="0" (set "_rps_rc=%rps_rc%" & goto :RunPowerShellFromLabel)
exit /b 0

:_GitHistoryImport_start
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArgs
)

$ErrorActionPreference = 'Stop'
$ToolVersion = '0.3.5'
$StateSchema = 'git-history-import-state/v1'
$PlanSchema = 'history-import-plan/v1'
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Write-Heading {
    param([string]$Text)
    Write-Host ''
    Write-Host ('=' * 60) -ForegroundColor DarkCyan
    Write-Host (' ' + $Text) -ForegroundColor Cyan
    Write-Host ('=' * 60) -ForegroundColor DarkCyan
    Write-Host ''
}

function Write-Ok {
    param([string]$Text)
    Write-Host $Text -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)
    Write-Host $Text -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Text)
    Write-Host $Text -ForegroundColor Red
}

function Write-InfoPair {
    param([string]$Name, [string]$Value, [ConsoleColor]$ValueColor = [ConsoleColor]::White)
    Write-Host ($Name.PadRight(16)) -NoNewline -ForegroundColor DarkCyan
    Write-Host $Value -ForegroundColor $ValueColor
}

function Get-UtcText {
    return [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function Write-Utf8File {
    param([string]$Path, [string]$Text)
    $parent = Split-Path -Parent $Path
    if ($parent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "JSON file not found: $Path" }
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Write-JsonFile {
    param([string]$Path, $Object)
    $json = $Object | ConvertTo-Json -Depth 100
    Write-Utf8File $Path ($json + "`n")
}

function Invoke-Captured {
    param([string]$File, [string[]]$Arguments, [string]$WorkingDirectory)
    $old = Get-Location
    try {
        if ($WorkingDirectory) { Set-Location -LiteralPath $WorkingDirectory }
        $output = & $File @Arguments 2>&1 | ForEach-Object { $_.ToString() }
        $rc = $LASTEXITCODE
        if ($null -eq $rc) { $rc = 0 }
        return [pscustomobject]@{ Rc=[int]$rc; Output=($output -join "`n") }
    } finally {
        Set-Location -LiteralPath $old
    }
}

function Invoke-Git {
    param([string]$Root, [string[]]$Arguments, [switch]$AllowFailure)
    $r = Invoke-Captured 'git.exe' $Arguments $Root
    if (-not $AllowFailure -and $r.Rc -ne 0) {
        throw "git $($Arguments -join ' ') failed with rc=$($r.Rc).`n$($r.Output)"
    }
    return $r
}

function Get-RepositoryRoot {
    $cwd = (Get-Location).Path
    $r = Invoke-Captured 'git.exe' @('rev-parse','--show-toplevel') $cwd
    if ($r.Rc -eq 0 -and $r.Output.Trim()) {
        return [IO.Path]::GetFullPath($r.Output.Trim())
    }
    $tools = Split-Path -Parent $env:rps_self
    return [IO.Path]::GetFullPath((Join-Path $tools '..'))
}

function Get-GitDirectory {
    param([string]$Root)
    $r = Invoke-Git $Root @('rev-parse','--git-dir') -AllowFailure
    if ($r.Rc -ne 0 -or -not $r.Output.Trim()) { return $null }
    $p = $r.Output.Trim()
    if (-not [IO.Path]::IsPathRooted($p)) { $p = Join-Path $Root $p }
    return [IO.Path]::GetFullPath($p)
}

function Get-PointerPath {
    param([string]$Root)
    $gd = Get-GitDirectory $Root
    if (-not $gd) { return $null }
    return (Join-Path (Join-Path $gd 'info') 'git_history_import.work-folder.txt')
}

function Get-DefaultWorkFolder {
    param([string]$Root)
    return [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $Root) 'local_history_import'))
}

function Resolve-WorkFolder {
    param([string]$Root, [string]$Explicit)
    if ($Explicit) { return [IO.Path]::GetFullPath($Explicit) }
    $pointer = Get-PointerPath $Root
    if ($pointer -and (Test-Path -LiteralPath $pointer -PathType Leaf)) {
        $v = (Get-Content -LiteralPath $pointer -Raw -Encoding UTF8).Trim()
        if ($v) { return [IO.Path]::GetFullPath($v) }
    }
    return (Get-DefaultWorkFolder $Root)
}

function Set-WorkPointer {
    param([string]$Root, [string]$WorkFolder)
    $p = Get-PointerPath $Root
    if (-not $p) { return }
    [IO.Directory]::CreateDirectory((Split-Path -Parent $p)) | Out-Null
    Write-Utf8File $p ([IO.Path]::GetFullPath($WorkFolder) + "`n")
}

function Clear-WorkPointer {
    param([string]$Root)
    $p = Get-PointerPath $Root
    if ($p -and (Test-Path -LiteralPath $p)) { Remove-Item -LiteralPath $p -Force }
}

function Ensure-LocalIgnore {
    param([string]$Root, [string]$WorkFolder)
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $workFull = [IO.Path]::GetFullPath($WorkFolder)
    if (-not $workFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) { return }
    $rel = $workFull.Substring($rootFull.Length).Replace('\','/')
    $gd = Get-GitDirectory $Root
    if (-not $gd) { return }
    $exclude = Join-Path (Join-Path $gd 'info') 'exclude'
    $old = ''
    if (Test-Path -LiteralPath $exclude) { $old = Get-Content -LiteralPath $exclude -Raw -Encoding UTF8 }
    $marker = '# git_history_import local work folder'
    $line = '/' + $rel.Trim('/') + '/'
    if ($old -notmatch [regex]::Escape($marker) -or $old -notmatch [regex]::Escape($line)) {
        if ($old -and -not $old.EndsWith("`n")) { $old += "`n" }
        Write-Utf8File $exclude ($old + $marker + "`n" + $line + "`n")
    }
}

function New-PhaseRecord {
    param([bool]$Ok, [string]$Report, [string]$Detail)
    return [pscustomobject][ordered]@{
        ok=$Ok
        utc=Get-UtcText
        report=if($Report){$Report}else{$null}
        detail=if($Detail){$Detail}else{''}
    }
}

function Get-StatePath {
    param([string]$WorkFolder)
    return (Join-Path $WorkFolder 'git_history_import.state.json')
}

function Save-State {
    param([string]$WorkFolder, $State)
    [IO.Directory]::CreateDirectory($WorkFolder) | Out-Null
    $now=Get-UtcText
    if($State.psobject.Properties['updatedUtc']){$State.updatedUtc=$now}else{$State|Add-Member -NotePropertyName updatedUtc -NotePropertyValue $now}
    Write-JsonFile (Get-StatePath $WorkFolder) $State
}

function Load-State {
    param([string]$Root, [string]$ExplicitWorkFolder, [switch]$Optional)
    $wf = Resolve-WorkFolder $Root $ExplicitWorkFolder
    $script:CurrentWorkFolder=$wf
    $sp = Get-StatePath $wf
    if (-not (Test-Path -LiteralPath $sp -PathType Leaf)) {
        if ($Optional) { return [pscustomobject]@{ WorkFolder=$wf; State=$null } }
        throw "No history-import setup was found at $sp`nRun: tools\git_history_import setup"
    }
    $state = Read-JsonFile $sp
    if ($state.schema -ne $StateSchema) { throw "Unsupported state schema in ${sp}: $($state.schema)" }
    return [pscustomobject]@{ WorkFolder=$wf; State=$state }
}

function Read-YesNo {
    param([string]$Prompt, [bool]$DefaultYes)
    $suffix = if($DefaultYes){'[Y/n]'}else{'[y/N]'}
    $a = Read-Host "$Prompt $suffix"
    if (-not $a) { return $DefaultYes }
    return ($a -match '^(?i)y(?:es)?$')
}

function Read-RunStopSkip {
    param([string]$Prompt)
    while ($true) {
        $a = Read-Host "$Prompt [Y/n/s]"
        if (-not $a -or $a -match '^(?i)y(?:es)?$') { return 'run' }
        if ($a -match '^(?i)n(?:o)?$') { return 'stop' }
        if ($a -match '^(?i)s(?:kip)?$') { return 'skip' }
        Write-Warn 'Enter Y, n, or s.'
    }
}

function Parse-Options {
    param([string[]]$OptionArgs, [int]$Start)
    $o = @{}
    for ($i=$Start; $i -lt $OptionArgs.Count; $i++) {
        $a = $OptionArgs[$i]
        if ($a -eq '--import-all') { $o['import-all']=$true; continue }
        if (-not $a.StartsWith('--')) { throw "Unexpected argument: $a" }
        $name = $a.Substring(2)
        if ($i + 1 -ge $OptionArgs.Count) { throw "Missing value for $a" }
        $i++
        $o[$name]=$OptionArgs[$i]
    }
    return $o
}

function Get-Option {
    param($Options, [string]$Name)
    if ($Options.ContainsKey($Name)) { return [string]$Options[$Name] }
    return $null
}

function Get-CompanionFile {
    param([string]$Source, [string]$Kind)
    $full=[IO.Path]::GetFullPath($Source)
    $isFolder=Test-Path -LiteralPath $full -PathType Container
    $parent=if($isFolder){Split-Path -Parent $full}else{Split-Path -Parent $full}
    $leaf=if($isFolder){Split-Path -Leaf $full}else{[IO.Path]::GetFileName($full)}
    $stem=if($isFolder){$leaf}else{[IO.Path]::GetFileNameWithoutExtension($full)}
    $exact=New-Object System.Collections.Generic.List[string]
    $search=New-Object System.Collections.Generic.List[string]
    if($isFolder){
        $exact.Add((Join-Path $full ($leaf+'.'+$Kind+'.txt')))
        $exact.Add((Join-Path $parent ($leaf+'.'+$Kind+'.txt')))
        $search.Add($full)
        if($parent -and $parent -ne $full){$search.Add($parent)}
    }else{
        $exact.Add($full+'.'+$Kind+'.txt')
        if($stem -and $stem -ne $leaf){$exact.Add((Join-Path $parent ($stem+'.'+$Kind+'.txt')))}
        $search.Add($parent)
    }
    foreach($p in $exact){
        if(Test-Path -LiteralPath $p -PathType Leaf){return [pscustomobject]@{Path=[IO.Path]::GetFullPath($p);Match='exact'}}
    }
    $found=New-Object System.Collections.Generic.List[string]
    foreach($dir in $search){
        if(-not $dir -or -not(Test-Path -LiteralPath $dir -PathType Container)){continue}
        foreach($f in @(Get-ChildItem -LiteralPath $dir -File -Filter ('*.'+$Kind+'.txt') -ErrorAction SilentlyContinue)){
            $fp=[IO.Path]::GetFullPath($f.FullName)
            if(-not $found.Contains($fp)){$found.Add($fp)}
        }
    }
    if($found.Count -eq 1){return [pscustomobject]@{Path=$found[0];Match='unique wildcard'}}
    if($found.Count -gt 1){
        $detail=($found|ForEach-Object{'  '+$_}) -join "`n"
        $option=if($Kind -eq 'exclude'){'exclude-list'}else{$Kind}
        throw "More than one *.$Kind.txt companion was found for source '$full'. Use the explicit --$option option.`n$detail"
    }
    return $null
}

function Read-LayoutReferenceFile {
    param([string]$Path)
    $full=[IO.Path]::GetFullPath($Path)
    if(-not(Test-Path -LiteralPath $full -PathType Leaf)){throw "Layout companion file not found: $full"}
    $items=@(Read-ListFile $full)
    if($items.Count -ne 1){throw "Layout companion must contain exactly one active line (blank lines and # comments are ignored): $full"}
    $value=[string]$items[0]
    if([IO.Path]::IsPathRooted($value)){return [IO.Path]::GetFullPath($value)}
    $relative=Join-Path (Split-Path -Parent $full) $value
    if(Test-Path -LiteralPath $relative){return [IO.Path]::GetFullPath($relative)}
    return $value
}

function Resolve-LayoutValue {
    param([string]$Value, [ref]$LayoutFile)
    if(-not $Value){return $null}
    if(Test-Path -LiteralPath $Value -PathType Leaf){
        $full=[IO.Path]::GetFullPath($Value)
        if([IO.Path]::GetFileName($full) -like '*.layout.txt'){
            $LayoutFile.Value=$full
            return (Read-LayoutReferenceFile $full)
        }
        return $full
    }
    if(Test-Path -LiteralPath $Value -PathType Container){return [IO.Path]::GetFullPath($Value)}
    return $Value
}

function Write-AutoCompanion {
    param([string]$Kind, $Match)
    Write-Host '  [AUTO] ' -NoNewline -ForegroundColor Green
    Write-Host ($Kind+': ') -NoNewline -ForegroundColor Cyan
    Write-Host $Match.Path -ForegroundColor White
}

function Remove-TreeRobust {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $last = $null
    for ($attempt=1; $attempt -le 8; $attempt++) {
        try {
            & attrib.exe -R "$Path\*" /S /D 2>$null | Out-Null
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            return
        } catch {
            $last = $_
            Start-Sleep -Milliseconds ([Math]::Min(200 * $attempt, 1000))
        }
    }
    throw "Could not reset disposable folder after 8 attempts: $Path`n$last"
}

function Copy-OrHardLink {
    param([string]$Source, [string]$Destination)
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Destination)) | Out-Null
    try {
        New-Item -ItemType HardLink -Path $Destination -Target $Source -ErrorAction Stop | Out-Null
    } catch {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
}

function New-ZipFromFolder {
    param([string]$Folder, [string]$ZipPath)
    if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
    [IO.Compression.ZipFile]::CreateFromDirectory($Folder, $ZipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
}

function Prepare-Source {
    param([string]$Original, [string]$WorkFolder)
    $originalFull = [IO.Path]::GetFullPath($Original)
    $aliases = @{}
    $notes = New-Object System.Collections.Generic.List[string]
    if (Test-Path -LiteralPath $originalFull -PathType Container) {
        $dirs = @(Get-ChildItem -LiteralPath $originalFull -Directory | Sort-Object Name)
        $zips = @(Get-ChildItem -LiteralPath $originalFull -File | Where-Object { $_.Extension -ieq '.zip' } | Sort-Object Name)
        if ($dirs.Count -eq 0) {
            if ($zips.Count -eq 0) { throw "Source directory contains no version folders or ZIP archives: $originalFull" }
            return [pscustomobject]@{ Source=$originalFull; Aliases=$aliases; Notes=$notes.ToArray() }
        }
        $cache = Join-Path $WorkFolder 'source-cache'
        Remove-TreeRobust $cache
        [IO.Directory]::CreateDirectory($cache) | Out-Null
        $used = @{}
        foreach($z in $zips) {
            if ($used.ContainsKey($z.Name.ToLowerInvariant())) { throw "Duplicate normalized source name: $($z.Name)" }
            Copy-OrHardLink $z.FullName (Join-Path $cache $z.Name)
            $used[$z.Name.ToLowerInvariant()]=$true
        }
        foreach($d in $dirs) {
            $name = $d.Name + '.zip'
            if ($used.ContainsKey($name.ToLowerInvariant())) { throw "Version folder $($d.Name) collides with ZIP revision $name." }
            New-ZipFromFolder $d.FullName (Join-Path $cache $name)
            $aliases[$d.Name]=$name
            $used[$name.ToLowerInvariant()]=$true
        }
        $notes.Add("Normalized $($dirs.Count) version folder(s) into $cache")
        return [pscustomobject]@{ Source=$cache; Aliases=$aliases; Notes=$notes.ToArray() }
    }
    if (-not (Test-Path -LiteralPath $originalFull -PathType Leaf)) { throw "Source does not exist: $originalFull" }
    if ([IO.Path]::GetExtension($originalFull) -ine '.zip') { throw "Source compressed file must be a ZIP archive: $originalFull" }
    $cache = Join-Path $WorkFolder 'source-cache'
    Remove-TreeRobust $cache
    [IO.Directory]::CreateDirectory($cache) | Out-Null
    $outer = [IO.Compression.ZipFile]::OpenRead($originalFull)
    try {
        $files = @($outer.Entries | Where-Object { $_.Name })
        $nested = @($files | Where-Object { $_.FullName -match '(?i)\.zip$' })
        $nonzip = @($files | Where-Object { $_.FullName -notmatch '(?i)\.zip$' })
        $used = @{}
        foreach($e in $nested) {
            $name = [IO.Path]::GetFileName($e.FullName)
            $key = $name.ToLowerInvariant()
            if ($used.ContainsKey($key)) { throw "Duplicate nested revision name: $name" }
            $dest = Join-Path $cache $name
            $inStream = $e.Open()
            $outStream = [IO.File]::Create($dest)
            try { $inStream.CopyTo($outStream) } finally { $outStream.Dispose(); $inStream.Dispose() }
            $used[$key]=$true
        }
        $groups = @{}
        $rootFiles = New-Object System.Collections.Generic.List[object]
        foreach($e in $nonzip) {
            $parts = $e.FullName.Replace('\','/').Split('/')
            if ($parts.Count -lt 2) { $rootFiles.Add($e); continue }
            $g = $parts[0]
            if (-not $groups.ContainsKey($g)) { $groups[$g] = New-Object System.Collections.Generic.List[object] }
            $groups[$g].Add($e)
        }
        foreach($g in @($groups.Keys | Sort-Object)) {
            $name = $g + '.zip'
            $key = $name.ToLowerInvariant()
            if ($used.ContainsKey($key)) { throw "Version folder $g collides with nested archive $name." }
            $dest = Join-Path $cache $name
            $fs = [IO.File]::Create($dest)
            $za = [IO.Compression.ZipArchive]::new($fs,[IO.Compression.ZipArchiveMode]::Create,$false)
            try {
                $prefix = $g.TrimEnd('/') + '/'
                foreach($e in $groups[$g]) {
                    $rel = $e.FullName.Replace('\','/').Substring($prefix.Length)
                    if (-not $rel) { continue }
                    $ze = $za.CreateEntry($rel,[IO.Compression.CompressionLevel]::Optimal)
                    $src = $e.Open(); $dst = $ze.Open()
                    try { $src.CopyTo($dst) } finally { $dst.Dispose(); $src.Dispose() }
                }
            } finally { $za.Dispose(); $fs.Dispose() }
            $aliases[$g]=$name
            $used[$key]=$true
        }
        if ($nested.Count -eq 0 -and $groups.Count -eq 0 -and $rootFiles.Count -gt 0) {
            Copy-OrHardLink $originalFull (Join-Path $cache ([IO.Path]::GetFileName($originalFull)))
            $notes.Add('Treated the supplied ZIP as one version snapshot.')
        } else {
            if ($rootFiles.Count -gt 0) { $notes.Add("Ignored $($rootFiles.Count) loose outer-archive file(s) not belonging to a version folder.") }
            if ($groups.Count -gt 0) { $notes.Add("Normalized $($groups.Count) version folder(s) from the outer ZIP into $cache") }
        }
    } finally {
        $outer.Dispose()
    }
    if (@(Get-ChildItem -LiteralPath $cache -Filter *.zip -File).Count -eq 0) { throw 'Compressed source contains no detectable version ZIPs/folders.' }
    return [pscustomobject]@{ Source=$cache; Aliases=$aliases; Notes=$notes.ToArray() }
}

function Get-Sha256Bytes {
    param([byte[]]$Bytes)
    $h=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($h.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() } finally { $h.Dispose() }
}

function Get-Sha256File {
    param([string]$Path)
    $h=[Security.Cryptography.SHA256]::Create()
    $s=[IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','').ToLowerInvariant() } finally { $s.Dispose(); $h.Dispose() }
}

function Normalize-ZipPath {
    param([string]$Path)
    $p=$Path.Replace('\','/')
    if ($p.StartsWith('/')) { throw "Unsafe archive path: $Path" }
    $parts = @($p.Split('/') | Where-Object { $_ -and $_ -ne '.' })
    if ($parts.Count -eq 0 -or $parts -contains '..') { throw "Unsafe archive path: $Path" }
    foreach($x in $parts) { if ($x.Contains(':')) { throw "Unsafe archive path: $Path" } }
    return ($parts -join '/')
}

function Read-ZipInventory {
    param([string]$ZipPath, [bool]$IncludeData)
    $z=[IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entries=@($z.Entries | Where-Object { $_.Name })
        $names=@()
        foreach($e in $entries){ $names += (Normalize-ZipPath $e.FullName) }
        $prefix=''
        if ($names.Count -gt 0) {
            $first=$null; $allNested=$true
            foreach($n in $names){
                $parts=$n.Split('/')
                if ($parts.Count -lt 2){$allNested=$false;break}
                if ($null -eq $first){$first=$parts[0]} elseif($parts[0] -cne $first){$allNested=$false;break}
            }
            if ($allNested){$prefix=$first+'/'}
        }
        $files=[System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
        for($i=0;$i -lt $entries.Count;$i++){
            $raw=$names[$i]
            $rel=if($prefix -and $raw.StartsWith($prefix,[StringComparison]::Ordinal)){$raw.Substring($prefix.Length)}else{$raw}
            $rel=Normalize-ZipPath $rel
            if($files.ContainsKey($rel)){throw "Duplicate path after root stripping: $rel"}
            $s=$entries[$i].Open(); $m=New-Object IO.MemoryStream
            try{$s.CopyTo($m);$bytes=$m.ToArray()}finally{$m.Dispose();$s.Dispose()}
            $rec=[ordered]@{sha256=Get-Sha256Bytes $bytes;size=$bytes.Length}
            if($IncludeData){$rec.data=$bytes}
            $files.Add($rel,[pscustomobject]$rec)
        }
        return [pscustomobject]@{Files=$files;Prefix=$prefix}
    } finally {$z.Dispose()}
}

function Get-StableTreeHash {
    param($Files)
    $paths=[string[]]@($Files.Keys)
    [Array]::Sort($paths,[StringComparer]::OrdinalIgnoreCase)
    $m=New-Object IO.MemoryStream
    try{
        foreach($p in $paths){
            $b=$Utf8NoBom.GetBytes($p);$m.Write($b,0,$b.Length);$m.WriteByte(0)
            $h=[Text.Encoding]::ASCII.GetBytes([string]$Files[$p].sha256);$m.Write($h,0,$h.Length);$m.WriteByte(10)
        }
        return (Get-Sha256Bytes ($m.ToArray()))
    }finally{$m.Dispose()}
}

function Parse-VersionName {
    param([string]$Name)
    $m=[regex]::Match([IO.Path]::GetFileName($Name),'(?i)(?<version>\d+(?:\.\d+){1,3})(?:-(?<variant>[^.]+))?\.zip$')
    if(-not $m.Success){throw "Could not parse a numeric version from archive name: $Name"}
    $ver=$m.Groups['version'].Value
    $nums=@($ver.Split('.')|ForEach-Object{[int]$_})
    $key=($nums|ForEach-Object{$_.ToString('D10')}) -join '.'
    return [pscustomobject]@{Version=$ver;Variant=$m.Groups['variant'].Value;SortKey=$key}
}

function Match-Pattern {
    param([string]$Name,[string[]]$Patterns)
    foreach($p in @($Patterns)){if($Name -like $p){return $p}}
    return $null
}

function Get-Delta {
    param($Previous,$Current)
    if($null -eq $Previous){return [pscustomobject][ordered]@{added=$Current.Count;modified=0;deleted=0;unchanged=0}}
    $p=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($k in $Previous.Keys){$p.Add($k)|Out-Null}
    $c=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($k in $Current.Keys){$c.Add($k)|Out-Null}
    $added=0;$deleted=0;$modified=0;$unchanged=0
    foreach($k in $c){
        if(-not $p.Contains($k)){$added++}
        elseif($Previous[$k].sha256 -cne $Current[$k].sha256){$modified++}
        else{$unchanged++}
    }
    foreach($k in $p){if(-not $c.Contains($k)){$deleted++}}
    return [pscustomobject][ordered]@{added=$added;modified=$modified;deleted=$deleted;unchanged=$unchanged}
}

function Map-Snapshot {
    param($Files,$Moves)
    $out=[System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $orig=@{};$collisions=New-Object System.Collections.Generic.List[object]
    foreach($src in $Files.Keys){
        $dst=if($Moves.ContainsKey($src)){$Moves[$src]}else{$src}
        if($out.ContainsKey($dst)){$collisions.Add([pscustomobject]@{destination=$dst;sourceA=$orig[$dst];sourceB=$src});continue}
        $out.Add($dst,$Files[$src]);$orig[$dst]=$src
    }
    return [pscustomobject]@{Files=$out;Collisions=$collisions.ToArray()}
}

function Get-ArchiveTexts {
    param([string]$ZipPath)
    $inv=Read-ZipInventory $ZipPath $true
    $readme='';$history=''
    foreach($k in $inv.Files.Keys){
        if($k -ieq 'README.md'){$readme=$Utf8NoBom.GetString([byte[]]$inv.Files[$k].data)}
        if($k -ieq 'doc/project-version-history.txt'){$history=$Utf8NoBom.GetString([byte[]]$inv.Files[$k].data)}
    }
    return [pscustomobject]@{Readme=$readme;History=$history}
}

function Get-HistoryBullets {
    param([string]$History,[string]$Version)
    if(-not $History){return @()}
    $lines=@($History -split "`r?`n")
    $start=-1
    $exact='^\s*'+[regex]::Escape($Version)+'(?:\s*-\s*.*)?\s*$'
    for($i=0;$i -lt $lines.Count;$i++){if($lines[$i] -match $exact){$start=$i+1;break}}
    if($start -lt 0){return @()}
    $out=New-Object System.Collections.Generic.List[string];$current=''
    for($i=$start;$i -lt $lines.Count;$i++){
        $line=$lines[$i]
        if($line -match '^\s*\d+(?:\.\d+){1,3}(?:\s*-\s*.*)?\s*$'){break}
        if($line -match '^\s*[-*]\s+(.*)$'){
            if($current){$out.Add(($current -replace '\s+',' ').Trim())}
            $current=$Matches[1].Trim()
        }elseif($current -and $line.Trim()){$current+=' '+$line.Trim()}
    }
    if($current){$out.Add(($current -replace '\s+',' ').Trim())}
    return $out.ToArray()
}

function Get-ReadmeBullets {
    param([string]$Readme)
    if(-not $Readme){return @()}
    $lines=@($Readme -split "`r?`n")
    $wanted=@('what is included','changes','highlights','what changed','overview')
    for($i=0;$i -lt $lines.Count;$i++){
        if($lines[$i] -match '^##\s+(.+)$' -and $wanted -contains $Matches[1].Trim().ToLowerInvariant()){
            $out=New-Object System.Collections.Generic.List[string]
            for($j=$i+1;$j -lt $lines.Count;$j++){
                if($lines[$j] -match '^##\s+'){break}
                if($lines[$j] -match '^\s*[-*]\s+(.*)$'){$out.Add(($Matches[1] -replace '\s+',' ').Trim())}
            }
            if($out.Count){return $out.ToArray()}
        }
    }
    return @()
}

function Get-ProposedDescription {
    param([string]$ZipPath,[string]$Version)
    $t=Get-ArchiveTexts $ZipPath
    $b=Get-HistoryBullets $t.History $Version
    if($b.Count -eq 0){$b=Get-ReadmeBullets $t.Readme}
    return @($b)
}

function Get-ExternalLayoutInventory {
    param([string]$Layout)
    $full=[IO.Path]::GetFullPath($Layout)
    if(Test-Path -LiteralPath $full -PathType Container){
        $files=[System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
        foreach($f in Get-ChildItem -LiteralPath $full -File -Recurse | Sort-Object FullName){
            $rel=$f.FullName.Substring($full.TrimEnd('\').Length+1).Replace('\','/')
            $files.Add($rel,[pscustomobject]@{sha256=Get-Sha256File $f.FullName;size=$f.Length})
        }
        if($files.Count -eq 0){throw "Layout directory contains no files: $full"}
        return [pscustomobject]@{Files=$files;Prefix=''}
    }
    if(Test-Path -LiteralPath $full -PathType Leaf){
        $inv=Read-ZipInventory $full $false
        return $inv
    }
    throw "Layout must be a directory or ZIP archive: $Layout"
}

function Inspect-Source {
    param(
        [string]$Source,
        [string]$Output,
        [string]$Layout,
        [bool]$IdentityLayout,
        [string[]]$ExcludePatterns,
        [string[]]$IncludeNames
    )
    $entries=@(Get-ChildItem -LiteralPath $Source -Filter *.zip -File | Sort-Object Name)
    if($entries.Count -eq 0){throw "No version ZIPs were found in $Source"}
    $excluded=New-Object System.Collections.Generic.List[object]
    $included=New-Object System.Collections.Generic.List[object]
    foreach($e in $entries){
        if($IncludeNames.Count -gt 0 -and -not ($IncludeNames -contains $e.Name)){
            $excluded.Add([pscustomobject]@{archive=$e.Name;reason='not selected by include filter'});continue
        }
        $pat=Match-Pattern $e.Name $ExcludePatterns
        if($pat){$excluded.Add([pscustomobject]@{archive=$e.Name;reason="matches exclude pattern $pat"})}
        else{$included.Add($e)}
    }
    if($included.Count -eq 0){throw 'All discovered archives were excluded.'}
    $parsed=@()
    foreach($e in $included){
        $v=Parse-VersionName $e.Name
        $parsed += [pscustomobject]@{Entry=$e;Version=$v.Version;Variant=$v.Variant;SortKey=($v.SortKey+'|'+$e.Name.ToLowerInvariant())}
    }
    $parsed=@($parsed|Sort-Object SortKey)
    $layoutMode='identity';$finalName=$null;$finalPrefix='';$finalFiles=[System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    if(-not $IdentityLayout){
        $layoutMode='reference'
        if($Layout){
            if(Test-Path -LiteralPath $Layout){
                $li=Get-ExternalLayoutInventory $Layout;$finalFiles=$li.Files;$finalPrefix=$li.Prefix;$finalName=[IO.Path]::GetFullPath($Layout)
            }else{
                $match=@($parsed|Where-Object{$_.Entry.Name -ceq [IO.Path]::GetFileName($Layout)})
                if($match.Count -ne 1){throw "Layout reference '$Layout' is neither an existing path nor exactly one included source archive."}
                $finalName=$match[0].Entry.Name;$li=Read-ZipInventory $match[0].Entry.FullName $false;$finalFiles=$li.Files;$finalPrefix=$li.Prefix
            }
        }else{
            $final=$parsed[-1];$finalName=$final.Entry.Name;$li=Read-ZipInventory $final.Entry.FullName $false;$finalFiles=$li.Files;$finalPrefix=$li.Prefix
        }
    }
    $finalBase=@{};$finalHash=@{}
    foreach($q in $finalFiles.Keys){
        $b=[IO.Path]::GetFileName($q).ToLowerInvariant()
        if(-not $finalBase.ContainsKey($b)){$finalBase[$b]=New-Object System.Collections.Generic.List[string]}
        $finalBase[$b].Add($q)
        $h=$finalFiles[$q].sha256
        if(-not $finalHash.ContainsKey($h)){$finalHash[$h]=New-Object System.Collections.Generic.List[string]}
        $finalHash[$h].Add($q)
    }
    $allPaths=[System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $pathHashes=[System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $raw=New-Object System.Collections.Generic.List[object]
    $order=0
    foreach($item in $parsed){
        $order++;$e=$item.Entry;$inv=Read-ZipInventory $e.FullName $false
        foreach($q in $inv.Files.Keys){
            if(-not $allPaths.ContainsKey($q)){$allPaths.Add($q,[System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal))}
            $allPaths[$q].Add($e.Name)|Out-Null
            if(-not $pathHashes.ContainsKey($q)){$pathHashes.Add($q,[System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal))}
            $pathHashes[$q].Add([string]$inv.Files[$q].sha256)|Out-Null
        }
        $desc=Get-ProposedDescription $e.FullName $item.Version
        $subject='v'+$item.Version
        if($item.Variant){$subject+='-'+$item.Variant}
        $subject+=' import archived revision'
        $raw.Add([pscustomobject][ordered]@{
            order=$order;archive=$e.Name;version=$item.Version;variant=$item.Variant
            archiveSha256=Get-Sha256File $e.FullName;archiveBytes=$e.Length
            archiveTimestamp=$e.LastWriteTime.ToString('yyyy-MM-ddTHH:mm:ss')
            stripRoot=$inv.Prefix.TrimEnd('/');sourceFileCount=$inv.Files.Count
            subject=$subject;description=@($desc);files=$inv.Files
        })
    }
    $moves=@{};$moveRecords=New-Object System.Collections.Generic.List[object]
    $historical=New-Object System.Collections.Generic.List[object];$ambiguous=New-Object System.Collections.Generic.List[object]
    if($layoutMode -eq 'reference'){
        $paths=[string[]]@($allPaths.Keys);[Array]::Sort($paths,[StringComparer]::OrdinalIgnoreCase)
        foreach($q in $paths){
            if($finalFiles.ContainsKey($q)){continue}
            $base=[IO.Path]::GetFileName($q).ToLowerInvariant();$byBase=@()
            if($finalBase.ContainsKey($base)){$byBase=$finalBase[$base].ToArray()}
            if($byBase.Count -eq 1){$moves[$q]=$byBase[0];$moveRecords.Add([pscustomobject]@{from=$q;to=$byBase[0];reason='unique-basename-in-final'});continue}
            $cand=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach($h in $pathHashes[$q]){if($finalHash.ContainsKey($h)){foreach($d in $finalHash[$h]){$cand.Add($d)|Out-Null}}}
            if($cand.Count -eq 1){$d=($cand | Select-Object -First 1);$moves[$q]=$d;$moveRecords.Add([pscustomobject]@{from=$q;to=$d;reason='unique-content-match-in-final'});continue}
            if($byBase.Count -gt 0 -or $cand.Count -gt 0){
                $ambiguous.Add([pscustomobject]@{path=$q;basenameCandidates=@($byBase|Sort-Object);contentCandidates=@($cand.GetEnumerator()|Sort-Object);seenIn=@($allPaths[$q].GetEnumerator()|Sort-Object)})
            }else{$historical.Add([pscustomobject]@{path=$q;action='keep-original-path';seenIn=@($allPaths[$q].GetEnumerator()|Sort-Object)})}
        }
    }
    $revisions=New-Object System.Collections.Generic.List[object];$collisions=New-Object System.Collections.Generic.List[object]
    $generated=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $prev=$null
    foreach($r in $raw){
        $mapped=Map-Snapshot $r.files $moves
        foreach($c in $mapped.Collisions){$collisions.Add([pscustomobject]@{destination=$c.destination;sourceA=$c.sourceA;sourceB=$c.sourceB;archive=$r.archive})}
        foreach($q in $mapped.Files.Keys){if($q -match '(?i)(^|/)__pycache__(/|$)' -or $q -match '(?i)\.pyc$'){$generated.Add($q)|Out-Null}}
        $revisions.Add([pscustomobject][ordered]@{
            order=$r.order;archive=$r.archive;version=$r.version;variant=$r.variant
            archiveSha256=$r.archiveSha256;archiveBytes=$r.archiveBytes;archiveTimestamp=$r.archiveTimestamp
            stripRoot=$r.stripRoot;sourceFileCount=$r.sourceFileCount;subject=$r.subject;description=@($r.description)
            normalizedFileCount=$mapped.Files.Count;normalizedTreeSha256=Get-StableTreeHash $mapped.Files
            deltaFromPrevious=Get-Delta $prev $mapped.Files
        })
        $prev=$mapped.Files
    }
    $plan=[pscustomobject][ordered]@{
        schema=$PlanSchema;createdUtc=Get-UtcText
        source=[pscustomobject][ordered]@{name=[IO.Path]::GetFileName($Source);type='directory';finalArchive=$finalName;excludePatterns=@($ExcludePatterns);includePatterns=@($IncludeNames);excluded=$excluded.ToArray()}
        policies=[pscustomobject][ordered]@{preserveUnmanagedTargetFiles=$true;replaceUnmanagedPaths=@('README.md');historicalOnly='keep-original-path';exactBytes=$true;publishCommand='just_publish.bat historyexact yes messagefile <file> PUBLISH COMMIT'}
        layout=[pscustomobject][ordered]@{mode=$layoutMode;finalArchive=$finalName;finalStripRoot=$finalPrefix.TrimEnd('/');finalFileCount=$finalFiles.Count;moves=$moveRecords.ToArray();historicalOnly=$historical.ToArray();ambiguous=$ambiguous.ToArray();collisions=$collisions.ToArray()}
        revisions=$revisions.ToArray()
        warnings=[pscustomobject][ordered]@{generatedHistoricalFiles=@($generated.GetEnumerator()|Sort-Object)}
        summary=[pscustomobject][ordered]@{
            discoveredArchives=$entries.Count;includedRevisions=$revisions.Count;excludedArchives=$excluded.Count
            distinctHistoricalPaths=$allPaths.Count;finalPaths=$finalFiles.Count;inferredMoves=$moveRecords.Count
            historicalOnlyPaths=$historical.Count;ambiguousMappings=$ambiguous.Count;collisions=$collisions.Count
            generatedHistoricalFileCandidates=$generated.Count
        }
    }
    Write-JsonFile $Output $plan
    Write-Host "Wrote: $Output" -ForegroundColor DarkCyan
    foreach($p in $plan.summary.psobject.Properties){Write-Host ($p.Name+': ') -NoNewline -ForegroundColor DarkCyan;Write-Host $p.Value}
    if($ambiguous.Count -gt 0 -or $collisions.Count -gt 0){Write-Warn 'WARNING: plan contains unresolved mapping problems.';return 3}
    return 0
}

function Read-ListFile {
    param([string]$Path)
    $out=New-Object System.Collections.Generic.List[string]
    foreach($line in Get-Content -LiteralPath $Path -Encoding UTF8){
        $t=$line.Trim()
        if($t -and -not $t.StartsWith('#')){$out.Add($t)}
    }
    return $out.ToArray()
}

function Write-ReviewFiles {
    param([string]$WorkFolder,$Plan)
    $ex=@($Plan.source.excluded|ForEach-Object{$_.archive}|Where-Object{$_})
    Write-Utf8File (Join-Path $WorkFolder 'EXCLUDED-ARCHIVES.txt') (($ex -join "`n") + $(if($ex.Count){"`n"}else{''}))
    $msgDir=Join-Path $WorkFolder 'messages';Remove-TreeRobust $msgDir;[IO.Directory]::CreateDirectory($msgDir)|Out-Null
    $combined=New-Object Text.StringBuilder;$i=0
    foreach($r in @($Plan.revisions)){
        $i++;$subject=[string]$r.subject;$body=@($r.description|ForEach-Object{([string]$_).Trim()}|Where-Object{$_})
        $text=$subject+"`n";if($body.Count){$text+="`n"+(($body|ForEach-Object{'- '+$_})-join"`n")+"`n"}
        $safe=('{0:D3}-{1}-{2}' -f $i,$r.version,$r.variant) -replace '[^A-Za-z0-9._-]+','_'
        $safe=$safe.Trim('_')
        Write-Utf8File (Join-Path $msgDir ($safe+'.txt')) $text
        [void]$combined.AppendLine('='*72);[void]$combined.AppendLine(('{0:D3}  {1}' -f $i,$r.archive));[void]$combined.AppendLine('='*72);[void]$combined.AppendLine($text.TrimEnd());[void]$combined.AppendLine()
    }
    Write-Utf8File (Join-Path $WorkFolder 'COMMIT-MESSAGES.txt') $combined.ToString()
}

function Read-MultilineVersions {
    Write-Host ''
    Write-Host 'Paste one version per line:' -ForegroundColor Cyan
    Write-Host '  <version> <commit message>' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Press CTRL+G twice when finished.' -ForegroundColor Yellow
    Write-Host ''
    $sb=New-Object Text.StringBuilder;$bells=0
    while($true){
        $k=[Console]::ReadKey($true)
        if($k.KeyChar -eq [char]3){throw 'Cancelled by CTRL+C.'}
        if([int]$k.KeyChar -eq 7){$bells++;if($bells -ge 2){Write-Host '';break};continue}
        $bells=0
        if($k.Key -eq [ConsoleKey]::Enter){[void]$sb.Append("`n");Write-Host '';continue}
        if($k.Key -eq [ConsoleKey]::Backspace){if($sb.Length -gt 0){$sb.Length--;Write-Host "`b `b" -NoNewline};continue}
        [void]$sb.Append($k.KeyChar);Write-Host $k.KeyChar -NoNewline
    }
    return $sb.ToString()
}

function Parse-VersionRows {
    param([string]$Text)
    $rows=New-Object System.Collections.Generic.List[object]
    foreach($line in $Text -split "`r?`n"){
        $t=$line.Trim()
        if(-not $t -or $t.StartsWith('#')){continue}
        $m=[regex]::Match($t,'^(\S+)\s+(.+)$')
        if(-not $m.Success){$rows.Add([pscustomobject]@{Token=$t;Message='';Full=$t});continue}
        $rows.Add([pscustomobject]@{Token=$m.Groups[1].Value;Message=$m.Groups[2].Value;Full=$t})
    }
    return $rows.ToArray()
}

function Get-VersionAliases {
    param($Revisions)
    $numeric=@{}
    foreach($r in @($Revisions)){$k=([string]$r.version).ToLowerInvariant();if(-not $numeric.ContainsKey($k)){$numeric[$k]=0};$numeric[$k]++}
    $aliases=@{}
    foreach($r in @($Revisions)){
        $ver=[string]$r.version;$variant=([string]$r.variant).Trim();$keys=@()
        if($variant){$keys+=($ver+'-'+$variant);$keys+=('v'+$ver+'-'+$variant)}
        if(-not $variant -or $numeric[$ver.ToLowerInvariant()] -eq 1){$keys+=$ver;$keys+=('v'+$ver)}
        foreach($k in $keys){$lk=$k.ToLowerInvariant();if(-not $aliases.ContainsKey($lk)){$aliases[$lk]=New-Object System.Collections.Generic.List[object]};$aliases[$lk].Add($r)}
    }
    return $aliases
}

function Select-PlanVersions {
    param([string]$WorkFolder,$State,[string]$VersionsOverride)
    Write-Heading 'git_history_import - versions'
    $candidate=Read-JsonFile $State.candidatePlan
    $versionsPath=if($VersionsOverride){$VersionsOverride}else{$State.versionsFile}
    if($State.importAll){
        $rows=@($candidate.revisions|ForEach-Object{[pscustomobject]@{Token=('v'+$_.version+$(if($_.variant){'-'+$_.variant}else{''}));Message=([string]$_.subject -replace '^\S+\s*','');Full=[string]$_.subject}})
        Write-Host "--import-all: selecting all $($rows.Count) available revisions."
    }else{
        if($versionsPath){
            if(-not(Test-Path -LiteralPath $versionsPath -PathType Leaf)){throw "Versions file not found: $versionsPath"}
            Write-Host "Reading versions from: $versionsPath" -ForegroundColor Cyan
            $text=Get-Content -LiteralPath $versionsPath -Raw -Encoding UTF8
        }else{$text=Read-MultilineVersions}
        $rows=Parse-VersionRows $text
    }
    if($rows.Count -eq 0){throw 'No version/message lines were supplied.'}
    $aliases=Get-VersionAliases $candidate.revisions;$selected=New-Object System.Collections.Generic.List[object];$seen=@{};$errors=0
    Write-Host ''
    foreach($row in $rows){
        $token=$row.Token;$key=$token.ToLowerInvariant()
        if(-not $row.Message -and -not $State.importAll){Write-Host '[ERROR]' -NoNewline -ForegroundColor Red;Write-Host " $token  missing commit message";$errors++;continue}
        if(-not $aliases.ContainsKey($key)){Write-Host '[MISS]' -NoNewline -ForegroundColor Red;Write-Host "  $token  no matching source revision";$errors++;continue}
        $candidates=$aliases[$key].ToArray()
        if($candidates.Count -ne 1){Write-Host '[ERROR]' -NoNewline -ForegroundColor Red;Write-Host " $token  ambiguous: $((@($candidates|ForEach-Object{$_.archive})) -join ', ')";$errors++;continue}
        $rev=$candidates[0]
        if($seen.ContainsKey([string]$rev.archive)){Write-Host '[ERROR]' -NoNewline -ForegroundColor Red;Write-Host " $token  duplicate version selection";$errors++;continue}
        $seen[[string]$rev.archive]=$true
        Write-Host '[FOUND]' -NoNewline -ForegroundColor Green;Write-Host (' '+$token+'  ') -NoNewline -ForegroundColor Cyan;Write-Host $rev.archive
        $selected.Add([pscustomobject]@{Archive=[string]$rev.archive;Subject=[string]$row.Full})
    }
    if($errors){
        $State.phases.versions=New-PhaseRecord $false $null "$errors version-selection errors";Save-State $WorkFolder $State
        Write-Fail "VERSIONS FAIL: $errors problem(s). No import plan was activated.";return 2
    }
    $planPath=Join-Path $WorkFolder 'plan.json';$include=@($selected.ToArray()|ForEach-Object{$_.Archive})
    Write-Host '';Write-Host 'Re-inspecting only the selected revisions...' -ForegroundColor Cyan
    $rc=Inspect-Source $State.source $planPath $State.layout.value ($State.layout.mode -eq 'identity') @($State.excludePatterns) $include
    if($rc -ne 0){$State.phases.versions=New-PhaseRecord $false $planPath 'selected plan has layout ambiguity/collision';Save-State $WorkFolder $State;return $rc}
    $plan=Read-JsonFile $planPath;$by=@{};foreach($r in @($plan.revisions)){$by[[string]$r.archive]=$r}
    $ordered=New-Object System.Collections.Generic.List[object];$i=0
    foreach($s in $selected){$i++;$r=$by[$s.Archive];$r.order=$i;$r.subject=$s.Subject;$ordered.Add($r)}
    $plan.revisions=$ordered.ToArray();$plan.summary.includedRevisions=$ordered.Count
    Write-JsonFile $planPath $plan;Write-ReviewFiles $WorkFolder $plan
    $State.plan=$planPath;$State.selectedVersions=$selected.Count;$State.phases.versions=New-PhaseRecord $true $planPath "$($selected.Count) revisions selected"
    $State.phases.dryrun=$null;$State.phases.rehearse=$null;$State.phases.publish=$null;Save-State $WorkFolder $State
    Write-Host '';Write-Ok "VERSIONS PASS: $($selected.Count) revisions matched with commit messages."
    Write-InfoPair 'Commit messages:' (Join-Path $WorkFolder 'COMMIT-MESSAGES.txt') Cyan
    Write-InfoPair 'Excluded entries:' (Join-Path $WorkFolder 'EXCLUDED-ARCHIVES.txt') Cyan
    return 0
}

function Get-MoveMap {
    param($Plan)
    $m=@{}
    foreach($x in @($Plan.layout.moves)){$m[[string]$x.from]=[string]$x.to}
    return $m
}

function Get-ArchiveSnapshot {
    param([string]$Source,$Revision,$Moves,[bool]$IncludeData)
    $path=Join-Path $Source ([string]$Revision.archive)
    $actual=Get-Sha256File $path
    if($actual -cne [string]$Revision.archiveSha256){throw "Archive hash changed for $($Revision.archive): expected $($Revision.archiveSha256), got $actual"}
    $inv=Read-ZipInventory $path $IncludeData;$mapped=Map-Snapshot $inv.Files $Moves
    if($mapped.Collisions.Count){throw "Mapping collision in $($Revision.archive)"}
    $tree=Get-StableTreeHash $mapped.Files
    if($tree -cne [string]$Revision.normalizedTreeSha256){throw "Normalized tree hash changed for $($Revision.archive): expected $($Revision.normalizedTreeSha256), got $tree"}
    return $mapped.Files
}

function Format-TimeSpan {
    param([TimeSpan]$Value)
    return ('{0:D2}:{1:D2}:{2:D2}' -f [int]$Value.TotalHours,$Value.Minutes,$Value.Seconds)
}

function Get-ProgressText {
    param([Diagnostics.Stopwatch]$Watch,[int]$Done,[int]$Total)
    $elapsed=$Watch.Elapsed
    if($Done -ge $Total){return 'elapsed '+(Format-TimeSpan $elapsed)}
    $remain=[TimeSpan]::FromSeconds(($elapsed.TotalSeconds/[Math]::Max($Done,1))*($Total-$Done))
    return 'elapsed '+(Format-TimeSpan $elapsed)+'  estimated remaining '+(Format-TimeSpan $remain)
}

function New-Report {
    param([string]$Mode,[string]$Source,[string]$Plan)
    return [pscustomobject][ordered]@{schema='history-import-report/v1';mode=$Mode;createdUtc=Get-UtcText;source=$Source;plan=$Plan;revisions=(New-Object System.Collections.Generic.List[object]);ok=$false}
}

function Write-Report {
    param([string]$LogDir,$Report)
    [IO.Directory]::CreateDirectory($LogDir)|Out-Null
    Write-JsonFile (Join-Path $LogDir 'report.json') $Report
    $sb=New-Object Text.StringBuilder
    [void]$sb.AppendLine("Mode: $($Report.mode)");[void]$sb.AppendLine("Source: $($Report.source)");[void]$sb.AppendLine("Revisions: $($Report.revisions.Count)");[void]$sb.AppendLine()
    $i=0
    foreach($r in $Report.revisions){$i++;[void]$sb.AppendLine(('{0:D3} {1}  files={2} add={3} mod={4} del={5} tree={6}' -f $i,$r.archive,$r.files,$r.delta.added,$r.delta.modified,$r.delta.deleted,([string]$r.treeSha256).Substring(0,16)));[void]$sb.AppendLine('    '+$r.subject)}
    [void]$sb.AppendLine();[void]$sb.AppendLine('Result: '+$(if($Report.ok){'PASS'}else{'FAIL'}))
    if($Report.psobject.Properties['error']){[void]$sb.AppendLine('Error: '+$Report.error)}
    Write-Utf8File (Join-Path $LogDir 'report.txt') $sb.ToString()
}

function Get-SafeTargetPath {
    param([string]$Root,[string]$Relative)
    $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd('\')+'\'
    $target=[IO.Path]::GetFullPath((Join-Path $Root ($Relative.Replace('/','\'))))
    if(-not $target.StartsWith($rootFull,[StringComparison]::OrdinalIgnoreCase)){throw "Unsafe target path: $Relative"}
    return $target
}

function Apply-Snapshot {
    param([string]$Root,$Previous,$Current,$Managed,[string[]]$ReplaceUnmanaged)
    foreach($rel in $Previous.Keys){
        $p=Get-SafeTargetPath $Root $rel
        if(Test-Path -LiteralPath $p -PathType Leaf){
            if((Get-Sha256File $p) -cne [string]$Previous[$rel].sha256){throw "Managed target files changed outside replay; first mismatch: $rel"}
        }elseif($Current.ContainsKey($rel)){throw "Managed target files changed outside replay; first mismatch: $rel"}
    }
    $deleted=0
    foreach($rel in @($Previous.Keys|Where-Object{-not $Current.ContainsKey($_)}|Sort-Object -Descending)){
        $p=Get-SafeTargetPath $Root $rel
        if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Force;$deleted++}
    }
    $written=0
    foreach($rel in $Current.Keys){
        $p=Get-SafeTargetPath $Root $rel
        if((Test-Path -LiteralPath $p -PathType Leaf) -and -not $Managed.Contains($rel)){
            $existing=Get-Sha256File $p;$allow=$false
            foreach($u in $ReplaceUnmanaged){if($rel -ieq $u){$allow=$true;break}}
            if(-not $allow -and $existing -cne [string]$Current[$rel].sha256){throw "Refusing to replace unmanaged target file '$rel'."}
        }
        [IO.Directory]::CreateDirectory((Split-Path -Parent $p))|Out-Null
        [IO.File]::WriteAllBytes($p,[byte[]]$Current[$rel].data);$written++
    }
    foreach($rel in $Current.Keys){$p=Get-SafeTargetPath $Root $rel;if((Get-Sha256File $p) -cne [string]$Current[$rel].sha256){throw "Post-write byte verification failed; first mismatch: $rel"}}
    return [pscustomobject]@{written=$written;deleted=$deleted;verified=$Current.Count}
}

function Copy-Baseline {
    param([string]$Source,[string]$Destination)
    foreach($item in Get-ChildItem -LiteralPath $Source -Force){
        if($item.Name -eq '.git'){continue}
        Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
    }
}

function Install-ExactAttributes {
    param([string]$Root)
    $gd=(Invoke-Git $Root @('rev-parse','--git-dir')).Output.Trim()
    if(-not[IO.Path]::IsPathRooted($gd)){$gd=Join-Path $Root $gd}
    $p=Join-Path (Join-Path $gd 'info') 'attributes'
    $old='';if(Test-Path -LiteralPath $p){$old=Get-Content -LiteralPath $p -Raw -Encoding UTF8}
    $pattern='(?s)# history-import exact-bytes begin.*?# history-import exact-bytes end\s*'
    $old=[regex]::Replace($old,$pattern,'')
    if($old -and -not $old.EndsWith("`n")){$old+="`n"}
    Write-Utf8File $p ($old+"# history-import exact-bytes begin`n* -text`n# history-import exact-bytes end`n")
}

function Remove-ExactAttributes {
    param([string]$Root)
    try{$gd=(Invoke-Git $Root @('rev-parse','--git-dir')).Output.Trim()}catch{return}
    if(-not[IO.Path]::IsPathRooted($gd)){$gd=Join-Path $Root $gd}
    $p=Join-Path (Join-Path $gd 'info') 'attributes'
    if(-not(Test-Path -LiteralPath $p)){return}
    $old=Get-Content -LiteralPath $p -Raw -Encoding UTF8
    $new=[regex]::Replace($old,'(?s)# history-import exact-bytes begin.*?# history-import exact-bytes end\s*','')
    Write-Utf8File $p $new
}

function Get-GitBlobOid {
    param([byte[]]$Data,[string]$Algorithm)
    $head=[Text.Encoding]::ASCII.GetBytes(('blob '+$Data.Length+[char]0))
    $all=New-Object byte[] ($head.Length+$Data.Length);[Array]::Copy($head,0,$all,0,$head.Length);[Array]::Copy($Data,0,$all,$head.Length,$Data.Length)
    $h=if($Algorithm -eq 'sha256'){[Security.Cryptography.SHA256]::Create()}else{[Security.Cryptography.SHA1]::Create()}
    try{return ([BitConverter]::ToString($h.ComputeHash($all))).Replace('-','').ToLowerInvariant()}finally{$h.Dispose()}
}

function Verify-CommittedBlobs {
    param([string]$Root,$Current)
    $fmt=(Invoke-Git $Root @('config','--get','extensions.objectFormat') -AllowFailure).Output.Trim().ToLowerInvariant();$algo=if($fmt -eq 'sha256'){'sha256'}else{'sha1'}
    $r=Invoke-Git $Root @('ls-files','-s');$tree=@{}
    foreach($line in $r.Output -split "`r?`n"){if($line -match '^\d+\s+([0-9a-f]+)\s+\d+\t(.*)$'){$tree[$Matches[2].Replace('\','/')]=$Matches[1]}}
    foreach($rel in $Current.Keys){
        $expected=Get-GitBlobOid ([byte[]]$Current[$rel].data) $algo
        if(-not $tree.ContainsKey($rel) -or $tree[$rel] -cne $expected){throw "Committed blob byte verification failed: $rel"}
    }
}

function New-MessageFile {
    param([string]$LogDir,$Revision)
    $dir=Join-Path $LogDir 'messages';[IO.Directory]::CreateDirectory($dir)|Out-Null
    $safe=('{0:D3}-{1}-{2}' -f [int]$Revision.order,$Revision.version,$Revision.variant) -replace '[^A-Za-z0-9._-]+','_';$safe=$safe.Trim('_')
    $p=Join-Path $dir ($safe+'.txt');$body=@($Revision.description|ForEach-Object{([string]$_).Trim()}|Where-Object{$_})
    $text=[string]$Revision.subject+"`n";if($body.Count){$text+="`n"+(($body|ForEach-Object{'- '+$_})-join"`n")+"`n"}
    Write-Utf8File $p $text;return $p
}

function Replay-History {
    param([string]$Mode,[string]$Root,[string]$WorkFolder,$State)
    $planPath=[string]$State.plan
    if(-not $planPath -or -not(Test-Path -LiteralPath $planPath)){throw 'No activated plan. Run versions first.'}
    $plan=Read-JsonFile $planPath
    if(@($plan.layout.ambiguous).Count -or @($plan.layout.collisions).Count){throw 'Plan contains ambiguous mappings or collisions.'}
    $moves=Get-MoveMap $plan;$logDir=Join-Path (Join-Path $WorkFolder 'logs') $Mode;$report=New-Report $Mode $State.source $planPath
    if($Mode -eq 'dryrun'){
        $prev=$null;$watch=[Diagnostics.Stopwatch]::StartNew();$total=@($plan.revisions).Count;$i=0
        try{
            foreach($rev in @($plan.revisions)){
                $i++;$cur=Get-ArchiveSnapshot $State.source $rev $moves $false
                $report.revisions.Add([pscustomobject][ordered]@{order=$rev.order;archive=$rev.archive;version=$rev.version;files=$cur.Count;treeSha256=Get-StableTreeHash $cur;delta=Get-Delta $prev $cur;subject=$rev.subject})
                $prev=$cur
                Write-Host ('[{0:D2}/{1:D2}] ' -f $i,$total) -NoNewline -ForegroundColor Cyan;Write-Host ([string]$rev.version+'  ') -NoNewline -ForegroundColor Cyan;Write-Host ([string]$rev.archive+'  ') -NoNewline;Write-Host 'OK  ' -NoNewline -ForegroundColor Green;Write-Host (Get-ProgressText $watch $i $total) -ForegroundColor DarkGray
            }
            $report.ok=$true;Write-Report $logDir $report;Write-Ok "DRY RUN PASS: $($report.revisions.Count) revisions verified.";Write-InfoPair 'Logs:' $logDir Cyan;return 0
        }catch{$report.ok=$false;$report|Add-Member -NotePropertyName error -NotePropertyValue $_.Exception.Message -Force;Write-Report $logDir $report;throw}
    }
    $target=if($Mode -eq 'rehearse'){Join-Path $WorkFolder 'rehearsal-repository'}else{[string]$State.repoRoot}
    $installed=$false
    try{
        if($Mode -eq 'rehearse'){
            Remove-TreeRobust $target;[IO.Directory]::CreateDirectory($target)|Out-Null;Copy-Baseline ([string]$State.repoRoot) $target
            Invoke-Git $target @('init','-b','main')|Out-Null;Invoke-Git $target @('config','user.name','History Replay Rehearsal')|Out-Null;Invoke-Git $target @('config','user.email','rehearsal@example.invalid')|Out-Null
            Install-ExactAttributes $target;$installed=$true
            Invoke-Git $target @('-c','core.autocrlf=false','add','-A')|Out-Null
            $d=Invoke-Git $target @('diff','--cached','--quiet') -AllowFailure
            if($d.Rc -ne 0){Invoke-Git $target @('commit','-m','History replay rehearsal baseline')|Out-Null}
        }else{
            if(-not(Test-Path -LiteralPath $target -PathType Container)){throw "Publish target is not a directory: $target"}
            $st=Invoke-Git $target @('status','--porcelain')
            if($st.Output.Trim()){throw "Publish target must start clean.`n$($st.Output)"}
            Install-ExactAttributes $target;$installed=$true
        }
        $prev=[System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
        $managed=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $watch=[Diagnostics.Stopwatch]::StartNew();$total=@($plan.revisions).Count;$i=0
        foreach($rev in @($plan.revisions)){
            $i++;Write-Host ('[{0:D2}/{1:D2}] ' -f $i,$total) -NoNewline -ForegroundColor Cyan;Write-Host ([string]$rev.version+'  ') -NoNewline -ForegroundColor Cyan;Write-Host $rev.archive
            Write-Host '          commit message: ' -NoNewline -ForegroundColor Magenta;Write-Host $rev.subject -ForegroundColor White
            Write-Host '          materialize...' -ForegroundColor Cyan
            $cur=Get-ArchiveSnapshot $State.source $rev $moves $true
            $action=Apply-Snapshot $target $prev $cur $managed @($plan.policies.replaceUnmanagedPaths)
            $managed=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);foreach($k in $cur.Keys){$managed.Add($k)|Out-Null}
            $audit=Invoke-Git $target @('diff','--check') -AllowFailure;$msg=New-MessageFile $logDir $rev;$commit=''
            if($Mode -eq 'rehearse'){
                Write-Host '          stage...' -ForegroundColor Cyan;Invoke-Git $target @('-c','core.autocrlf=false','add','-A')|Out-Null
                Write-Host '          commit...' -ForegroundColor Cyan;Invoke-Git $target @('commit','-F',$msg)|Out-Null
                $commit=(Invoke-Git $target @('rev-parse','--short=12','HEAD')).Output.Trim()
                Write-Host '          verify committed blobs...' -ForegroundColor Cyan;Verify-CommittedBlobs $target $cur
                if((Invoke-Git $target @('status','--porcelain')).Output.Trim()){throw "Rehearsal worktree not clean after commit $($rev.order)."}
            }else{
                Write-Host '          publish...' -ForegroundColor Yellow
                $publisher=Join-Path $target 'just_publish.bat';if(-not(Test-Path -LiteralPath $publisher -PathType Leaf)){throw "Publisher not found: $publisher"}
                $oldExact=$env:HISTORY_IMPORT_EXACT;$env:HISTORY_IMPORT_EXACT='1'
                try{
                    $cmd='call "'+$publisher+'" historyexact yes messagefile "'+$msg+'" PUBLISH COMMIT'
                    $old=Get-Location;try{Set-Location -LiteralPath $target;& $env:ComSpec /d /s /c $cmd 2>&1 | ForEach-Object { Write-Host $_ };$rc=$LASTEXITCODE}finally{Set-Location -LiteralPath $old}
                }finally{$env:HISTORY_IMPORT_EXACT=$oldExact}
                if($rc -ne 0){throw "just_publish failed for revision $($rev.order) ($($rev.archive)) with rc=$rc"}
                $commit=(Invoke-Git $target @('rev-parse','--short=12','HEAD')).Output.Trim();Verify-CommittedBlobs $target $cur
                if((Invoke-Git $target @('status','--porcelain')).Output.Trim()){throw "Publish worktree not clean after revision $($rev.order)."}
            }
            $report.revisions.Add([pscustomobject][ordered]@{order=$rev.order;archive=$rev.archive;version=$rev.version;files=$cur.Count;treeSha256=Get-StableTreeHash $cur;delta=Get-Delta $prev $cur;subject=$rev.subject;messageFile=$msg;written=$action.written;deleted=$action.deleted;verified=$action.verified;diffCheckRc=$audit.Rc;diffCheckLines=@($audit.Output -split "`r?`n"|Where-Object{$_.Trim()}).Count;commit=$commit})
            $prev=$cur
            Write-Host '          OK ' -NoNewline -ForegroundColor Green;Write-Host 'commit=' -NoNewline -ForegroundColor DarkGray;Write-Host $commit -NoNewline -ForegroundColor Yellow;Write-Host ('  '+(Get-ProgressText $watch $i $total)) -ForegroundColor DarkGray
        }
        $report.ok=$true;Write-Report $logDir $report
    }catch{$report.ok=$false;$report|Add-Member -NotePropertyName error -NotePropertyValue $_.Exception.Message -Force;try{Write-Report $logDir $report}catch{};throw}
    finally{if($installed){Remove-ExactAttributes $target}}
    Write-Ok ($Mode.ToUpperInvariant()+" PASS: $($report.revisions.Count) revisions processed.");Write-InfoPair 'Logs:' $logDir Cyan;return 0
}


function Add-ZipFile {
    param($Archive,[string]$Source,[string]$EntryName)
    if(-not(Test-Path -LiteralPath $Source -PathType Leaf)){return}
    $entry=$Archive.CreateEntry($EntryName.Replace('\','/'),[IO.Compression.CompressionLevel]::Optimal)
    $src=[IO.File]::OpenRead($Source);$dst=$entry.Open()
    try{$src.CopyTo($dst)}finally{$dst.Dispose();$src.Dispose()}
}

function Add-ZipText {
    param($Archive,[string]$EntryName,[string]$Text)
    $entry=$Archive.CreateEntry($EntryName.Replace('\','/'),[IO.Compression.CompressionLevel]::Optimal)
    $stream=$entry.Open();$writer=[IO.StreamWriter]::new($stream,$Utf8NoBom)
    try{$writer.Write($Text)}finally{$writer.Dispose();$stream.Dispose()}
}

function Add-ZipTree {
    param($Archive,[string]$Folder,[string]$EntryRoot)
    if(-not(Test-Path -LiteralPath $Folder -PathType Container)){return}
    $base=[IO.Path]::GetFullPath($Folder).TrimEnd('\')+'\'
    foreach($f in Get-ChildItem -LiteralPath $Folder -File -Recurse -ErrorAction SilentlyContinue){
        $rel=$f.FullName.Substring($base.Length).Replace('\','/')
        Add-ZipFile $Archive $f.FullName (($EntryRoot.TrimEnd('/'))+'/'+$rel)
    }
}

function Write-LastError {
    param([string]$Root,[string]$WorkFolder,$ErrorRecord,[string[]]$CommandArgs)
    if(-not $WorkFolder){$WorkFolder=Get-DefaultWorkFolder $Root}
    [IO.Directory]::CreateDirectory($WorkFolder)|Out-Null
    $sb=New-Object Text.StringBuilder
    [void]$sb.AppendLine('git_history_import diagnostic error')
    [void]$sb.AppendLine('Tool version: '+$ToolVersion)
    [void]$sb.AppendLine('UTC: '+(Get-UtcText))
    [void]$sb.AppendLine('Repository: '+$Root)
    [void]$sb.AppendLine('Work folder: '+$WorkFolder)
    [void]$sb.AppendLine('Command arguments: '+($CommandArgs -join ' '))
    [void]$sb.AppendLine()
    [void]$sb.AppendLine($ErrorRecord.ToString())
    if($ErrorRecord.ScriptStackTrace){[void]$sb.AppendLine();[void]$sb.AppendLine('PowerShell stack:');[void]$sb.AppendLine($ErrorRecord.ScriptStackTrace)}
    Write-Utf8File (Join-Path $WorkFolder 'last-error.txt') $sb.ToString()
}

function Invoke-Logs {
    param([string]$Root,[string]$WorkOverride)
    $workFolder=Resolve-WorkFolder $Root $WorkOverride
    $projectLog=Join-Path (Join-Path $Root 'tools') 'logs'
    [IO.Directory]::CreateDirectory($projectLog)|Out-Null
    $stamp=(Get-Date).ToString('yyyy-MM-dd.HHmmss')
    $zipPath=Join-Path $projectLog ('git_history_import.'+$stamp+'.zip')
    $fs=[IO.File]::Create($zipPath)
    $archive=[IO.Compression.ZipArchive]::new($fs,[IO.Compression.ZipArchiveMode]::Create,$false)
    try{
        $summary=New-Object Text.StringBuilder
        [void]$summary.AppendLine('git_history_import diagnostic bundle')
        [void]$summary.AppendLine('Tool version: '+$ToolVersion)
        [void]$summary.AppendLine('Created: '+(Get-UtcText))
        [void]$summary.AppendLine('Repository: '+$Root)
        [void]$summary.AppendLine('Work folder: '+$workFolder)
        $gh=Get-GithubStatus $Root
        [void]$summary.AppendLine('GitHub: '+$gh.Status+$(if($gh.Account){' ('+$gh.Account+')'}else{''}))
        $origin=Invoke-Git $Root @('remote','get-url','origin') -AllowFailure
        if($origin.Rc -eq 0){[void]$summary.AppendLine('origin: '+$origin.Output.Trim())}
        Add-ZipText $archive 'diagnostic-summary.txt' $summary.ToString()
        Add-ZipFile $archive $env:rps_self 'tool/git_history_import.bat'
        foreach($name in @('git_history_import.state.json','candidate-plan.json','plan.json','EXCLUDED-ARCHIVES.txt','COMMIT-MESSAGES.txt','last-error.txt')){
            Add-ZipFile $archive (Join-Path $workFolder $name) ('work/'+$name)
        }
        Add-ZipTree $archive (Join-Path $workFolder 'logs') 'work/logs'
        Add-ZipTree $archive (Join-Path $workFolder 'messages') 'work/messages'
        $statePath=Join-Path $workFolder 'git_history_import.state.json'
        if(Test-Path -LiteralPath $statePath -PathType Leaf){
            $state=Read-JsonFile $statePath
            $companions=@()
            if($state.layout.file){$companions+=@([string]$state.layout.file)}
            if($state.excludeList){$companions+=@([string]$state.excludeList)}
            if($state.versionsFile){$companions+=@([string]$state.versionsFile)}
            foreach($p in $companions){
                if(Test-Path -LiteralPath $p -PathType Leaf){Add-ZipFile $archive $p ('companions/'+[IO.Path]::GetFileName($p))}
            }
        }
    }finally{$archive.Dispose();$fs.Dispose()}
    Write-Ok 'LOG BUNDLE CREATED'
    Write-InfoPair 'ZIP:' $zipPath Cyan
    return 0
}

function Find-Gh {
    param([string]$Root)
    $local=Join-Path (Join-Path (Join-Path $Root 'tools') 'gh\bin') 'gh.exe'
    if(Test-Path -LiteralPath $local -PathType Leaf){return $local}
    $c=Get-Command gh.exe -ErrorAction SilentlyContinue;if($c){return $c.Source}
    return $null
}

function Get-GithubStatus {
    param([string]$Root)
    $gh=Find-Gh $Root;if(-not $gh){return [pscustomobject]@{Status='unavailable';Account='GitHub CLI not found'}}
    $s=Invoke-Captured $gh @('auth','status','-h','github.com') $Root
    if($s.Rc -ne 0){return [pscustomobject]@{Status='logged out';Account=''}}
    $u=Invoke-Captured $gh @('api','user','--jq','.login') $Root
    return [pscustomobject]@{Status='logged in';Account=$(if($u.Rc -eq 0){$u.Output.Trim()}else{'authenticated'})}
}

function Get-GithubRepoFromOrigin {
    param([string]$Origin)
    $m=[regex]::Match($Origin,'(?i)github\.com[:/](?<repo>[^/]+/[^/]+?)(?:\.git)?$')
    if($m.Success){return $m.Groups['repo'].Value}
    return $null
}

function Test-GithubPushPermission {
    param([string]$Root,[string]$Origin)
    $repo=Get-GithubRepoFromOrigin $Origin;if(-not $repo){return [pscustomobject]@{Known=$false;Allowed=$false;Detail='origin is not a recognized GitHub URL'}}
    $gh=Find-Gh $Root;if(-not $gh){return [pscustomobject]@{Known=$false;Allowed=$false;Detail='GitHub CLI not found'}}
    $r=Invoke-Captured $gh @('api',('repos/'+$repo),'--jq','.permissions.push') $Root
    if($r.Rc -ne 0){return [pscustomobject]@{Known=$false;Allowed=$false;Detail=$r.Output.Trim()}}
    $v=$r.Output.Trim().ToLowerInvariant()
    if($v -eq 'true'){return [pscustomobject]@{Known=$true;Allowed=$true;Detail=$repo}}
    if($v -eq 'false'){return [pscustomobject]@{Known=$true;Allowed=$false;Detail=$repo}}
    return [pscustomobject]@{Known=$false;Allowed=$false;Detail=('unexpected permission response: '+$r.Output.Trim())}
}

function Phase-Passed {
    param($State,[string]$Name)
    $p=$State.phases.$Name
    return ($null -ne $p -and [bool]$p.ok)
}

function Invoke-ReplayAction {
    param([string]$Mode,[string]$Root,[string]$WorkFolder,$State)
    if($Mode -eq 'publish'){
        if(-not(Phase-Passed $State 'dryrun')){throw 'Publish is blocked until dryrun has passed.'}
        if(-not(Phase-Passed $State 'rehearse')){throw 'Publish is blocked until rehearsal has passed.'}
        $st=Invoke-Git $Root @('status','--porcelain')
        if($st.Output.Trim()){throw "Live repository must be clean before publish.`n$($st.Output)"}
        $o=Invoke-Git $Root @('remote','get-url','origin') -AllowFailure
        if($o.Rc -ne 0 -or -not $o.Output.Trim()){throw 'Publish target has no origin remote.'}
        $origin=$o.Output.Trim();$ghs=Get-GithubStatus $Root
        if($ghs.Status -ne 'logged in'){throw 'GitHub login is required before publish.'}
        $perm=Test-GithubPushPermission $Root $origin
        if(-not $perm.Known){throw "Could not verify GitHub push permission before publish.`norigin: $origin`ndetail: $($perm.Detail)"}
        if(-not $perm.Allowed){throw "Authenticated GitHub account '$($ghs.Account)' does not have push permission to $($perm.Detail)."}
        Write-Host '';Write-Host 'LIVE PUBLICATION' -ForegroundColor Red
        Write-InfoPair 'Repository:' $Root Yellow;Write-InfoPair 'origin:' $origin Yellow;Write-InfoPair 'GitHub:' ($ghs.Status+' ('+$ghs.Account+')') Green;Write-InfoPair 'Revisions:' ([string]$State.selectedVersions) Cyan
        Write-Warn 'Review the origin above carefully. This operation creates and pushes commits.'
        if(-not(Read-YesNo 'Publish now' $false)){Write-Warn 'Publication cancelled.';return 0}
    }
    $rc=Replay-History $Mode $Root $WorkFolder $State
    $report=Join-Path (Join-Path (Join-Path $WorkFolder 'logs') $Mode) 'report.json'
    $State.phases.$Mode=New-PhaseRecord ($rc -eq 0) $(if(Test-Path -LiteralPath $report){$report}else{$null}) ''
    Save-State $WorkFolder $State
    return $rc
}

function Invoke-Setup {
    param([string]$Root,$Options)
    Write-Heading "git_history_import $ToolVersion - setup"
    $wf=Get-Option $Options 'work-folder';if($wf){$wf=[IO.Path]::GetFullPath($wf)}else{$wf=Get-DefaultWorkFolder $Root}
    $script:CurrentWorkFolder=$wf
    $source=Get-Option $Options 'source';if(-not $source){$source=Read-Host 'Folder or compressed ZIP containing the history revisions'}
    if(-not $source){throw 'A source folder or ZIP is required.'};$source=[IO.Path]::GetFullPath($source);if(-not(Test-Path -LiteralPath $source)){throw "Source does not exist: $source"}
    $layoutInput=Get-Option $Options 'layout';$layout=$null;$layoutFile=$null;$identity=$false
    if($null -eq $layoutInput){
        $autoLayout=Get-CompanionFile $source 'layout'
        if($autoLayout){Write-AutoCompanion 'layout' $autoLayout;$layoutFile=$autoLayout.Path;$layout=Read-LayoutReferenceFile $layoutFile}
        elseif(Read-YesNo 'Use a final reference layout' $false){$layoutInput=Read-Host 'Reference layout folder/ZIP, source archive name, or .layout.txt file';if(-not $layoutInput){throw 'A layout reference was requested but not supplied.'};$layout=Resolve-LayoutValue $layoutInput ([ref]$layoutFile)}
        else{$identity=$true}
    }else{$layout=Resolve-LayoutValue $layoutInput ([ref]$layoutFile)}
    $exclude=Get-Option $Options 'exclude-list'
    if(-not $exclude){
        $autoExclude=Get-CompanionFile $source 'exclude'
        if($autoExclude){Write-AutoCompanion 'exclude list' $autoExclude;$exclude=$autoExclude.Path}
        else{$x=Read-Host 'Exclude-list file (optional; blank for none)';if($x){$exclude=$x}}
    }
    $patterns=@()
    if($exclude){$exclude=[IO.Path]::GetFullPath($exclude);if(-not(Test-Path -LiteralPath $exclude -PathType Leaf)){throw "Exclude-list file not found: $exclude"};$patterns=Read-ListFile $exclude}
    $importAll=$Options.ContainsKey('import-all')
    $versions=Get-Option $Options 'versions'
    if(-not $versions -and -not $importAll){
        $autoVersions=Get-CompanionFile $source 'versions'
        if($autoVersions){Write-AutoCompanion 'versions' $autoVersions;$versions=$autoVersions.Path}
    }
    if($versions){$versions=[IO.Path]::GetFullPath($versions);if(-not(Test-Path -LiteralPath $versions -PathType Leaf)){throw "Versions file not found: $versions"}}
    if($importAll -and $versions){throw '--import-all and --versions are mutually exclusive.'}
    [IO.Directory]::CreateDirectory($wf)|Out-Null;Ensure-LocalIgnore $Root $wf
    $prep=Prepare-Source $source $wf;$engineSource=$prep.Source
    if($layout -and $prep.Aliases.ContainsKey($layout)){$layout=$prep.Aliases[$layout]}
    $mappedPatterns=@();foreach($p in $patterns){if($prep.Aliases.ContainsKey($p)){$mappedPatterns+=$prep.Aliases[$p]}else{$mappedPatterns+=$p}}
    $candidate=Join-Path $wf 'candidate-plan.json'
    Write-InfoPair 'Repository:' $Root Cyan;Write-InfoPair 'Work folder:' $wf Cyan;Write-InfoPair 'Source:' $source Cyan
    if($engineSource -cne $source){Write-InfoPair 'Engine source:' $engineSource DarkGray}
    foreach($n in @($prep.Notes)){Write-Host ('  '+$n) -ForegroundColor DarkGray}
    Write-InfoPair 'Layout:' $(if($layout){$layout}else{'none (identity layout)'}) Cyan
    if($layoutFile){Write-InfoPair 'Layout file:' $layoutFile Cyan}
    Write-InfoPair 'Exclude list:' $(if($exclude){$exclude}else{'none'}) Cyan
    Write-InfoPair 'Import all:' $(if($importAll){'yes'}else{'no'}) Cyan
    Write-Host '';Write-Host 'Inspecting source...' -ForegroundColor Cyan
    $rc=Inspect-Source $engineSource $candidate $layout $identity $mappedPatterns @()
    if($rc -notin @(0,3)){return $rc}
    $plan=Read-JsonFile $candidate
    $state=[pscustomobject][ordered]@{
        schema=$StateSchema;toolVersion=$ToolVersion;createdUtc=Get-UtcText;repoRoot=$Root;workFolder=$wf
        source=$engineSource;sourceOriginal=$source;layout=[pscustomobject]@{mode=$(if($identity){'identity'}else{'reference'});value=$layout;file=$layoutFile}
        excludeList=$exclude;excludePatterns=@($mappedPatterns);versionsFile=$versions;importAll=$importAll;candidatePlan=$candidate;plan=$null;selectedVersions=0
        phases=[pscustomobject]@{setup=New-PhaseRecord $true $candidate 'candidate source/layout inspection complete';versions=$null;dryrun=$null;rehearse=$null;publish=$null}
    }
    Save-State $wf $state;Set-WorkPointer $Root $wf;Write-ReviewFiles $wf $plan
    Write-Host '';Write-Ok 'SETUP PASS';Write-InfoPair 'Discovered:' ([string]$plan.summary.discoveredArchives) Cyan;Write-InfoPair 'Available:' ([string]$plan.summary.includedRevisions) Green;Write-InfoPair 'Excluded:' ([string]$plan.summary.excludedArchives) Yellow
    if($mappedPatterns.Count){
        $names=@(Get-ChildItem -LiteralPath $engineSource -Filter *.zip -File|ForEach-Object{$_.Name});$matched=0;$absent=@()
        foreach($p in $mappedPatterns){if(@($names|Where-Object{$_ -like $p}).Count){$matched++}else{$absent+=$p}}
        Write-Host "Exclude rules: $($mappedPatterns.Count) configured, $matched matched, $($absent.Count) absent"
        foreach($p in $absent){Write-Warn "  [ABSENT] $p"}
    }
    if(Read-YesNo 'Run tools\git_history_import versions now' $true){
        $rc=Select-PlanVersions $wf $state $versions;if($rc){return $rc}
        return (Invoke-GuidedRemainder $Root $wf $state)
    }
    Write-Host '';Write-Host 'When ready: tools\git_history_import versions'
    return 0
}

function Invoke-GuidedRemainder {
    param([string]$Root,[string]$WorkFolder,$State)
    $choice=Read-RunStopSkip 'Run dryrun now'
    if($choice -eq 'run'){$rc=Invoke-ReplayAction 'dryrun' $Root $WorkFolder $State;if($rc){return $rc}}
    elseif($choice -eq 'stop'){Write-Warn 'Stopped before dryrun.';Write-Host 'When ready: tools\git_history_import dryrun';return 0}
    else{Write-Warn ('[SKIP] dryrun - '+$(if(Phase-Passed $State 'dryrun'){'previous PASS retained'}else{'not run; publish remains blocked'}))}
    $choice=Read-RunStopSkip 'Run rehearsal now'
    if($choice -eq 'run'){$rc=Invoke-ReplayAction 'rehearse' $Root $WorkFolder $State;if($rc){return $rc}}
    elseif($choice -eq 'stop'){Write-Warn 'Stopped before rehearsal.';Write-Host 'When ready: tools\git_history_import rehearse';return 0}
    else{Write-Warn ('[SKIP] rehearsal - '+$(if(Phase-Passed $State 'rehearse'){'previous PASS retained'}else{'not run; publish remains blocked'}))}
    if(-not(Phase-Passed $State 'dryrun') -or -not(Phase-Passed $State 'rehearse')){Write-Warn 'Publish is not offered because dryrun and rehearsal have not both passed.';return 0}
    if(Read-YesNo 'Publish now' $false){return (Invoke-ReplayAction 'publish' $Root $WorkFolder $State)}
    Write-Host '';Write-Host 'When ready: tools\git_history_import publish';return 0
}

function Invoke-Status {
    param([string]$Root,[string]$WorkOverride)
    $loaded=Load-State $Root $WorkOverride -Optional;Write-Heading "git_history_import $ToolVersion - status"
    Write-InfoPair 'Repository:' $Root Cyan;Write-InfoPair 'Work folder:' $loaded.WorkFolder Cyan
    $gh=Get-GithubStatus $Root;Write-InfoPair 'GitHub:' ($gh.Status+$(if($gh.Account){' ('+$gh.Account+')'}else{''})) $(if($gh.Status -eq 'logged in'){'Green'}else{'Yellow'})
    $origin=Invoke-Git $Root @('remote','get-url','origin') -AllowFailure;if($origin.Rc -eq 0){Write-InfoPair 'origin:' $origin.Output.Trim() Cyan}
    if($null -eq $loaded.State){Write-Warn 'Setup: NOT CONFIGURED';Write-Host 'Run: tools\git_history_import setup';return 0}
    $s=$loaded.State;Write-Host '';Write-InfoPair 'Source:' ([string]$s.sourceOriginal) Cyan;Write-InfoPair 'Layout:' $(if($s.layout.value){[string]$s.layout.value}else{'none (identity layout)'}) Cyan
    if($s.layout.file){Write-InfoPair 'Layout file:' ([string]$s.layout.file) Cyan}
    if($s.excludeList){Write-InfoPair 'Exclude list:' ([string]$s.excludeList) Cyan}
    if($s.versionsFile){Write-InfoPair 'Versions file:' ([string]$s.versionsFile) Cyan}
    Write-InfoPair 'Selected:' ([string]$s.selectedVersions+' revision(s)') Cyan
    Write-Host '';Write-Host 'Phases:' -ForegroundColor Cyan
    foreach($name in @('setup','versions','dryrun','rehearse','publish')){$p=$s.phases.$name;$mark=if($null -eq $p){'NOT RUN'}elseif($p.ok){'PASS'}else{'FAIL'};$color=if($mark -eq 'PASS'){'Green'}elseif($mark -eq 'FAIL'){'Red'}else{'Yellow'};Write-Host ('  '+$name.PadRight(10)) -NoNewline;Write-Host $mark -ForegroundColor $color}
    return 0
}

function Invoke-Reset {
    param([string]$Root,[string]$WorkOverride)
    $loaded=Load-State $Root $WorkOverride -Optional;Write-Heading 'git_history_import - reset'
    if($null -eq $loaded.State){Write-Host 'Nothing to reset.';Clear-WorkPointer $Root;return 0}
    Write-Warn "This will delete history-import working state:`n  $($loaded.WorkFolder)"
    if(-not(Read-YesNo 'Reset and start over' $false)){Write-Warn 'Reset cancelled.';return 0}
    Remove-TreeRobust $loaded.WorkFolder;Clear-WorkPointer $Root;Write-Ok 'RESET COMPLETE';return 0
}

function Invoke-Relogin {
    param([string]$Root)
    Write-Heading 'git_history_import - GitHub relogin'
    $gh=Find-Gh $Root;if(-not $gh){throw 'GitHub CLI was not found.'}
    $status=Get-GithubStatus $Root
    if($status.Status -eq 'logged in'){
        $ghArgs=@('auth','logout','-h','github.com');if($status.Account -and $status.Account -ne 'authenticated'){$ghArgs+=@('-u',$status.Account)}
        $r=Invoke-Captured $gh $ghArgs $Root;if($r.Rc -ne 0){throw "GitHub logout failed.`n$($r.Output)"}
    }
    $login=Join-Path $Root 'just_login.bat'
    if(Test-Path -LiteralPath $login -PathType Leaf){$cmd='call "'+$login+'" authenticate';$old=Get-Location;try{Set-Location -LiteralPath $Root;& $env:ComSpec /d /s /c $cmd 2>&1 | ForEach-Object { Write-Host $_ };$rc=$LASTEXITCODE}finally{Set-Location -LiteralPath $old}}
    else{$r=Invoke-Captured $gh @('auth','login','-h','github.com','-p','https','-w') $Root;$rc=$r.Rc}
    if($rc -ne 0){throw 'GitHub login failed.'}
    $status=Get-GithubStatus $Root;Write-InfoPair 'GitHub:' ($status.Status+' ('+$status.Account+')') Green;return 0
}

function Show-Help {
    Write-Host "git_history_import $ToolVersion" -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Reconstruct and publish Git history from complete archived project revisions.'
    Write-Host ''
    Write-Host 'USAGE' -ForegroundColor Cyan
    Write-Host '  tools\git_history_import SOURCE [options]'
    Write-Host '  tools\git_history_import setup [SOURCE] [options]'
    Write-Host '  tools\git_history_import versions [--versions FILE]'
    Write-Host '  tools\git_history_import inspect'
    Write-Host '  tools\git_history_import dryrun'
    Write-Host '  tools\git_history_import rehearse [--work-folder FOLDER]'
    Write-Host '  tools\git_history_import publish'
    Write-Host '  tools\git_history_import status'
    Write-Host '  tools\git_history_import reset'
    Write-Host '  tools\git_history_import relogin'
    Write-Host '  tools\git_history_import logs [--work-folder FOLDER]'
    Write-Host ''
    Write-Host 'SETUP OPTIONS' -ForegroundColor Cyan
    Write-Host '  --source PATH         Folder of version ZIPs/folders or outer ZIP containing them.'
    Write-Host '  --layout PATH|NAME   Canonical layout folder/ZIP, source revision name, or .layout.txt file.'
    Write-Host '  --versions FILE      Version/message list.'
    Write-Host '  --exclude-list FILE  Source-entry names/globs to exclude, one per line.'
    Write-Host '  --work-folder PATH   Local state/log/rehearsal folder.'
    Write-Host '  --import-all         Select all non-excluded revisions.'
    Write-Host ''
    Write-Host 'COMPANION DISCOVERY' -ForegroundColor Cyan
    Write-Host '  File source Project.zip prefers Project.zip.layout.txt, .exclude.txt, and .versions.txt.'
    Write-Host '  Folder source Project prefers Project\Project.layout.txt, .exclude.txt, and .versions.txt.'
    Write-Host '  Sibling folder companions and a unique matching *.TYPE.txt are accepted as fallbacks.'
    Write-Host '  Explicit --layout, --exclude-list, and --versions options always win.'
    Write-Host ''
    Write-Host 'WORKFLOW' -ForegroundColor Cyan
    Write-Host '  setup -> versions -> dryrun -> rehearse -> publish'
    Write-Host '  Guided dryrun/rehearse prompts accept Y=run, n=stop, s=skip.'
    Write-Host '  dryrun changes no repository.'
    Write-Host '  rehearse commits into a disposable local repository.'
    Write-Host '  publish modifies the live repository and pushes.' -ForegroundColor Yellow
    Write-Host '  logs creates a diagnostic ZIP under tools\logs.'
    Write-Host ''
    Write-Host 'EXAMPLES' -ForegroundColor Cyan
    Write-Host '  tools\git_history_import "D:\history\Project.zip"'
    Write-Host '  tools\git_history_import "D:\history\Project"'
    Write-Host '  tools\git_history_import setup "D:\history\Project.zip"'
    Write-Host '  tools\git_history_import setup --source "D:\history\Project.zip" --layout "Project-1.2.0.zip" --exclude-list "D:\history\Project.zip.exclude.txt" --versions "D:\history\Project.zip.versions.txt"'
    Write-Host ''
    Write-Host 'This tool has no Python dependency. ZIP/JSON/hash operations use Windows PowerShell/.NET.'
}

function Invoke-InspectAction {
    param([string]$Root,[string]$WorkOverride)
    $loaded=Load-State $Root $WorkOverride;$s=$loaded.State;$out=Join-Path $loaded.WorkFolder 'candidate-plan.json'
    return (Inspect-Source $s.source $out $s.layout.value ($s.layout.mode -eq 'identity') @($s.excludePatterns) @())
}

function Main {
    param([string[]]$CommandArgs)
    if($CommandArgs.Count -eq 0 -or $CommandArgs[0] -in @('/?','/h','-?','-h','--help')){Show-Help;return 0}
    $root=Get-RepositoryRoot
    $script:CurrentRoot=$root
    $known=@('setup','versions','inspect','dryrun','rehearse','publish','status','reset','relogin','logs')
    $first=$CommandArgs[0]
    if($first.ToLowerInvariant() -notin $known){
        if(-not(Test-Path -LiteralPath $first)){Write-Fail "Source not found: $first";return 2}
        $opts=Parse-Options $CommandArgs 1
        if($opts.ContainsKey('source')){throw 'Do not combine positional SOURCE with --source.'}
        $opts['source']=$first
        return (Invoke-Setup $root $opts)
    }
    $cmd=$first.ToLowerInvariant()
    if($cmd -eq 'setup' -and $CommandArgs.Count -gt 1 -and -not $CommandArgs[1].StartsWith('--')){
        $sourceArg=$CommandArgs[1]
        if(-not(Test-Path -LiteralPath $sourceArg)){Write-Fail "Source not found: $sourceArg";return 2}
        $opts=Parse-Options $CommandArgs 2
        if($opts.ContainsKey('source')){throw 'Do not combine positional SOURCE with --source.'}
        $opts['source']=$sourceArg
    } else {
        $opts=Parse-Options $CommandArgs 1
    }
    switch($cmd){
        'setup' { return (Invoke-Setup $root $opts) }
        'versions' {
            $loaded=Load-State $root (Get-Option $opts 'work-folder');$rc=Select-PlanVersions $loaded.WorkFolder $loaded.State (Get-Option $opts 'versions');if($rc){return $rc};return (Invoke-GuidedRemainder $root $loaded.WorkFolder $loaded.State)
        }
        'inspect' { return (Invoke-InspectAction $root (Get-Option $opts 'work-folder')) }
        'dryrun' { $l=Load-State $root (Get-Option $opts 'work-folder');return (Invoke-ReplayAction 'dryrun' $root $l.WorkFolder $l.State) }
        'rehearse' { $l=Load-State $root (Get-Option $opts 'work-folder');return (Invoke-ReplayAction 'rehearse' $root $l.WorkFolder $l.State) }
        'publish' { $l=Load-State $root (Get-Option $opts 'work-folder');return (Invoke-ReplayAction 'publish' $root $l.WorkFolder $l.State) }
        'status' { return (Invoke-Status $root (Get-Option $opts 'work-folder')) }
        'reset' { return (Invoke-Reset $root (Get-Option $opts 'work-folder')) }
        'relogin' { return (Invoke-Relogin $root) }
        'logs' { return (Invoke-Logs $root (Get-Option $opts 'work-folder')) }
        default { Write-Fail "Unknown command: $cmd";Show-Help;return 2 }
    }
}

try {
    $rc=Main $CliArgs
    exit [int]$rc
} catch {
    Write-Host ''
    Write-Fail ('ERROR: '+$_.Exception.Message)
    try{
        $diagRoot=if($script:CurrentRoot){$script:CurrentRoot}else{Get-RepositoryRoot}
        $diagWork=if($script:CurrentWorkFolder){$script:CurrentWorkFolder}else{Resolve-WorkFolder $diagRoot $null}
        Write-LastError $diagRoot $diagWork $_ $CliArgs
        Write-Host ('Diagnostic: '+(Join-Path $diagWork 'last-error.txt')) -ForegroundColor DarkGray
        Write-Host 'Run: tools\git_history_import logs' -ForegroundColor Yellow
    }catch{}
    exit 1
}
:_GitHistoryImport_end
