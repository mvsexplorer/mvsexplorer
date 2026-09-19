$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$IndexInput = [string]$env:mvshb_index_root
$OutputInput = [string]$env:mvshb_output_file
$Caller = [string]$env:mvshb_caller
$Version = [string]$env:mvshb_version
$ProjectRootInput = [string]$env:mvshb_project_root
$US = [char]31
$Tab = [char]9
$started = [Diagnostics.Stopwatch]::StartNew()

function Write-Line { param([AllowEmptyString()][string]$Text) [Console]::Out.WriteLine($Text) }
function Write-Err { param([string]$Text) [Console]::Error.WriteLine($Text) }
function Fail { param([int]$Code,[string]$Message) Write-Err ('ERROR: '+$Message); [Environment]::Exit($Code) }
function Is-HelpToken { param([AllowNull()][AllowEmptyString()][string]$Value) return @('--help','-h','-?','/h','/?') -contains $Value }
function Show-Usage {
    Write-Line ('MVS Explorer Toolkit self-contained HTML browser builder '+$Version)
    Write-Line ('Usage: '+$Caller+' compact-family-index [output.html]')
    Write-Line 'Builds one offline HTML file with cascading family/product/release/title filters.'
    Write-Line 'If output.html is omitted, a date/time-stamped mvs-browser-YYYYMMDD-HHmmss.html is written in the project root.'
}
function Resolve-IndexRoot {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    try {
        if (-not (Test-Path -LiteralPath $Name -PathType Container)) { return $null }
        $resolved=(Resolve-Path -LiteralPath $Name).Path
        foreach($need in @(
            'product-classifications.tsv','unclassified-products.tsv',
            'product-presence-all-ever.tsv','product-ids-all-ever.tsv',
            'product-dates-all-ever.tsv','product-files-all-ever.tsv',
            'product-file-hashes-all-ever.tsv','product-notes-all-ever.tsv'
        )) {
            if(-not(Test-Path -LiteralPath (Join-Path $resolved $need) -PathType Leaf)){return $null}
        }
        return $resolved
    } catch { return $null }
}
function Get-TableSchema {
    param([string]$Name)
    $path=Join-Path $IndexRoot $Name
    $reader=New-Object IO.StreamReader($path,$utf8,$true,65536)
    try{$header=$reader.ReadLine()}finally{$reader.Dispose()}
    if($null-eq$header){Fail 3 ('Compact family table is empty: '+$Name)}
    return [pscustomobject]@{path=$path;headers=[string[]]$header.Split([char]9)}
}
function Read-TsvRows {
    param([string]$Name,[scriptblock]$Action)
    $schema=Get-TableSchema $Name
    $reader=New-Object IO.StreamReader($schema.path,$utf8,$true,65536)
    try {
        [void]$reader.ReadLine()
        while(($line=$reader.ReadLine()) -ne $null) {
            $parts=[string[]]$line.Split([char]9)
            $row=@{}
            for($i=0;$i-lt$schema.headers.Count;$i++){
                $row[$schema.headers[$i]]=if($i-lt$parts.Count){[string]$parts[$i]}else{''}
            }
            & $Action $row
        }
    } finally { $reader.Dispose() }
}
function New-OrdinalObjectDictionary {
    return New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
}
function New-OrdinalStringSet {
    return New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
}
function New-IgnoreCaseStringSet {
    return New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
}
function Ensure-Product {
    param([string]$Title)
    if(-not$Products.ContainsKey($Title)){
        $Products[$Title]=[ordered]@{
            title=$Title
            broad='(Unclassified / historical)'
            product_family='(Unclassified / historical)'
            release=''
            confidence=''
            status='unclassified'
            first=''
            last=''
            ids=(New-OrdinalStringSet)
            dates=(New-OrdinalStringSet)
            notes=(New-OrdinalStringSet)
            files=(New-OrdinalObjectDictionary)
        }
    }
    return $Products[$Title]
}
function Json {
    param([object]$Value)
    $text=[string](ConvertTo-Json -InputObject $Value -Compress -Depth 10)
    return $text.Replace('<','\u003c')
}
function Sort-Ordinal {
    param([System.Collections.IEnumerable]$Values)
    [string[]]$a=@($Values)
    [Array]::Sort($a,[StringComparer]::OrdinalIgnoreCase)
    return ,$a
}
function Update-ObservedRange {
    param([object]$Product,[string]$First,[string]$Last)
    if($First -and ((-not$Product.first) -or [StringComparer]::Ordinal.Compare($First,[string]$Product.first)-lt 0)){$Product.first=$First}
    if($Last -and ((-not$Product.last) -or [StringComparer]::Ordinal.Compare($Last,[string]$Product.last)-gt 0)){$Product.last=$Last}
}

if(Is-HelpToken $IndexInput){Show-Usage;[Environment]::Exit(0)}
if([string]::IsNullOrWhiteSpace($IndexInput)){Show-Usage;Fail 2 'Compact family index is required.'}
$IndexRoot=Resolve-IndexRoot $IndexInput
if($null-eq$IndexRoot){Fail 3 ('Not a compact MVS family index: '+$IndexInput)}
if([string]::IsNullOrWhiteSpace($OutputInput)){
    $projectOut=$ProjectRootInput
    try{$projectOut=(Resolve-Path -LiteralPath $ProjectRootInput).Path}catch{$projectOut=(Get-Location).Path}
    $OutputInput=Join-Path $projectOut ('mvs-browser-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.html')
}
try{$OutputPath=[IO.Path]::GetFullPath($OutputInput)}catch{Fail 2 ('Invalid output path: '+$OutputInput)}
if([IO.Path]::GetExtension($OutputPath)-ine'.html'){Fail 2 'Output file must use the .html extension.'}
$parent=[IO.Path]::GetDirectoryName($OutputPath)
if(-not(Test-Path -LiteralPath $parent -PathType Container)){Fail 3 ('Output directory does not exist: '+$parent)}

Write-Line ('MVS Explorer Toolkit self-contained HTML browser builder '+$Version)
Write-Line ('Compact family index: '+$IndexRoot)
Write-Line ('Output: '+$OutputPath)

$Products=New-OrdinalObjectDictionary
$BroadSet=New-OrdinalStringSet
$FamilySet=New-OrdinalStringSet
[void]$BroadSet.Add('(Unclassified / historical)')
[void]$FamilySet.Add('(Unclassified / historical)')

Read-TsvRows 'product-classifications.tsv' {
    param($r)
    $p=Ensure-Product ([string]$r.product_title)
    $p.broad=if($r.broad_family){[string]$r.broad_family}else{'(Unclassified / historical)'}
    $p.product_family=if($r.product_family){[string]$r.product_family}else{'(Unclassified / historical)'}
    $p.release=[string]$r.release
    $p.confidence=[string]$r.confidence
    $p.status=[string]$r.status
    [void]$BroadSet.Add([string]$p.broad)
    [void]$FamilySet.Add([string]$p.product_family)
}
Read-TsvRows 'unclassified-products.tsv' { param($r) [void](Ensure-Product ([string]$r.product_title)) }
Read-TsvRows 'product-presence-all-ever.tsv' {
    param($r)
    $p=Ensure-Product ([string]$r.product_title)
    Update-ObservedRange $p ([string]$r.first_seen) ([string]$r.last_seen)
}

Read-TsvRows 'product-ids-all-ever.tsv' {
    param($r)
    $p=Ensure-Product ([string]$r.product_title)
    if($r.id){[void]$p.ids.Add([string]$r.id)}
}
Read-TsvRows 'product-dates-all-ever.tsv' {
    param($r)
    $p=Ensure-Product ([string]$r.product_title)
    [void]$p.dates.Add(([string]$r.date)+$US+([string]$r.id))
}

$FilenameSet=New-OrdinalStringSet
$HashSet=New-OrdinalStringSet
$NoteTextSet=New-OrdinalStringSet
Read-TsvRows 'product-files-all-ever.tsv' {
    param($r)
    $p=Ensure-Product ([string]$r.product_title)
    $fn=[string]$r.filename
    if(-not$p.files.ContainsKey($fn)){$p.files[$fn]=New-OrdinalStringSet}
    [void]$FilenameSet.Add($fn)
}
Read-TsvRows 'product-file-hashes-all-ever.tsv' {
    param($r)
    $p=Ensure-Product ([string]$r.product_title)
    $fn=[string]$r.filename
    if(-not$p.files.ContainsKey($fn)){$p.files[$fn]=New-OrdinalStringSet}
    $alg=[string]$r.algorithm
    $hash=[string]$r.hash
    [void]$p.files[$fn].Add($alg+$US+$hash)
    [void]$FilenameSet.Add($fn)
    [void]$HashSet.Add($hash)
}
Read-TsvRows 'product-notes-all-ever.tsv' {
    param($r)
    $p=Ensure-Product ([string]$r.product_title)
    $text=[string]$r.note_text
    [void]$p.notes.Add($text+$US+([string]$r.raw_html_sha256)+$US+([string]$r.first_seen)+$US+([string]$r.last_seen))
    [void]$NoteTextSet.Add($text)
}

$BroadList=Sort-Ordinal $BroadSet
$FamilyList=Sort-Ordinal $FamilySet
$TitleList=Sort-Ordinal $Products.Keys
$FilenameList=Sort-Ordinal $FilenameSet
$HashList=Sort-Ordinal $HashSet
$NoteTextList=Sort-Ordinal $NoteTextSet

$BroadIndex=@{};for($i=0;$i-lt$BroadList.Count;$i++){$BroadIndex[[string]$BroadList[$i]]=$i}
$FamilyIndex=@{};for($i=0;$i-lt$FamilyList.Count;$i++){$FamilyIndex[[string]$FamilyList[$i]]=$i}
$FilenameIndex=@{};for($i=0;$i-lt$FilenameList.Count;$i++){$FilenameIndex[[string]$FilenameList[$i]]=$i}
$HashIndex=@{};for($i=0;$i-lt$HashList.Count;$i++){$HashIndex[[string]$HashList[$i]]=$i}
$NoteTextIndex=@{};for($i=0;$i-lt$NoteTextList.Count;$i++){$NoteTextIndex[[string]$NoteTextList[$i]]=$i}

$HtmlPrefix=@'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>MVS Browser 0.1.0</title>
<style>
:root{color-scheme:light dark;--bg:#f6f7f9;--panel:#fff;--text:#17202a;--muted:#667085;--line:#d9dee7;--accent:#2563eb;--accentSoft:#e8f0ff;--chip:#eef2f7;--warn:#9a6700;--shadow:0 1px 3px rgba(0,0,0,.08)}
@media(prefers-color-scheme:dark){:root{--bg:#111318;--panel:#191d24;--text:#edf2f7;--muted:#9aa4b2;--line:#303642;--accent:#7aa2ff;--accentSoft:#223150;--chip:#252b35;--warn:#f0c36a;--shadow:none}}
*{box-sizing:border-box} body{margin:0;background:var(--bg);color:var(--text);font:14px/1.4 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
header{padding:16px 20px 12px;background:var(--panel);border-bottom:1px solid var(--line);position:sticky;top:0;z-index:20}
h1{font-size:20px;margin:0 0 4px}.sub{color:var(--muted);font-size:12px}.wrap{padding:14px 16px 28px;max-width:1800px;margin:auto}
.toolbar{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px;align-items:center}.pill{background:var(--chip);border:1px solid var(--line);border-radius:999px;padding:4px 8px;font-size:12px}.btn{appearance:none;border:1px solid var(--line);background:var(--panel);color:var(--text);border-radius:6px;padding:6px 9px;cursor:pointer}.btn:hover{border-color:var(--accent)}.btn.primary{background:var(--accent);color:white;border-color:var(--accent)}
.browser-grid{display:grid;grid-template-columns:repeat(4,minmax(220px,1fr));gap:10px;align-items:stretch}
.panel{background:var(--panel);border:1px solid var(--line);border-radius:8px;box-shadow:var(--shadow);min-width:0}.panel-head{padding:10px;border-bottom:1px solid var(--line)}.panel-title{font-weight:700;display:flex;justify-content:space-between;gap:8px}.count{color:var(--muted);font-weight:500}
.filter{width:100%;margin-top:8px;border:1px solid var(--line);background:var(--bg);color:var(--text);border-radius:6px;padding:7px 8px;outline:none}.filter:focus{border-color:var(--accent)}
.mini-actions{display:flex;gap:6px;margin-top:7px}.mini-actions button{font-size:11px;padding:3px 6px}
.list{height:310px;overflow:auto;padding:4px}.row{display:flex;align-items:center;gap:7px;padding:5px 6px;border-radius:5px;cursor:pointer}.row:hover{background:var(--chip)}.row.sel{background:var(--accentSoft)}.row input{margin:0}.label{min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1}.badge{font-size:11px;color:var(--muted);font-variant-numeric:tabular-nums}
.empty{color:var(--muted);padding:12px;text-align:center}
.details{margin-top:12px}.summary-grid{display:grid;grid-template-columns:repeat(5,minmax(130px,1fr));gap:8px;margin-bottom:10px}.metric{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:10px}.metric b{display:block;font-size:19px}.metric span{color:var(--muted);font-size:11px}
.tabs{display:flex;gap:4px;border-bottom:1px solid var(--line);padding:0 8px;background:var(--panel);border-radius:8px 8px 0 0}.tab{border:0;background:transparent;color:var(--muted);padding:10px 12px;cursor:pointer;border-bottom:2px solid transparent}.tab.active{color:var(--text);border-bottom-color:var(--accent);font-weight:700}
.tabbody{background:var(--panel);border:1px solid var(--line);border-top:0;border-radius:0 0 8px 8px;padding:10px;min-height:220px}
.detail-toolbar{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin-bottom:8px}.detail-toolbar .filter{margin:0;max-width:460px}.muted{color:var(--muted)}.warning{color:var(--warn)}
table{width:100%;border-collapse:collapse;font-size:12px}th,td{text-align:left;vertical-align:top;border-bottom:1px solid var(--line);padding:6px 7px}th{position:sticky;top:0;background:var(--panel);z-index:2}.tablewrap{max-height:480px;overflow:auto;border:1px solid var(--line);border-radius:6px}
code{font-family:ui-monospace,SFMono-Regular,Consolas,monospace;font-size:11px;word-break:break-all}
.note{border:1px solid var(--line);border-radius:7px;padding:10px;margin:8px 0}.note-title{font-weight:700;margin-bottom:4px}.note-meta{color:var(--muted);font-size:11px;margin-top:6px}.chips{display:flex;gap:5px;flex-wrap:wrap;margin:7px 0}.chip{background:var(--chip);border-radius:999px;padding:3px 7px;font-size:11px}
.pagination{display:flex;gap:8px;align-items:center;margin-top:8px}.pagination button{padding:4px 8px}
@media(max-width:1000px){.browser-grid{grid-template-columns:repeat(2,minmax(220px,1fr))}.summary-grid{grid-template-columns:repeat(3,1fr)}}
@media(max-width:620px){.browser-grid{grid-template-columns:1fr}.summary-grid{grid-template-columns:repeat(2,1fr)}.list{height:240px}}
</style>
</head>
<body>
<header>
  <h1>MVS Browser <span class="muted">0.1.0</span></h1>
  <div class="sub">Self-contained browser generated from the MVS compact family database. Family classification is analytical; filenames/hashes are shown only from source-backed product evidence.</div>
  <div class="toolbar">
    <button class="btn" id="clearAll">Clear all selections</button>
    <span class="pill" id="matchedPill">Loading…</span>
    <span class="pill">None selected in a column = all available</span>
  </div>
</header>
<div class="wrap">
  <section class="browser-grid" id="browserGrid"></section>
  <section class="details">
    <div class="summary-grid" id="summaryGrid"></div>
    <div class="tabs">
      <button class="tab active" data-tab="products">Products</button>
      <button class="tab" data-tab="files">Files &amp; hashes</button>
      <button class="tab" data-tab="notes">Notes</button>
      <button class="tab" data-tab="selection">Selection</button>
    </div>
    <div class="tabbody" id="tabBody"></div>
  </section>
</div>
<script id="mvs-data" type="application/json">
'@
$HtmlSuffix=@'
</script>
<script>
'use strict';
const D=JSON.parse(document.getElementById('mvs-data').textContent);
const U='(Other / unversioned)';
const coll=new Intl.Collator(undefined,{numeric:true,sensitivity:'base'});
const S={b:new Set(),g:new Set(),r:new Set(),t:new Set(),q:{b:'',g:'',r:'',t:'',products:'',files:'',notes:''},tab:'products',page:{products:0,files:0},pageSize:200};
const COLS=[
 {k:'b',title:'1. Basic families',placeholder:'Filter families…'},
 {k:'g',title:'2. Products',placeholder:'Filter product families…'},
 {k:'r',title:'3. Releases',placeholder:'Filter releases / years…'},
 {k:'t',title:'4. Variants / exact titles',placeholder:'Filter exact product titles…'}
];
const grid=document.getElementById('browserGrid');
for(const c of COLS){
 const el=document.createElement('div');el.className='panel';el.innerHTML=`<div class="panel-head"><div class="panel-title"><span>${c.title}</span><span class="count" id="count-${c.k}"></span></div><input class="filter" id="filter-${c.k}" autocomplete="off" placeholder="${c.placeholder}"><div class="mini-actions"><button class="btn" data-select-visible="${c.k}">Select visible</button><button class="btn" data-clear="${c.k}">Clear</button></div></div><div class="list" id="list-${c.k}"></div>`;grid.appendChild(el);
 document.getElementById('filter-'+c.k).addEventListener('input',e=>{S.q[c.k]=e.target.value;renderLists();});
}
function rel(p){return p[3]||U}
function matchText(v,q){return !q||v.toLocaleLowerCase().includes(q.trim().toLocaleLowerCase())}
function matchesProduct(i,upto='all'){
 const p=D.p[i];
 if(S.b.size&&!S.b.has(p[1]))return false;
 if(upto==='b')return true;
 if(S.g.size&&!S.g.has(p[2]))return false;
 if(upto==='g')return true;
 if(S.r.size&&!S.r.has(rel(p)))return false;
 if(upto==='r')return true;
 if(S.t.size&&!S.t.has(i))return false;
 return true;
}
function available(k){
 const m=new Map();
 if(k==='b'){for(let i=0;i<D.p.length;i++)m.set(D.p[i][1],(m.get(D.p[i][1])||0)+1);return [...m].map(([v,n])=>[v,D.b[v],n]);}
 if(k==='g'){for(let i=0;i<D.p.length;i++){if(!matchesProduct(i,'b'))continue;const x=D.p[i][2];m.set(x,(m.get(x)||0)+1)}return [...m].map(([v,n])=>[v,D.g[v],n]);}
 if(k==='r'){for(let i=0;i<D.p.length;i++){if(!matchesProduct(i,'g'))continue;const x=rel(D.p[i]);m.set(x,(m.get(x)||0)+1)}return [...m].map(([v,n])=>[v,v,n]);}
 for(let i=0;i<D.p.length;i++){if(!matchesProduct(i,'r'))continue;m.set(i,1)}return [...m].map(([v])=>[v,D.p[v][0],1]);
}
function prune(){
 const avG=new Set(available('g').map(x=>x[0]));for(const x of [...S.g])if(!avG.has(x))S.g.delete(x);
 const avR=new Set(available('r').map(x=>x[0]));for(const x of [...S.r])if(!avR.has(x))S.r.delete(x);
 const avT=new Set(available('t').map(x=>x[0]));for(const x of [...S.t])if(!avT.has(x))S.t.delete(x);
}
function renderLists(){
 prune();
 for(const c of COLS){
  let rows=available(c.k).sort((a,b)=>coll.compare(a[1],b[1]));
  const q=S.q[c.k];const visible=rows.filter(x=>matchText(x[1],q));
  document.getElementById('count-'+c.k).textContent=`${visible.length}/${rows.length}`;
  const box=document.getElementById('list-'+c.k);box.textContent='';
  if(!visible.length){box.innerHTML='<div class="empty">No matches</div>';continue}
  const frag=document.createDocumentFragment();
  for(const [val,label,n] of visible){
   const row=document.createElement('label');const selected=S[c.k].has(val);row.className='row'+(selected?' sel':'');
   const cb=document.createElement('input');cb.type='checkbox';cb.checked=selected;cb.dataset.k=c.k;cb.dataset.v=String(val);
   const l=document.createElement('span');l.className='label';l.textContent=label;l.title=label;
   const badge=document.createElement('span');badge.className='badge';badge.textContent=n>1?n:'';
   row.append(cb,l,badge);frag.appendChild(row);
  }
  box.appendChild(frag);
 }
 renderDetails();
}
grid.addEventListener('change',e=>{
 const cb=e.target.closest('input[type=checkbox]');if(!cb)return;const k=cb.dataset.k;let v=cb.dataset.v;if(k==='b'||k==='g'||k==='t')v=Number(v);
 cb.checked?S[k].add(v):S[k].delete(v);S.page.products=S.page.files=0;renderLists();
});
grid.addEventListener('click',e=>{
 const sel=e.target.dataset.selectVisible, clr=e.target.dataset.clear;
 if(clr){S[clr].clear();S.page.products=S.page.files=0;renderLists();return}
 if(sel){
  for(const [v,label] of available(sel))if(matchText(label,S.q[sel]))S[sel].add(v);
  S.page.products=S.page.files=0;renderLists();
 }
});
document.getElementById('clearAll').onclick=()=>{for(const k of ['b','g','r','t'])S[k].clear();for(const k of ['b','g','r','t']){S.q[k]='';document.getElementById('filter-'+k).value=''}S.page.products=S.page.files=0;renderLists()};
document.querySelector('.tabs').addEventListener('click',e=>{const b=e.target.closest('.tab');if(!b)return;S.tab=b.dataset.tab;document.querySelectorAll('.tab').forEach(x=>x.classList.toggle('active',x===b));renderDetails()});
function matched(){const a=[];for(let i=0;i<D.p.length;i++)if(matchesProduct(i))a.push(i);return a}
function esc(s){return String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function activeLabel(set,dict,isTitle=false){
 if(!set.size)return 'All';
 const vals=[...set].slice(0,6).map(x=>isTitle?D.p[x][0]:dict?dict[x]:x);return vals.join(', ')+(set.size>6?` +${set.size-6}`:'');
}
function metrics(ms){
 let files=0,hashes=0,notes=new Set(),ids=new Set(),dates=new Set();
 for(const i of ms){const p=D.p[i];files+=p[11].length;for(const f of p[11])hashes+=f[1].length/2;for(const n of p[10])notes.add(n[0]);for(const x of p[8])ids.add(x);for(const x of p[9])dates.add(x[0]);}
 return {files,hashes,notes:notes.size,ids:ids.size,dates:dates.size};
}
function renderDetails(){
 const ms=matched(), m=metrics(ms);
 document.getElementById('matchedPill').textContent=`${ms.length.toLocaleString()} product title${ms.length===1?'':'s'} matched`;
 document.getElementById('summaryGrid').innerHTML=[
  ['Products',ms.length],['Files',m.files],['Hashes',m.hashes],['Notes',m.notes],['Distinct IDs / dates',m.ids+' / '+m.dates]
 ].map(x=>`<div class="metric"><b>${Number.isFinite(x[1])?x[1].toLocaleString():esc(x[1])}</b><span>${x[0]}</span></div>`).join('');
 if(S.tab==='products')renderProducts(ms);else if(S.tab==='files')renderFiles(ms);else if(S.tab==='notes')renderNotes(ms);else renderSelection(ms);
}
function pager(kind,total,render){
 const pages=Math.max(1,Math.ceil(total/S.pageSize));if(S.page[kind]>=pages)S.page[kind]=pages-1;
 const d=document.createElement('div');d.className='pagination';d.innerHTML=`<button class="btn" ${S.page[kind]<=0?'disabled':''}>Previous</button><span class="muted">Page ${S.page[kind]+1} of ${pages} · ${total.toLocaleString()} rows</span><button class="btn" ${S.page[kind]>=pages-1?'disabled':''}>Next</button>`;
 const bs=d.querySelectorAll('button');bs[0].onclick=()=>{S.page[kind]--;render()};bs[1].onclick=()=>{S.page[kind]++;render()};return d;
}
function renderProducts(ms){
 const body=document.getElementById('tabBody');const q=S.q.products;
 const rows=ms.filter(i=>matchText(D.p[i][0],q)||matchText(D.g[D.p[i][2]],q)||matchText(rel(D.p[i]),q));
 const start=S.page.products*S.pageSize, page=rows.slice(start,start+S.pageSize);
 body.innerHTML=`<div class="detail-toolbar"><input class="filter" id="qProducts" placeholder="Filter matched products…" value="${esc(q)}"><span class="muted">${rows.length.toLocaleString()} matching rows</span></div><div class="tablewrap"><table><thead><tr><th>Exact product title / variant</th><th>Product family</th><th>Release</th><th>Observed</th><th>IDs</th><th>Dates</th><th>Classification</th></tr></thead><tbody>${page.map(i=>{const p=D.p[i];return `<tr><td>${esc(p[0])}</td><td>${esc(D.g[p[2]])}</td><td>${esc(rel(p))}</td><td>${esc(p[6])}<br>${esc(p[7])}</td><td>${esc(p[8].join(', '))}</td><td>${esc(p[9].map(x=>x[0]).join(', '))}</td><td>${esc(p[4]||p[5])}</td></tr>`}).join('')}</tbody></table></div>`;
 body.querySelector('#qProducts').addEventListener('input',debounce(e=>{S.q.products=e.target.value;S.page.products=0;renderProducts(ms)},90));
 body.appendChild(pager('products',rows.length,()=>renderProducts(ms)));
}
function renderFiles(ms){
 const body=document.getElementById('tabBody');const q=S.q.files.trim().toLocaleLowerCase();const rows=[];
 outer:for(const i of ms){const p=D.p[i],title=p[0];for(const f of p[11]){const fn=D.fn[f[0]];const pairs=[];for(let j=0;j<f[1].length;j+=2){pairs.push([f[1][j]===0?'sha1':f[1][j]===1?'sha256':f[1][j],D.hv[f[1][j+1]]])}if(q){let ok=title.toLocaleLowerCase().includes(q)||fn.toLocaleLowerCase().includes(q);if(!ok)for(const pair of pairs)if(pair[1].toLocaleLowerCase().includes(q)){ok=true;break}if(!ok)continue}rows.push([title,fn,pairs]);}}
 const start=S.page.files*S.pageSize,page=rows.slice(start,start+S.pageSize);
 body.innerHTML=`<div class="detail-toolbar"><input class="filter" id="qFiles" placeholder="Filter filename, hash, or product title…" value="${esc(S.q.files)}"><span class="muted">${rows.length.toLocaleString()} applicable product/file rows</span></div><div class="tablewrap"><table><thead><tr><th>Product title</th><th>Filename</th><th>Hashes</th></tr></thead><tbody>${page.map(r=>`<tr><td>${esc(r[0])}</td><td><code>${esc(r[1])}</code></td><td>${r[2].length?r[2].map(x=>`<div><b>${esc(x[0])}</b> <code>${esc(x[1])}</code></div>`).join(''):'<span class="muted">(no product-section hash recorded)</span>'}</td></tr>`).join('')}</tbody></table></div>`;
 body.querySelector('#qFiles').addEventListener('input',debounce(e=>{S.q.files=e.target.value;S.page.files=0;renderFiles(ms)},120));
 body.appendChild(pager('files',rows.length,()=>renderFiles(ms)));
}
function renderNotes(ms){
 const body=document.getElementById('tabBody'), q=S.q.notes.trim().toLocaleLowerCase(), map=new Map();
 for(const i of ms){const p=D.p[i];for(const n of p[10]){const text=D.nt[n[0]];if(q&&!text.toLocaleLowerCase().includes(q)&&!p[0].toLocaleLowerCase().includes(q))continue;let x=map.get(n[0]);if(!x){x={titles:new Set(),hashes:new Set(),first:n[2],last:n[3]};map.set(n[0],x)}x.titles.add(p[0]);x.hashes.add(n[1]);if(n[2]&&(!x.first||n[2]<x.first))x.first=n[2];if(n[3]&&(!x.last||n[3]>x.last))x.last=n[3];}}
 const rows=[...map].sort((a,b)=>coll.compare(D.nt[a[0]],D.nt[b[0]]));
 body.innerHTML=`<div class="detail-toolbar"><input class="filter" id="qNotes" placeholder="Filter note text or product title…" value="${esc(S.q.notes)}"><span class="muted">${rows.length.toLocaleString()} distinct applicable notes</span></div>`+(rows.length?rows.slice(0,300).map(([ni,x])=>`<div class="note"><div>${esc(D.nt[ni])}</div><div class="note-meta">Applies to ${x.titles.size} matched title(s) · observed ${esc(x.first)} → ${esc(x.last)} · raw HTML evidence hash${x.hashes.size===1?'':'es'}: ${[...x.hashes].slice(0,3).map(h=>'<code>'+esc(h)+'</code>').join(', ')}</div><div class="chips">${[...x.titles].slice(0,8).map(t=>'<span class="chip">'+esc(t)+'</span>').join('')}${x.titles.size>8?'<span class="chip">+'+(x.titles.size-8)+' more</span>':''}</div></div>`).join(''):'<div class="empty">No applicable notes</div>')+(rows.length>300?`<div class="warning">Showing first 300 notes. Narrow the hierarchy or use the note filter.</div>`:'');
 body.querySelector('#qNotes').addEventListener('input',debounce(e=>{S.q.notes=e.target.value;renderNotes(ms)},120));
}
function renderSelection(ms){
 const body=document.getElementById('tabBody');
 body.innerHTML=`<h3>Active hierarchy</h3><div class="chips"><span class="chip"><b>Families:</b> ${esc(activeLabel(S.b,D.b))}</span><span class="chip"><b>Products:</b> ${esc(activeLabel(S.g,D.g))}</span><span class="chip"><b>Releases:</b> ${esc(activeLabel(S.r,null))}</span><span class="chip"><b>Variants:</b> ${esc(activeLabel(S.t,null,true))}</span></div><p class="muted">${ms.length.toLocaleString()} exact product titles currently contribute to the details below. Empty selection in a hierarchy column means “all values still available from the columns to its left.” Search boxes only filter the visible list; they do not silently select evidence.</p><h3>Evidence semantics</h3><p>Family/release membership comes from the analytical product-family classification. Files and hashes come only from actual <code>mvs.txt</code> product-section evidence in the compact family database. Notes remain title-level historical evidence. The browser does not pair or infer products from standalone manifest filenames.</p>`;
}
function debounce(fn,ms){let t;return function(...a){clearTimeout(t);t=setTimeout(()=>fn.apply(this,a),ms)}}
renderLists();
</script>
</body>
</html>
'@

$writer=New-Object IO.StreamWriter($OutputPath,$false,$utf8,65536)
try {
    $writer.Write($HtmlPrefix)
    $writer.Write('{"v":"0.1.0","b":')
    $writer.Write((Json ([object[]]$BroadList)))
    $writer.Write(',"g":')
    $writer.Write((Json ([object[]]$FamilyList)))
    $writer.Write(',"fn":')
    $writer.Write((Json ([object[]]$FilenameList)))
    $writer.Write(',"hv":')
    $writer.Write((Json ([object[]]$HashList)))
    $writer.Write(',"nt":')
    $writer.Write((Json ([object[]]$NoteTextList)))
    $writer.Write(',"p":[')
    $firstProduct=$true
    foreach($title in $TitleList){
        $p=$Products[[string]$title]
        $ids=[object[]](Sort-Ordinal $p.ids)
        $dateRows=New-Object System.Collections.ArrayList
        foreach($key in (Sort-Ordinal $p.dates)){
            $parts=[string[]]([string]$key).Split($US)
            [void]$dateRows.Add([object[]]@($parts[0],$(if($parts.Count-gt 1){$parts[1]}else{''})))
        }
        $noteRows=New-Object System.Collections.ArrayList
        foreach($key in (Sort-Ordinal $p.notes)){
            $parts=[string[]]([string]$key).Split($US)
            $noteText=if($parts.Count-gt 0){$parts[0]}else{''}
            [void]$noteRows.Add([object[]]@(
                [int]$NoteTextIndex[$noteText],
                $(if($parts.Count-gt 1){$parts[1]}else{''}),
                $(if($parts.Count-gt 2){$parts[2]}else{''}),
                $(if($parts.Count-gt 3){$parts[3]}else{''})
            ))
        }
        $fileRows=New-Object System.Collections.ArrayList
        foreach($fn in (Sort-Ordinal $p.files.Keys)){
            $flat=New-Object System.Collections.ArrayList
            foreach($pair in (Sort-Ordinal $p.files[[string]$fn])){
                $parts=[string[]]([string]$pair).Split($US)
                $alg=if($parts[0]-ieq'sha1'){0}elseif($parts[0]-ieq'sha256'){1}else{[string]$parts[0]}
                [void]$flat.Add($alg)
                [void]$flat.Add([int]$HashIndex[[string]$parts[1]])
            }
            [void]$fileRows.Add([object[]]@([int]$FilenameIndex[[string]$fn],[object[]]$flat))
        }
        $out=[object[]]@(
            [string]$p.title,
            [int]$BroadIndex[[string]$p.broad],
            [int]$FamilyIndex[[string]$p.product_family],
            [string]$p.release,
            [string]$p.confidence,
            [string]$p.status,
            [string]$p.first,
            [string]$p.last,
            [object[]]$ids,
            [object[]]$dateRows,
            [object[]]$noteRows,
            [object[]]$fileRows
        )
        if(-not$firstProduct){$writer.Write(',')}else{$firstProduct=$false}
        $writer.Write((Json $out))
    }
    $writer.Write(']}')
    $writer.Write($HtmlSuffix)
} finally {
    $writer.Dispose()
}
$started.Stop()
$size=(Get-Item -LiteralPath $OutputPath).Length
Write-Line ('Products: '+$TitleList.Count)
Write-Line ('Basic families: '+$BroadList.Count)
Write-Line ('Product families: '+$FamilyList.Count)
Write-Line ('Distinct filenames: '+$FilenameList.Count)
Write-Line ('Distinct hashes: '+$HashList.Count)
Write-Line ('Distinct note texts: '+$NoteTextList.Count)
Write-Line ('Output bytes: '+$size)
Write-Line ('Elapsed seconds: '+([math]::Round($started.Elapsed.TotalSeconds,2)))
Write-Line 'HTML browser build complete.'
[Environment]::Exit(0)
