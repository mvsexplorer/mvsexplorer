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
    return [pscustomobject]@{
        sets=$sets
        state_set=(New-ValueSet)
        state_ids=@{}
        title_ids=@{}
        section_count=0L
        zero_file_sections=0L
        duplicate_state_occurrences=0L
        exact_duplicate_occurrences=0L
        numeric_id_occurrences=0L
        exact_section_seen=(New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal))
    }
}

function Add-ModelValue {
    param([object]$Model,[string]$Kind,[AllowNull()][AllowEmptyString()][string]$Value,[string]$IdMode)
    $display=Get-DisplayValue $Value $Kind $IdMode
    if([string]::IsNullOrWhiteSpace($display)){return}
    $key=Get-Key $display $Kind
    $set=$Model.sets[$Kind]
    if($set.seen.Add($key)){[void]$set.rows.Add([pscustomobject]@{key=$key;value=$display})}
}


function Add-SectionState {
    param([object]$Model,[string]$Title,[string]$Id,[System.Collections.ArrayList]$Files)
    if($null -eq $Model -or [string]::IsNullOrWhiteSpace($Title)){return}
    $displayTitle=Normalize-Title $Title
    if($Files.Count -eq 0){
        $stateFiles=''
    } elseif($Files.Count -eq 1) {
        $stateFiles=[string]$Files[0]
    } else {
        [string[]]$parts=$Files.ToArray([string])
        [Array]::Sort($parts,[StringComparer]::OrdinalIgnoreCase)
        $stateFiles=$parts -join [char]0x1e
    }
    $stateKey=$displayTitle.ToLowerInvariant()+[char]0x1f+$stateFiles
    $Model.section_count=[int64]$Model.section_count+1
    if($Files.Count -eq 0){$Model.zero_file_sections=[int64]$Model.zero_file_sections+1}
    if($Id -match '^\d+$'){$Model.numeric_id_occurrences=[int64]$Model.numeric_id_occurrences+1}
    if($Model.state_set.seen.Add($stateKey)){
        [void]$Model.state_set.rows.Add([pscustomobject]@{key=$stateKey;value=$displayTitle})
    } else {
        $Model.duplicate_state_occurrences=[int64]$Model.duplicate_state_occurrences+1
    }
    if(-not $Model.state_ids.ContainsKey($stateKey)){
        $Model.state_ids[$stateKey]=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    }
    [void]$Model.state_ids[$stateKey].Add([string]$Id)
    $titleKey=$displayTitle.ToLowerInvariant()
    if(-not $Model.title_ids.ContainsKey($titleKey)){
        $Model.title_ids[$titleKey]=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    }
    [void]$Model.title_ids[$titleKey].Add([string]$Id)
    $exactKey=$stateKey+[char]0x1f+([string]$Id).ToLowerInvariant()
    if(-not $Model.exact_section_seen.Add($exactKey)){$Model.exact_duplicate_occurrences=[int64]$Model.exact_duplicate_occurrences+1}
}

$sha256Hasher=[Security.Cryptography.SHA256]::Create()

function Get-Sha256String {
    param([AllowNull()][AllowEmptyString()][string]$Text)
    if($null -eq $Text){$Text=''}
    $bytes=[Text.Encoding]::UTF8.GetBytes($Text)
    $hash=$sha256Hasher.ComputeHash($bytes)
    return ([BitConverter]::ToString($hash)).Replace('-','').ToLowerInvariant()
}

function Convert-NoteHtmlToText {
    param([AllowNull()][AllowEmptyString()][string]$Html)
    if([string]::IsNullOrEmpty($Html)){return ''}
    $text=[regex]::Replace($Html,'(?is)<br\s*/?>',' ')
    $text=[regex]::Replace($text,'(?is)</p\s*>',' ')
    $text=[regex]::Replace($text,'(?is)</li\s*>',' ')
    $text=[regex]::Replace($text,'(?is)</div\s*>',' ')
    $text=[regex]::Replace($text,'(?is)<[^>]+>',' ')
    $text=[System.Net.WebUtility]::HtmlDecode($text)
    $text=$text.Replace([char]0x00A0,' ')
    return ([regex]::Replace($text,'\s+',' ')).Trim()
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
        $reader=New-Object System.IO.StreamReader -ArgumentList @($Path,[System.Text.Encoding]::UTF8,$true,65536)
        try{
            while($true){
                $line=$reader.ReadLine();if($null-eq$line){break}
                $m=$RxIds.Match([string]$line)
                if($m.Success){
                    Add-ModelValue $model 'id' $m.Groups['id'].Value 'numeric'
                    Add-ModelValue $model 'title' $m.Groups['title'].Value ''
                }
            }
        } finally {$reader.Dispose()}
        return $model
    }

    if($Name -eq 'mvs_dates.txt'){
        $reader=New-Object System.IO.StreamReader -ArgumentList @($Path,[System.Text.Encoding]::UTF8,$true,65536)
        try{
            while($true){
                $line=$reader.ReadLine();if($null-eq$line){break}
                $m=$RxDates.Match([string]$line)
                if($m.Success){
                    Add-ModelValue $model 'id' $m.Groups['id'].Value 'numeric'
                    Add-ModelValue $model 'title' $m.Groups['title'].Value ''
                    Add-ModelValue $model 'date' $m.Groups['date'].Value ''
                }
            }
        } finally {$reader.Dispose()}
        return $model
    }

    if($Name -eq 'mvs.sha1' -or $Name -eq 'mvs.sha256'){
        $rx=if($Name -eq 'mvs.sha1'){$RxSha1}else{$RxSha256}
        $kind=if($Name -eq 'mvs.sha1'){'sha1'}else{'sha256'}
        $reader=New-Object System.IO.StreamReader -ArgumentList @($Path,[System.Text.Encoding]::UTF8,$true,65536)
        try{
            while($true){
                $line=$reader.ReadLine();if($null-eq$line){break}
                $m=$rx.Match([string]$line)
                if($m.Success){
                    Add-ModelValue $model $kind $m.Groups['hash'].Value ''
                    Add-ModelValue $model 'filename' $m.Groups['filename'].Value ''
                }
            }
        } finally {$reader.Dispose()}
        return $model
    }

    if($Name -eq 'mvs.txt' -or $Name -eq 'mvs_names.txt'){
        $inside=$false
        $headerRx=if($Name -eq 'mvs_names.txt'){$RxNamesHeader}else{$RxProductHeader}
        $idMode=if($Name -eq 'mvs_names.txt'){'text'}else{'numeric'}
        $currentTitle=''
        $currentId=''
        $currentFiles=New-Object System.Collections.ArrayList
        $reader=New-Object System.IO.StreamReader -ArgumentList @($Path,[System.Text.Encoding]::UTF8,$true,65536)
        try{
            while($true){
                $line=$reader.ReadLine()
                if($null -eq $line){break}
                $hm=$headerRx.Match([string]$line)
                if($hm.Success){
                    if($inside){Add-SectionState $model $currentTitle $currentId $currentFiles}
                    $inside=$true
                    $currentTitle=$hm.Groups['title'].Value
                    $currentId=Normalize-Id $hm.Groups['id'].Value $idMode
                    $currentFiles=New-Object System.Collections.ArrayList
                    Add-ModelValue $model 'id' $hm.Groups['id'].Value $idMode
                    Add-ModelValue $model 'title' $hm.Groups['title'].Value ''
                    continue
                }
                if([string]::IsNullOrWhiteSpace([string]$line)){
                    if($inside){Add-SectionState $model $currentTitle $currentId $currentFiles}
                    $inside=$false
                    $currentTitle=''
                    $currentId=''
                    $currentFiles=New-Object System.Collections.ArrayList
                    continue
                }
                if(-not $inside){continue}
                $fm=$RxFile.Match([string]$line)
                if($fm.Success){
                    $hash=$fm.Groups['hash'].Value.ToLowerInvariant()
                    $filename=$fm.Groups['filename'].Value.Trim()
                    [void]$currentFiles.Add($hash+'|'+$filename.ToLowerInvariant())
                    Add-ModelValue $model 'filename' $filename ''
                    if($hash.Length -eq 40){Add-ModelValue $model 'sha1' $hash ''}
                    elseif($hash.Length -eq 64){Add-ModelValue $model 'sha256' $hash ''}
                }
            }
            if($inside){Add-SectionState $model $currentTitle $currentId $currentFiles}
        } finally {$reader.Dispose()}
        return $model
    }

    throw ('Unsupported source file: '+$Name)
}


function Read-NoteSnapshot {
    param([string]$Path,[string]$SnapshotName,[string]$RawRoot,[System.IO.StreamWriter]$ObservationWriter,[object]$ProductModel,[object]$VariantModel)
    $records=New-Object System.Collections.ArrayList
    if([string]::IsNullOrWhiteSpace($Path) -or -not(Test-Path -LiteralPath $Path -PathType Leaf)){return @($records)}
    $html=[IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8)
    $rx=New-Object System.Text.RegularExpressions.Regex -ArgumentList @('(?is)<h[13][^>]*>(?<heading>.*?)</h[13]>(?<body>.*?)(?=<h[13]\b|\z)',[System.Text.RegularExpressions.RegexOptions]::Compiled)
    $occurrence=0
    foreach($m in $rx.Matches($html)){
        $occurrence++
        $heading=Normalize-Title ([regex]::Replace([string]$m.Groups['heading'].Value,'(?is)<[^>]+>',' '))
        $sourceId=''
        $title=$heading
        if($heading -match '^(?<title>.*?)\s*\[ID:\s*(?<id>[^\]]+?)\s*\]\s*$'){
            $title=Normalize-Title $Matches.title
            $sourceId=$Matches.id.Trim()
        }
        $rawBody=[string]$m.Groups['body'].Value
        $noteText=Convert-NoteHtmlToText $rawBody
        $bodySha=Get-Sha256String $noteText
        $rawSha=Get-Sha256String $rawBody
        $rawPath=Join-Path $RawRoot ($rawSha+'.html')
        if(-not(Test-Path -LiteralPath $rawPath -PathType Leaf)){[IO.File]::WriteAllText($rawPath,$rawBody,$utf8)}
        $row=[pscustomobject]@{
            occurrence=$occurrence;title=$title;source_id=$sourceId;body_sha256=$bodySha;raw_html_sha256=$rawSha;note_text=$noteText
        }
        [void]$records.Add($row)
        if($null -ne $ObservationWriter){
            $productIds=''
            $variantSourceIds=''
            $titleKey=$title.ToLowerInvariant()
            if($null -ne $ProductModel -and $ProductModel.title_ids.ContainsKey($titleKey)){
                $productIds=(@($ProductModel.title_ids[$titleKey]) | Sort-Object) -join ','
            }
            if($null -ne $VariantModel -and $VariantModel.title_ids.ContainsKey($titleKey)){
                $variantSourceIds=(@($VariantModel.title_ids[$titleKey]) | Sort-Object) -join ','
            }
            Write-TsvLine $ObservationWriter @($SnapshotName,[string]$occurrence,$title,$sourceId,$productIds,$variantSourceIds,$bodySha,$rawSha,$noteText)
        }
    }
    return @($records)
}

function Get-StateIdTransition {
    param([object]$PreviousModel,[object]$CurrentModel)
    if($null -eq $PreviousModel -or $null -eq $CurrentModel){
        return [pscustomobject]@{retained=0L;same_id=0L;changed_id=0L}
    }
    $retained=0L
    $same=0L
    $changed=0L
    foreach($row in @($CurrentModel.state_set.rows)){
        $key=[string]$row.key
        if(-not $PreviousModel.state_set.seen.Contains($key)){continue}
        $retained++
        $hasSame=$false
        $prevIds=$PreviousModel.state_ids[$key]
        $currIds=$CurrentModel.state_ids[$key]
        if($null -ne $prevIds -and $null -ne $currIds){
            foreach($id in $currIds){
                if($prevIds.Contains([string]$id)){$hasSame=$true;break}
            }
        }
        if($hasSame){$same++}else{$changed++}
    }
    return [pscustomobject]@{retained=$retained;same_id=$same;changed_id=$changed}
}

function New-UnionState {
    return [pscustomobject]@{
        map=(New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal))
        order=(New-Object System.Collections.ArrayList)
    }
}

function Update-Union {
    param([object]$State,[object]$Set,[string]$SnapshotName)
    $newCount=0L
    foreach($row in @($Set.rows)){
        $key=[string]$row.key
        if(-not $State.map.ContainsKey($key)){
            $record=[object[]]@($SnapshotName,$SnapshotName,1,[string]$row.value)
            $State.map.Add($key,$record)
            [void]$State.order.Add($key)
            $newCount++
        } else {
            $record=[object[]]$State.map[$key]
            $record[1]=$SnapshotName
            $record[2]=[int]$record[2]+1
        }
    }
    return $newCount
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
    $values=New-Object 'string[]' $Fields.Count
    for($wi=0;$wi-lt$Fields.Count;$wi++){
        $value=[string]$Fields[$wi]
        $values[$wi]=$value.Replace("`t",' ').Replace("`r",' ').Replace("`n",' ')
    }
    $Writer.WriteLine([string]::Join("`t",$values))
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
$evolutionRoot=Join-Path $OutputRoot 'evolution'
$noteRoot=Join-Path $evolutionRoot 'notes'
$rawNoteRoot=Join-Path $noteRoot 'raw-html'
Reset-Directory $addedRoot
Reset-Directory $removedRoot
Reset-Directory $allRoot
Reset-Directory $evolutionRoot
[void](New-Item -ItemType Directory -Path $noteRoot -Force)
[void](New-Item -ItemType Directory -Path $rawNoteRoot -Force)

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

$domainAddWriter=New-Utf8Writer (Join-Path $evolutionRoot 'per-dump-domain-additions.tsv') "index`tdump`tdomain`tnew_values`tcumulative_values"
$contributionWriter=New-Utf8Writer (Join-Path $evolutionRoot 'per-dump-contributions.tsv') "index`tdump`tnew_product_ids`tnew_product_titles`tnew_variant_source_ids`tnew_variant_titles`tnew_product_filenames`tnew_variant_filenames`tnew_product_sha1`tnew_product_sha256`tnew_variant_sha1`tnew_variant_sha256`tnew_product_states`tnew_variant_states`tnew_note_versions`tnew_note_bodies`tcumulative_product_states`tcumulative_variant_states`tcumulative_note_versions`tcumulative_note_bodies"
$qualityWriter=New-Utf8Writer (Join-Path $evolutionRoot 'per-dump-quality.tsv') "index`tdump`tproduct_sections`tproduct_zero_file_sections`tproduct_zero_file_pct`tproduct_duplicate_states`tproduct_exact_duplicate_sections`tvariant_sections`tvariant_zero_file_sections`tvariant_duplicate_states`tvariant_duplicate_pct`tvariant_exact_duplicate_sections`tvariant_unique_source_ids`tvariant_numeric_id_occurrences`tvariant_numeric_id_pct`tnote_records`tquality_flags"
$transitionWriter=New-Utf8Writer (Join-Path $evolutionRoot 'variant-id-transitions.tsv') "from_dump`tto_dump`tretained_variant_states`tsame_source_id`tchanged_source_id`tchanged_id_pct`tfrom_unique_ids`tto_unique_ids`tfrom_numeric_id_pct`tto_numeric_id_pct"
$noteObservationWriter=New-Utf8Writer (Join-Path $noteRoot 'note-observations.tsv') "dump`toccurrence`ttitle`tsource_id`tproduct_ids`tvariant_source_ids`tbody_sha256`traw_html_sha256`tnote_text"
$suggestWriter=New-Utf8Writer (Join-Path $evolutionRoot 'suggested-exclusions.tsv') "snapshot`tscope`trecommendation`treason`tmetric`tvalue"

$productStateUnion=New-UnionState
$variantStateUnion=New-UnionState
$noteVersionMap=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
$noteVersionOrder=New-Object System.Collections.ArrayList
$noteBodyMap=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
$noteBodyOrder=New-Object System.Collections.ArrayList
$noteRawMap=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
$noteRawOrder=New-Object System.Collections.ArrayList
$cumulativeDomain=@{}
foreach($domain in $Domains){$cumulativeDomain[$domain.name]=0L}

$previous=@{}
$addedCount=0L
$removedCount=0L
$sw=[Diagnostics.Stopwatch]::StartNew()

try{
    for($i=0;$i-lt$Snapshots.Count;$i++){
        $snapshot=$Snapshots[$i]
        $current=@{}
        $snapSw=[Diagnostics.Stopwatch]::StartNew()
        $newByDomain=@{}
        foreach($domain in $Domains){$newByDomain[$domain.name]=0L}

        foreach($source in $SourceFiles){
            $path=Get-SnapshotSourcePath $snapshot $source
            $present=$null -ne $path
            Write-TsvLine $allCoverage @([string]$snapshot.name,$source,$(if($present){'1'}else{'0'}))

            $model=$null
            if($present){$model=Read-SourceModel $path $source}
            $current[$source]=$model

            if($null -ne $model){
                foreach($domain in @($SourceDomains[$source])){
                    $newCount=[int64](Update-Union $unions[$domain.name] $model.sets[$domain.property] ([string]$snapshot.name))
                    $newByDomain[$domain.name]=$newCount
                    $cumulativeDomain[$domain.name]=[int64]$cumulativeDomain[$domain.name]+$newCount
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

        foreach($domain in $Domains){
            Write-TsvLine $domainAddWriter @(
                [string]($i+1),[string]$snapshot.name,[string]$domain.name,
                [string]$newByDomain[$domain.name],[string]$cumulativeDomain[$domain.name]
            )
        }

        $productModel=$current['mvs.txt']
        $variantModel=$current['mvs_names.txt']
        $newProductStates=0L
        $newVariantStates=0L
        if($null -ne $productModel){$newProductStates=[int64](Update-Union $productStateUnion $productModel.state_set ([string]$snapshot.name))}
        if($null -ne $variantModel){$newVariantStates=[int64](Update-Union $variantStateUnion $variantModel.state_set ([string]$snapshot.name))}

        $notePath=Get-SnapshotSourcePath $snapshot 'mvs_notes.html'
        $noteRecords=@()
        if($null -ne $notePath){$noteRecords=@(Read-NoteSnapshot $notePath ([string]$snapshot.name) $rawNoteRoot $noteObservationWriter $productModel $variantModel)}
        $newNoteVersions=0L
        $newNoteBodies=0L
        $noteVersionsSeenThisSnapshot=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        $noteBodiesSeenThisSnapshot=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        $noteRawSeenThisSnapshot=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach($note in $noteRecords){
            $versionKey=([string]$note.title).ToLowerInvariant()+[char]0x1f+[string]$note.body_sha256
            $firstVersionObservationThisSnapshot=$noteVersionsSeenThisSnapshot.Add($versionKey)
            if(-not $noteVersionMap.ContainsKey($versionKey)){
                $record=[pscustomobject]@{
                    first_seen=[string]$snapshot.name;last_seen=[string]$snapshot.name;observed=1L
                    title=[string]$note.title;body_sha256=[string]$note.body_sha256
                    raw_html_sha256=[string]$note.raw_html_sha256;note_text=[string]$note.note_text
                }
                $noteVersionMap.Add($versionKey,$record)
                [void]$noteVersionOrder.Add($versionKey)
                $newNoteVersions++
            } elseif($firstVersionObservationThisSnapshot) {
                $record=$noteVersionMap[$versionKey]
                $record.last_seen=[string]$snapshot.name
                $record.observed=[int64]$record.observed+1
            }
            $bodyKey=[string]$note.body_sha256
            $firstBodyObservationThisSnapshot=$noteBodiesSeenThisSnapshot.Add($bodyKey)
            if(-not $noteBodyMap.ContainsKey($bodyKey)){
                $bodyRecord=[pscustomobject]@{
                    first_seen=[string]$snapshot.name;last_seen=[string]$snapshot.name;observed=1L
                    body_sha256=$bodyKey;note_text=[string]$note.note_text
                }
                $noteBodyMap.Add($bodyKey,$bodyRecord)
                [void]$noteBodyOrder.Add($bodyKey)
                $newNoteBodies++
            } elseif($firstBodyObservationThisSnapshot) {
                $bodyRecord=$noteBodyMap[$bodyKey]
                $bodyRecord.last_seen=[string]$snapshot.name
                $bodyRecord.observed=[int64]$bodyRecord.observed+1
            }

            # Preserve distinct raw-markup forms even when their normalized note text is identical.
            $rawKey=$versionKey+[char]0x1f+[string]$note.raw_html_sha256
            $firstRawObservationThisSnapshot=$noteRawSeenThisSnapshot.Add($rawKey)
            if(-not $noteRawMap.ContainsKey($rawKey)){
                $rawRecord=[pscustomobject]@{
                    first_seen=[string]$snapshot.name;last_seen=[string]$snapshot.name;observed=1L
                    title=[string]$note.title;body_sha256=[string]$note.body_sha256;raw_html_sha256=[string]$note.raw_html_sha256
                }
                $noteRawMap.Add($rawKey,$rawRecord)
                [void]$noteRawOrder.Add($rawKey)
            } elseif($firstRawObservationThisSnapshot) {
                $rawRecord=$noteRawMap[$rawKey]
                $rawRecord.last_seen=[string]$snapshot.name
                $rawRecord.observed=[int64]$rawRecord.observed+1
            }
        }

        $productSections=if($null-ne$productModel){[int64]$productModel.section_count}else{0L}
        $productZero=if($null-ne$productModel){[int64]$productModel.zero_file_sections}else{0L}
        $productDup=if($null-ne$productModel){[int64]$productModel.duplicate_state_occurrences}else{0L}
        $productExactDup=if($null-ne$productModel){[int64]$productModel.exact_duplicate_occurrences}else{0L}
        $productZeroPct=if($productSections-gt0){[math]::Round(100.0*$productZero/$productSections,2)}else{0.0}

        $variantSections=if($null-ne$variantModel){[int64]$variantModel.section_count}else{0L}
        $variantZero=if($null-ne$variantModel){[int64]$variantModel.zero_file_sections}else{0L}
        $variantDup=if($null-ne$variantModel){[int64]$variantModel.duplicate_state_occurrences}else{0L}
        $variantExactDup=if($null-ne$variantModel){[int64]$variantModel.exact_duplicate_occurrences}else{0L}
        $variantUniqueIds=if($null-ne$variantModel){[int64]$variantModel.sets.id.rows.Count}else{0L}
        $variantNumeric=if($null-ne$variantModel){[int64]$variantModel.numeric_id_occurrences}else{0L}
        $variantDupPct=if($variantSections-gt0){[math]::Round(100.0*$variantDup/$variantSections,2)}else{0.0}
        $variantNumericPct=if($variantSections-gt0){[math]::Round(100.0*$variantNumeric/$variantSections,2)}else{0.0}

        $flags=New-Object System.Collections.ArrayList
        if($productZeroPct-ge20.0){
            [void]$flags.Add('PRODUCT_ZERO_FILE_SPIKE')
            Write-TsvLine $suggestWriter @([string]$snapshot.name,'products','review-canonical','High share of product sections have no file records.','product_zero_file_pct',[string]$productZeroPct)
        }
        if($variantDupPct-ge10.0){
            [void]$flags.Add('VARIANT_DUPLICATE_SPIKE')
            Write-TsvLine $suggestWriter @([string]$snapshot.name,'variants','review-canonical','High share of repeated variant states.','variant_duplicate_pct',[string]$variantDupPct)
        }

        if($i-gt0){
            $prevVariant=$previous['mvs_names.txt']
            if($null-ne$prevVariant -and $null-ne$variantModel){
                $transition=Get-StateIdTransition $prevVariant $variantModel
                $changedPct=if($transition.retained-gt0){[math]::Round(100.0*$transition.changed_id/$transition.retained,2)}else{0.0}
                $prevSections=[int64]$prevVariant.section_count
                $prevNumericPct=if($prevSections-gt0){[math]::Round(100.0*[int64]$prevVariant.numeric_id_occurrences/$prevSections,2)}else{0.0}
                Write-TsvLine $transitionWriter @(
                    [string]$Snapshots[$i-1].name,[string]$snapshot.name,[string]$transition.retained,
                    [string]$transition.same_id,[string]$transition.changed_id,[string]$changedPct,
                    [string]$prevVariant.sets.id.rows.Count,[string]$variantUniqueIds,[string]$prevNumericPct,[string]$variantNumericPct
                )
                if([math]::Abs($variantNumericPct-$prevNumericPct)-ge50.0){[void]$flags.Add('VARIANT_ID_REGIME_SHIFT')}
                if($prevSections-gt0 -and $variantSections-lt(0.70*$prevSections)){
                    [void]$flags.Add('VARIANT_SECTION_COLLAPSE')
                    $dropPct=[math]::Round(100.0*(1.0-$variantSections/$prevSections),2)
                    Write-TsvLine $suggestWriter @([string]$snapshot.name,'variants','review-canonical','Variant section count contracted by more than 30% from the previous dump.','variant_section_drop_pct',[string]$dropPct)
                }
                if($changedPct-ge80.0 -and $transition.retained-ge100){
                    [void]$flags.Add('VARIANT_REID_EVENT')
                }
            }
        }

        Write-TsvLine $qualityWriter @(
            [string]($i+1),[string]$snapshot.name,[string]$productSections,[string]$productZero,[string]$productZeroPct,
            [string]$productDup,[string]$productExactDup,[string]$variantSections,[string]$variantZero,
            [string]$variantDup,[string]$variantDupPct,[string]$variantExactDup,[string]$variantUniqueIds,
            [string]$variantNumeric,[string]$variantNumericPct,[string]$noteRecords.Count,(@($flags)-join '|')
        )

        Write-TsvLine $contributionWriter @(
            [string]($i+1),[string]$snapshot.name,
            [string]$newByDomain['id_from_mvs.txt'],[string]$newByDomain['title_from_mvs.txt'],
            [string]$newByDomain['id_from_mvs_names.txt'],[string]$newByDomain['title_from_mvs_names.txt'],
            [string]$newByDomain['filenames_from_mvs.txt'],[string]$newByDomain['filenames_from_mvs_names.txt'],
            [string]$newByDomain['sha1_from_mvs.txt'],[string]$newByDomain['sha256_from_mvs.txt'],
            [string]$newByDomain['sha1_from_mvs_names.txt'],[string]$newByDomain['sha256_from_mvs_names.txt'],
            [string]$newProductStates,[string]$newVariantStates,[string]$newNoteVersions,[string]$newNoteBodies,
            [string]$productStateUnion.map.Count,[string]$variantStateUnion.map.Count,[string]$noteVersionMap.Count,[string]$noteBodyMap.Count
        )

        $previous=$current
        $snapSw.Stop()
        foreach($writer in $addedWriters.Values){$writer.Flush()}
        foreach($writer in $removedWriters.Values){$writer.Flush()}
        $historyCoverage.Flush()
        $allCoverage.Flush()
        $domainAddWriter.Flush()
        $contributionWriter.Flush()
        $qualityWriter.Flush()
        $transitionWriter.Flush()
        $noteObservationWriter.Flush()
        $suggestWriter.Flush()
        Write-Line ('Fast archive snapshot '+($i+1)+'/'+$Snapshots.Count+': '+$snapshot.name+' ('+[math]::Round($snapSw.Elapsed.TotalSeconds,1)+' s)')
    }

    foreach($writer in $addedWriters.Values){$writer.Dispose()}
    foreach($writer in $removedWriters.Values){$writer.Dispose()}
    $historyCoverage.Dispose()
    $allCoverage.Dispose()
    $domainAddWriter.Dispose()
    $contributionWriter.Dispose()
    $qualityWriter.Dispose()
    $transitionWriter.Dispose()
    $noteObservationWriter.Dispose()
    $suggestWriter.Dispose()

    $productStateWriter=New-Utf8Writer (Join-Path $evolutionRoot 'product-states-all-ever.tsv') "first_seen_dump`tlast_seen_dump`tobserved_snapshots`tstate_sha256`ttitle"
    try{
        foreach($key in @($productStateUnion.order)){
            $record=[object[]]$productStateUnion.map[[string]$key]
            Write-TsvLine $productStateWriter @([string]$record[0],[string]$record[1],[string]$record[2],(Get-Sha256String ([string]$key)),[string]$record[3])
        }
    } finally {$productStateWriter.Dispose()}

    $variantStateWriter=New-Utf8Writer (Join-Path $evolutionRoot 'variant-states-all-ever.tsv') "first_seen_dump`tlast_seen_dump`tobserved_snapshots`tstate_sha256`tvariant_title"
    try{
        foreach($key in @($variantStateUnion.order)){
            $record=[object[]]$variantStateUnion.map[[string]$key]
            Write-TsvLine $variantStateWriter @([string]$record[0],[string]$record[1],[string]$record[2],(Get-Sha256String ([string]$key)),[string]$record[3])
        }
    } finally {$variantStateWriter.Dispose()}

    $noteVersionWriter=New-Utf8Writer (Join-Path $noteRoot 'note-versions.tsv') "first_seen_dump`tlast_seen_dump`tobserved_snapshots`ttitle`tbody_sha256`traw_html_sha256`tnote_text"
    try{
        foreach($key in @($noteVersionOrder)){
            $record=$noteVersionMap[[string]$key]
            Write-TsvLine $noteVersionWriter @($record.first_seen,$record.last_seen,[string]$record.observed,$record.title,$record.body_sha256,$record.raw_html_sha256,$record.note_text)
        }
    } finally {$noteVersionWriter.Dispose()}

    $noteBodyWriter=New-Utf8Writer (Join-Path $noteRoot 'note-bodies.tsv') "first_seen_dump`tlast_seen_dump`tobserved_snapshots`tbody_sha256`tnote_text"
    try{
        foreach($key in @($noteBodyOrder)){
            $record=$noteBodyMap[[string]$key]
            Write-TsvLine $noteBodyWriter @($record.first_seen,$record.last_seen,[string]$record.observed,$record.body_sha256,$record.note_text)
        }
    } finally {$noteBodyWriter.Dispose()}

    $noteRawWriter=New-Utf8Writer (Join-Path $noteRoot 'note-raw-variants.tsv') "first_seen_dump`tlast_seen_dump`tobserved_snapshots`ttitle`tbody_sha256`traw_html_sha256"
    try{
        foreach($key in @($noteRawOrder)){
            $record=$noteRawMap[[string]$key]
            Write-TsvLine $noteRawWriter @($record.first_seen,$record.last_seen,[string]$record.observed,$record.title,$record.body_sha256,$record.raw_html_sha256)
        }
    } finally {$noteRawWriter.Dispose()}

    # Retention answers whether evidence introduced by a dump was ever observed again later.
    $retention=@{}
    function Add-Retention {
        param([hashtable]$Map,[string]$Kind,[string]$First,[string]$Last)
        if([string]::IsNullOrWhiteSpace($First)){return}
        $key=$First+[char]0x1f+$Kind
        if(-not$Map.ContainsKey($key)){$Map[$key]=[int64[]]@(0L,0L)}
        $stats=[int64[]]$Map[$key]
        $stats[0]++
        if([string]::Equals($First,$Last,[StringComparison]::Ordinal)){$stats[1]++}
    }
    foreach($domain in $Domains){
        $state=$unions[$domain.name]
        foreach($key in @($state.order)){
            $record=[object[]]$state.map[[string]$key]
            Add-Retention $retention ([string]$domain.name) ([string]$record[0]) ([string]$record[1])
        }
    }
    foreach($key in @($productStateUnion.order)){
        $record=[object[]]$productStateUnion.map[[string]$key]
        Add-Retention $retention 'product_state' ([string]$record[0]) ([string]$record[1])
    }
    foreach($key in @($variantStateUnion.order)){
        $record=[object[]]$variantStateUnion.map[[string]$key]
        Add-Retention $retention 'variant_state' ([string]$record[0]) ([string]$record[1])
    }
    foreach($key in @($noteVersionOrder)){
        $record=$noteVersionMap[[string]$key]
        Add-Retention $retention 'note_version' ([string]$record.first_seen) ([string]$record.last_seen)
    }
    foreach($key in @($noteBodyOrder)){
        $record=$noteBodyMap[[string]$key]
        Add-Retention $retention 'note_body' ([string]$record.first_seen) ([string]$record.last_seen)
    }

    $retentionKinds=New-Object System.Collections.ArrayList
    [void]$retentionKinds.Add('product_state')
    [void]$retentionKinds.Add('variant_state')
    [void]$retentionKinds.Add('note_version')
    [void]$retentionKinds.Add('note_body')
    foreach($domain in $Domains){[void]$retentionKinds.Add([string]$domain.name)}
    $retentionWriter=New-Utf8Writer (Join-Path $evolutionRoot 'per-dump-retention.tsv') "index`tdump`tevidence_kind`tintroduced_here`tseen_later`tnever_seen_later"
    try{
        for($ri=0;$ri-lt$Snapshots.Count;$ri++){
            $dump=[string]$Snapshots[$ri].name
            foreach($kind in $retentionKinds){
                $key=$dump+[char]0x1f+[string]$kind
                $introduced=0L;$never=0L
                if($retention.ContainsKey($key)){
                    $stats=[int64[]]$retention[$key]
                    $introduced=[int64]$stats[0];$never=[int64]$stats[1]
                }
                Write-TsvLine $retentionWriter @([string]($ri+1),$dump,[string]$kind,[string]$introduced,[string]($introduced-$never),[string]$never)
            }
        }
    } finally {$retentionWriter.Dispose()}

    $evolutionSummary=New-Utf8Writer (Join-Path $evolutionRoot 'summary.tsv') "metric`tvalue"
    try{
        Write-TsvLine $evolutionSummary @('snapshots',[string]$Snapshots.Count)
        Write-TsvLine $evolutionSummary @('product_states_all_ever',[string]$productStateUnion.map.Count)
        Write-TsvLine $evolutionSummary @('variant_states_all_ever',[string]$variantStateUnion.map.Count)
        Write-TsvLine $evolutionSummary @('note_versions_all_ever',[string]$noteVersionMap.Count)
        Write-TsvLine $evolutionSummary @('note_bodies_all_ever',[string]$noteBodyMap.Count)
        Write-TsvLine $evolutionSummary @('note_raw_variants_all_ever',[string]$noteRawMap.Count)
    } finally {$evolutionSummary.Dispose()}

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
        'Product states all-ever: '+$productStateUnion.map.Count,
        'Variant states all-ever: '+$variantStateUnion.map.Count,
        'Note versions all-ever: '+$noteVersionMap.Count,
        'Note bodies all-ever: '+$noteBodyMap.Count,
        'Note raw variants all-ever: '+$noteRawMap.Count,
        'Elapsed milliseconds: '+$sw.ElapsedMilliseconds
    ) -join [Environment]::NewLine
    [IO.File]::WriteAllText((Join-Path $OutputRoot 'fast-archive-summary.txt'),$summary+[Environment]::NewLine,$utf8)
    $sha256Hasher.Dispose()
    Write-Line ('Fast archive complete: snapshots='+$Snapshots.Count+' added='+$addedCount+' removed='+$removedCount+' all-ever='+$unionRows)
    exit 0
} catch {
    foreach($writer in $addedWriters.Values){try{$writer.Dispose()}catch{}}
    foreach($writer in $removedWriters.Values){try{$writer.Dispose()}catch{}}
    try{$historyCoverage.Dispose()}catch{}
    try{$allCoverage.Dispose()}catch{}
    foreach($writer in @($domainAddWriter,$contributionWriter,$qualityWriter,$transitionWriter,$noteObservationWriter,$suggestWriter)){try{$writer.Dispose()}catch{}}
    try{$sha256Hasher.Dispose()}catch{}
    Fail 5 $_.Exception.Message
}
