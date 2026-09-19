@echo off
:setup
setlocal DisableDelayedExpansion
set "app.version=0.1.0"
set "app.name=build_archive_html_report"
set "app.rc=0"
set "app.self=%~f0"
set "mvsrep_results=%~1"
set "mvsrep_output=%~2"
set "mvsrep_exclusions=%~3"
set "mvsrep_script_root=%~dp0"
set "mvsrep_caller=%~nx0"
set "mvsrep_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSArchiveReport"
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

:_MVSArchiveReport_start
$ErrorActionPreference='Stop'
$utf8=New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8

$ResultsInput=[string]$env:mvsrep_results
$OutputInput=[string]$env:mvsrep_output
$ExclusionsInput=[string]$env:mvsrep_exclusions
$ScriptRoot=([string]$env:mvsrep_script_root).TrimEnd('\','/')
$Caller=[string]$env:mvsrep_caller
$Version=[string]$env:mvsrep_version

function Fail { param([int]$Code,[string]$Message) [Console]::Error.WriteLine('ERROR: '+$Message); [Environment]::Exit($Code) }
function Resolve-Folder {
    param([string]$Path)
    if([string]::IsNullOrWhiteSpace($Path) -or -not(Test-Path -LiteralPath $Path -PathType Container)){return $null}
    return (Resolve-Path -LiteralPath $Path).Path
}
function Read-Tsv {
    param([string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return @()}
    return @(Import-Csv -LiteralPath $Path -Delimiter "`t")
}
function Html {
    param([AllowNull()][AllowEmptyString()][string]$Text)
    if($null-eq$Text){return ''}
    return [System.Net.WebUtility]::HtmlEncode($Text)
}
function Json {
    param([object]$Value,[int]$Depth=5)
    $j=$Value | ConvertTo-Json -Compress -Depth $Depth
    if($null-eq$j){$j='[]'}
    return $j.Replace('</','<\/')
}
function Read-KeyValue {
    param([string]$Path)
    $map=[ordered]@{}
    foreach($row in Read-Tsv $Path){$map[[string]$row.metric]=[string]$row.value}
    return $map
}
function Percentile {
    param([double[]]$Values,[double]$P)
    if($null-eq$Values -or $Values.Count-eq0){return 0.0}
    $sorted=@($Values | Sort-Object)
    $idx=[int][Math]::Floor(($sorted.Count-1)*$P)
    return [double]$sorted[$idx]
}

if(@('--help','-h','-?','/h','/?') -contains $ResultsInput){
    [Console]::Out.WriteLine('MVS Explorer Toolkit interactive archive report '+$Version)
    [Console]::Out.WriteLine('Usage: '+$Caller+' results-folder [output-html] [exclusions-tsv]')
    exit 0
}
$Results=Resolve-Folder $ResultsInput
if($null-eq$Results){Fail 3 ('Results folder not found: '+$ResultsInput)}
$evolution=Join-Path (Join-Path $Results 'archive-output') 'evolution'
if(-not(Test-Path -LiteralPath $evolution -PathType Container)){Fail 4 ('Evolution output missing: '+$evolution)}

if([string]::IsNullOrWhiteSpace($OutputInput)){$Output=Join-Path $Results 'archive-summary.html'}
else{
    $Output=$OutputInput
    if(-not[IO.Path]::IsPathRooted($Output)){$Output=Join-Path (Get-Location).Path $Output}
    $Output=[IO.Path]::GetFullPath($Output)
}
if([string]::IsNullOrWhiteSpace($ExclusionsInput)){$ExclusionsInput=Join-Path $ScriptRoot 'archive-exclusions.tsv'}
$exclusions=@()
if(Test-Path -LiteralPath $ExclusionsInput -PathType Leaf){$exclusions=@(Read-Tsv $ExclusionsInput)}

$contrib=@(Read-Tsv (Join-Path $evolution 'per-dump-contributions.tsv'))
$quality=@(Read-Tsv (Join-Path $evolution 'per-dump-quality.tsv'))
$transitions=@(Read-Tsv (Join-Path $evolution 'variant-id-transitions.tsv'))
$suggestions=@(Read-Tsv (Join-Path $evolution 'suggested-exclusions.tsv'))
$notes=@(Read-Tsv (Join-Path (Join-Path $evolution 'notes') 'note-versions.tsv'))
$domainAdds=@(Read-Tsv (Join-Path $evolution 'per-dump-domain-additions.tsv'))
$retention=@(Read-Tsv (Join-Path $evolution 'per-dump-retention.tsv'))
$evoSummary=Read-KeyValue (Join-Path $evolution 'summary.tsv')
$runs=@(Read-Tsv (Join-Path $Results 'runs.tsv'))
$batches=@(Read-Tsv (Join-Path $Results 'fast-batches.tsv'))

$statusCounts=[ordered]@{PASS=0;NO_RESULT=0;SOURCE_MISSING=0;FAIL=0}
foreach($r in $runs){if($statusCounts.Contains([string]$r.status)){$statusCounts[[string]$r.status]++}}

$perf=@()
if($batches.Count-gt0){
    $perf=@($batches | ForEach-Object {
        $ms=0L;[long]::TryParse([string]$_.elapsed_ms,[ref]$ms)|Out-Null
        [pscustomobject]@{scope=$_.scope;snapshot=$_.snapshot;next_snapshot=$_.next_snapshot;logical_checks=$_.logical_checks;elapsed_ms=$ms;elapsed_seconds=[math]::Round($ms/1000.0,2);rc=$_.rc}
    } | Sort-Object elapsed_ms -Descending | Select-Object -First 200)
}
$batchValues=[double[]]@($batches | ForEach-Object {[double]$_.elapsed_ms})
$perfSummary=[ordered]@{
    batch_count=$batches.Count
    total_active_hours=[math]::Round((($batchValues|Measure-Object -Sum).Sum)/3600000.0,2)
    median_batch_seconds=[math]::Round((Percentile $batchValues 0.5)/1000.0,2)
    p95_batch_seconds=[math]::Round((Percentile $batchValues 0.95)/1000.0,2)
    max_batch_seconds=[math]::Round((Percentile $batchValues 1.0)/1000.0,2)
}

# Annotate quality with configured exclusions without removing any evidence.
$excludeMap=@{}
foreach($e in $exclusions){
    if([string]::IsNullOrWhiteSpace([string]$e.snapshot)){continue}
    $k=([string]$e.snapshot).ToLowerInvariant()
    if(-not$excludeMap.ContainsKey($k)){$excludeMap[$k]=New-Object System.Collections.ArrayList}
    [void]$excludeMap[$k].Add([string]$e.scope)
}
$qualityAnnotated=@($quality | ForEach-Object {
    $k=([string]$_.dump).ToLowerInvariant()
    $scopes=if($excludeMap.ContainsKey($k)){(@($excludeMap[$k]) -join ',')}else{''}
    [pscustomobject]@{
        index=$_.index;dump=$_.dump;product_sections=$_.product_sections;product_zero_file_pct=$_.product_zero_file_pct
        variant_sections=$_.variant_sections;variant_duplicate_pct=$_.variant_duplicate_pct;variant_unique_source_ids=$_.variant_unique_source_ids
        variant_numeric_id_pct=$_.variant_numeric_id_pct;note_records=$_.note_records;quality_flags=$_.quality_flags;excluded_scopes=$scopes
    }
})

$domainFinal=@()
foreach($group in @($domainAdds | Group-Object domain)){
    $last=@($group.Group | Sort-Object {[int]$_.index})[-1]
    $domainFinal+=[pscustomobject]@{domain=$group.Name;cumulative_values=$last.cumulative_values}
}

$overview=[ordered]@{
    snapshots=$evoSummary['snapshots']
    logical_checks=$runs.Count
    pass=$statusCounts.PASS
    no_result=$statusCounts.NO_RESULT
    source_missing=$statusCounts.SOURCE_MISSING
    fail=$statusCounts.FAIL
    product_states=$evoSummary['product_states_all_ever']
    variant_states=$evoSummary['variant_states_all_ever']
    note_versions=$evoSummary['note_versions_all_ever']
    note_bodies=$evoSummary['note_bodies_all_ever']
}

$productStates=@(Read-Tsv (Join-Path $evolution 'product-states-all-ever.tsv'))
$variantStates=@(Read-Tsv (Join-Path $evolution 'variant-states-all-ever.tsv'))
$noteBodies=@(Read-Tsv (Join-Path (Join-Path $evolution 'notes') 'note-bodies.tsv'))
$exclusionImpact=New-Object System.Collections.ArrayList
foreach($e in $exclusions){
    $canonical=([string]$e.canonical).ToLowerInvariant()
    if(@('no','false','0','exclude') -notcontains $canonical){continue}
    $snapshot=[string]$e.snapshot
    $scope=([string]$e.scope).ToLowerInvariant()
    $introduced=0;$unique=0;$kind=''
    if($scope-eq'products'){
        $kind='product_states';$rows=$productStates
    } elseif($scope-eq'variants'){
        $kind='variant_states';$rows=$variantStates
    } elseif($scope-eq'notes'){
        $kind='note_versions';$rows=$notes
    } else {
        $kind='(scope metadata only)';$rows=@()
    }
    if($rows.Count-gt0){
        $introduced=@($rows|Where-Object{[string]$_.first_seen_dump-eq$snapshot}).Count
        $unique=@($rows|Where-Object{[string]$_.first_seen_dump-eq$snapshot-and[string]$_.last_seen_dump-eq$snapshot}).Count
    }
    [void]$exclusionImpact.Add([pscustomobject]@{
        snapshot=$snapshot;scope=$scope;evidence_kind=$kind;introduced_here=$introduced;never_seen_later=$unique;seen_later=($introduced-$unique);reason=[string]$e.reason
    })
}
$canonicalSequences=New-Object System.Collections.ArrayList
$dumpNames=@($quality|Sort-Object {[int]$_.index}|ForEach-Object{[string]$_.dump})
foreach($scope in @('products','variants','notes','payloads','comparison-baseline')){
    $kept=New-Object System.Collections.ArrayList
    foreach($dump in $dumpNames){
        $excluded=$false
        foreach($e in $exclusions){
            $canonical=([string]$e.canonical).ToLowerInvariant()
            if(@('no','false','0','exclude') -notcontains $canonical){continue}
            if(-not[string]::Equals([string]$e.snapshot,$dump,[StringComparison]::OrdinalIgnoreCase)){continue}
            if([string]::Equals([string]$e.scope,$scope,[StringComparison]::OrdinalIgnoreCase)-or[string]::Equals([string]$e.scope,'all',[StringComparison]::OrdinalIgnoreCase)){$excluded=$true;break}
        }
        if(-not$excluded){[void]$kept.Add($dump)}
    }
    [void]$canonicalSequences.Add([pscustomobject]@{scope=$scope;included_dumps=$kept.Count;excluded_dumps=($dumpNames.Count-$kept.Count);sequence=(@($kept)-join' -> ')})
}
$noteDisplay=@($notes | Select-Object first_seen_dump,last_seen_dump,observed_snapshots,title,body_sha256,raw_html_sha256,note_text)
$payload=[ordered]@{
    overview=$overview
    performance_summary=$perfSummary
    contributions=$contrib
    domain_additions=$domainAdds
    retention=$retention
    quality=$qualityAnnotated
    transitions=$transitions
    notes=$noteDisplay
    suggestions=$suggestions
    exclusions=$exclusions
    exclusion_impact=@($exclusionImpact)
    canonical_sequences=@($canonicalSequences)
    performance=$perf
    domain_totals=$domainFinal
}
$data=(Json $payload 6).Replace('</','<\/')
$generated=(Get-Date).ToString('o')

$html=@'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>MVS Explorer Toolkit — Archive Summary</title>
<style>
:root{font-family:Segoe UI,Arial,sans-serif;color:#1f2937;background:#f5f7fa}
body{margin:0}.top{background:#111827;color:white;padding:18px 24px}.top h1{margin:0 0 4px;font-size:24px}.top small{color:#cbd5e1}
.tabs{display:flex;flex-wrap:wrap;gap:4px;padding:10px 16px;background:white;border-bottom:1px solid #d1d5db;position:sticky;top:0;z-index:3}
.tabs button{border:0;background:#e5e7eb;padding:9px 13px;border-radius:6px;cursor:pointer}.tabs button.active{background:#111827;color:white}
.panel{display:none;padding:18px 22px}.panel.active{display:block}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin:0 0 18px}
.card{background:white;border:1px solid #e5e7eb;border-radius:8px;padding:12px}.card .v{font-size:22px;font-weight:650}.card .k{font-size:12px;color:#6b7280;margin-top:3px}
.tablewrap{overflow:auto;background:white;border:1px solid #e5e7eb;border-radius:8px;max-height:70vh}
table{border-collapse:collapse;width:100%;font-size:12px}th,td{padding:7px 9px;border-bottom:1px solid #e5e7eb;text-align:left;vertical-align:top;white-space:nowrap}
th{position:sticky;top:0;background:#f9fafb;cursor:pointer;z-index:1}td.wrap{white-space:normal;min-width:340px}
.controls{margin:0 0 10px;display:flex;gap:8px;align-items:center}.controls input{padding:7px 9px;min-width:320px;border:1px solid #cbd5e1;border-radius:5px}
.badge{display:inline-block;padding:2px 6px;border-radius:10px;background:#fee2e2;color:#991b1b;font-size:11px}.ok{background:#dcfce7;color:#166534}
.note{background:#fffbeb;border:1px solid #fde68a;padding:10px 12px;border-radius:7px;margin-bottom:12px}
</style>
</head>
<body>
<div class="top"><h1>MVS Explorer Toolkit — Archive Summary</h1><small id="generated"></small></div>
<div class="tabs" id="tabs"></div>
<div id="Overview" class="panel"></div>
<div id="Dumps" class="panel"></div>
<div id="Added" class="panel"></div>
<div id="ReID" class="panel"></div>
<div id="Duplicates" class="panel"></div>
<div id="Notes" class="panel"></div>
<div id="Exclusions" class="panel"></div>
<div id="AllEver" class="panel"></div>
<div id="Performance" class="panel"></div>
<script>
const DATA=__DATA__;
const GENERATED="__GENERATED__";
const tabs=[["Overview","Overview"],["Dumps","Dumps"],["Added","What This Dump Added"],["ReID","Re-ID / ID Regimes"],["Duplicates","Duplicates / Quality"],["Notes","Notes"],["Exclusions","Exclusions"],["AllEver","All-Ever"],["Performance","Performance"]];
function esc(v){return String(v??"").replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));}
function cards(obj){return '<div class="cards">'+Object.entries(obj).map(([k,v])=>`<div class="card"><div class="v">${esc(v)}</div><div class="k">${esc(k.replaceAll("_"," "))}</div></div>`).join("")+'</div>';}
function table(id,rows,cols,wrapCols=[]){
  if(!rows||!rows.length)return '<div class="note">No rows.</div>';
  const qid=id+"_q";
  let h=`<div class="controls"><input id="${qid}" placeholder="Filter rows..." oninput="filterTable('${id}','${qid}')"><span>${rows.length.toLocaleString()} rows</span></div><div class="tablewrap"><table id="${id}"><thead><tr>`;
  h+=cols.map((c,i)=>`<th onclick="sortTable('${id}',${i})">${esc(c)}</th>`).join("")+'</tr></thead><tbody>';
  for(const r of rows){h+='<tr>'+cols.map(c=>`<td class="${wrapCols.includes(c)?'wrap':''}">${esc(r[c]??"")}</td>`).join("")+'</tr>';}
  return h+'</tbody></table></div>';
}
function filterTable(id,qid){const q=document.getElementById(qid).value.toLowerCase();for(const tr of document.querySelectorAll(`#${id} tbody tr`)){tr.style.display=tr.innerText.toLowerCase().includes(q)?"":"none";}}
const dir={};function sortTable(id,col){const t=document.getElementById(id),b=t.tBodies[0],rows=[...b.rows];const k=id+":"+col;dir[k]=!dir[k];rows.sort((a,b)=>{let x=a.cells[col].innerText,y=b.cells[col].innerText;const nx=Number(x.replace(/,/g,"")),ny=Number(y.replace(/,/g,""));let c=Number.isFinite(nx)&&Number.isFinite(ny)?nx-ny:x.localeCompare(y,undefined,{numeric:true,sensitivity:"base"});return dir[k]?c:-c});rows.forEach(r=>b.appendChild(r));}
function show(name){document.querySelectorAll(".panel").forEach(p=>p.classList.toggle("active",p.id===name));document.querySelectorAll(".tabs button").forEach(b=>b.classList.toggle("active",b.dataset.tab===name));}
document.getElementById("tabs").innerHTML=tabs.map(([id,label])=>`<button data-tab="${id}" onclick="show('${id}')">${label}</button>`).join("");
document.getElementById("generated").textContent="Generated "+GENERATED;
document.getElementById("Overview").innerHTML=cards(DATA.overview)+cards(DATA.performance_summary)+'<div class="note">Canonical exclusions are non-destructive: excluded scopes are removed only from canonical sanity-check interpretation. All source evidence, notes, and all-ever observations remain retained.</div>';
document.getElementById("Dumps").innerHTML=table("dumpTable",DATA.quality,["index","dump","product_sections","product_zero_file_pct","variant_sections","variant_duplicate_pct","variant_unique_source_ids","variant_numeric_id_pct","note_records","quality_flags","excluded_scopes"]);
document.getElementById("Added").innerHTML='<div class="note">High-level and source-local first-seen counts are retained independently. Retention shows whether evidence first introduced by a dump was ever observed again later, which is especially useful before marking a dump non-canonical.</div><h3>High-level contributions</h3>'+table("addTable",DATA.contributions,Object.keys(DATA.contributions[0]||{}))+'<h3>Introduced here vs. seen later</h3>'+table("retentionTable",DATA.retention,Object.keys(DATA.retention[0]||{}))+'<h3>Source-local domain additions</h3>'+table("domainAddTable",DATA.domain_additions,Object.keys(DATA.domain_additions[0]||{}));
document.getElementById("ReID").innerHTML='<div class="note">Variant identity below is content/title state independent of the source-level mvs_names ID. A high changed-ID percentage with high retained-state overlap usually indicates an ID regime change, not new content.</div>'+table("reidTable",DATA.transitions,Object.keys(DATA.transitions[0]||{}));
document.getElementById("Duplicates").innerHTML=table("qualityTable",DATA.quality,Object.keys(DATA.quality[0]||{}));
document.getElementById("Notes").innerHTML='<div class="note">Every unique title + normalized note-text version is retained. Raw HTML bodies are stored under archive-output/evolution/notes/raw-html by SHA-256.</div>'+table("noteTable",DATA.notes,["first_seen_dump","last_seen_dump","observed_snapshots","title","body_sha256","raw_html_sha256","note_text"],["note_text"]);
document.getElementById("Exclusions").innerHTML='<div class="note">Exclusions never delete evidence. “Never seen later” quantifies information that would be lost if a dump were physically skipped instead of only excluded from canonical interpretation.</div><h3>Configured canonical exclusions</h3>'+table("excludeTable",DATA.exclusions,Object.keys(DATA.exclusions[0]||{snapshot:"",scope:"",canonical:"",reason:""}),["reason"])+'<h3>Exclusion impact</h3>'+table("impactTable",DATA.exclusion_impact,Object.keys(DATA.exclusion_impact[0]||{}),["reason"])+'<h3>Canonical sequences by scope</h3>'+table("seqTable",DATA.canonical_sequences,Object.keys(DATA.canonical_sequences[0]||{}),["sequence"])+'<h3>Analyzer suggestions (not automatically applied)</h3>'+table("suggestTable",DATA.suggestions,Object.keys(DATA.suggestions[0]||{}),["reason"]);
document.getElementById("AllEver").innerHTML=cards({product_states:DATA.overview.product_states,variant_states:DATA.overview.variant_states,note_versions:DATA.overview.note_versions,note_bodies:DATA.overview.note_bodies})+table("domainTable",DATA.domain_totals,["domain","cumulative_values"]);
document.getElementById("Performance").innerHTML=cards(DATA.performance_summary)+table("perfTable",DATA.performance,["scope","snapshot","next_snapshot","logical_checks","elapsed_seconds","rc"]);
show("Overview");
</script>
</body></html>
'@
$html=$html.Replace('__DATA__',$data).Replace('__GENERATED__',(Html $generated))
$parent=Split-Path -Parent $Output
if(-not(Test-Path -LiteralPath $parent -PathType Container)){[void](New-Item -ItemType Directory -Path $parent -Force)}
[IO.File]::WriteAllText($Output,$html,$utf8)
[Console]::Out.WriteLine('Interactive report: '+$Output)
exit 0
:_MVSArchiveReport_end
