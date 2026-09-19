@echo off
:setup
REM Validates freshly generated archive/full-family/compact-family databases and executes every family query tool.
setlocal DisableDelayedExpansion
set "app.version=0.1.1"
set "app.name=test_generated_databases"
set "app.rc=0"
set "app.self=%~f0"
set "mvsdb_archive=%~1"
set "mvsdb_family=%~2"
set "mvsdb_compact=%~3"
set "mvsdb_output=%~4"
set "mvsdb_project_version=%~5"
set "mvsdb_project_root=%~dp0.."
set "mvsdb_caller=%~nx0"
set "mvsdb_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSDatabaseValidation"
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

:_MVSDatabaseValidation_start
$ErrorActionPreference='Stop'
$utf8=New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8

$ArchiveInput=[string]$env:mvsdb_archive
$FamilyInput=[string]$env:mvsdb_family
$CompactInput=[string]$env:mvsdb_compact
$OutputInput=[string]$env:mvsdb_output
$ProjectVersion=[string]$env:mvsdb_project_version
$ProjectRoot=([string]$env:mvsdb_project_root).TrimEnd('\','/')
$Caller=[string]$env:mvsdb_caller
$ToolVersion=[string]$env:mvsdb_version
$script:Passed=0
$script:Failed=0
$script:Index=0
$script:Total=0
$script:ConsoleWriter=$null
$script:ResultWriter=$null
$script:ToolPerfWriter=$null
$US=[char]31

function Is-HelpToken{param([string]$v)return @('--help','-h','-?','/h','/?')-contains$v}
function Clean-Tsv{param([AllowNull()][object]$v)if($null-eq$v){return ''};return ([string]$v).Replace("`t",' ').Replace("`r",' ').Replace("`n",' ')}
function Resolve-Dir{param([string]$v)if([string]::IsNullOrWhiteSpace($v)-or-not(Test-Path -LiteralPath $v -PathType Container)){return $null};return (Resolve-Path -LiteralPath $v).Path}
function Write-Line{
    param([AllowEmptyString()][string]$Text)
    [Console]::Out.WriteLine($Text)
    if($null-ne$script:ConsoleWriter){$script:ConsoleWriter.WriteLine($Text);$script:ConsoleWriter.Flush()}
}
function Add-Result{
    param([string]$Status,[string]$Name,[string]$Reason,[long]$ElapsedMs)
    $script:Index++
    if($Status-eq'PASS'){$script:Passed++}else{$script:Failed++}
    $remaining=[Math]::Max(0,$script:Total-$script:Index)
    $prefix='[MVS '+$ProjectVersion+'] [DB TEST '+$script:Index+'/'+$script:Total+' | remaining='+$remaining+']'
    if($Status-eq'PASS'){Write-Line ($prefix+' [PASS] '+$Name)}else{Write-Line ($prefix+' [FAIL] '+$Name+' - '+$Reason)}
    $script:ResultWriter.WriteLine((@($script:Index,$Status,$Name,$Reason,$ElapsedMs)|ForEach-Object{Clean-Tsv $_})-join"`t")
    $script:ResultWriter.Flush()
}
function Test-Case{
    param([string]$Name,[scriptblock]$Action)
    $sw=[Diagnostics.Stopwatch]::StartNew()
    try{
        $ok=&$Action
        $sw.Stop()
        if([bool]$ok){Add-Result 'PASS' $Name '' $sw.ElapsedMilliseconds}else{Add-Result 'FAIL' $Name 'condition returned false' $sw.ElapsedMilliseconds}
    }catch{
        $sw.Stop()
        Add-Result 'FAIL' $Name $_.Exception.Message $sw.ElapsedMilliseconds
    }
}
function Read-SummaryMap{
    param([string]$Path)
    $map=@{}
    foreach($line in [IO.File]::ReadAllLines($Path,$utf8)){
        $idx=$line.IndexOf(':')
        if($idx-le0){continue}
        $key=$line.Substring(0,$idx).Trim()
        $val=$line.Substring($idx+1).Trim()
        $map[$key]=$val
    }
    return $map
}
function Count-DataRows{
    param([string]$Path)
    $sr=New-Object IO.StreamReader($Path,$utf8,$true,65536)
    try{
        [void]$sr.ReadLine()
        [long]$count=0
        while($null-ne($line=$sr.ReadLine())){$count++}
        return $count
    }finally{$sr.Dispose()}
}
function Get-FirstTsvRow{
    param([string]$Path)
    $sr=New-Object IO.StreamReader($Path,$utf8,$true,65536)
    try{
        $header=$sr.ReadLine()
        $line=$sr.ReadLine()
        if($null-eq$header-or$null-eq$line){return $null}
        $names=$header.Split("`t")
        $vals=$line.Split("`t")
        $obj=[ordered]@{}
        for($i=0;$i-lt$names.Count;$i++){$obj[$names[$i]]=if($i-lt$vals.Count){$vals[$i]}else{''}}
        return [pscustomobject]$obj
    }finally{$sr.Dispose()}
}
function Sum-NumericColumn{
    param([string]$Path,[string]$Column)
    $sr=New-Object IO.StreamReader($Path,$utf8,$true,65536)
    try{
        $head=$sr.ReadLine().Split("`t")
        $idx=[Array]::IndexOf($head,$Column)
        if($idx-lt0){throw($Column+' column missing in '+$Path)}
        [long]$sum=0
        while($null-ne($line=$sr.ReadLine())){
            $parts=$line.Split("`t")
            if($idx-ge$parts.Count){throw('short row in '+$Path)}
            [long]$v=0
            if(-not[long]::TryParse($parts[$idx],[ref]$v)){throw('invalid '+$Column+' in '+$Path)}
            $sum+=$v
        }
        return $sum
    }finally{$sr.Dispose()}
}
function Get-FileSha256{
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Invoke-BatchCapture{
    param([string]$ToolPath,[object[]]$ToolArgs)
    $psi=New-Object Diagnostics.ProcessStartInfo
    $psi.FileName=if([string]::IsNullOrWhiteSpace($env:ComSpec)){'cmd.exe'}else{$env:ComSpec}
    $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
    $psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
    $psi.EnvironmentVariables['DB_TOOL']=$ToolPath
    $parts=New-Object Collections.ArrayList
    [void]$parts.Add('"%DB_TOOL%"')
    for($i=0;$i-lt$ToolArgs.Count;$i++){
        $n='DB_ARG'+$i;$psi.EnvironmentVariables[$n]=[string]$ToolArgs[$i];[void]$parts.Add(('"%'+$n+'%"'))
    }
    $psi.Arguments='/d /s /c "'+($parts-join' ')+'"'
    if($psi.PSObject.Properties.Name-contains'StandardOutputEncoding'){$psi.StandardOutputEncoding=$utf8;$psi.StandardErrorEncoding=$utf8}
    $p=New-Object Diagnostics.Process;$p.StartInfo=$psi
    $sw=[Diagnostics.Stopwatch]::StartNew()
    [void]$p.Start()
    $outTask=$p.StandardOutput.ReadToEndAsync();$errTask=$p.StandardError.ReadToEndAsync()
    $p.WaitForExit();$sw.Stop()
    $stdout=$outTask.Result.Replace("`r`n","`n").TrimEnd("`r","`n")
    $stderr=$errTask.Result.Replace("`r`n","`n").TrimEnd("`r","`n")
    $lines=if([string]::IsNullOrWhiteSpace($stdout)){0}else{@($stdout-split"`n").Count}
    return [pscustomobject]@{rc=$p.ExitCode;stdout=$stdout;stderr=$stderr;elapsed_ms=[long]$sw.ElapsedMilliseconds;output_lines=$lines}
}
function Escape-Wildcard{
    param([string]$Value)
    return [Management.Automation.WildcardPattern]::Escape($Value)
}
function New-StringSet{return ,(New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase))}
function New-OrdinalSet{return ,(New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal))}
function New-SetMap{return ,(New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase))}
function Add-SetMap{
    param([object]$Map,[string]$Key,[string]$Value)
    if(-not$Map.ContainsKey($Key)){$Map.Add($Key,(New-OrdinalSet))}
    [void]$Map[$Key].Add($Value)
}
function Test-Dag{
    param([object[]]$Nodes,[object[]]$Edges)
    $indegree=@{};$adj=@{}
    foreach($n in $Nodes){$key=[string]$n.family;$indegree[$key]=0;$adj[$key]=New-Object Collections.ArrayList}
    foreach($e in $Edges){
        $c=[string]$e.child_family;$p=[string]$e.parent_family
        if(-not$indegree.ContainsKey($c)-or-not$indegree.ContainsKey($p)){return $false}
        [void]$adj[$c].Add($p);$indegree[$p]=[int]$indegree[$p]+1
    }
    $q=New-Object Collections.Queue
    foreach($k in @($indegree.Keys)){if([int]$indegree[$k]-eq0){$q.Enqueue($k)}}
    $seen=0
    while($q.Count-gt0){
        $n=[string]$q.Dequeue();$seen++
        foreach($to in $adj[$n]){$indegree[$to]=[int]$indegree[$to]-1;if([int]$indegree[$to]-eq0){$q.Enqueue($to)}}
    }
    return ($seen-eq$indegree.Count)
}
function Validate-SnapshotSets{
    param([string]$CompactRoot)
    $rows=@(Import-Csv -LiteralPath (Join-Path $CompactRoot 'snapshot-sets.tsv') -Delimiter "`t" -Encoding UTF8)
    $map=@{}
    foreach($r in $rows){
        $names=if([string]::IsNullOrWhiteSpace([string]$r.snapshots)){@()}else{@(([string]$r.snapshots)-split'\|')}
        if([int]$r.snapshot_count-ne$names.Count){return [pscustomobject]@{ok=$false;map=$map;reason='snapshot_count mismatch for '+$r.snapshot_set_id}}
        if($names.Count-gt0-and(([string]$r.first_snapshot-ne$names[0])-or([string]$r.last_snapshot-ne$names[$names.Count-1]))){return [pscustomobject]@{ok=$false;map=$map;reason='first/last mismatch for '+$r.snapshot_set_id}}
        $map[[string]$r.snapshot_set_id]=$r
    }
    return [pscustomobject]@{ok=$true;map=$map;reason=''}
}
function Validate-SnapshotReferences{
    param([string]$CompactRoot,[hashtable]$Sets,[string[]]$Files)
    foreach($name in $Files){
        $path=Join-Path $CompactRoot $name
        $sr=New-Object IO.StreamReader($path,$utf8,$true,65536)
        try{
            $head=$sr.ReadLine().Split("`t")
            $setIdx=[Array]::IndexOf($head,'snapshot_set_id');$countIdx=[Array]::IndexOf($head,'snapshot_count');$firstIdx=[Array]::IndexOf($head,'first_seen');$lastIdx=[Array]::IndexOf($head,'last_seen')
            if($setIdx-lt0-or$countIdx-lt0-or$firstIdx-lt0-or$lastIdx-lt0){throw('snapshot columns missing: '+$name)}
            while($null-ne($line=$sr.ReadLine())){
                $p=$line.Split("`t");$id=$p[$setIdx]
                if(-not$Sets.ContainsKey($id)){return $false}
                $s=$Sets[$id]
                if([string]$p[$countIdx]-ne[string]$s.snapshot_count-or[string]$p[$firstIdx]-ne[string]$s.first_snapshot-or[string]$p[$lastIdx]-ne[string]$s.last_snapshot){return $false}
            }
        }finally{$sr.Dispose()}
    }
    return $true
}

if(Is-HelpToken $ArchiveInput){
    [Console]::Out.WriteLine('MVS Explorer Toolkit generated-database validator '+$ToolVersion)
    [Console]::Out.WriteLine('Usage: '+$Caller+' archive-db family-index compact-index output-folder [project-version]')
    exit 0
}
$ArchiveRoot=Resolve-Dir $ArchiveInput;$FamilyRoot=Resolve-Dir $FamilyInput;$CompactRoot=Resolve-Dir $CompactInput
if($null-eq$ArchiveRoot-or$null-eq$FamilyRoot-or$null-eq$CompactRoot){[Console]::Error.WriteLine('ERROR: one or more database roots are missing');exit 2}
if([string]::IsNullOrWhiteSpace($OutputInput)){[Console]::Error.WriteLine('ERROR: output folder required');exit 2}
if(Test-Path -LiteralPath $OutputInput){[Console]::Error.WriteLine('ERROR: output folder already exists: '+$OutputInput);exit 2}
$OutputRoot=[IO.Path]::GetFullPath($OutputInput)
[void](New-Item -ItemType Directory -Path $OutputRoot -Force)
if([string]::IsNullOrWhiteSpace($ProjectVersion)){$ProjectVersion='unknown'}

$script:ConsoleWriter=New-Object IO.StreamWriter((Join-Path $OutputRoot 'console.log'),$false,$utf8,65536);$script:ConsoleWriter.NewLine="`r`n";$script:ConsoleWriter.AutoFlush=$true
$script:ResultWriter=New-Object IO.StreamWriter((Join-Path $OutputRoot 'database-tests.tsv'),$false,$utf8,65536);$script:ResultWriter.NewLine="`r`n";$script:ResultWriter.AutoFlush=$true;$script:ResultWriter.WriteLine("index`tstatus`tcase`treason`telapsed_ms")
$script:ToolPerfWriter=New-Object IO.StreamWriter((Join-Path $OutputRoot 'all-family-tools-performance.tsv'),$false,$utf8,65536);$script:ToolPerfWriter.NewLine="`r`n";$script:ToolPerfWriter.AutoFlush=$true;$script:ToolPerfWriter.WriteLine("tool`tpattern`tstatus`trc`telapsed_ms`toutput_lines`tstderr")

$queryTools=@(Get-ChildItem -LiteralPath $ProjectRoot -File -Filter '*.bat'|Where-Object{$_.Name-match'^(?:print|read)_mvs_product_'}|Sort-Object Name)
$script:Total=25+$queryTools.Count
$validationStarted=Get-Date
Write-Line ('MVS Explorer Toolkit database validation '+$ToolVersion)
Write-Line ('Project version: '+$ProjectVersion)
Write-Line ('Archive database: '+$ArchiveRoot)
Write-Line ('Family database: '+$FamilyRoot)
Write-Line ('Compact database: '+$CompactRoot)
Write-Line ('Expected database tests: '+$script:Total)

# Load small reusable tables once.
$familyNodes=@();$memberships=@();$classifications=@();$parents=@();$unclassified=@()
try{$familyNodes=@(Import-Csv -LiteralPath (Join-Path $FamilyRoot 'family-nodes.tsv') -Delimiter "`t" -Encoding UTF8)}catch{}
try{$memberships=@(Import-Csv -LiteralPath (Join-Path $FamilyRoot 'product-family-memberships.tsv') -Delimiter "`t" -Encoding UTF8)}catch{}
try{$classifications=@(Import-Csv -LiteralPath (Join-Path $FamilyRoot 'product-classifications.tsv') -Delimiter "`t" -Encoding UTF8)}catch{}
try{$parents=@(Import-Csv -LiteralPath (Join-Path $FamilyRoot 'family-parent-relationships.tsv') -Delimiter "`t" -Encoding UTF8)}catch{}
try{$unclassified=@(Import-Csv -LiteralPath (Join-Path $FamilyRoot 'unclassified-products.tsv') -Delimiter "`t" -Encoding UTF8)}catch{}

$familyRequired=@('family-nodes.tsv','family-parent-relationships.tsv','classification-rules.tsv','product-classifications.tsv','product-family-memberships.tsv','product-ids.tsv','product-dates.tsv','product-files.tsv','product-hashes.tsv','product-notes.tsv','product-snapshots.tsv','unclassified-products.tsv','overrides-applied.tsv','family-index-summary.txt')
$compactRequired=@('snapshot-catalog.tsv','snapshot-sets.tsv','product-ids-all-ever.tsv','product-dates-all-ever.tsv','product-files-all-ever.tsv','product-file-hashes-all-ever.tsv','file-hashes-all-ever.tsv','product-notes-all-ever.tsv','product-presence-all-ever.tsv','filename-hash-conflicts.tsv','filename-hash-conflict-details.tsv','product-file-hash-conflicts.tsv','hash-filename-aliases.tsv','compact-index-summary.txt','product-classifications.tsv','product-family-memberships.tsv','family-nodes.tsv','family-parent-relationships.tsv')

Test-Case 'archive database required files present' {
    foreach($r in @('plan.tsv','runs.tsv','summary.txt','archive-output\fast-archive-summary.txt','archive-summary.html','quality-check\summary.txt')){if(-not(Test-Path -LiteralPath (Join-Path $ArchiveRoot $r) -PathType Leaf)){return $false}}
    return $true
}
Test-Case 'archive plan/runs align by index and identity' {
    $plan=@(Import-Csv -LiteralPath (Join-Path $ArchiveRoot 'plan.tsv') -Delimiter "`t" -Encoding UTF8)
    $runs=@(Import-Csv -LiteralPath (Join-Path $ArchiveRoot 'runs.tsv') -Delimiter "`t" -Encoding UTF8)
    if($plan.Count-ne$runs.Count-or$plan.Count-eq0){return $false}
    $seen=New-OrdinalSet
    for($i=0;$i-lt$plan.Count;$i++){
        if(-not$seen.Add([string]$runs[$i].index)){return $false}
        foreach($f in @('index','scope','snapshot','tool')){if([string]$plan[$i].$f-ne[string]$runs[$i].$f){return $false}}
    }
    return $true
}
Test-Case 'archive runs contain no FAIL status' {
    foreach($r in @(Import-Csv -LiteralPath (Join-Path $ArchiveRoot 'runs.tsv') -Delimiter "`t" -Encoding UTF8)){if([string]$r.status-eq'FAIL'){return $false}}
    return $true
}
Test-Case 'archive summary status counters match runs.tsv' {
    $sum=Read-SummaryMap (Join-Path $ArchiveRoot 'summary.txt')
    $counts=@{PASS=0;NO_RESULT=0;SOURCE_MISSING=0;FAIL=0}
    $runs=@(Import-Csv -LiteralPath (Join-Path $ArchiveRoot 'runs.tsv') -Delimiter "`t" -Encoding UTF8)
    foreach($r in $runs){if($counts.ContainsKey([string]$r.status)){$counts[[string]$r.status]++}}
    if([long]$sum['Planned invocations']-ne$runs.Count-or[long]$sum['Completed invocations']-ne$runs.Count){return $false}
    foreach($k in $counts.Keys){if([long]$sum[$k]-ne[long]$counts[$k]){return $false}}
    return $true
}
Test-Case 'archive report/output/quality summaries are nonempty' {
    foreach($r in @('archive-summary.html','archive-output\fast-archive-summary.txt','quality-check\summary.txt')){$p=Join-Path $ArchiveRoot $r;if((Get-Item -LiteralPath $p).Length-le0){return $false}}
    return $true
}

Test-Case 'full family database required files present' {
    foreach($r in $familyRequired){if(-not(Test-Path -LiteralPath (Join-Path $FamilyRoot $r) -PathType Leaf)){return $false}}
    return $true
}
Test-Case 'full family summary counts match all source-backed tables' {
    $s=Read-SummaryMap (Join-Path $FamilyRoot 'family-index-summary.txt')
    $checks=@(
        @('Classified/review products','product-classifications.tsv'),
        @('Family memberships','product-family-memberships.tsv'),
        @('Product ID observations','product-ids.tsv'),
        @('Product date observations','product-dates.tsv'),
        @('Product file observations','product-files.tsv'),
        @('Product hash observations','product-hashes.tsv'),
        @('Product note observations','product-notes.tsv'),
        @('Product snapshot observations','product-snapshots.tsv'),
        @('Unclassified/excluded products','unclassified-products.tsv'),
        @('Family nodes','family-nodes.tsv'),
        @('Family parent relationships','family-parent-relationships.tsv')
    )
    foreach($c in $checks){if([long]$s[$c[0]]-ne(Count-DataRows (Join-Path $FamilyRoot $c[1]))){return $false}}
    $rawCount=@(Get-ChildItem -LiteralPath (Join-Path $FamilyRoot 'raw-html') -File -Filter '*.html').Count
    return ([long]$s['Raw note HTML blobs']-eq$rawCount)
}
Test-Case 'family memberships reference existing family nodes' {
    $set=New-StringSet;foreach($n in $familyNodes){[void]$set.Add([string]$n.family)}
    foreach($m in $memberships){if(-not$set.Contains([string]$m.family)){return $false}}
    return $true
}
Test-Case 'family memberships reference classified/review product titles' {
    $set=New-StringSet;foreach($c in $classifications){[void]$set.Add([string]$c.product_title)}
    foreach($m in $memberships){if(-not$set.Contains([string]$m.product_title)){return $false}}
    return $true
}
Test-Case 'family parent relationships reference existing nodes' {
    $set=New-StringSet;foreach($n in $familyNodes){[void]$set.Add([string]$n.family)}
    foreach($e in $parents){if(-not$set.Contains([string]$e.child_family)-or-not$set.Contains([string]$e.parent_family)){return $false}}
    return $true
}
Test-Case 'family hierarchy is acyclic' {return (Test-Dag $familyNodes $parents)}
Test-Case 'full family note references resolve to raw HTML blobs' {
    $raw=New-OrdinalSet;foreach($f in @(Get-ChildItem -LiteralPath (Join-Path $FamilyRoot 'raw-html') -File -Filter '*.html')){[void]$raw.Add($f.BaseName.ToLowerInvariant())}
    $sr=New-Object IO.StreamReader((Join-Path $FamilyRoot 'product-notes.tsv'),$utf8,$true,65536)
    try{$head=$sr.ReadLine().Split("`t");$idx=[Array]::IndexOf($head,'raw_html_sha256');while($null-ne($line=$sr.ReadLine())){$p=$line.Split("`t");if($idx-lt0-or$idx-ge$p.Count-or-not$raw.Contains($p[$idx].ToLowerInvariant())){return $false}}}finally{$sr.Dispose()}
    return $true
}
Test-Case 'full family raw HTML filenames equal content SHA256' {
    foreach($f in @(Get-ChildItem -LiteralPath (Join-Path $FamilyRoot 'raw-html') -File -Filter '*.html')){if((Get-FileSha256 $f.FullName)-ne$f.BaseName.ToLowerInvariant()){return $false}}
    return $true
}

Test-Case 'compact family database required files present' {
    foreach($r in $compactRequired){if(-not(Test-Path -LiteralPath (Join-Path $CompactRoot $r) -PathType Leaf)){return $false}}
    return $true
}
Test-Case 'compact taxonomy/classification metadata is byte-identical to full family database' {
    foreach($r in @('family-nodes.tsv','family-parent-relationships.tsv','classification-rules.tsv','product-classifications.tsv','product-family-memberships.tsv','unclassified-products.tsv','overrides-applied.tsv')){if((Get-FileSha256 (Join-Path $FamilyRoot $r))-ne(Get-FileSha256 (Join-Path $CompactRoot $r))){return $false}}
    return $true
}
$snapshotValidation=$null
Test-Case 'compact snapshot-set dictionary is internally consistent' {
    $script:snapshotValidation=Validate-SnapshotSets $CompactRoot
    return [bool]$script:snapshotValidation.ok
}
Test-Case 'every compact snapshot-set reference resolves with exact count/first/last' {
    if($null-eq$script:snapshotValidation-or-not$script:snapshotValidation.ok){$script:snapshotValidation=Validate-SnapshotSets $CompactRoot}
    return (Validate-SnapshotReferences $CompactRoot $script:snapshotValidation.map @('product-ids-all-ever.tsv','product-dates-all-ever.tsv','product-files-all-ever.tsv','product-file-hashes-all-ever.tsv','file-hashes-all-ever.tsv','product-notes-all-ever.tsv','product-presence-all-ever.tsv','filename-hash-conflict-details.tsv'))
}
Test-Case 'compact snapshot_count sums exactly reconstruct full observation totals' {
    $full=Read-SummaryMap (Join-Path $FamilyRoot 'family-index-summary.txt')
    $pairs=@(
        @('Product ID observations','product-ids-all-ever.tsv'),
        @('Product date observations','product-dates-all-ever.tsv'),
        @('Product file observations','product-files-all-ever.tsv'),
        @('Product hash observations','product-file-hashes-all-ever.tsv'),
        @('Product note observations','product-notes-all-ever.tsv'),
        @('Product snapshot observations','product-presence-all-ever.tsv')
    )
    foreach($p in $pairs){if([long]$full[$p[0]]-ne(Sum-NumericColumn (Join-Path $CompactRoot $p[1]) 'snapshot_count')){return $false}}
    return $true
}
Test-Case 'compact summary counts match compact fact/exception tables' {
    $s=Read-SummaryMap (Join-Path $CompactRoot 'compact-index-summary.txt')
    $pairs=@(
        @('Product IDs all-ever','product-ids-all-ever.tsv'),@('Product dates all-ever','product-dates-all-ever.tsv'),
        @('Product files all-ever','product-files-all-ever.tsv'),@('Product file hashes all-ever','product-file-hashes-all-ever.tsv'),
        @('Global file-hash tuples','file-hashes-all-ever.tsv'),@('Product notes all-ever','product-notes-all-ever.tsv'),
        @('Product presence facts all-ever','product-presence-all-ever.tsv'),@('Filename+algorithm conflicts','filename-hash-conflicts.tsv'),
        @('Product+filename+algorithm hash disagreements','product-file-hash-conflicts.tsv'),@('Hash aliases across filenames','hash-filename-aliases.tsv')
    )
    foreach($p in $pairs){if([long]$s[$p[0]]-ne(Count-DataRows (Join-Path $CompactRoot $p[1]))){return $false}}
    return $true
}
Test-Case 'filename+algorithm conflict ledger recomputes from global file-hash tuples' {
    $map=New-SetMap
    foreach($r in @(Import-Csv -LiteralPath (Join-Path $CompactRoot 'file-hashes-all-ever.tsv') -Delimiter "`t" -Encoding UTF8)){Add-SetMap $map (([string]$r.filename)+$US+([string]$r.algorithm)) ([string]$r.hash)}
    $expected=New-StringSet;foreach($k in $map.Keys){if($map[$k].Count-gt1){[void]$expected.Add($k)}}
    $actual=New-StringSet;foreach($r in @(Import-Csv -LiteralPath (Join-Path $CompactRoot 'filename-hash-conflicts.tsv') -Delimiter "`t" -Encoding UTF8)){[void]$actual.Add(([string]$r.filename)+$US+([string]$r.algorithm))}
    return ($expected.SetEquals($actual))
}
Test-Case 'same-product filename/hash disagreement ledger recomputes exactly' {
    $map=New-SetMap
    foreach($r in @(Import-Csv -LiteralPath (Join-Path $CompactRoot 'product-file-hashes-all-ever.tsv') -Delimiter "`t" -Encoding UTF8)){Add-SetMap $map (([string]$r.product_title)+$US+([string]$r.filename)+$US+([string]$r.algorithm)) ([string]$r.hash)}
    $expected=New-StringSet;foreach($k in $map.Keys){if($map[$k].Count-gt1){[void]$expected.Add($k)}}
    $actual=New-StringSet;foreach($r in @(Import-Csv -LiteralPath (Join-Path $CompactRoot 'product-file-hash-conflicts.tsv') -Delimiter "`t" -Encoding UTF8)){[void]$actual.Add(([string]$r.product_title)+$US+([string]$r.filename)+$US+([string]$r.algorithm))}
    return ($expected.SetEquals($actual))
}
Test-Case 'hash-to-multiple-filename alias ledger recomputes exactly' {
    $map=New-SetMap
    foreach($r in @(Import-Csv -LiteralPath (Join-Path $CompactRoot 'file-hashes-all-ever.tsv') -Delimiter "`t" -Encoding UTF8)){Add-SetMap $map (([string]$r.algorithm)+$US+([string]$r.hash)) ([string]$r.filename)}
    $expected=New-StringSet;foreach($k in $map.Keys){if($map[$k].Count-gt1){[void]$expected.Add($k)}}
    $actual=New-StringSet;foreach($r in @(Import-Csv -LiteralPath (Join-Path $CompactRoot 'hash-filename-aliases.tsv') -Delimiter "`t" -Encoding UTF8)){[void]$actual.Add(([string]$r.algorithm)+$US+([string]$r.hash))}
    return ($expected.SetEquals($actual))
}
Test-Case 'compact raw-note references and content-addressed blobs are valid' {
    $raw=New-OrdinalSet
    foreach($f in @(Get-ChildItem -LiteralPath (Join-Path $CompactRoot 'raw-html') -File -Filter '*.html')){if((Get-FileSha256 $f.FullName)-ne$f.BaseName.ToLowerInvariant()){return $false};[void]$raw.Add($f.BaseName.ToLowerInvariant())}
    foreach($r in @(Import-Csv -LiteralPath (Join-Path $CompactRoot 'product-notes-all-ever.tsv') -Delimiter "`t" -Encoding UTF8)){if(-not$raw.Contains(([string]$r.raw_html_sha256).ToLowerInvariant())){return $false}}
    return $true
}
Test-Case 'compact provenance/pairing semantic flags are safe' {
    $s=Read-SummaryMap (Join-Path $CompactRoot 'compact-index-summary.txt')
    return (([string]$s['Exact snapshot provenance preserved via snapshot_set_id']).ToLowerInvariant()-eq'true'-and([string]$s['SHA1/SHA256 pairings inferred by filename']).ToLowerInvariant()-eq'false')
}
Test-Case 'all 32 public family query tools are present for final-database smoke execution' {return ($queryTools.Count-eq32)}

# Prepare low-volume exact patterns for every query direction.
$familyCounts=@{};foreach($m in $memberships){$k=[string]$m.family;if(-not$familyCounts.ContainsKey($k)){$familyCounts[$k]=0};$familyCounts[$k]++}
$membersByTitle=@{};foreach($m in $memberships){$t=[string]$m.product_title;if(-not$membersByTitle.ContainsKey($t)){$membersByTitle[$t]=New-Object Collections.ArrayList};[void]$membersByTitle[$t].Add($m)}
function Get-NarrowFamily{
    param([string]$Title)
    if(-not$membersByTitle.ContainsKey($Title)){return ''}
    $rows=@($membersByTitle[$Title]|Sort-Object @{Expression={$familyCounts[[string]$_.family]}},family)
    if($rows.Count-eq0){return ''};return [string]$rows[0].family
}
$firstMembership=if($memberships.Count-gt0){$memberships[0]}else{$null}
$firstId=Get-FirstTsvRow (Join-Path $FamilyRoot 'product-ids.tsv')
$firstDate=Get-FirstTsvRow (Join-Path $FamilyRoot 'product-dates.tsv')
$firstFile=Get-FirstTsvRow (Join-Path $FamilyRoot 'product-files.tsv')
$firstHash=Get-FirstTsvRow (Join-Path $FamilyRoot 'product-hashes.tsv')
$firstSnapshot=Get-FirstTsvRow (Join-Path $FamilyRoot 'product-snapshots.tsv')
$firstNote=Get-FirstTsvRow (Join-Path $FamilyRoot 'product-notes.tsv')
$releaseClass=@($classifications|Where-Object{-not[string]::IsNullOrWhiteSpace([string]$_.release)}|Select-Object -First 1)
$firstParent=if($parents.Count-gt0){$parents[0]}else{$null}

function Pattern-ForTool{
    param([string]$Name)
    $v=''
    switch -Regex($Name){
        'product_titles_from_family' {$v=Get-NarrowFamily ([string]$firstMembership.product_title);break}
        'product_families_from_title' {$v=[string]$firstMembership.product_title;break}
        'product_ids_from_family' {$v=Get-NarrowFamily ([string]$firstId.product_title);break}
        'product_families_from_id' {$v=[string]$firstId.id;break}
        'product_dates_from_family' {$v=Get-NarrowFamily ([string]$firstDate.product_title);break}
        'product_families_from_date' {$v=[string]$firstDate.date;break}
        'product_filenames_from_family' {$v=Get-NarrowFamily ([string]$firstFile.product_title);break}
        'product_families_from_filename' {$v=[string]$firstFile.filename;break}
        'product_hashes_from_family' {$v=Get-NarrowFamily ([string]$firstHash.product_title);break}
        'product_families_from_hash' {$v=[string]$firstHash.hash;break}
        'product_snapshots_from_family' {$v=Get-NarrowFamily ([string]$firstSnapshot.product_title);break}
        'product_families_from_snapshot' {$v=[string]$firstSnapshot.snapshot;break}
        'product_family_parents_from_family' {$v=[string]$firstParent.child_family;break}
        'product_family_children_from_family' {$v=[string]$firstParent.parent_family;break}
        'product_notes_from_family' {$v=Get-NarrowFamily ([string]$firstNote.product_title);break}
        'product_releases_from_family' {$v=Get-NarrowFamily ([string]$releaseClass[0].product_title);break}
    }
    return (Escape-Wildcard $v)
}

foreach($tool in $queryTools){
    $pattern=Pattern-ForTool $tool.BaseName
    $name='real family query tool '+$tool.BaseName
    $sw=[Diagnostics.Stopwatch]::StartNew()
    try{
        if([string]::IsNullOrWhiteSpace($pattern)){throw'could not derive nonempty real-data sample pattern'}
        $run=Invoke-BatchCapture $tool.FullName @($FamilyRoot,$pattern)
        $sw.Stop()
        $status=if($run.rc-eq0-and-not[string]::IsNullOrWhiteSpace($run.stdout)-and[string]::IsNullOrWhiteSpace($run.stderr)){'PASS'}else{'FAIL'}
        $script:ToolPerfWriter.WriteLine((@($tool.BaseName,$pattern,$status,$run.rc,$run.elapsed_ms,$run.output_lines,$run.stderr)|ForEach-Object{Clean-Tsv $_})-join"`t");$script:ToolPerfWriter.Flush()
        if($status-eq'PASS'){Add-Result 'PASS' $name '' $sw.ElapsedMilliseconds}else{Add-Result 'FAIL' $name ('rc='+$run.rc+' lines='+$run.output_lines+' stderr='+$run.stderr) $sw.ElapsedMilliseconds}
    }catch{
        $sw.Stop()
        $script:ToolPerfWriter.WriteLine((@($tool.BaseName,$pattern,'FAIL',-1,$sw.ElapsedMilliseconds,0,$_.Exception.Message)|ForEach-Object{Clean-Tsv $_})-join"`t");$script:ToolPerfWriter.Flush()
        Add-Result 'FAIL' $name $_.Exception.Message $sw.ElapsedMilliseconds
    }
}

$finished=Get-Date
$summary=@(
    'MVS Explorer Toolkit generated database validation',
    ('Project version: '+$ProjectVersion),
    ('Tool version: '+$ToolVersion),
    ('Started: '+$validationStarted.ToString('o')),
    ('Finished: '+$finished.ToString('o')),
    ('Duration: '+($finished-$validationStarted).ToString()),
    ('Passed: '+$script:Passed),
    ('Failed: '+$script:Failed),
    ('Total: '+($script:Passed+$script:Failed)),
    ('Family query tools executed: '+$queryTools.Count),
    ('Archive database: '+$ArchiveRoot),
    ('Family database: '+$FamilyRoot),
    ('Compact database: '+$CompactRoot),
    ('Results: '+$OutputRoot)
)
[IO.File]::WriteAllText((Join-Path $OutputRoot 'summary.txt'),(($summary-join[Environment]::NewLine)+[Environment]::NewLine),$utf8)
Write-Line ('SUMMARY: passed='+$script:Passed+' failed='+$script:Failed+' total='+($script:Passed+$script:Failed))

$script:ToolPerfWriter.Dispose();$script:ResultWriter.Dispose();$script:ConsoleWriter.Dispose()
if($script:Failed-gt0){exit 1}
exit 0
:_MVSDatabaseValidation_end
