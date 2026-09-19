$ErrorActionPreference='Stop'
$utf8=New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8

$InputPath=[string]$env:mvsp_results
$Caller=[string]$env:mvsp_caller
$Version=[string]$env:mvsp_version

function Fail{param([int]$Code,[string]$Message)[Console]::Error.WriteLine('ERROR: '+$Message);[Environment]::Exit($Code)}
if([string]::IsNullOrWhiteSpace($InputPath) -or @('--help','-h','-?','/h','/?') -contains $InputPath){
    [Console]::Out.WriteLine('MVS Explorer Toolkit archive-sweep performance analyzer '+$Version)
    [Console]::Out.WriteLine('Usage: '+$Caller+' archive-sweep-results-folder')
    exit 0
}
if(-not(Test-Path -LiteralPath $InputPath -PathType Container)){Fail 3 ('Results folder not found: '+$InputPath)}
$root=(Resolve-Path -LiteralPath $InputPath).Path
$runsPath=Join-Path $root 'runs.tsv'
$planPath=Join-Path $root 'plan.tsv'
if(-not(Test-Path -LiteralPath $runsPath -PathType Leaf)){Fail 4 'runs.tsv is missing.'}
if(-not(Test-Path -LiteralPath $planPath -PathType Leaf)){Fail 4 'plan.tsv is missing.'}

$runs=@(Import-Csv -LiteralPath $runsPath -Delimiter "`t")
$plan=@(Import-Csv -LiteralPath $planPath -Delimiter "`t")
$planByIndex=@{}
foreach($p in $plan){$planByIndex[[string]$p.index]=$p}

$joined=New-Object System.Collections.ArrayList
foreach($r in $runs){
    $p=$planByIndex[[string]$r.index]
    $elapsed=0L
    [void][long]::TryParse([string]$r.elapsed_ms,[ref]$elapsed)
    $stdout=0L
    [void][long]::TryParse([string]$r.stdout_bytes,[ref]$stdout)
    [void]$joined.Add([pscustomobject]@{
        index=[string]$r.index;executor=[string]$r.executor;scope=[string]$r.scope;snapshot=[string]$r.snapshot
        tool=[string]$r.tool;family=$(if($null -ne $p){[string]$p.family}else{''})
        operation=$(if($null -ne $p){[string]$p.operation}else{''});status=[string]$r.status
        elapsed_ms=$elapsed;stdout_bytes=$stdout
    })
}

function Write-Tsv{param([string]$Path,[object[]]$Rows)
    if($Rows.Count -eq 0){[IO.File]::WriteAllText($Path,'',$utf8);return}
    $Rows | Export-Csv -LiteralPath $Path -Delimiter "`t" -NoTypeInformation -Encoding UTF8
    # Windows PowerShell 5.1 Export-Csv writes a BOM. Rewrite as UTF-8 no BOM.
    $text=[IO.File]::ReadAllText($Path)
    [IO.File]::WriteAllText($Path,$text,$utf8)
}

$toolRows=New-Object System.Collections.ArrayList
foreach($g in @($joined | Group-Object tool)){
    $vals=@($g.Group)
    $times=@($vals | ForEach-Object {[long]$_.elapsed_ms})
    $outs=@($vals | ForEach-Object {[long]$_.stdout_bytes})
    $total=($times | Measure-Object -Sum).Sum
    $max=($times | Measure-Object -Maximum).Maximum
    [void]$toolRows.Add([pscustomobject]@{
        tool=$g.Name;family=[string]$vals[0].family;operation=[string]$vals[0].operation
        completed=$vals.Count;total_elapsed_ms=[long]$total
        mean_elapsed_ms=$(if($vals.Count){[math]::Round([double]$total/$vals.Count,2)}else{0})
        max_elapsed_ms=[long]$max
        total_stdout_bytes=[long](($outs | Measure-Object -Sum).Sum)
    })
}
$toolRows=@($toolRows | Sort-Object total_elapsed_ms -Descending)
Write-Tsv (Join-Path $root 'performance-by-tool.tsv') $toolRows

$familyRows=New-Object System.Collections.ArrayList
foreach($g in @($joined | Group-Object family,operation)){
    $vals=@($g.Group);$times=@($vals|ForEach-Object{[long]$_.elapsed_ms});$total=($times|Measure-Object -Sum).Sum
    [void]$familyRows.Add([pscustomobject]@{
        family=[string]$vals[0].family;operation=[string]$vals[0].operation;completed=$vals.Count
        total_elapsed_ms=[long]$total;mean_elapsed_ms=$(if($vals.Count){[math]::Round([double]$total/$vals.Count,2)}else{0})
        max_elapsed_ms=[long](($times|Measure-Object -Maximum).Maximum)
    })
}
$familyRows=@($familyRows|Sort-Object total_elapsed_ms -Descending)
Write-Tsv (Join-Path $root 'performance-by-family.tsv') $familyRows

$slow=@($joined|Sort-Object elapsed_ms -Descending|Select-Object -First 100)
Write-Tsv (Join-Path $root 'slowest-100-invocations.tsv') $slow

$batchPath=Join-Path $root 'fast-batches.tsv'
$batchCount=0;$batchMs=0L
if(Test-Path -LiteralPath $batchPath -PathType Leaf){
    $batches=@(Import-Csv -LiteralPath $batchPath -Delimiter "`t")
    $batchCount=$batches.Count
    foreach($b in $batches){$v=0L;if([long]::TryParse([string]$b.elapsed_ms,[ref]$v)){$batchMs+=$v}}
}
$statusCounts=@{}
foreach($name in @('PASS','NO_RESULT','SOURCE_MISSING','FAIL')){$statusCounts[$name]=@($joined|Where-Object{$_.status-eq$name}).Count}
$logicalMs=[long](($joined|Measure-Object elapsed_ms -Sum).Sum)
$summary=@(
    'MVS Explorer Toolkit archive-sweep performance analysis',
    '',
    'Results folder: '+$root,
    'Completed logical checks: '+$joined.Count,
    'PASS: '+$statusCounts.PASS,
    'NO_RESULT: '+$statusCounts.NO_RESULT,
    'SOURCE_MISSING: '+$statusCounts.SOURCE_MISSING,
    'FAIL: '+$statusCounts.FAIL,
    'Logical per-check elapsed total ms: '+$logicalMs,
    'Fast combined batches: '+$batchCount,
    'Fast combined batch wall-time total ms: '+$batchMs,
    '',
    'See performance-by-tool.tsv, performance-by-family.tsv, and slowest-100-invocations.tsv.'
)-join[Environment]::NewLine
[IO.File]::WriteAllText((Join-Path $root 'performance-summary.txt'),$summary+[Environment]::NewLine,$utf8)
[Console]::Out.WriteLine($summary)
exit 0
