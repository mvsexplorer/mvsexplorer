@echo off
:setup
REM Generated internal create/update component. It is standalone but orchestrated by create_or_update_mvs_database.bat.
setlocal DisableDelayedExpansion
set "app.version=0.2.3"
set "app.name=04_rebuild_family_index"
set "app.rc=0"
set "app.self=%~f0"
set "mvsdbm_arg1=%~1"
set "mvsdbm_arg2=%~2"
set "mvsdbm_arg3=%~3"
set "mvsdbm_arg4=%~4"
set "mvsdbm_arg5=%~5"
set "mvsdbm_arg6=%~6"
set "mvsdbm_arg7=%~7"
set "mvsdbm_arg8=%~8"
set "mvsdbm_version=%app.version%"
set "mvsdbm_project_version=0.21.1"
:main
set "RunPowerShellFromLabel.function=MVSDatabaseMaintenance"
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

:_MVSDatabaseMaintenance_start
$ErrorActionPreference='Stop'
$utf8=New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8
$ProjectRoot=[IO.Path]::GetFullPath([string]$env:mvsdbm_arg1)
$ArchiveRoot=[IO.Path]::GetFullPath([string]$env:mvsdbm_arg2)
$DatabaseRoot=[IO.Path]::GetFullPath([string]$env:mvsdbm_arg3)
$SlotRoot=[IO.Path]::GetFullPath([string]$env:mvsdbm_arg4)
$RunId=[string]$env:mvsdbm_arg5
$WorkerSpec=[string]$env:mvsdbm_arg6
$LogicalCores=[Math]::Max(1,[Environment]::ProcessorCount)
$WorkerStart=[Math]::Max(1,[int][Math]::Ceiling($LogicalCores/4.0))
$WorkerMax=$LogicalCores
$WorkerMode='adaptive'
if($WorkerSpec -match '^fixed:(?<n>\d+)$'){
    $WorkerStart=[int]$Matches.n;$WorkerMax=$WorkerStart;$WorkerMode='fixed'
}elseif($WorkerSpec -match '^adaptive:(?<start>\d+):(?<max>\d+)$'){
    $WorkerStart=[int]$Matches.start;$WorkerMax=[int]$Matches.max;$WorkerMode='adaptive'
}else{
    $legacy=0
    if([int]::TryParse($WorkerSpec,[ref]$legacy) -and $legacy -gt 0){$WorkerStart=$legacy;$WorkerMax=$legacy;$WorkerMode='fixed'}
}
if($WorkerStart -lt 1 -or $WorkerMax -lt 1 -or $WorkerStart -gt $WorkerMax){throw ('Invalid worker specification: '+$WorkerSpec)}
$RunLogs=[IO.Path]::GetFullPath([string]$env:mvsdbm_arg7)
$Extra=[string]$env:mvsdbm_arg8
$ToolVersion=[string]$env:mvsdbm_version
$Version=[string]$env:mvsdbm_project_version
$KnownSources=@('mvs.txt','mvs_ids.txt','mvs_dates.txt','mvs_names.txt','mvs_notes.html','mvs.sha1','mvs.sha256')
$SnapshotPattern='^mvs_\d{4}-\d{2}-\d{2}(?:-\d{4})?(?:_\d+)?$'
$Tab=[char]9
$US=[char]31

function Write-Line { param([AllowEmptyString()][string]$Text) [Console]::Out.WriteLine($Text) }
function Write-Err { param([AllowEmptyString()][string]$Text) [Console]::Error.WriteLine($Text) }
function Fail { param([int]$Code,[string]$Message) Write-Err ('ERROR: '+$Message); [Environment]::Exit($Code) }
function Ensure-Directory { param([string]$Path) if(   -not   (Test-Path -LiteralPath $Path -PathType Container)){[void](New-Item -ItemType Directory -Path $Path -Force)} }
function Write-Utf8 { param([string]$Path,[AllowEmptyString()][string]$Text) [IO.File]::WriteAllText($Path,$Text,$utf8) }
function Get-Sha256File {
    param([string]$Path)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{
        $stream=New-Object IO.FileStream($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        try{return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}finally{$stream.Dispose()}
    }finally{$sha.Dispose()}
}
function Get-Sha256Text {
    param([AllowEmptyString()][string]$Text)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($Text)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Resolve-SnapshotDataPath {
    param([string]$SnapshotPath)
    foreach($name in $KnownSources){if(Test-Path -LiteralPath (Join-Path $SnapshotPath $name) -PathType Leaf){return $SnapshotPath}}
    $nested=Join-Path $SnapshotPath 'mvs_dmp'
    if(Test-Path -LiteralPath $nested -PathType Container){
        foreach($name in $KnownSources){if(Test-Path -LiteralPath (Join-Path $nested $name) -PathType Leaf){return $nested}}
    }
    return $SnapshotPath
}
function Get-SnapshotDirectories {
    param([string]$Root)
    return @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction Stop|Where-Object{$_.Name  -match  $SnapshotPattern}|Sort-Object Name)
}
function Get-SnapshotFingerprint {
    param([string]$SnapshotPath)
    $data=Resolve-SnapshotDataPath $SnapshotPath
    $parts=New-Object System.Collections.ArrayList
    $present=0
    foreach($name in $KnownSources){
        $path=Join-Path $data $name
        if(Test-Path -LiteralPath $path -PathType Leaf){
            $present++
            [void]$parts.Add(($name+'='+((Get-Sha256File $path))))
        }else{[void]$parts.Add(($name+'=MISSING'))}
    }
    $text=($parts -join "`n")+"`n"
    return [pscustomobject]@{fingerprint=(Get-Sha256Text $text);file_count=$present;data_path=$data}
}
function Get-ToolsetFingerprint {
    param([string]$Root)
    $paths=New-Object System.Collections.ArrayList
    $tools=Join-Path $Root 'tools'
    foreach($file in @(Get-ChildItem -LiteralPath $tools -File -Filter '*.bat' -ErrorAction Stop|Sort-Object Name)){
        if($file.Name  -match  '^(?:print_mvs_dump_|read_mvs_dump_|lookup_mvs_|find_mvs_|compare_mvs_dump_|build_mvs_dump_)'){
            [void]$paths.Add($file)
        }
    }
    # The archive sweep orchestrator itself is deliberately excluded: scheduling,
    # progress text, and worker-policy changes do not change logical result semantics.
    foreach($relative in @('test\fast\run_snapshot_tools_fast.bat','test\fast\run_compare_tools_fast.bat','test\fast\run_archive_tools_fast.bat')){
        $path=Join-Path $Root $relative
        if(Test-Path -LiteralPath $path -PathType Leaf){[void]$paths.Add((Get-Item -LiteralPath $path))}
    }
    $rows=New-Object System.Collections.ArrayList
    foreach($file in @($paths|Sort-Object FullName)){
        $relative=$file.FullName.Substring($Root.TrimEnd('\').Length).TrimStart('\').Replace('\','/')
        [void]$rows.Add(($relative+'='+(Get-Sha256File $file.FullName)))
    }
    return Get-Sha256Text (($rows -join "`n")+"`n")
}
function Test-LegacyToolsetCompatibility {
    param([string]$OldFingerprint,[string]$NewFingerprint)
    # 0.19.2/0.19.3 used a v1 aggregate that also hashed test_all_dumps.bat.
    # Its processing workers and public result-producing tools are byte-identical
    # to the v2 semantic fingerprint below, so this one-time migration is safe.
    $legacyV1='0e4b3684c228141691369687dca9fba6d9a4abcfd8170e81650f056aaeb2a4ee'
    $semanticV2='f6cda38a68f276386a136cd43518c67f917732405875b8148c0611d255784bde'
    return [StringComparer]::Ordinal.Equals($OldFingerprint,$legacyV1) -and [StringComparer]::Ordinal.Equals($NewFingerprint,$semanticV2)
}

function Plan-Key {
    param([object]$Row)
    return @([string]$Row.scope,[string]$Row.snapshot,[string]$Row.next_snapshot,[string]$Row.tool,[string]$Row.search_source,[string]$Row.search_value,[string]$Row.search_origin)-join$US
}
function New-OrdinalObjectDictionary { return ,(New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)) }
function New-IgnoreCaseObjectDictionary { return ,(New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase)) }
function New-IgnoreCaseStringSet { return ,(New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)) }
function Convert-TsvField {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if($null  -eq  $Value){return ''}
    return $Value.Replace("`t",' ').Replace("`r",' ').Replace("`n",' ')
}
function Invoke-BatChecked {
    param([string]$Path,[string[]]$Arguments,[string]$Description)
    if(   -not   (Test-Path -LiteralPath $Path -PathType Leaf)){throw ('Missing '+$Description+': '+$Path)}
    & $Path @Arguments
    $rc=$LASTEXITCODE
    if($rc  -ne   0){throw ($Description+' failed with rc='+$rc)}
}
function Swap-Directory {
    param([string]$Staging,[string]$Current)
    if(   -not   (Test-Path -LiteralPath $Staging -PathType Container)){throw ('Staging directory missing: '+$Staging)}
    $previous=$Current+'.previous'
    if(Test-Path -LiteralPath $previous){Remove-Item -LiteralPath $previous -Recurse -Force}
    if(Test-Path -LiteralPath $Current -PathType Container){Move-Item -LiteralPath $Current -Destination $previous}
    try{
        Move-Item -LiteralPath $Staging -Destination $Current
        if(Test-Path -LiteralPath $previous){Remove-Item -LiteralPath $previous -Recurse -Force}
    }catch{
        if((   -not   (Test-Path -LiteralPath $Current))    -and    (Test-Path -LiteralPath $previous)){Move-Item -LiteralPath $previous -Destination $Current}
        throw
    }
}
function Copy-TreeHardLinkOrCopy {
    param([string]$Source,[string]$Destination)
    if(   -not   (Test-Path -LiteralPath $Source -PathType Container)){return}
    Ensure-Directory $Destination
    $prefix=$Source.TrimEnd('\').Length
    foreach($dir in @(Get-ChildItem -LiteralPath $Source -Directory -Recurse -ErrorAction Stop)){
        $rel=$dir.FullName.Substring($prefix).TrimStart('\')
        Ensure-Directory (Join-Path $Destination $rel)
    }
    foreach($file in @(Get-ChildItem -LiteralPath $Source -File -Recurse -ErrorAction Stop)){
        $rel=$file.FullName.Substring($prefix).TrimStart('\')
        $target=Join-Path $Destination $rel
        Ensure-Directory (Split-Path -Parent $target)
        try{[void](New-Item -ItemType HardLink -Path $target -Target $file.FullName -ErrorAction Stop)}
        catch{Copy-Item -LiteralPath $file.FullName -Destination $target -Force}
    }
}

$archiveAnalysis=Join-Path $SlotRoot 'archive-analysis'
if(   -not   (Test-Path -LiteralPath $archiveAnalysis -PathType Container)){throw 'Committed archive analysis is missing.'}
$tool=Join-Path $ProjectRoot 'tools\build_mvs_product_family_index.bat'
$toolHash=Get-Sha256File $tool
$hashPath=Join-Path $SlotRoot 'family-toolset-sha256.txt'
$oldHash=if(Test-Path -LiteralPath $hashPath -PathType Leaf){([IO.File]::ReadAllText($hashPath)).Trim()}else{''}
$current=Join-Path $SlotRoot 'family-index'
$statePath=Join-Path $archiveAnalysis 'update-state.json'
$pending=1
if(Test-Path -LiteralPath $statePath -PathType Leaf){$pending=[int](ConvertFrom-Json ([IO.File]::ReadAllText($statePath))).pending_checks}
$need=($pending -gt 0)   -or   (   -not   (Test-Path -LiteralPath $current -PathType Container))   -or   (   -not   [StringComparer]::Ordinal.Equals($oldHash,$toolHash))
$marker=Join-Path $SlotRoot ('family-rebuilt-'+$RunId+'.flag')
if(Test-Path -LiteralPath $marker){Remove-Item -LiteralPath $marker -Force}
if(   -not   $need){
    Write-Line 'Already done: full product-family database is current.'
    [Environment]::Exit(0)
}
$staging=Join-Path $SlotRoot ('family-index.staging-'+$RunId)
foreach($oldStage in @(Get-ChildItem -LiteralPath $SlotRoot -Directory -Filter 'family-index.staging-*' -ErrorAction SilentlyContinue)){Remove-Item -LiteralPath $oldStage.FullName -Recurse -Force}
Write-Line 'Building full product-family evidence database ...'
Invoke-BatChecked $tool @($ArchiveRoot,$staging) 'full product-family builder'
Swap-Directory $staging $current
Write-Utf8 $hashPath ($toolHash+"`r`n")
Write-Utf8 $marker "rebuilt`r`n"
Write-Line ('Full product-family database committed: '+$current)
:_MVSDatabaseMaintenance_end
