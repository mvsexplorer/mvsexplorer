$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$ArchiveInput = [string]$env:mvsfa_archive_root
$OutputInput = [string]$env:mvsfa_output_root
$Caller = [string]$env:mvsfa_caller
$Version = [string]$env:mvsfa_version

$Domains = @(
    [pscustomobject]@{ name='id_from_mvs.txt'; property='id'; source_file='mvs.txt'; id_mode='numeric' },
    [pscustomobject]@{ name='id_from_mvs_ids.txt'; property='id'; source_file='mvs_ids.txt'; id_mode='numeric' },
    [pscustomobject]@{ name='id_from_mvs_names.txt'; property='id'; source_file='mvs_names.txt'; id_mode='text' },
    [pscustomobject]@{ name='id_from_mvs_dates.txt'; property='id'; source_file='mvs_dates.txt'; id_mode='numeric' },
    [pscustomobject]@{ name='title_from_mvs.txt'; property='title'; source_file='mvs.txt'; id_mode='' },
    [pscustomobject]@{ name='title_from_mvs_ids.txt'; property='title'; source_file='mvs_ids.txt'; id_mode='' },
    [pscustomobject]@{ name='title_from_mvs_names.txt'; property='title'; source_file='mvs_names.txt'; id_mode='' },
    [pscustomobject]@{ name='title_from_mvs_dates.txt'; property='title'; source_file='mvs_dates.txt'; id_mode='' },
    [pscustomobject]@{ name='dates_from_mvs_dates.txt'; property='date'; source_file='mvs_dates.txt'; id_mode='' },
    [pscustomobject]@{ name='sha1_from_mvs.txt'; property='sha1'; source_file='mvs.txt'; id_mode='' },
    [pscustomobject]@{ name='sha1_from_mvs_names.txt'; property='sha1'; source_file='mvs_names.txt'; id_mode='' },
    [pscustomobject]@{ name='sha1_from_mvs.sha1'; property='sha1'; source_file='mvs.sha1'; id_mode='' },
    [pscustomobject]@{ name='sha256_from_mvs.txt'; property='sha256'; source_file='mvs.txt'; id_mode='' },
    [pscustomobject]@{ name='sha256_from_mvs_names.txt'; property='sha256'; source_file='mvs_names.txt'; id_mode='' },
    [pscustomobject]@{ name='sha256_from_mvs.sha256'; property='sha256'; source_file='mvs.sha256'; id_mode='' },
    [pscustomobject]@{ name='filenames_from_mvs.txt'; property='filename'; source_file='mvs.txt'; id_mode='' },
    [pscustomobject]@{ name='filenames_from_mvs_names.txt'; property='filename'; source_file='mvs_names.txt'; id_mode='' },
    [pscustomobject]@{ name='filenames_from_mvs.sha1'; property='filename'; source_file='mvs.sha1'; id_mode='' },
    [pscustomobject]@{ name='filenames_from_mvs.sha256'; property='filename'; source_file='mvs.sha256'; id_mode='' }
)

$SourceFiles = @('mvs.txt','mvs_ids.txt','mvs_names.txt','mvs_dates.txt','mvs.sha1','mvs.sha256')
$SourceDomains = @{}
foreach ($source in $SourceFiles) {
    $SourceDomains[$source] = @($Domains | Where-Object { $_.source_file -eq $source })
}

$RegexOptions = [System.Text.RegularExpressions.RegexOptions]::Compiled
$RxIds = New-Object System.Text.RegularExpressions.Regex -ArgumentList @('^(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$',$RegexOptions)
$RxDates = New-Object System.Text.RegularExpressions.Regex -ArgumentList @('^(?<date>.*?)\s+-\s+(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$',$RegexOptions)
$RxProductHeader = New-Object System.Text.RegularExpressions.Regex -ArgumentList @('^---\s*(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*---\s*$',$RegexOptions)
$RxNamesHeader = New-Object System.Text.RegularExpressions.Regex -ArgumentList @('^---\s*(?<title>.*?)\s*\[ID:\s*(?<id>[^\]]+?)\s*\]\s*---\s*$',$RegexOptions)
$RxFile = New-Object System.Text.RegularExpressions.Regex -ArgumentList @('^\s*(?<hash>[0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})\s+\*(?<filename>.+?)\s*$',$RegexOptions)
$RxSha1 = New-Object System.Text.RegularExpressions.Regex -ArgumentList @('^\s*(?<hash>[0-9A-Fa-f]{40})\s+\*(?<filename>.+?)\s*$',$RegexOptions)
$RxSha256 = New-Object System.Text.RegularExpressions.Regex -ArgumentList @('^\s*(?<hash>[0-9A-Fa-f]{64})\s+\*(?<filename>.+?)\s*$',$RegexOptions)

function Write-Line {
    param([AllowEmptyString()][string]$Text)
    [Console]::Out.WriteLine($Text)
}

function Write-Err {
    param([string]$Text)
    [Console]::Error.WriteLine($Text)
}

function Fail {
    param([int]$Code,[string]$Message)
    Write-Err ('ERROR: ' + $Message)
    [Environment]::Exit($Code)
}

function Show-Usage {
    Write-Line ('MVS Explorer Toolkit fast archive builder ' + $Version)
    Write-Line ('Usage: ' + $Caller + ' mvs-dumps-root output-folder')
    Write-Line 'Builds both change-history and all-ever outputs in one streaming archive pass.'
}

function Convert-TsvField {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    return $Value.Replace("`t",' ').Replace("`r",' ').Replace("`n",' ')
}

function Resolve-ArchiveRoot {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    try {
        if (-not (Test-Path -LiteralPath $Name -PathType Container)) { return $null }
        $resolved = (Resolve-Path -LiteralPath $Name).Path
        $direct = @(Get-ChildItem -LiteralPath $resolved -Directory -ErrorAction Stop |
            Where-Object { $_.Name -match '^mvs_\d{4}-\d{2}-\d{2}(?:-\d{4})?(?:_\d+)?$' })
        if ($direct.Count -gt 0) { return $resolved }
        $wrapper = Join-Path $resolved 'mvs_dumps_archive'
        if (Test-Path -LiteralPath $wrapper -PathType Container) {
            $wrapped = @(Get-ChildItem -LiteralPath $wrapper -Directory -ErrorAction Stop |
                Where-Object { $_.Name -match '^mvs_\d{4}-\d{2}-\d{2}(?:-\d{4})?(?:_\d+)?$' })
            if ($wrapped.Count -gt 0) { return (Resolve-Path -LiteralPath $wrapper).Path }
        }
    } catch {
    }
    return $null
}

function Resolve-OutputRoot {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    $path=$Name
    if (-not [IO.Path]::IsPathRooted($path)) { $path=Join-Path (Get-Location).Path $path }
    $full=[IO.Path]::GetFullPath($path)
    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $full -Force)
    }
    return (Resolve-Path -LiteralPath $full).Path
}

function Get-Snapshots {
    param([string]$Root)
    $items=New-Object System.Collections.ArrayList
    foreach($dir in @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction Stop)){
        if($dir.Name -notmatch '^mvs_(?<date>\d{4}-\d{2}-\d{2})(?:-(?<time>\d{4}))?(?:_(?<revision>\d+))?$'){continue}
        $dateKey=$Matches.date.Replace('-','')
        $timeKey=if([string]::IsNullOrWhiteSpace([string]$Matches.time)){'0000'}else{[string]$Matches.time}
        $revision=0
        if(-not [string]::IsNullOrWhiteSpace([string]$Matches.revision)){$revision=[int]$Matches.revision}
        $sortKey=$dateKey+$timeKey+$revision.ToString('D8')+'|'+$dir.Name.ToLowerInvariant()
        [void]$items.Add([pscustomobject]@{name=$dir.Name;path=$dir.FullName;sort_key=$sortKey})
    }
    return @($items | Sort-Object sort_key,name)
}

function Get-SnapshotSourcePath {
    param([object]$Snapshot,[string]$SourceFile)
    $direct=Join-Path ([string]$Snapshot.path) $SourceFile
    if(Test-Path -LiteralPath $direct -PathType Leaf){return $direct}
    $nested=Join-Path (Join-Path ([string]$Snapshot.path) 'mvs_dmp') $SourceFile
    if(Test-Path -LiteralPath $nested -PathType Leaf){return $nested}
    return $null
}

function Normalize-Title {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if($null -eq $Value){return ''}
    $decoded=[System.Net.WebUtility]::HtmlDecode($Value)
    return ([regex]::Replace($decoded,'\s+',' ')).Trim()
}

function Normalize-Id {
    param([AllowNull()][AllowEmptyString()][string]$Value,[string]$IdMode)
    if($null -eq $Value){return ''}
    $text=$Value.Trim()
    if($IdMode -eq 'numeric' -and $text -match '^\d+$'){
        $text=[regex]::Replace($text,'^0+(?=\d)','')
    }
    return $text
}

function Get-DisplayValue {
    param([AllowNull()][AllowEmptyString()][string]$Value,[string]$Kind,[string]$IdMode)
    if($null -eq $Value){return ''}
    switch($Kind){
        'id' { return Normalize-Id $Value $IdMode }
        'title' { return Normalize-Title $Value }
        'date' { return $Value.Trim() }
        'sha1' { return $Value.Trim().ToLowerInvariant() }
        'sha256' { return $Value.Trim().ToLowerInvariant() }
        'filename' { return $Value.Trim() }
        default { return $Value.Trim() }
    }
}

function Get-Key {
    param([string]$Display,[string]$Kind)
    if($Kind -eq 'date'){return $Display}
    return $Display.ToLowerInvariant()
}

function New-ValueSet {
    return [pscustomobject]@{
        rows=(New-Object System.Collections.ArrayList)
        seen=(New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal))
    }
}

function New-SourceModel {
    $sets=@{}
    foreach($kind in @('id','title','date','sha1','sha256','filename')){$sets[$kind]=New-ValueSet}
    return [pscustomobject]@{sets=$sets}
}

function Add-ModelValue {
    param([object]$Model,[string]$Kind,[AllowNull()][AllowEmptyString()][string]$Value,[string]$IdMode)
    $display=Get-DisplayValue $Value $Kind $IdMode
    if([string]::IsNullOrWhiteSpace($display)){return}
    $key=Get-Key $display $Kind
    $set=$Model.sets[$Kind]
    if($set.seen.Add($key)){[void]$set.rows.Add([pscustomobject]@{key=$key;value=$display})}
}

function Invoke-ForEachLine {
    param([string]$Path,[scriptblock]$Action)
    $reader=New-Object System.IO.StreamReader -ArgumentList @($Path,[System.Text.Encoding]::UTF8,$true,65536)
    try {
        while($true){
            $line=$reader.ReadLine()
            if($null -eq $line){break}
            & $Action ([string]$line)
        }
    } finally {
        $reader.Dispose()
    }
}

function Read-SourceModel {
    param([string]$Path,[string]$Name)
    $model=New-SourceModel

    if($Name -eq 'mvs_ids.txt'){
        Invoke-ForEachLine $Path {
            param($line)
            $m=$RxIds.Match($line)
            if($m.Success){
                Add-ModelValue $model 'id' $m.Groups['id'].Value 'numeric'
                Add-ModelValue $model 'title' $m.Groups['title'].Value ''
            }
        }
        return $model
    }

    if($Name -eq 'mvs_dates.txt'){
        Invoke-ForEachLine $Path {
            param($line)
            $m=$RxDates.Match($line)
            if($m.Success){
                Add-ModelValue $model 'id' $m.Groups['id'].Value 'numeric'
                Add-ModelValue $model 'title' $m.Groups['title'].Value ''
                Add-ModelValue $model 'date' $m.Groups['date'].Value ''
            }
        }
        return $model
    }

    if($Name -eq 'mvs.sha1' -or $Name -eq 'mvs.sha256'){
        $rx=if($Name -eq 'mvs.sha1'){$RxSha1}else{$RxSha256}
        $kind=if($Name -eq 'mvs.sha1'){'sha1'}else{'sha256'}
        Invoke-ForEachLine $Path {
            param($line)
            $m=$rx.Match($line)
            if($m.Success){
                Add-ModelValue $model $kind $m.Groups['hash'].Value ''
                Add-ModelValue $model 'filename' $m.Groups['filename'].Value ''
            }
        }
        return $model
    }

    if($Name -eq 'mvs.txt' -or $Name -eq 'mvs_names.txt'){
        $inside=$false
        $headerRx=if($Name -eq 'mvs_names.txt'){$RxNamesHeader}else{$RxProductHeader}
        $idMode=if($Name -eq 'mvs_names.txt'){'text'}else{'numeric'}
        # Use a direct StreamReader because section state must persist across lines.
        $reader=New-Object System.IO.StreamReader -ArgumentList @($Path,[System.Text.Encoding]::UTF8,$true,65536)
        try{
            while($true){
                $line=$reader.ReadLine()
                if($null -eq $line){break}
                $hm=$headerRx.Match([string]$line)
                if($hm.Success){
                    $inside=$true
                    Add-ModelValue $model 'id' $hm.Groups['id'].Value $idMode
                    Add-ModelValue $model 'title' $hm.Groups['title'].Value ''
                    continue
                }
                if([string]::IsNullOrWhiteSpace([string]$line)){$inside=$false;continue}
                if(-not $inside){continue}
                $fm=$RxFile.Match([string]$line)
                if($fm.Success){
                    $hash=$fm.Groups['hash'].Value
                    Add-ModelValue $model 'filename' $fm.Groups['filename'].Value ''
                    if($hash.Length -eq 40){Add-ModelValue $model 'sha1' $hash ''}
                    elseif($hash.Length -eq 64){Add-ModelValue $model 'sha256' $hash ''}
                }
            }
        } finally {$reader.Dispose()}
        return $model
    }

    throw ('Unsupported source file: '+$Name)
}

function New-UnionState {
    return [pscustomobject]@{
        map=(New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal))
        order=(New-Object System.Collections.ArrayList)
    }
}

function Update-Union {
    param([object]$State,[object]$Set,[string]$SnapshotName)
    foreach($row in @($Set.rows)){
        $key=[string]$row.key
        if(-not $State.map.ContainsKey($key)){
            $record=[object[]]@($SnapshotName,$SnapshotName,1,[string]$row.value)
            $State.map.Add($key,$record)
            [void]$State.order.Add($key)
        } else {
            $record=[object[]]$State.map[$key]
            $record[1]=$SnapshotName
            $record[2]=[int]$record[2]+1
        }
    }
}

function Reset-Directory {
    param([string]$Path)
    if(Test-Path -LiteralPath $Path){Remove-Item -LiteralPath $Path -Recurse -Force}
    [void](New-Item -ItemType Directory -Path $Path -Force)
}

function New-Utf8Writer {
    param([string]$Path,[string]$Header)
    $parent=Split-Path -Parent $Path
    if(-not(Test-Path -LiteralPath $parent -PathType Container)){[void](New-Item -ItemType Directory -Path $parent -Force)}
    $writer=New-Object System.IO.StreamWriter -ArgumentList @($Path,$false,$utf8,65536)
    $writer.NewLine=[Environment]::NewLine
    $writer.WriteLine($Header)
    return $writer
}

function Write-TsvLine {
    param([System.IO.StreamWriter]$Writer,[object[]]$Fields)
    $values=New-Object System.Collections.ArrayList
    foreach($field in $Fields){[void]$values.Add((Convert-TsvField ([string]$field)))}
    $Writer.WriteLine((@($values) -join [char]9))
}

if(@('--help','-h','-?','/h','/?') -contains $ArchiveInput){Show-Usage;exit 0}
if([string]::IsNullOrWhiteSpace($ArchiveInput) -or [string]::IsNullOrWhiteSpace($OutputInput)){Show-Usage;Fail 2 'Missing required argument.'}

$ArchiveRoot=Resolve-ArchiveRoot $ArchiveInput
if($null -eq $ArchiveRoot){Fail 3 ('Archive root not found: '+$ArchiveInput)}
$OutputRoot=Resolve-OutputRoot $OutputInput
if($null -eq $OutputRoot){Fail 2 ('Invalid output folder: '+$OutputInput)}

$Snapshots=@(Get-Snapshots $ArchiveRoot)
if($Snapshots.Count -lt 2){Fail 4 ('Insufficient recognized snapshots: '+$Snapshots.Count)}

$addedRoot=Join-Path $OutputRoot 'added'
$removedRoot=Join-Path $OutputRoot 'removed'
$allRoot=Join-Path $OutputRoot 'all-ever'
Reset-Directory $addedRoot
Reset-Directory $removedRoot
Reset-Directory $allRoot

$addedWriters=@{}
$removedWriters=@{}
$unions=@{}
foreach($domain in $Domains){
    $addedWriters[$domain.name]=New-Utf8Writer (Join-Path $addedRoot ($domain.name+'.tsv')) "from_dump`tto_dump`tvalue"
    $removedWriters[$domain.name]=New-Utf8Writer (Join-Path $removedRoot ($domain.name+'.tsv')) "from_dump`tto_dump`tvalue"
    $unions[$domain.name]=New-UnionState
}

$historyCoverage=New-Utf8Writer (Join-Path $OutputRoot 'history-coverage.tsv') "from_dump`tto_dump`tsource_file`tstatus"
$allCoverage=New-Utf8Writer (Join-Path $OutputRoot 'all-ever-coverage.tsv') "dump`tsource_file`tpresent"
$snapshotWriter=New-Utf8Writer (Join-Path $OutputRoot 'history-snapshots.tsv') "index`tdump"
$everSnapshotWriter=New-Utf8Writer (Join-Path $OutputRoot 'all-ever-snapshots.tsv') "index`tdump"
for($i=0;$i-lt$Snapshots.Count;$i++){
    Write-TsvLine $snapshotWriter @([string]($i+1),[string]$Snapshots[$i].name)
    Write-TsvLine $everSnapshotWriter @([string]($i+1),[string]$Snapshots[$i].name)
}
$snapshotWriter.Dispose()
$everSnapshotWriter.Dispose()

$previous=@{}
$addedCount=0L
$removedCount=0L
$sw=[Diagnostics.Stopwatch]::StartNew()

try{
    for($i=0;$i-lt$Snapshots.Count;$i++){
        $snapshot=$Snapshots[$i]
        $current=@{}
        $snapSw=[Diagnostics.Stopwatch]::StartNew()

        foreach($source in $SourceFiles){
            $path=Get-SnapshotSourcePath $snapshot $source
            $present=$null -ne $path
            Write-TsvLine $allCoverage @([string]$snapshot.name,$source,$(if($present){'1'}else{'0'}))

            $model=$null
            if($present){$model=Read-SourceModel $path $source}
            $current[$source]=$model

            if($null -ne $model){
                foreach($domain in @($SourceDomains[$source])){
                    Update-Union $unions[$domain.name] $model.sets[$domain.property] ([string]$snapshot.name)
                }
            }

            if($i -gt 0){
                $prevModel=$previous[$source]
                $prevPresent=$null -ne $prevModel
                $status=if($prevPresent -and $present){'compared'}elseif($prevPresent){'missing-second'}elseif($present){'missing-first'}else{'missing-both'}
                Write-TsvLine $historyCoverage @([string]$Snapshots[$i-1].name,[string]$snapshot.name,$source,$status)

                if($prevPresent -and $present){
                    foreach($domain in @($SourceDomains[$source])){
                        $prevSet=$prevModel.sets[$domain.property]
                        $currSet=$model.sets[$domain.property]
                        foreach($row in @($prevSet.rows)){
                            if(-not $currSet.seen.Contains([string]$row.key)){
                                Write-TsvLine $removedWriters[$domain.name] @([string]$Snapshots[$i-1].name,[string]$snapshot.name,[string]$row.value)
                                $removedCount++
                            }
                        }
                        foreach($row in @($currSet.rows)){
                            if(-not $prevSet.seen.Contains([string]$row.key)){
                                Write-TsvLine $addedWriters[$domain.name] @([string]$Snapshots[$i-1].name,[string]$snapshot.name,[string]$row.value)
                                $addedCount++
                            }
                        }
                    }
                }
            }
        }

        $previous=$current
        $snapSw.Stop()
        foreach($writer in $addedWriters.Values){$writer.Flush()}
        foreach($writer in $removedWriters.Values){$writer.Flush()}
        $historyCoverage.Flush()
        $allCoverage.Flush()
        Write-Line ('Fast archive snapshot '+($i+1)+'/'+$Snapshots.Count+': '+$snapshot.name+' ('+[math]::Round($snapSw.Elapsed.TotalSeconds,1)+' s)')
    }

    foreach($writer in $addedWriters.Values){$writer.Dispose()}
    foreach($writer in $removedWriters.Values){$writer.Dispose()}
    $historyCoverage.Dispose()
    $allCoverage.Dispose()

    $unionRows=0L
    foreach($domain in $Domains){
        $writer=New-Utf8Writer (Join-Path $allRoot ($domain.name+'.tsv')) "first_seen_dump`tlast_seen_dump`tobserved_snapshots`tvalue"
        try{
            $state=$unions[$domain.name]
            foreach($key in @($state.order)){
                $record=[object[]]$state.map[[string]$key]
                Write-TsvLine $writer @([string]$record[0],[string]$record[1],[string]$record[2],[string]$record[3])
                $unionRows++
            }
        } finally {$writer.Dispose()}
    }

    $sw.Stop()
    $summary=@(
        'MVS Explorer Toolkit fast archive builder',
        '',
        'Snapshots: '+$Snapshots.Count,
        'Domains: '+$Domains.Count,
        'Added records: '+$addedCount,
        'Removed records: '+$removedCount,
        'All-ever unique source-local records: '+$unionRows,
        'Elapsed milliseconds: '+$sw.ElapsedMilliseconds
    ) -join [Environment]::NewLine
    [IO.File]::WriteAllText((Join-Path $OutputRoot 'fast-archive-summary.txt'),$summary+[Environment]::NewLine,$utf8)
    Write-Line ('Fast archive complete: snapshots='+$Snapshots.Count+' added='+$addedCount+' removed='+$removedCount+' all-ever='+$unionRows)
    exit 0
} catch {
    foreach($writer in $addedWriters.Values){try{$writer.Dispose()}catch{}}
    foreach($writer in $removedWriters.Values){try{$writer.Dispose()}catch{}}
    try{$historyCoverage.Dispose()}catch{}
    try{$allCoverage.Dispose()}catch{}
    Fail 5 $_.Exception.Message
}
