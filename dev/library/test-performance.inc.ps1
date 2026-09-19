$ErrorActionPreference='Stop'
$utf8=New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8
$ResultsInput=[string]$env:mvstp_results
$Strict=([string]$env:mvstp_strict -eq '1')
$ThresholdMs=30000L
if(-not[string]::IsNullOrWhiteSpace([string]$env:mvstp_threshold)){
    $v=0L;if(-not[long]::TryParse([string]$env:mvstp_threshold,[ref]$v)-or$v-lt1){[Console]::Error.WriteLine('ERROR: invalid threshold');exit 2};$ThresholdMs=$v
}
$Caller=[string]$env:mvstp_caller
$Version=[string]$env:mvstp_version
function Fail {param([int]$Code,[string]$Message)[Console]::Error.WriteLine('ERROR: '+$Message);exit $Code}
function Median {param([double[]]$Values)if($null-eq$Values-or$Values.Count-eq0){return 0.0};$s=@($Values|Sort-Object);$n=$s.Count;if(($n%2)-eq1){return [double]$s[[int]($n/2)]};return([double]$s[$n/2-1]+[double]$s[$n/2])/2.0}
function Pctl {param([double[]]$Values,[double]$P)if($null-eq$Values-or$Values.Count-eq0){return 0.0};$s=@($Values|Sort-Object);return [double]$s[[int][Math]::Floor(($s.Count-1)*$P)]}
function Tsv {param([AllowNull()][AllowEmptyString()][string]$Value)if($null-eq$Value){return ''};return $Value.Replace("`t",' ').Replace("`r",' ').Replace("`n",' ')}
function Tool-FromCase {
    param([string]$Case)
    if([string]::IsNullOrWhiteSpace($Case)){return ''}
    $name=$Case.Trim()
    $name=[regex]::Replace($name,'\s+\[[^\]]+\]\s*$','')
    return $name
}
if(@('--help','-h','-?','/h','/?')-contains$ResultsInput){[Console]::Out.WriteLine('Usage: '+$Caller+' test-results-folder [--strict] [threshold-ms]');exit 0}
if([string]::IsNullOrWhiteSpace($ResultsInput)-or-not(Test-Path -LiteralPath $ResultsInput -PathType Container)){Fail 3 ('Test results folder not found: '+$ResultsInput)}
$Results=(Resolve-Path -LiteralPath $ResultsInput).Path
$path=Join-Path $Results 'all-results.tsv'
if(-not(Test-Path -LiteralPath $path -PathType Leaf)){Fail 4 ('all-results.tsv missing: '+$path)}
$rows=@(Import-Csv -LiteralPath $path -Delimiter "`t")
$timed=@($rows|Where-Object{[string]$_.elapsed_ms-match'^\d+$'})
$out=Join-Path $Results 'performance'
if(Test-Path -LiteralPath $out){Remove-Item -LiteralPath $out -Recurse -Force}
[void](New-Item -ItemType Directory -Path $out -Force)
$sorted=@($timed|Sort-Object {[int64]$_.elapsed_ms} -Descending)
$sb=New-Object Text.StringBuilder;[void]$sb.Append("index`tscope`tstatus`tcase`telapsed_ms`n")
foreach($r in $sorted){[void]$sb.Append((Tsv $r.index)+"`t"+(Tsv $r.scope)+"`t"+(Tsv $r.status)+"`t"+(Tsv $r.case)+"`t"+(Tsv $r.elapsed_ms)+"`n")}
[IO.File]::WriteAllText((Join-Path $out 'all-timed-cases.tsv'),$sb.ToString(),$utf8)
$outliers=@($sorted|Where-Object{[int64]$_.elapsed_ms-gt$ThresholdMs})
$sb=New-Object Text.StringBuilder;[void]$sb.Append("index`tscope`tstatus`ttool`tcase`telapsed_ms`tthreshold_ms`n")
foreach($r in $outliers){
    $tool=Tool-FromCase ([string]$r.case)
    [void]$sb.Append((Tsv $r.index)+"`t"+(Tsv $r.scope)+"`t"+(Tsv $r.status)+"`t"+(Tsv $tool)+"`t"+(Tsv $r.case)+"`t"+(Tsv $r.elapsed_ms)+"`t"+$ThresholdMs+"`n")
}
[IO.File]::WriteAllText((Join-Path $out 'performance-outliers.tsv'),$sb.ToString(),$utf8)
$vals=[double[]]@($timed|ForEach-Object{[double]$_.elapsed_ms})

# Aggregate actual timed public-tool calls by tool/case base so repeated lookup/hash
# cases expose both total cost and tail latency.
$toolRows=New-Object System.Collections.ArrayList
$decorated=@($timed|ForEach-Object{
    [pscustomobject]@{tool=(Tool-FromCase ([string]$_.case));elapsed_ms=[double]$_.elapsed_ms}
})
foreach($g in $decorated|Where-Object{-not[string]::IsNullOrWhiteSpace($_.tool)}|Group-Object tool){
    $v=[double[]]@($g.Group|ForEach-Object{[double]$_.elapsed_ms})
    [void]$toolRows.Add([pscustomobject]@{
        tool=$g.Name;calls=$v.Count;total_ms=[math]::Round((($v|Measure-Object -Sum).Sum),2)
        median_ms=[math]::Round((Median $v),2);p95_ms=[math]::Round((Pctl $v 0.95),2);max_ms=[math]::Round((Pctl $v 1),2)
    })
}
$toolRows=@($toolRows|Sort-Object total_ms -Descending)
$sb=New-Object Text.StringBuilder;[void]$sb.Append("tool`tcalls`ttotal_ms`tmedian_ms`tp95_ms`tmax_ms`n")
foreach($r in $toolRows){[void]$sb.Append((Tsv $r.tool)+"`t"+$r.calls+"`t"+$r.total_ms+"`t"+$r.median_ms+"`t"+$r.p95_ms+"`t"+$r.max_ms+"`n")}
[IO.File]::WriteAllText((Join-Path $out 'performance-by-tool.tsv'),$sb.ToString(),$utf8)

$scopeRows=New-Object System.Collections.ArrayList
foreach($g in $timed|Group-Object scope){
    $v=[double[]]@($g.Group|ForEach-Object{[double]$_.elapsed_ms})
    [void]$scopeRows.Add([pscustomobject]@{scope=$g.Name;calls=$v.Count;median_ms=[math]::Round((Median $v),2);p95_ms=[math]::Round((Pctl $v 0.95),2);max_ms=[math]::Round((Pctl $v 1),2)})
}
$sb=New-Object Text.StringBuilder;[void]$sb.Append("scope`tcalls`tmedian_ms`tp95_ms`tmax_ms`n")
foreach($r in $scopeRows){[void]$sb.Append((Tsv $r.scope)+"`t"+$r.calls+"`t"+$r.median_ms+"`t"+$r.p95_ms+"`t"+$r.max_ms+"`n")}
[IO.File]::WriteAllText((Join-Path $out 'performance-by-scope.tsv'),$sb.ToString(),$utf8)
$summary=@(
'MVS Explorer Toolkit public regression performance',
'',
'Timed cases: '+$timed.Count,
'Threshold milliseconds: '+$ThresholdMs,
'Outliers: '+$outliers.Count,
'Median milliseconds: '+[math]::Round((Median $vals),2),
'P95 milliseconds: '+[math]::Round((Pctl $vals 0.95),2),
'Maximum milliseconds: '+[math]::Round((Pctl $vals 1),2),
'Strict: '+$Strict
)
[IO.File]::WriteAllText((Join-Path $out 'summary.txt'),(($summary-join[Environment]::NewLine)+[Environment]::NewLine),$utf8)
foreach($line in $summary){[Console]::Out.WriteLine($line)}
if($Strict-and$outliers.Count-gt0){exit 1}
exit 0
