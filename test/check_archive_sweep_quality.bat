@echo off
:setup
setlocal DisableDelayedExpansion
set "app.version=0.1.1"
set "app.name=check_archive_sweep_quality"
set "app.rc=0"
set "app.self=%~f0"
set "mvsq_results=%~1"
set "mvsq_strict_performance=0"
if /i "%~2"=="--strict-performance" set "mvsq_strict_performance=1"
set "mvsq_caller=%~nx0"
set "mvsq_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSArchiveQuality"
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

:_MVSArchiveQuality_start
$ErrorActionPreference='Stop'
$utf8=New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8
$ResultsInput=[string]$env:mvsq_results
$StrictPerformance=([string]$env:mvsq_strict_performance -eq '1')
$Caller=[string]$env:mvsq_caller
$Version=[string]$env:mvsq_version

function Fail { param([int]$Code,[string]$Message) [Console]::Error.WriteLine('ERROR: '+$Message); [Environment]::Exit($Code) }
function Write-Utf8 { param([string]$Path,[string]$Text) [IO.File]::WriteAllText($Path,$Text,$utf8) }
function Tsv { param([AllowNull()][AllowEmptyString()][string]$Value) if($null-eq$Value){return ''};return $Value.Replace("`t",' ').Replace("`r",' ').Replace("`n",' ') }
function Required-Sources {
    param([object]$Entry)
    switch([string]$Entry.family){
        'scalar' {return 'mvs_ids.txt|mvs_dates.txt'}
        'lookup' {return 'mvs_ids.txt|mvs_dates.txt'}
        'diagnostic' {return [string]$Entry.source_file}
        'relationship' {return 'mvs.txt'}
        'single-complete' {
            switch([string]$Entry.operation){
                'detail_query' {return 'mvs.txt'}
                'product_file_query' {return 'mvs.txt'}
                'product_section_query' {return 'mvs.txt'}
                'variant_query' {return 'mvs_names.txt'}
                'note_query' {return 'mvs_notes.html'}
                'unparsed_query' {return [string]$Entry.source_file}
                'hash_diagnostic' {return [string]$Entry.source_file}
                default {return ''}
            }
        }
        default {return ''}
    }
}
function Median {
    param([double[]]$Values)
    if($null-eq$Values -or $Values.Count-eq0){return 0.0}
    $s=@($Values|Sort-Object);$n=$s.Count
    if(($n%2)-eq1){return [double]$s[[int]($n/2)]}
    return ([double]$s[$n/2-1]+[double]$s[$n/2])/2.0
}
function Percentile {
    param([double[]]$Values,[double]$P)
    if($null-eq$Values -or $Values.Count-eq0){return 0.0}
    $s=@($Values|Sort-Object);$idx=[int][Math]::Floor(($s.Count-1)*$P);return [double]$s[$idx]
}

function Read-KeyValueTsv {
    param([string]$Path)
    $map=@{}
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $map}
    foreach($row in @(Import-Csv -LiteralPath $Path -Delimiter "`t")){
        $map[[string]$row.metric]=[string]$row.value
    }
    return $map
}

if(@('--help','-h','-?','/h','/?') -contains $ResultsInput){
    [Console]::Out.WriteLine('MVS Explorer Toolkit archive quality/performance checker '+$Version)
    [Console]::Out.WriteLine('Usage: '+$Caller+' results-folder [--strict-performance]')
    exit 0
}
if([string]::IsNullOrWhiteSpace($ResultsInput)-or-not(Test-Path -LiteralPath $ResultsInput -PathType Container)){Fail 3 ('Results folder not found: '+$ResultsInput)}
$Results=(Resolve-Path -LiteralPath $ResultsInput).Path
$planPath=Join-Path $Results 'plan.tsv';$runsPath=Join-Path $Results 'runs.tsv';$snapPath=Join-Path $Results 'snapshots.tsv'
foreach($p in @($planPath,$runsPath,$snapPath)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){Fail 4 ('Required result file missing: '+$p)}}
$plan=@(Import-Csv -LiteralPath $planPath -Delimiter "`t")
$runs=@(Import-Csv -LiteralPath $runsPath -Delimiter "`t")
$snaps=@(Import-Csv -LiteralPath $snapPath -Delimiter "`t")

$out=Join-Path $Results 'quality-check'
if(Test-Path -LiteralPath $out){Remove-Item -LiteralPath $out -Recurse -Force}
[void](New-Item -ItemType Directory -Path $out -Force)

$errors=New-Object System.Collections.ArrayList
$warnings=New-Object System.Collections.ArrayList
if($plan.Count-ne$runs.Count){[void]$errors.Add('plan/run row count mismatch: '+$plan.Count+' vs '+$runs.Count)}
$planIds=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach($r in $plan){if(-not$planIds.Add([string]$r.index)){[void]$errors.Add('duplicate plan index '+$r.index)}}
$runIds=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach($r in $runs){if(-not$runIds.Add([string]$r.index)){[void]$errors.Add('duplicate run index '+$r.index)}}
foreach($id in $planIds){if(-not$runIds.Contains($id)){[void]$errors.Add('missing run index '+$id)}}
foreach($id in $runIds){if(-not$planIds.Contains($id)){[void]$errors.Add('unexpected run index '+$id)}}

$planMap=@{};foreach($r in $plan){$planMap[[string]$r.index]=$r}
foreach($r in $runs){
    $e=$planMap[[string]$r.index]
    if($null-eq$e){continue}
    foreach($field in @('scope','snapshot','next_snapshot','tool','executor')){
        if([string]$r.$field-ne[string]$e.$field){[void]$errors.Add('run/plan metadata mismatch index '+$r.index+' field '+$field);break}
    }
}

$status=@{PASS=0;NO_RESULT=0;SOURCE_MISSING=0;FAIL=0}
foreach($r in $runs){if($status.ContainsKey([string]$r.status)){$status[[string]$r.status]++}else{[void]$errors.Add('invalid status '+$r.status+' at index '+$r.index)}}
if($status.FAIL-gt0){[void]$errors.Add('logical FAIL rows: '+$status.FAIL)}

# Validate summary counters against the authoritative ledger.
$summaryPath=Join-Path $Results 'summary.txt'
if(Test-Path -LiteralPath $summaryPath -PathType Leaf){
    $summaryText=[IO.File]::ReadAllText($summaryPath)
    foreach($name in @('PASS','NO_RESULT','SOURCE_MISSING','FAIL')){
        $m=[regex]::Match($summaryText,'(?m)^'+[regex]::Escape($name)+':\s*(?<n>\d+)\s*$')
        if($m.Success -and [int64]$m.Groups['n'].Value-ne[int64]$status[$name]){[void]$errors.Add('summary counter mismatch '+$name+': summary='+$m.Groups['n'].Value+' ledger='+$status[$name])}
    }
}

# Validate SOURCE_MISSING against the final frozen source inventory.
$snapMap=@{};foreach($s in $snaps){$snapMap[[string]$s.snapshot]=$s}
$expectedMissing=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach($e in $plan){
    if([string]$e.scope-eq'single'){
        $spec=Required-Sources $e
        if([string]::IsNullOrWhiteSpace($spec)){continue}
        $s=$snapMap[[string]$e.snapshot];$missing=$false
        foreach($name in $spec.Split('|')){if(-not[string]::IsNullOrWhiteSpace($name)-and[string]$s.$name-ne'1'){$missing=$true;break}}
        if($missing){[void]$expectedMissing.Add([string]$e.index)}
    } elseif([string]$e.scope-eq'compare'){
        $name=[string]$e.source_file
        if([string]::IsNullOrWhiteSpace($name)){continue}
        $a=$snapMap[[string]$e.snapshot];$b=$snapMap[[string]$e.next_snapshot]
        if([string]$a.$name-ne'1'-or[string]$b.$name-ne'1'){[void]$expectedMissing.Add([string]$e.index)}
    }
}
$actualMissing=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach($r in $runs){if([string]$r.status-eq'SOURCE_MISSING'){[void]$actualMissing.Add([string]$r.index)}}
$unexpected=New-Object System.Collections.ArrayList
foreach($id in $actualMissing){if(-not$expectedMissing.Contains($id)){[void]$unexpected.Add($id)}}
$missingExpected=New-Object System.Collections.ArrayList
foreach($id in $expectedMissing){if(-not$actualMissing.Contains($id)){[void]$missingExpected.Add($id)}}
if($unexpected.Count-gt0){[void]$errors.Add('unexpected SOURCE_MISSING rows: '+$unexpected.Count)}
if($missingExpected.Count-gt0){[void]$errors.Add('expected SOURCE_MISSING rows not classified as missing: '+$missingExpected.Count)}
if($unexpected.Count-gt0){
    $w=New-Object Text.StringBuilder;[void]$w.Append("index`tsnapshot`ttool`tstatus`n")
    foreach($id in @($unexpected|Sort-Object {[int]$_})){
        $r=@($runs|Where-Object{$_.index-eq$id})[0]
        [void]$w.Append((Tsv $id)+"`t"+(Tsv $r.snapshot)+"`t"+(Tsv $r.tool)+"`t"+(Tsv $r.status)+"`n")
    }
    Write-Utf8 (Join-Path $out 'unexpected-source-missing.tsv') $w.ToString()
}

# Quality flags emitted by the evolution analyzer are warnings, not automatic exclusions.
$qualityPath=Join-Path (Join-Path (Join-Path $Results 'archive-output') 'evolution') 'per-dump-quality.tsv'
$flagRows=@()
if(Test-Path -LiteralPath $qualityPath -PathType Leaf){
    $flagRows=@(Import-Csv -LiteralPath $qualityPath -Delimiter "`t"|Where-Object{-not[string]::IsNullOrWhiteSpace([string]$_.quality_flags)})
    foreach($q in $flagRows){[void]$warnings.Add('quality flags '+$q.dump+': '+$q.quality_flags)}
}

# Fast-combined evolution output must be internally coherent as well as ledger-complete.
$executor=if($plan.Count-gt0){[string]$plan[0].executor}else{''}
$evolutionRoot=Join-Path (Join-Path (Join-Path $Results 'archive-output') 'evolution') ''
if($executor-eq'fast-combined'){
    $requiredEvolution=@(
        'summary.tsv','per-dump-contributions.tsv','per-dump-domain-additions.tsv',
        'per-dump-retention.tsv','per-dump-quality.tsv','variant-id-transitions.tsv',
        'product-states-all-ever.tsv','variant-states-all-ever.tsv',
        'notes\note-observations.tsv','notes\note-versions.tsv','notes\note-bodies.tsv','notes\note-raw-variants.tsv'
    )
    foreach($rel in $requiredEvolution){
        $path=Join-Path $evolutionRoot $rel
        if(-not(Test-Path -LiteralPath $path -PathType Leaf)){[void]$errors.Add('required evolution output missing: '+$rel)}
    }
    $evoSummaryPath=Join-Path $evolutionRoot 'summary.tsv'
    if(Test-Path -LiteralPath $evoSummaryPath -PathType Leaf){
        $evo=Read-KeyValueTsv $evoSummaryPath
        if([int64]$evo['snapshots']-ne[int64]$snaps.Count){[void]$errors.Add('evolution snapshot count mismatch')}
        $countChecks=@(
            @('product_states_all_ever','product-states-all-ever.tsv'),
            @('variant_states_all_ever','variant-states-all-ever.tsv'),
            @('note_versions_all_ever','notes\note-versions.tsv'),
            @('note_bodies_all_ever','notes\note-bodies.tsv'),
            @('note_raw_variants_all_ever','notes\note-raw-variants.tsv')
        )
        foreach($check in $countChecks){
            $metric=[string]$check[0];$rel=[string]$check[1];$path=Join-Path $evolutionRoot $rel
            if(-not(Test-Path -LiteralPath $path -PathType Leaf)){continue}
            $rows=@(Import-Csv -LiteralPath $path -Delimiter "`t")
            $expected=0L
            if(-not[int64]::TryParse([string]$evo[$metric],[ref]$expected)){[void]$errors.Add('invalid evolution summary metric '+$metric);continue}
            if($rows.Count-ne$expected){[void]$errors.Add('evolution count mismatch '+$metric+': summary='+$expected+' rows='+$rows.Count)}
            if($metric-like'note_*'){
                foreach($row in $rows){
                    $observed=0L
                    if(-not[int64]::TryParse([string]$row.observed_snapshots,[ref]$observed)-or$observed-lt1-or$observed-gt$snaps.Count){
                        [void]$errors.Add('invalid note observed_snapshots in '+$rel);break
                    }
                }
            }
        }
    }

    $retentionPath=Join-Path $evolutionRoot 'per-dump-retention.tsv'
    if(Test-Path -LiteralPath $retentionPath -PathType Leaf){
        $retentionRows=@(Import-Csv -LiteralPath $retentionPath -Delimiter "`t")
        $kinds=@($retentionRows|Select-Object -ExpandProperty evidence_kind -Unique)
        $expectedRetentionRows=$snaps.Count*$kinds.Count
        if($retentionRows.Count-ne$expectedRetentionRows){[void]$errors.Add('retention matrix is incomplete: rows='+$retentionRows.Count+' expected='+$expectedRetentionRows)}
        foreach($row in $retentionRows){
            $introduced=0L;$later=0L;$never=0L
            [void][int64]::TryParse([string]$row.introduced_here,[ref]$introduced)
            [void][int64]::TryParse([string]$row.seen_later,[ref]$later)
            [void][int64]::TryParse([string]$row.never_seen_later,[ref]$never)
            if($introduced-lt0-or$later-lt0-or$never-lt0-or$introduced-ne($later+$never)){
                [void]$errors.Add('invalid retention accounting at '+$row.dump+' / '+$row.evidence_kind);break
            }
        }
    }

    $rawRoot=Join-Path (Join-Path $evolutionRoot 'notes') 'raw-html'
    $noteVersionsPath=Join-Path (Join-Path $evolutionRoot 'notes') 'note-versions.tsv'
    if(Test-Path -LiteralPath $noteVersionsPath -PathType Leaf){
        foreach($row in @(Import-Csv -LiteralPath $noteVersionsPath -Delimiter "`t")){
            if(-not[string]::IsNullOrWhiteSpace([string]$row.raw_html_sha256)){
                $rawPath=Join-Path $rawRoot ([string]$row.raw_html_sha256+'.html')
                if(-not(Test-Path -LiteralPath $rawPath -PathType Leaf)){[void]$errors.Add('missing retained raw note HTML '+$row.raw_html_sha256);break}
            }
        }
    }
}

# Performance analysis.
$toolStats=New-Object System.Collections.ArrayList
$groups=$runs|Where-Object{[string]$_.scope-eq'single'}|Group-Object tool
foreach($g in $groups){
    $vals=[double[]]@($g.Group|ForEach-Object{[double]$_.elapsed_ms})
    [void]$toolStats.Add([pscustomobject]@{
        tool=$g.Name;calls=$vals.Count;mean_ms=[math]::Round((($vals|Measure-Object -Average).Average),2)
        median_ms=[math]::Round((Median $vals),2);p95_ms=[math]::Round((Percentile $vals 0.95),2);max_ms=[math]::Round((Percentile $vals 1.0),2)
    })
}
$sortedTools=@($toolStats|Sort-Object mean_ms -Descending)
$perfWriter=New-Object Text.StringBuilder;[void]$perfWriter.Append("tool`tcalls`tmean_ms`tmedian_ms`tp95_ms`tmax_ms`n")
foreach($r in $sortedTools){[void]$perfWriter.Append((Tsv $r.tool)+"`t"+$r.calls+"`t"+$r.mean_ms+"`t"+$r.median_ms+"`t"+$r.p95_ms+"`t"+$r.max_ms+"`n")}
Write-Utf8 (Join-Path $out 'performance-by-tool.tsv') $perfWriter.ToString()

$means=[double[]]@($toolStats|ForEach-Object{[double]$_.mean_ms}|Where-Object{$_-gt0})
$medianMean=Median $means
$outliers=@($sortedTools|Where-Object{$_.mean_ms-gt[math]::Max(5000.0,8.0*$medianMean)-or$_.max_ms-gt60000.0})
$outWriter=New-Object Text.StringBuilder;[void]$outWriter.Append("tool`tcalls`tmean_ms`tmedian_ms`tp95_ms`tmax_ms`treason`n")
foreach($r in $outliers){
    $reason=if($r.max_ms-gt60000.0){'max>60s'}else{'mean>max(5s,8x median tool mean)'}
    [void]$outWriter.Append((Tsv $r.tool)+"`t"+$r.calls+"`t"+$r.mean_ms+"`t"+$r.median_ms+"`t"+$r.p95_ms+"`t"+$r.max_ms+"`t"+$reason+"`n")
}
Write-Utf8 (Join-Path $out 'performance-outliers.tsv') $outWriter.ToString()
if($outliers.Count-gt0){[void]$warnings.Add('performance outliers: '+$outliers.Count)}
if($StrictPerformance-and$outliers.Count-gt0){[void]$errors.Add('strict performance check failed: '+$outliers.Count+' outliers')}

$batchPath=Join-Path $Results 'fast-batches.tsv'
$batchSummary=''
$singleBatchSummary=''
$compareBatchSummary=''
$archiveBatchSummary=''
$batchOutliers=@()
$archiveBatchOutliers=@()
$archiveThreshold=3600000.0
if(Test-Path -LiteralPath $batchPath -PathType Leaf){
    $b=@(Import-Csv -LiteralPath $batchPath -Delimiter "`t")
    $success=@($b|Where-Object{[string]$_.rc-eq'0'})
    $vals=[double[]]@($success|ForEach-Object{[double]$_.elapsed_ms})
    if($vals.Count-gt0){
        $batchSummary='successful_batches='+$success.Count+' median_seconds='+[math]::Round((Median $vals)/1000.0,2)+' p95_seconds='+[math]::Round((Percentile $vals 0.95)/1000.0,2)+' max_seconds='+[math]::Round((Percentile $vals 1.0)/1000.0,2)
    }

    $batchWriter=New-Object Text.StringBuilder
    [void]$batchWriter.Append("scope`tsnapshot`tnext_snapshot`tlogical_checks`tworker`telapsed_ms`telapsed_seconds`trc`n")
    foreach($row in @($success|Sort-Object {[double]$_.elapsed_ms} -Descending)){
        [void]$batchWriter.Append((Tsv $row.scope)+"`t"+(Tsv $row.snapshot)+"`t"+(Tsv $row.next_snapshot)+"`t"+(Tsv $row.logical_checks)+"`t"+(Tsv $row.worker)+"`t"+(Tsv $row.elapsed_ms)+"`t"+([math]::Round(([double]$row.elapsed_ms)/1000.0,2))+"`t"+(Tsv $row.rc)+"`n")
    }
    Write-Utf8 (Join-Path $out 'performance-by-batch.tsv') $batchWriter.ToString()

    $singleSuccess=@($success|Where-Object{[string]$_.scope-eq'single'})
    $singleVals=[double[]]@($singleSuccess|ForEach-Object{[double]$_.elapsed_ms})
    $singleMedian=Median $singleVals
    if($singleVals.Count-gt0){
        $singleBatchSummary='successful_batches='+$singleSuccess.Count+' median_seconds='+[math]::Round($singleMedian/1000.0,2)+' p95_seconds='+[math]::Round((Percentile $singleVals 0.95)/1000.0,2)+' max_seconds='+[math]::Round((Percentile $singleVals 1.0)/1000.0,2)
    }
    $batchThreshold=[math]::Max(60000.0,3.0*$singleMedian)
    $batchOutliers=@($singleSuccess|Where-Object{[double]$_.elapsed_ms-gt$batchThreshold}|Sort-Object {[double]$_.elapsed_ms} -Descending)
    $batchOutWriter=New-Object Text.StringBuilder
    [void]$batchOutWriter.Append("scope`tsnapshot`tlogical_checks`tworker`telapsed_ms`tthreshold_ms`treason`n")
    foreach($row in $batchOutliers){
        [void]$batchOutWriter.Append((Tsv $row.scope)+"`t"+(Tsv $row.snapshot)+"`t"+(Tsv $row.logical_checks)+"`t"+(Tsv $row.worker)+"`t"+(Tsv $row.elapsed_ms)+"`t"+([math]::Round($batchThreshold,2))+"`tsnapshot batch > max(60s, 3x median)`n")
    }
    Write-Utf8 (Join-Path $out 'performance-batch-outliers.tsv') $batchOutWriter.ToString()
    if($batchOutliers.Count-gt0){[void]$warnings.Add('snapshot batch performance outliers: '+$batchOutliers.Count)}
    if($StrictPerformance-and$batchOutliers.Count-gt0){[void]$errors.Add('strict performance check failed: '+$batchOutliers.Count+' snapshot batch outliers')}

    $compareSuccess=@($success|Where-Object{[string]$_.scope-eq'compare'})
    $compareVals=[double[]]@($compareSuccess|ForEach-Object{[double]$_.elapsed_ms})
    if($compareVals.Count-gt0){
        $compareBatchSummary='successful_batches='+$compareSuccess.Count+' median_seconds='+[math]::Round((Median $compareVals)/1000.0,2)+' p95_seconds='+[math]::Round((Percentile $compareVals 0.95)/1000.0,2)+' max_seconds='+[math]::Round((Percentile $compareVals 1.0)/1000.0,2)
    }

    $archiveSuccess=@($success|Where-Object{[string]$_.scope-eq'archive'})
    $archiveVals=[double[]]@($archiveSuccess|ForEach-Object{[double]$_.elapsed_ms})
    if($archiveVals.Count-gt0){
        $archiveBatchSummary='successful_batches='+$archiveSuccess.Count+' median_seconds='+[math]::Round((Median $archiveVals)/1000.0,2)+' p95_seconds='+[math]::Round((Percentile $archiveVals 0.95)/1000.0,2)+' max_seconds='+[math]::Round((Percentile $archiveVals 1.0)/1000.0,2)
    }
    $archiveBatchOutliers=@($archiveSuccess|Where-Object{[double]$_.elapsed_ms-gt$archiveThreshold}|Sort-Object {[double]$_.elapsed_ms} -Descending)
    $archiveOutWriter=New-Object Text.StringBuilder
    [void]$archiveOutWriter.Append("scope`tsnapshot`tlogical_checks`tworker`telapsed_ms`tthreshold_ms`treason`n")
    foreach($row in $archiveBatchOutliers){
        [void]$archiveOutWriter.Append((Tsv $row.scope)+"`t"+(Tsv $row.snapshot)+"`t"+(Tsv $row.logical_checks)+"`t"+(Tsv $row.worker)+"`t"+(Tsv $row.elapsed_ms)+"`t"+([math]::Round($archiveThreshold,2))+"`tarchive batch > 1 hour`n")
    }
    Write-Utf8 (Join-Path $out 'performance-archive-outliers.tsv') $archiveOutWriter.ToString()
    if($archiveBatchOutliers.Count-gt0){[void]$warnings.Add('archive batch performance outliers: '+$archiveBatchOutliers.Count)}
    if($StrictPerformance-and$archiveBatchOutliers.Count-gt0){[void]$errors.Add('strict performance check failed: '+$archiveBatchOutliers.Count+' archive batch outliers')}
}

$summary=@(
    'MVS Explorer Toolkit archive quality/performance check',
    '',
    'Results: '+$Results,
    'Plan rows: '+$plan.Count,
    'Run rows: '+$runs.Count,
    'PASS: '+$status.PASS,
    'NO_RESULT: '+$status.NO_RESULT,
    'SOURCE_MISSING: '+$status.SOURCE_MISSING,
    'FAIL: '+$status.FAIL,
    'Expected historical SOURCE_MISSING: '+$expectedMissing.Count,
    'Unexpected SOURCE_MISSING: '+$unexpected.Count,
    'Quality-flagged dumps: '+$flagRows.Count,
    'Performance outliers: '+$outliers.Count,
    'Snapshot batch outliers: '+$batchOutliers.Count,
    'Archive batch outliers: '+$archiveBatchOutliers.Count,
    'Performance strict: '+$StrictPerformance,
    'Batch performance: '+$batchSummary,
    'Snapshot batch performance: '+$singleBatchSummary,
    'Compare batch performance: '+$compareBatchSummary,
    'Archive batch performance: '+$archiveBatchSummary,
    'Warnings: '+$warnings.Count,
    'Errors: '+$errors.Count
)
if($warnings.Count-gt0){$summary+='';$summary+='Warnings:';foreach($w in $warnings){$summary+='- '+$w}}
if($errors.Count-gt0){$summary+='';$summary+='Errors:';foreach($e in $errors){$summary+='- '+$e}}
Write-Utf8 (Join-Path $out 'summary.txt') (($summary-join[Environment]::NewLine)+[Environment]::NewLine)

# The file keeps the stable detailed key/value format. The interactive console
# uses horizontal space so a healthy run is readable at a glance.
[Console]::Out.WriteLine('MVS Explorer Toolkit archive quality/performance check')
[Console]::Out.WriteLine('Results: '+$Results)
[Console]::Out.WriteLine(('Ledger: plan={0} run={1} | PASS={2} NO_RESULT={3} SOURCE_MISSING={4} FAIL={5}' -f $plan.Count,$runs.Count,$status.PASS,$status.NO_RESULT,$status.SOURCE_MISSING,$status.FAIL))
[Console]::Out.WriteLine(('Source coverage: expected_missing={0} unexpected_missing={1}' -f $expectedMissing.Count,$unexpected.Count))
[Console]::Out.WriteLine(('Quality: flagged_dumps={0} warnings={1} errors={2}' -f $flagRows.Count,$warnings.Count,$errors.Count))
[Console]::Out.WriteLine(('Performance: tool_outliers={0} snapshot_batch_outliers={1} archive_batch_outliers={2} strict={3}' -f $outliers.Count,$batchOutliers.Count,$archiveBatchOutliers.Count,$StrictPerformance))
[Console]::Out.WriteLine('Batch performance: '+$batchSummary)
[Console]::Out.WriteLine('Snapshot batches: '+$singleBatchSummary)
[Console]::Out.WriteLine('Compare batches: '+$compareBatchSummary)
[Console]::Out.WriteLine('Archive batches: '+$archiveBatchSummary)
if($warnings.Count-gt0){[Console]::Out.WriteLine('Warnings:');foreach($w in $warnings){[Console]::Out.WriteLine('- '+$w)}}
if($errors.Count-gt0){[Console]::Out.WriteLine('Errors:');foreach($e in $errors){[Console]::Out.WriteLine('- '+$e)}}
if($errors.Count-gt0){exit 1}
exit 0
:_MVSArchiveQuality_end
