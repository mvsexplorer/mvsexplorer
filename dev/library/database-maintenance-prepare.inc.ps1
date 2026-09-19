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
