@echo off
:setup
REM Generated internal create/update component. It is standalone but orchestrated by create_or_update_mvs_database.bat.
setlocal DisableDelayedExpansion
set "app.version=0.1.0"
set "app.name=02_prepare_archive_update"
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
$Workers=8
if(   -not    [int]::TryParse([string]$env:mvsdbm_arg6,[ref]$Workers)    -or    $Workers  -lt   1){$Workers=8}
$RunLogs=[IO.Path]::GetFullPath([string]$env:mvsdbm_arg7)
$Extra=[string]$env:mvsdbm_arg8
$Version=[string]$env:mvsdbm_version
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
    foreach($relative in @('test\test_all_dumps.bat','test\fast\run_snapshot_tools_fast.bat','test\fast\run_compare_tools_fast.bat','test\fast\run_archive_tools_fast.bat')){
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

Write-Line ('Preparing incremental archive analysis for '+$ArchiveRoot)
Ensure-Directory $DatabaseRoot
Ensure-Directory $SlotRoot
Ensure-Directory $RunLogs
$staging=Join-Path $SlotRoot ('archive-analysis.staging-'+$RunId)
foreach($oldStage in @(Get-ChildItem -LiteralPath $SlotRoot -Directory -Filter 'archive-analysis.staging-*' -ErrorAction SilentlyContinue)){
    Write-Line ('Removing incomplete prior staging area: '+$oldStage.Name)
    Remove-Item -LiteralPath $oldStage.FullName -Recurse -Force
}
$cache=Join-Path $SlotRoot 'cache'
Ensure-Directory $cache
$sweep=Join-Path $ProjectRoot 'test\test_all_dumps.bat'
Invoke-BatChecked $sweep @($ArchiveRoot,$staging,'--plan-only','--quiet-plan','--workers',[string]$Workers,'--cache-folder',$cache) 'archive plan preflight'

$newPlan=@(Import-Csv -LiteralPath (Join-Path $staging 'plan.tsv') -Delimiter "`t")
if($newPlan.Count -eq 0){throw 'Generated archive plan is empty.'}
$newToolset=Get-ToolsetFingerprint $ProjectRoot
Write-Utf8 (Join-Path $staging 'toolset-sha256.txt') ($newToolset+"`r`n")

$fingerprintRows=New-Object System.Collections.ArrayList
$newFp=New-IgnoreCaseObjectDictionary
foreach($snap in @(Get-SnapshotDirectories $ArchiveRoot)){
    Write-Line ('Fingerprinting source content: '+$snap.Name)
    $fp=Get-SnapshotFingerprint $snap.FullName
    $row=[pscustomobject]@{snapshot=$snap.Name;fingerprint=$fp.fingerprint;source_file_count=$fp.file_count;data_path=$fp.data_path}
    [void]$fingerprintRows.Add($row)
    $newFp[$snap.Name]=$row
}
$fpLines=New-Object System.Collections.ArrayList
[void]$fpLines.Add("snapshot`tfingerprint`tsource_file_count`tdata_path")
foreach($row in $fingerprintRows){[void]$fpLines.Add(($row.snapshot+"`t"+$row.fingerprint+"`t"+$row.source_file_count+"`t"+(Convert-TsvField $row.data_path)))}
Write-Utf8 (Join-Path $staging 'source-fingerprints.tsv') (($fpLines -join "`r`n")+"`r`n")

$current=Join-Path $SlotRoot 'archive-analysis'
$oldPlan=@();$oldRuns=@();$oldFp=New-IgnoreCaseObjectDictionary;$oldToolset=''
if(Test-Path -LiteralPath $current -PathType Container){
    if(Test-Path -LiteralPath (Join-Path $current 'plan.tsv') -PathType Leaf){$oldPlan=@(Import-Csv -LiteralPath (Join-Path $current 'plan.tsv') -Delimiter "`t")}
    if(Test-Path -LiteralPath (Join-Path $current 'runs.tsv') -PathType Leaf){$oldRuns=@(Import-Csv -LiteralPath (Join-Path $current 'runs.tsv') -Delimiter "`t")}
    if(Test-Path -LiteralPath (Join-Path $current 'source-fingerprints.tsv') -PathType Leaf){
        foreach($r in @(Import-Csv -LiteralPath (Join-Path $current 'source-fingerprints.tsv') -Delimiter "`t")){$oldFp[[string]$r.snapshot]=$r}
    }
    if(Test-Path -LiteralPath (Join-Path $current 'toolset-sha256.txt') -PathType Leaf){$oldToolset=([IO.File]::ReadAllText((Join-Path $current 'toolset-sha256.txt'))).Trim()}
}
$toolsetReusable=($oldToolset  -and  [StringComparer]::Ordinal.Equals($oldToolset,$newToolset))
if($oldPlan.Count -gt 0  -and    -not  $toolsetReusable){Write-Line 'Sweep toolset changed or lacks a prior fingerprint; prior dump results will not be reused.'}

$oldPlanByKey=New-OrdinalObjectDictionary
foreach($r in $oldPlan){$oldPlanByKey[(Plan-Key $r)]=$r}
$oldRunByIndex=New-OrdinalObjectDictionary
foreach($r in $oldRuns){$oldRunByIndex[[string]$r.index]=$r}

$seededByNewIndex=New-OrdinalObjectDictionary
$seededSnapshots=New-IgnoreCaseStringSet
$pendingSnapshots=New-IgnoreCaseStringSet
$newSnapshots=0;$changedSnapshots=0;$faultySnapshots=0;$alreadySnapshots=0

foreach($snapshot in @($newFp.Keys|Sort-Object)){
    $rows=@($newPlan|Where-Object{$_.scope  -eq  'single'   -and   $_.snapshot  -eq  $snapshot})
    $reason=''
    if(   -not   $toolsetReusable){$reason='toolset changed'}
    elseif(   -not   $oldFp.ContainsKey($snapshot)){$reason='new dump';$newSnapshots++}
    elseif(   -not   [StringComparer]::Ordinal.Equals([string]$oldFp[$snapshot].fingerprint,[string]$newFp[$snapshot].fingerprint)){$reason='source content changed';$changedSnapshots++}
    else{
        foreach($nr in $rows){
            $key=Plan-Key $nr
            if(   -not   $oldPlanByKey.ContainsKey($key)){$reason='prior processing incomplete';break}
            $or=$oldPlanByKey[$key]
            $idx=[string]$or.index
            if(   -not   $oldRunByIndex.ContainsKey($idx)   -or   ([string]$oldRunByIndex[$idx].status -notin @('PASS','NO_RESULT','SOURCE_MISSING'))){$reason='prior processing incomplete/faulty';break}
        }
    }
    if(   -not   $reason){
        foreach($nr in $rows){
            $or=$oldPlanByKey[(Plan-Key $nr)]
            $oldRun=$oldRunByIndex[[string]$or.index]
            $copy=[pscustomobject]@{
                index=[string]$nr.index;executor=[string]$nr.executor;scope=[string]$nr.scope;snapshot=[string]$nr.snapshot;next_snapshot=[string]$nr.next_snapshot;
                tool=[string]$nr.tool;search_source=[string]$nr.search_source;search_value=[string]$nr.search_value;search_origin=[string]$nr.search_origin;
                status=[string]$oldRun.status;rc=[string]$oldRun.rc;stdout_bytes=[string]$oldRun.stdout_bytes;stderr_bytes=[string]$oldRun.stderr_bytes;elapsed_ms=[string]$oldRun.elapsed_ms
            }
            $seededByNewIndex[[string]$nr.index]=$copy
        }
        [void]$seededSnapshots.Add($snapshot);$alreadySnapshots++
        Write-Line ('Already done: '+$snapshot+' ('+$rows.Count+'/'+$rows.Count+' checks reusable).')
    }else{
        [void]$pendingSnapshots.Add($snapshot)
        if($reason  -like  'prior processing*'){$faultySnapshots++}
        Write-Line ('Processing from scratch: '+$snapshot+' - '+$reason+'.')
    }
}

$seededComparePairs=New-IgnoreCaseStringSet
$compareGroups=@($newPlan|Where-Object{$_.scope  -eq  'compare'}|Group-Object {([string]$_.snapshot)+'|'+([string]$_.next_snapshot)})
foreach($group in $compareGroups){
    $rows=@($group.Group);$from=[string]$rows[0].snapshot;$to=[string]$rows[0].next_snapshot;$pair=$from+'|'+$to
    $reuse=$toolsetReusable  -and  $seededSnapshots.Contains($from)   -and   $seededSnapshots.Contains($to)
    if($reuse){
        foreach($nr in $rows){
            $key=Plan-Key $nr
            if(   -not   $oldPlanByKey.ContainsKey($key)){$reuse=$false;break}
            $or=$oldPlanByKey[$key];$idx=[string]$or.index
            if(   -not   $oldRunByIndex.ContainsKey($idx)   -or   ([string]$oldRunByIndex[$idx].status -notin @('PASS','NO_RESULT','SOURCE_MISSING'))){$reuse=$false;break}
        }
    }
    if($reuse){
        foreach($nr in $rows){
            $or=$oldPlanByKey[(Plan-Key $nr)];$oldRun=$oldRunByIndex[[string]$or.index]
            $seededByNewIndex[[string]$nr.index]=[pscustomobject]@{
                index=[string]$nr.index;executor=[string]$nr.executor;scope=[string]$nr.scope;snapshot=[string]$nr.snapshot;next_snapshot=[string]$nr.next_snapshot;
                tool=[string]$nr.tool;search_source=[string]$nr.search_source;search_value=[string]$nr.search_value;search_origin=[string]$nr.search_origin;
                status=[string]$oldRun.status;rc=[string]$oldRun.rc;stdout_bytes=[string]$oldRun.stdout_bytes;stderr_bytes=[string]$oldRun.stderr_bytes;elapsed_ms=[string]$oldRun.elapsed_ms
            }
        }
        [void]$seededComparePairs.Add($pair)
        Write-Line ('Already done compare: '+$from+' -> '+$to+' ('+$rows.Count+' checks reusable).')
    }else{Write-Line ('Pending compare: '+$from+' -> '+$to+'.')}
}

$archiveRows=@($newPlan|Where-Object{$_.scope  -eq  'archive'})
$reuseArchive=($pendingSnapshots.Count -eq 0  -and  $seededComparePairs.Count  -eq  $compareGroups.Count  -and  $toolsetReusable)
if($reuseArchive){
    foreach($nr in $archiveRows){
        $key=Plan-Key $nr
        if(   -not   $oldPlanByKey.ContainsKey($key)){$reuseArchive=$false;break}
        $or=$oldPlanByKey[$key];$idx=[string]$or.index
        if(   -not   $oldRunByIndex.ContainsKey($idx)   -or   ([string]$oldRunByIndex[$idx].status -notin @('PASS','NO_RESULT','SOURCE_MISSING'))){$reuseArchive=$false;break}
    }
}
if($reuseArchive){
    foreach($nr in $archiveRows){
        $or=$oldPlanByKey[(Plan-Key $nr)];$oldRun=$oldRunByIndex[[string]$or.index]
        $seededByNewIndex[[string]$nr.index]=[pscustomobject]@{
            index=[string]$nr.index;executor=[string]$nr.executor;scope=[string]$nr.scope;snapshot=[string]$nr.snapshot;next_snapshot=[string]$nr.next_snapshot;
            tool=[string]$nr.tool;search_source=[string]$nr.search_source;search_value=[string]$nr.search_value;search_origin=[string]$nr.search_origin;
            status=[string]$oldRun.status;rc=[string]$oldRun.rc;stdout_bytes=[string]$oldRun.stdout_bytes;stderr_bytes=[string]$oldRun.stderr_bytes;elapsed_ms=[string]$oldRun.elapsed_ms
        }
    }
    Copy-TreeHardLinkOrCopy (Join-Path $current 'archive-output') (Join-Path $staging 'archive-output')
    Write-Line 'Already done: archive-wide builders are reusable.'
}else{Write-Line 'Archive-wide builders will be regenerated after pending dump/compare work.'}

$runHeader=@('index','executor','scope','snapshot','next_snapshot','tool','search_source','search_value','search_origin','status','rc','stdout_bytes','stderr_bytes','elapsed_ms')
$runLines=New-Object System.Collections.ArrayList
[void]$runLines.Add(($runHeader-join$Tab))
foreach($nr in @($newPlan|Sort-Object {[int]$_.index})){
    $idx=[string]$nr.index
    if($seededByNewIndex.ContainsKey($idx)){
        $r=$seededByNewIndex[$idx]
        $vals=foreach($h in $runHeader){Convert-TsvField ([string]$r.$h)}
        [void]$runLines.Add(($vals-join$Tab))
    }
}
Write-Utf8 (Join-Path $staging 'runs.tsv') (($runLines-join"`r`n")+"`r`n")

$batchLines=New-Object System.Collections.ArrayList
[void]$batchLines.Add("scope`tsnapshot`tnext_snapshot`tlogical_checks`tworker`telapsed_ms`trc")
$oldBatchesPath=Join-Path $current 'fast-batches.tsv'
if(Test-Path -LiteralPath $oldBatchesPath -PathType Leaf){
    foreach($b in @(Import-Csv -LiteralPath $oldBatchesPath -Delimiter "`t")){
        $keep=$false
        if($b.scope  -eq  'single'){$keep=$seededSnapshots.Contains([string]$b.snapshot)}
        elseif($b.scope  -eq  'compare'){$keep=$seededComparePairs.Contains(([string]$b.snapshot)+'|'+([string]$b.next_snapshot))}
        elseif($b.scope  -eq  'archive'){$keep=$reuseArchive}
        if($keep){[void]$batchLines.Add(@($b.scope,$b.snapshot,$b.next_snapshot,$b.logical_checks,$b.worker,$b.elapsed_ms,$b.rc)-join$Tab)}
    }
}
Write-Utf8 (Join-Path $staging 'fast-batches.tsv') (($batchLines-join"`r`n")+"`r`n")

$pending=$newPlan.Count-$seededByNewIndex.Count
$state=[ordered]@{
    run_id=$RunId;archive_root=$ArchiveRoot;staging=$staging;planned_checks=$newPlan.Count;seeded_checks=$seededByNewIndex.Count;pending_checks=$pending;
    already_done_snapshots=$alreadySnapshots;pending_snapshots=$pendingSnapshots.Count;new_snapshots=$newSnapshots;changed_snapshots=$changedSnapshots;
    faulty_or_incomplete_snapshots=$faultySnapshots;toolset_reusable=$toolsetReusable;archive_reused=$reuseArchive
}
Write-Utf8 (Join-Path $staging 'update-state.json') ((ConvertTo-Json $state -Depth 4)+"`r`n")
Write-Line ('Prepared: seeded='+$seededByNewIndex.Count+' pending='+$pending+' planned='+$newPlan.Count+'.')
:_MVSDatabaseMaintenance_end
