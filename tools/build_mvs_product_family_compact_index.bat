@echo off
:setup
REM Scoped because this standalone compact product-family index builder embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=0.1.0"
set "app.name=build_mvs_product_family_compact_index"
set "app.rc=0"
set "app.self=%~f0"
set "mvspfc_index_root=%~1"
set "mvspfc_output_root=%~2"
set "mvspfc_caller=%~nx0"
set "mvspfc_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSProductFamilyCompact"
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

:_MVSProductFamilyCompact_start
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$IndexInput = [string]$env:mvspfc_index_root
$OutputInput = [string]$env:mvspfc_output_root
$Caller = [string]$env:mvspfc_caller
$Version = [string]$env:mvspfc_version
$US = [char]31
$Tab = [char]9
$started = [Diagnostics.Stopwatch]::StartNew()

function Write-Line { param([AllowEmptyString()][string]$Text) [Console]::Out.WriteLine($Text) }
function Write-Err { param([string]$Text) [Console]::Error.WriteLine($Text) }
function Fail { param([int]$Code,[string]$Message) Write-Err ('ERROR: '+$Message); [Environment]::Exit($Code) }
function Is-HelpToken { param([AllowNull()][AllowEmptyString()][string]$Value) return @('--help','-h','-?','/h','/?') -contains $Value }
function Show-Usage {
    Write-Line ('MVS Explorer Toolkit compact product-family index builder '+$Version)
    Write-Line ('Usage: '+$Caller+' family-index output-folder')
    Write-Line 'Builds a compact, exact-provenance all-ever view from a full product-family index.'
    Write-Line 'The output folder must not already exist.'
}
function Resolve-IndexRoot {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    try {
        if (-not (Test-Path -LiteralPath $Name -PathType Container)) { return $null }
        $resolved=(Resolve-Path -LiteralPath $Name).Path
        foreach($need in @('product-family-memberships.tsv','product-files.tsv','product-hashes.tsv','product-snapshots.tsv')) {
            if(-not(Test-Path -LiteralPath (Join-Path $resolved $need) -PathType Leaf)){return $null}
        }
        return $resolved
    } catch { return $null }
}
function Clean-Field {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if($null -eq $Value){return ''}
    return $Value.Replace("`t",' ').Replace("`r",' ').Replace("`n",' ')
}
function New-Writer {
    param([string]$Path,[string[]]$Header)
    $sw=New-Object IO.StreamWriter($Path,$false,$utf8,65536)
    $sw.NewLine="`r`n"
    $sw.WriteLine(($Header -join $Tab))
    return $sw
}
function Write-Tsv {
    param([IO.StreamWriter]$Writer,[object[]]$Fields)
    $values=New-Object 'string[]' $Fields.Count
    for($i=0;$i-lt$Fields.Count;$i++){ $values[$i]=Clean-Field ([string]$Fields[$i]) }
    $Writer.WriteLine(($values -join $Tab))
}
function New-MaskDictionary {
    return New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
}
function New-StringDictionary {
    return New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
}
function New-StringSet {
    return New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
}
function New-Mask {
    return (New-Object 'System.UInt64[]' $script:MaskSegments)
}
function Or-SnapshotIntoMask {
    param([UInt64[]]$Mask,[int]$SnapshotIndex)
    $segment=[int][Math]::Floor($SnapshotIndex/64)
    $offset=$SnapshotIndex%64
    $bit=[uint64][Math]::Pow(2,$offset)
    $Mask[$segment]=[uint64]($Mask[$segment] -bor $bit)
}
function Or-MaskInto {
    param([object]$Dictionary,[string]$Key,[UInt64[]]$Source)
    if($Dictionary.ContainsKey($Key)){
        [UInt64[]]$target=$Dictionary[$Key]
        for($i=0;$i-lt$script:MaskSegments;$i++){ $target[$i]=[uint64]($target[$i] -bor $Source[$i]) }
    } else {
        [UInt64[]]$copy=New-Mask
        [Array]::Copy($Source,$copy,$script:MaskSegments)
        $Dictionary.Add($Key,$copy)
    }
}
function Get-MaskKey {
    param([UInt64[]]$Mask)
    $parts=New-Object 'string[]' $Mask.Length
    for($i=0;$i-lt$Mask.Length;$i++){ $parts[$i]=$Mask[$i].ToString('X16') }
    return ($parts -join '-')
}
function Get-KeyFields {
    param([string]$Key)
    return $Key.Split($US)
}
function Add-FirstOrConflict {
    param(
        [object]$FirstMap,
        [object]$ConflictMap,
        [string]$Key,
        [string]$Value
    )
    if(-not $FirstMap.ContainsKey($Key)){ $FirstMap.Add($Key,$Value); return }
    $first=[string]$FirstMap[$Key]
    if($first -eq $Value){return}
    if(-not $ConflictMap.ContainsKey($Key)){
        $set=New-StringSet
        [void]$set.Add($first)
        $ConflictMap.Add($Key,$set)
    }
    [void]$ConflictMap[$Key].Add($Value)
}
function Get-SortedStrings {
    param([object]$Values)
    [string[]]$items=@($Values)
    [Array]::Sort($items,[StringComparer]::Ordinal)
    return $items
}
function Read-SnapshotCatalog {
    param([string]$Path)
    $list=New-Object System.Collections.ArrayList
    $seen=New-StringSet
    $sr=New-Object IO.StreamReader($Path,$utf8,$true,65536)
    try {
        $header=$sr.ReadLine()
        if($null -eq $header){Fail 3 'product-snapshots.tsv is empty'}
        while(-not $sr.EndOfStream){
            $line=$sr.ReadLine()
            if([string]::IsNullOrEmpty($line)){continue}
            $pos=$line.IndexOf($Tab)
            $snap=if($pos-ge0){$line.Substring(0,$pos)}else{$line}
            if($seen.Add($snap)){[void]$list.Add($snap)}
        }
    } finally {$sr.Dispose()}
    return @($list)
}
function Read-FactTable {
    param([string]$FileName,[string[]]$KeyFields)
    $path=Join-Path $IndexRoot $FileName
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){Fail 3 ('Family index table missing: '+$FileName)}
    $dict=New-MaskDictionary
    $rows=0L
    $sr=New-Object IO.StreamReader($path,$utf8,$true,65536)
    try {
        $headerLine=$sr.ReadLine()
        if($null -eq $headerLine){Fail 3 ($FileName+' is empty')}
        $headers=$headerLine.Split($Tab)
        $index=@{}
        for($i=0;$i-lt$headers.Count;$i++){$index[$headers[$i]]=$i}
        if(-not $index.ContainsKey('snapshot')){Fail 3 ($FileName+' lacks snapshot column')}
        $selected=New-Object 'int[]' $KeyFields.Count
        for($j=0;$j-lt$KeyFields.Count;$j++){
            if(-not $index.ContainsKey($KeyFields[$j])){Fail 3 ($FileName+' lacks '+$KeyFields[$j]+' column')}
            $selected[$j]=[int]$index[$KeyFields[$j]]
        }
        while(-not $sr.EndOfStream){
            $line=$sr.ReadLine()
            if([string]::IsNullOrEmpty($line)){continue}
            $parts=$line.Split($Tab)
            $snap=$parts[[int]$index['snapshot']]
            if(-not $SnapshotIndex.ContainsKey($snap)){Fail 3 ('Unknown snapshot in '+$FileName+': '+$snap)}
            $fields=New-Object 'string[]' $KeyFields.Count
            for($j=0;$j-lt$selected.Count;$j++){$fields[$j]=$parts[$selected[$j]]}
            $key=$fields -join $US
            if($dict.ContainsKey($key)){[UInt64[]]$mask=$dict[$key]}else{[UInt64[]]$mask=New-Mask;$dict.Add($key,$mask)}
            Or-SnapshotIntoMask $mask ([int]$SnapshotIndex[$snap])
            $rows++
        }
    } finally {$sr.Dispose()}
    return [pscustomobject]@{Rows=$rows;Facts=$dict;Fields=$KeyFields}
}
function Get-MaskInfo {
    param([UInt64[]]$Mask)
    $snaps=New-Object System.Collections.ArrayList
    for($i=0;$i-lt$Snapshots.Count;$i++){
        $segment=[int][Math]::Floor($i/64)
        $offset=$i%64
        $bit=[uint64][Math]::Pow(2,$offset)
        if(($Mask[$segment] -band $bit)-ne 0){[void]$snaps.Add([string]$Snapshots[$i])}
    }
    return [pscustomobject]@{
        Count=$snaps.Count
        First=if($snaps.Count-gt0){[string]$snaps[0]}else{''}
        Last=if($snaps.Count-gt0){[string]$snaps[$snaps.Count-1]}else{''}
        Snapshots=(@($snaps)-join '|')
    }
}
function Write-CompactFacts {
    param([object]$Table,[string]$OutputName)
    $headers=@($Table.Fields)+@('snapshot_set_id','snapshot_count','first_seen','last_seen')
    $sw=New-Writer (Join-Path $TempRoot $OutputName) $headers
    try {
        [string[]]$keys=@($Table.Facts.Keys)
        [Array]::Sort($keys,[StringComparer]::Ordinal)
        foreach($key in $keys){
            [UInt64[]]$mask=$Table.Facts[$key]
            $mk=Get-MaskKey $mask
            $info=$SnapshotInfo[$mk]
            $fields=@(Get-KeyFields $key)+@($SnapshotSetId[$mk],$info.Count,$info.First,$info.Last)
            Write-Tsv $sw $fields
        }
    } finally {$sw.Dispose()}
}
function Get-DirectoryBytes {
    param([string]$Path)
    $sum=0L
    foreach($f in @(Get-ChildItem -LiteralPath $Path -File -Recurse)){ $sum += [long]$f.Length }
    return $sum
}

if(Is-HelpToken $IndexInput){Show-Usage;exit 0}
if([string]::IsNullOrWhiteSpace($IndexInput)-or[string]::IsNullOrWhiteSpace($OutputInput)){Show-Usage;Fail 2 'family index and output folder are required'}
$IndexRoot=Resolve-IndexRoot $IndexInput
if($null-eq$IndexRoot){Fail 3 ('Family index not found or incomplete: '+$IndexInput)}
try {
    $OutputFull=[IO.Path]::GetFullPath($OutputInput)
} catch { Fail 2 ('Invalid output folder: '+$OutputInput) }
if(Test-Path -LiteralPath $OutputFull){Fail 3 ('Output folder already exists: '+$OutputFull)}
$parent=Split-Path -Parent $OutputFull
if([string]::IsNullOrWhiteSpace($parent)){$parent=(Get-Location).Path}
if(-not(Test-Path -LiteralPath $parent -PathType Container)){[void](New-Item -ItemType Directory -Path $parent -Force)}
$TempRoot=Join-Path $parent ('.mvs-family-compact-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $TempRoot)

try {
    $Snapshots=@(Read-SnapshotCatalog (Join-Path $IndexRoot 'product-snapshots.tsv'))
    if($Snapshots.Count-eq0){Fail 3 'Family index contains no snapshots'}
    $SnapshotIndex=@{}
    for($i=0;$i-lt$Snapshots.Count;$i++){$SnapshotIndex[[string]$Snapshots[$i]]=$i}
    $script:MaskSegments=[int][Math]::Ceiling($Snapshots.Count/64.0)

    Write-Line ('Source family index: '+$IndexRoot)
    Write-Line ('Output: '+$OutputFull)
    Write-Line ('Snapshots: '+$Snapshots.Count)

    $Ids=Read-FactTable 'product-ids.tsv' @('source_file','product_title','id')
    $Dates=Read-FactTable 'product-dates.tsv' @('source_file','product_title','date','id')
    $Files=Read-FactTable 'product-files.tsv' @('source_file','product_title','product_id','filename')
    $Hashes=Read-FactTable 'product-hashes.tsv' @('source_file','product_title','product_id','filename','algorithm','hash')
    $Notes=Read-FactTable 'product-notes.tsv' @('source_file','product_title','source_id','note_text','raw_html_sha256')
    $Presence=Read-FactTable 'product-snapshots.tsv' @('product_title','evidence_sources')

    $GlobalHashes=New-MaskDictionary
    $FileAlgFirst=New-StringDictionary
    $FileAlgConflicts=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    $ProdFileAlgFirst=New-StringDictionary
    $ProdFileAlgConflicts=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    $HashFirstFilename=New-StringDictionary
    $HashFilenameAliases=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)

    foreach($key in @($Hashes.Facts.Keys)){
        $p=Get-KeyFields $key
        $title=$p[1];$filename=$p[3];$alg=$p[4];$hash=$p[5]
        $globalKey=$filename+$US+$alg+$US+$hash
        Or-MaskInto $GlobalHashes $globalKey ([UInt64[]]$Hashes.Facts[$key])
        Add-FirstOrConflict $FileAlgFirst $FileAlgConflicts ($filename+$US+$alg) $hash
        Add-FirstOrConflict $ProdFileAlgFirst $ProdFileAlgConflicts ($title+$US+$filename+$US+$alg) $hash
        Add-FirstOrConflict $HashFirstFilename $HashFilenameAliases ($alg+$US+$hash) $filename
    }

    $AllMaskKeys=New-StringSet
    $MaskByKey=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    foreach($table in @($Ids,$Dates,$Files,$Hashes,$Notes,$Presence)){
        foreach($mask in @($table.Facts.Values)){
            $mk=Get-MaskKey ([UInt64[]]$mask)
            if($AllMaskKeys.Add($mk)){$MaskByKey.Add($mk,$mask)}
        }
    }
    foreach($mask in @($GlobalHashes.Values)){
        $mk=Get-MaskKey ([UInt64[]]$mask)
        if($AllMaskKeys.Add($mk)){$MaskByKey.Add($mk,$mask)}
    }
    [string[]]$sortedMasks=@($AllMaskKeys)
    [Array]::Sort($sortedMasks,[StringComparer]::Ordinal)
    $SnapshotSetId=New-StringDictionary
    $SnapshotInfo=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    for($i=0;$i-lt$sortedMasks.Count;$i++){
        $id=('S{0:D4}' -f ($i+1))
        $mk=$sortedMasks[$i]
        $SnapshotSetId.Add($mk,$id)
        $SnapshotInfo.Add($mk,(Get-MaskInfo ([UInt64[]]$MaskByKey[$mk])))
    }

    foreach($name in @('classification-rules.tsv','family-nodes.tsv','family-parent-relationships.tsv','overrides-applied.tsv','product-classifications.tsv','product-family-memberships.tsv','unclassified-products.tsv')){
        $src=Join-Path $IndexRoot $name
        if(Test-Path -LiteralPath $src -PathType Leaf){[IO.File]::Copy($src,(Join-Path $TempRoot $name),$false)}
    }
    $sourceSummary=Join-Path $IndexRoot 'family-index-summary.txt'
    if(Test-Path -LiteralPath $sourceSummary -PathType Leaf){[IO.File]::Copy($sourceSummary,(Join-Path $TempRoot 'source-family-index-summary.txt'),$false)}

    $sw=New-Writer (Join-Path $TempRoot 'snapshot-catalog.tsv') @('snapshot_index','snapshot')
    try{for($i=0;$i-lt$Snapshots.Count;$i++){Write-Tsv $sw @(($i+1),$Snapshots[$i])}}finally{$sw.Dispose()}
    $sw=New-Writer (Join-Path $TempRoot 'snapshot-sets.tsv') @('snapshot_set_id','snapshot_count','first_snapshot','last_snapshot','snapshots')
    try{
        foreach($mk in $sortedMasks){
            $info=$SnapshotInfo[$mk]
            Write-Tsv $sw @($SnapshotSetId[$mk],$info.Count,$info.First,$info.Last,$info.Snapshots)
        }
    }finally{$sw.Dispose()}

    Write-CompactFacts $Ids 'product-ids-all-ever.tsv'
    Write-CompactFacts $Dates 'product-dates-all-ever.tsv'
    Write-CompactFacts $Files 'product-files-all-ever.tsv'
    Write-CompactFacts $Hashes 'product-file-hashes-all-ever.tsv'
    Write-CompactFacts $Notes 'product-notes-all-ever.tsv'
    Write-CompactFacts $Presence 'product-presence-all-ever.tsv'

    $sw=New-Writer (Join-Path $TempRoot 'file-hashes-all-ever.tsv') @('filename','algorithm','hash','snapshot_set_id','snapshot_count','first_seen','last_seen')
    try{
        [string[]]$keys=@($GlobalHashes.Keys);[Array]::Sort($keys,[StringComparer]::Ordinal)
        foreach($key in $keys){
            $p=Get-KeyFields $key
            [UInt64[]]$mask=$GlobalHashes[$key]
            $mk=Get-MaskKey $mask;$info=$SnapshotInfo[$mk]
            Write-Tsv $sw @($p[0],$p[1],$p[2],$SnapshotSetId[$mk],$info.Count,$info.First,$info.Last)
        }
    }finally{$sw.Dispose()}

    $ConflictTitles=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    foreach($key in @($Hashes.Facts.Keys)){
        $p=Get-KeyFields $key;$title=$p[1];$filename=$p[3];$alg=$p[4];$hash=$p[5]
        $fileAlg=$filename+$US+$alg
        if(-not $FileAlgConflicts.ContainsKey($fileAlg)){continue}
        $globalKey=$filename+$US+$alg+$US+$hash
        if(-not $ConflictTitles.ContainsKey($globalKey)){$ConflictTitles.Add($globalKey,(New-StringSet))}
        [void]$ConflictTitles[$globalKey].Add($title)
    }

    $sw=New-Writer (Join-Path $TempRoot 'filename-hash-conflicts.tsv') @('filename','algorithm','distinct_hashes','conflict_type')
    try{
        [string[]]$keys=@($FileAlgConflicts.Keys);[Array]::Sort($keys,[StringComparer]::Ordinal)
        foreach($key in $keys){
            $p=Get-KeyFields $key
            $hasProductConflict=$false
            foreach($pk in @($ProdFileAlgConflicts.Keys)){
                $pp=Get-KeyFields $pk
                if($pp[1]-eq$p[0]-and$pp[2]-eq$p[1]){$hasProductConflict=$true;break}
            }
            $type=if($hasProductConflict){'PRODUCT_HASH_DISAGREEMENT_PRESENT'}else{'CROSS_PRODUCT_FILENAME_REUSE'}
            Write-Tsv $sw @($p[0],$p[1],$FileAlgConflicts[$key].Count,$type)
        }
    }finally{$sw.Dispose()}

    $sw=New-Writer (Join-Path $TempRoot 'filename-hash-conflict-details.tsv') @('filename','algorithm','hash','snapshot_set_id','snapshot_count','first_seen','last_seen','product_title_count','product_titles')
    try{
        [string[]]$keys=@($GlobalHashes.Keys);[Array]::Sort($keys,[StringComparer]::Ordinal)
        foreach($key in $keys){
            $p=Get-KeyFields $key;$fileAlg=$p[0]+$US+$p[1]
            if(-not $FileAlgConflicts.ContainsKey($fileAlg)){continue}
            [UInt64[]]$mask=$GlobalHashes[$key];$mk=Get-MaskKey $mask;$info=$SnapshotInfo[$mk]
            [string[]]$titles=if($ConflictTitles.ContainsKey($key)){Get-SortedStrings $ConflictTitles[$key]}else{@()}
            Write-Tsv $sw @($p[0],$p[1],$p[2],$SnapshotSetId[$mk],$info.Count,$info.First,$info.Last,$titles.Count,($titles -join '|'))
        }
    }finally{$sw.Dispose()}

    $sw=New-Writer (Join-Path $TempRoot 'product-file-hash-conflicts.tsv') @('product_title','filename','algorithm','distinct_hashes','hashes','conflict_type')
    try{
        [string[]]$keys=@($ProdFileAlgConflicts.Keys);[Array]::Sort($keys,[StringComparer]::Ordinal)
        foreach($key in $keys){
            $p=Get-KeyFields $key;[string[]]$values=Get-SortedStrings $ProdFileAlgConflicts[$key]
            Write-Tsv $sw @($p[0],$p[1],$p[2],$values.Count,($values -join '|'),'PRODUCT_HASH_DISAGREEMENT')
        }
    }finally{$sw.Dispose()}

    $sw=New-Writer (Join-Path $TempRoot 'hash-filename-aliases.tsv') @('algorithm','hash','filename_count','filenames')
    try{
        [string[]]$keys=@($HashFilenameAliases.Keys);[Array]::Sort($keys,[StringComparer]::Ordinal)
        foreach($key in $keys){
            $p=Get-KeyFields $key;[string[]]$values=Get-SortedStrings $HashFilenameAliases[$key]
            Write-Tsv $sw @($p[0],$p[1],$values.Count,($values -join '|'))
        }
    }finally{$sw.Dispose()}

    $rawSource=Join-Path $IndexRoot 'raw-html'
    $rawTarget=Join-Path $TempRoot 'raw-html'
    [void](New-Item -ItemType Directory -Path $rawTarget)
    $rawCount=0
    if(Test-Path -LiteralPath $rawSource -PathType Container){
        foreach($f in @(Get-ChildItem -LiteralPath $rawSource -File)){
            [IO.File]::Copy($f.FullName,(Join-Path $rawTarget $f.Name),$false);$rawCount++
        }
    }

    $started.Stop()
    $summaryPath=Join-Path $TempRoot 'compact-index-summary.txt'
    $sw=New-Object IO.StreamWriter($summaryPath,$false,$utf8,65536);$sw.NewLine="`r`n"
    try{
        $sw.WriteLine('MVS Explorer Toolkit compact product-family index '+$Version)
        $sw.WriteLine('Source family index: '+$IndexRoot)
        $sw.WriteLine('Snapshots: '+$Snapshots.Count)
        $sw.WriteLine('Snapshot sets: '+$sortedMasks.Count)
        $sw.WriteLine('Product ID observations: '+$Ids.Rows)
        $sw.WriteLine('Product IDs all-ever: '+$Ids.Facts.Count)
        $sw.WriteLine('Product date observations: '+$Dates.Rows)
        $sw.WriteLine('Product dates all-ever: '+$Dates.Facts.Count)
        $sw.WriteLine('Product file observations: '+$Files.Rows)
        $sw.WriteLine('Product files all-ever: '+$Files.Facts.Count)
        $sw.WriteLine('Product hash observations: '+$Hashes.Rows)
        $sw.WriteLine('Product file hashes all-ever: '+$Hashes.Facts.Count)
        $sw.WriteLine('Global file-hash tuples: '+$GlobalHashes.Count)
        $sw.WriteLine('Filename+algorithm conflicts: '+$FileAlgConflicts.Count)
        $sw.WriteLine('Product+filename+algorithm hash disagreements: '+$ProdFileAlgConflicts.Count)
        $sw.WriteLine('Hash aliases across filenames: '+$HashFilenameAliases.Count)
        $sw.WriteLine('Product note observations: '+$Notes.Rows)
        $sw.WriteLine('Product notes all-ever: '+$Notes.Facts.Count)
        $sw.WriteLine('Product presence observations: '+$Presence.Rows)
        $sw.WriteLine('Product presence facts all-ever: '+$Presence.Facts.Count)
        $sw.WriteLine('Raw note HTML blobs: '+$rawCount)
        $sw.WriteLine('Exact snapshot provenance preserved via snapshot_set_id: true')
        $sw.WriteLine('SHA1/SHA256 pairings inferred by filename: false')
        $sw.WriteLine('Elapsed milliseconds: '+$started.ElapsedMilliseconds)
    }finally{$sw.Dispose()}

    $bytes=Get-DirectoryBytes $TempRoot
    Move-Item -LiteralPath $TempRoot -Destination $OutputFull
    Write-Line ('Compact family index complete: files='+$Files.Facts.Count+' product-file-hashes='+$Hashes.Facts.Count+' global-file-hashes='+$GlobalHashes.Count+' conflicts='+$FileAlgConflicts.Count)
    Write-Line ('Output bytes: '+$bytes)
    Write-Line ('Results: '+$OutputFull)
    exit 0
} catch {
    if(Test-Path -LiteralPath $TempRoot){Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue}
    throw
}
:_MVSProductFamilyCompact_end
