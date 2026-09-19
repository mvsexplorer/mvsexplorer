@echo off
:setup
setlocal DisableDelayedExpansion
set "app.version=0.1.1"
set "app.name=run_compare_tools_fast"
set "app.rc=0"
set "app.self=%~f0"
set "mvsf_mode=compare"
set "mvsf_first_data=%~1"
set "mvsf_second_data=%~2"
set "mvsf_plan=%~3"
set "mvsf_output=%~4"
set "mvsf_caller=%~nx0"
set "mvsf_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSFastSweep"
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

:_MVSFastSweep_start
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$Mode = [string]$env:mvsf_mode
$FirstData = [string]$env:mvsf_first_data
$SecondData = [string]$env:mvsf_second_data
$PlanPath = [string]$env:mvsf_plan
$OutputPath = [string]$env:mvsf_output
$Caller = [string]$env:mvsf_caller
$Version = [string]$env:mvsf_version

function Write-Err { param([string]$Text) [Console]::Error.WriteLine($Text) }
function Fail { param([int]$Code,[string]$Message) Write-Err ('ERROR: ' + $Message); [Environment]::Exit($Code) }

function Normalize-Title {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    $decoded = [System.Net.WebUtility]::HtmlDecode($Value)
    return ([regex]::Replace($decoded, '\s+', ' ')).Trim()
}
function Normalize-Scalar {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    return ([regex]::Replace($Value, '[\t\r\n]+', ' ')).Trim()
}
function Convert-NoteHtmlToText {
    param([AllowNull()][AllowEmptyString()][string]$Html)
    if ([string]::IsNullOrEmpty($Html)) { return '' }
    $text = [regex]::Replace($Html, '(?is)<br\s*/?>', ' ')
    $text = [regex]::Replace($text, '(?is)</p\s*>', ' ')
    $text = [regex]::Replace($text, '(?is)</li\s*>', ' ')
    $text = [regex]::Replace($text, '(?is)</div\s*>', ' ')
    $text = [regex]::Replace($text, '(?is)<[^>]+>', ' ')
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    $text = $text.Replace([char]0x00A0, ' ')
    return ([regex]::Replace($text, '\s+', ' ')).Trim()
}
function Matches-Exact {
    param([AllowNull()][string]$Value,[AllowNull()][string]$Needle)
    if ($null -eq $Value -or $null -eq $Needle) { return $false }
    return [string]::Equals($Value.Trim(),$Needle.Trim(),[StringComparison]::OrdinalIgnoreCase)
}
function Test-StarPattern {
    param([AllowNull()][string]$Value,[string]$Pattern)
    if ($null -eq $Value) { return $false }
    $parts = $Pattern.Split([char]'*') | ForEach-Object { [regex]::Escape($_) }
    $rx = '^(?i:' + ($parts -join '.*') + ')$'
    return [regex]::IsMatch($Value,$rx)
}
function New-List { return ,(New-Object System.Collections.ArrayList) }

function Source-Exists {
    param([string]$Root,[string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $true }
    return Test-Path -LiteralPath (Join-Path $Root $Name) -PathType Leaf
}
function All-Sources-Exist {
    param([string]$Root,[string]$Spec)
    if ([string]::IsNullOrWhiteSpace($Spec)) { return $true }
    foreach ($name in $Spec.Split('|')) {
        if (-not [string]::IsNullOrWhiteSpace($name) -and -not (Source-Exists $Root $name)) { return $false }
    }
    return $true
}

function Add-HashRecord {
    param([System.Collections.ArrayList]$List,[string]$Source,[string]$Filename,[string]$Hash,[string]$Id,[string]$Title,[string]$VariantTitle)
    if ([string]::IsNullOrWhiteSpace($Filename) -or $Hash -notmatch '^(?i:[0-9a-f]{40}|[0-9a-f]{64})$') { return }
    [void]$List.Add([pscustomobject]@{
        source=$Source
        id=$Id
        title=$Title
        variant_title=$VariantTitle
        filename=$Filename.Trim()
        hash=$Hash.ToLowerInvariant()
        algorithm=$(if($Hash.Length -eq 40){'SHA1'}else{'SHA256'})
    })
}

function Read-FastModel {
    param([string]$Root)
    $ids = New-List
    $dates = New-List
    $productSections = New-List
    $productFiles = New-List
    $variantSections = New-List
    $variants = New-List
    $hashRecords = New-List
    $notes = New-List

    $idsPath = Join-Path $Root 'mvs_ids.txt'
    if (Test-Path -LiteralPath $idsPath -PathType Leaf) {
        foreach ($lineValue in Get-Content -LiteralPath $idsPath -Encoding UTF8) {
            $line = [string]$lineValue
            if ($line -match '^(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') {
                [void]$ids.Add([pscustomobject]@{ id=[string][int]$Matches.id; title=Normalize-Title $Matches.title })
            }
        }
    }

    $dateById = @{}
    $datesPath = Join-Path $Root 'mvs_dates.txt'
    if (Test-Path -LiteralPath $datesPath -PathType Leaf) {
        foreach ($lineValue in Get-Content -LiteralPath $datesPath -Encoding UTF8) {
            $line = [string]$lineValue
            if ($line -match '^(?<date>.*?)\s+-\s+(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') {
                $id = [string][int]$Matches.id
                $row = [pscustomobject]@{ id=$id; title=Normalize-Title $Matches.title; date=$Matches.date.Trim() }
                [void]$dates.Add($row)
                if (-not $dateById.ContainsKey($id)) { $dateById[$id]=$row.date }
            }
        }
    }

    $noteByTitle = @{}
    $notesPath = Join-Path $Root 'mvs_notes.html'
    if (Test-Path -LiteralPath $notesPath -PathType Leaf) {
        $html = Get-Content -LiteralPath $notesPath -Raw -Encoding UTF8
        $occurrence = 0
        foreach ($match in [regex]::Matches($html,'(?is)<h1>(.*?)</h1>(.*?)(?=<h1>|\z)')) {
            $occurrence++
            $title = Normalize-Title ([regex]::Replace($match.Groups[1].Value,'(?is)<[^>]+>',' '))
            $note = Convert-NoteHtmlToText $match.Groups[2].Value
            [void]$notes.Add([pscustomobject]@{ occurrence=$occurrence; title=$title; note=$note })
            if (-not [string]::IsNullOrWhiteSpace($title) -and -not [string]::IsNullOrWhiteSpace($note)) {
                $key=$title.ToLowerInvariant()
                if (-not $noteByTitle.ContainsKey($key)) { $noteByTitle[$key]=New-List }
                if (-not $noteByTitle[$key].Contains($note)) { [void]$noteByTitle[$key].Add($note) }
            }
        }
    }

    $mvsPath = Join-Path $Root 'mvs.txt'
    if (Test-Path -LiteralPath $mvsPath -PathType Leaf) {
        $current=$null
        foreach ($lineValue in Get-Content -LiteralPath $mvsPath -Encoding UTF8) {
            $line=[string]$lineValue
            if ($line -match '^---\s*(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*---\s*$') {
                $id=[string][int]$Matches.id
                $title=Normalize-Title $Matches.title
                $date=$(if($dateById.ContainsKey($id)){[string]$dateById[$id]}else{''})
                $nkey=$title.ToLowerInvariant()
                $note=$(if($noteByTitle.ContainsKey($nkey)){(($noteByTitle[$nkey] | ForEach-Object {[string]$_}) -join ' || ')}else{''})
                $current=[pscustomobject]@{id=$id;title=$title;date=$date;note=$note}
                [void]$productSections.Add($current)
                continue
            }
            if ([string]::IsNullOrWhiteSpace($line)) { $current=$null; continue }
            if ($null -ne $current -and $line -match '^\s*(?<hash>[0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})\s+\*(?<filename>.+?)\s*$') {
                $hash=$Matches.hash.ToLowerInvariant()
                $filename=$Matches.filename.Trim()
                $row=[pscustomobject]@{
                    id=$current.id;title=$current.title;date=$current.date;note=$current.note
                    filename=$filename;hash=$hash;algorithm=$(if($hash.Length -eq 40){'SHA1'}else{'SHA256'})
                }
                [void]$productFiles.Add($row)
                Add-HashRecord $hashRecords 'mvs.txt' $filename $hash $current.id $current.title ''
            }
        }
    }

    $namesPath = Join-Path $Root 'mvs_names.txt'
    if (Test-Path -LiteralPath $namesPath -PathType Leaf) {
        $current=$null
        $occurrence=0
        $hasFile=$false
        foreach ($lineValue in Get-Content -LiteralPath $namesPath -Encoding UTF8) {
            $line=[string]$lineValue
            if ($line -match '^---\s*(?<title>.*?)\s*\[ID:\s*(?<id>[^\]]+?)\s*\]\s*---\s*$') {
                if ($null -ne $current -and -not $hasFile) {
                    [void]$variants.Add([pscustomobject]@{occurrence=$current.occurrence;id=$current.id;variant_title=$current.variant_title;filename='';hash='';algorithm=''})
                }
                $occurrence++
                $current=[pscustomobject]@{occurrence=$occurrence;id=$Matches.id.Trim();variant_title=Normalize-Title $Matches.title}
                [void]$variantSections.Add($current)
                $hasFile=$false
                continue
            }
            if ([string]::IsNullOrWhiteSpace($line)) {
                if ($null -ne $current -and -not $hasFile) {
                    [void]$variants.Add([pscustomobject]@{occurrence=$current.occurrence;id=$current.id;variant_title=$current.variant_title;filename='';hash='';algorithm=''})
                }
                $current=$null;$hasFile=$false;continue
            }
            if ($null -ne $current -and $line -match '^\s*(?<hash>[0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})\s+\*(?<filename>.+?)\s*$') {
                $hash=$Matches.hash.ToLowerInvariant();$filename=$Matches.filename.Trim();$hasFile=$true
                [void]$variants.Add([pscustomobject]@{
                    occurrence=$current.occurrence;id=$current.id;variant_title=$current.variant_title
                    filename=$filename;hash=$hash;algorithm=$(if($hash.Length -eq 40){'SHA1'}else{'SHA256'})
                })
                Add-HashRecord $hashRecords 'mvs_names.txt' $filename $hash $current.id '' $current.variant_title
            }
        }
        if ($null -ne $current -and -not $hasFile) {
            [void]$variants.Add([pscustomobject]@{occurrence=$current.occurrence;id=$current.id;variant_title=$current.variant_title;filename='';hash='';algorithm=''})
        }
    }

    foreach ($name in @('mvs.sha1','mvs.sha256')) {
        $length=if($name -eq 'mvs.sha1'){40}else{64}
        $path=Join-Path $Root $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $pattern='^\s*(?<hash>[0-9A-Fa-f]{' + $length + '})\s+\*(?<filename>.+?)\s*$'
        foreach ($lineValue in Get-Content -LiteralPath $path -Encoding UTF8) {
            $line=[string]$lineValue
            if ($line -match $pattern) { Add-HashRecord $hashRecords $name $Matches.filename $Matches.hash '' '' '' }
        }
    }

    return [pscustomobject]@{
        root=$Root;ids=@($ids);dates=@($dates);product_sections=@($productSections);product_files=@($productFiles)
        variant_sections=@($variantSections);variants=@($variants);hash_records=@($hashRecords);notes=@($notes)
    }
}

function Get-Fields {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    return @($Text.Split(',') | ForEach-Object {$_.Trim()} | Where-Object {$_})
}
function Get-PropertyText {
    param([object]$Row,[string]$Field)
    if ($null -eq $Row) { return '' }
    $p=$Row.PSObject.Properties[$Field]
    if ($null -eq $p) { return '' }
    return Normalize-Scalar ([string]$p.Value)
}
function Has-Projection {
    param([object[]]$Rows,[string]$FieldsText)
    $fields=Get-Fields $FieldsText
    foreach ($row in @($Rows)) {
        foreach ($field in $fields) {
            if (-not [string]::IsNullOrEmpty((Get-PropertyText $row $field))) { return $true }
        }
    }
    return $false
}
function Get-LookupProducts {
    param([object]$Model)
    $dateById=@{}
    foreach($d in $Model.dates){$dateById[[string]$d.id]=[string]$d.date}
    $noteByTitle=@{}
    foreach($n in $Model.notes){
        if([string]::IsNullOrWhiteSpace($n.note)){continue}
        $k=$n.title.ToLowerInvariant()
        if(-not $noteByTitle.ContainsKey($k)){$noteByTitle[$k]=New-List}
        if(-not $noteByTitle[$k].Contains($n.note)){[void]$noteByTitle[$k].Add($n.note)}
    }
    $rows=New-List
    foreach($r in $Model.ids){
        $date=$(if($dateById.ContainsKey([string]$r.id)){[string]$dateById[[string]$r.id]}else{''})
        $k=$r.title.ToLowerInvariant()
        $note=$(if($noteByTitle.ContainsKey($k)){(($noteByTitle[$k]|ForEach-Object{[string]$_}) -join ' || ')}else{''})
        [void]$rows.Add([pscustomobject]@{id=$r.id;title=$r.title;date=$date;note=$note})
    }
    return @($rows)
}

function Required-Sources {
    param([object]$Entry)
    switch([string]$Entry.family){
        'scalar' { return 'mvs_ids.txt|mvs_dates.txt' }
        'lookup' { return 'mvs_ids.txt|mvs_dates.txt' }
        'diagnostic' { return [string]$Entry.source_file }
        'relationship' { return 'mvs.txt' }
        'single-complete' {
            switch([string]$Entry.operation){
                'detail_query' { return 'mvs.txt' }
                'product_file_query' { return 'mvs.txt' }
                'product_section_query' { return 'mvs.txt' }
                'variant_query' { return 'mvs_names.txt' }
                'note_query' { return 'mvs_notes.html' }
                'unparsed_query' { return [string]$Entry.source_file }
                'hash_diagnostic' { return [string]$Entry.source_file }
                default { return '' }
            }
        }
        default { return '' }
    }
}

function Get-CandidateFilenames {
    param([object]$Model,[string]$Source,[string]$Needle)
    $rows=New-List
    $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    if($Source -eq 'filename'){
        foreach($r in $Model.hash_records){
            if(Matches-Exact $r.filename $Needle){
                if($seen.Add($r.filename)){[void]$rows.Add($r.filename)}
            }
        }
    } elseif($Source -eq 'hash'){
        foreach($r in $Model.hash_records){
            if(Matches-Exact $r.hash $Needle){
                if($seen.Add($r.filename)){[void]$rows.Add($r.filename)}
            }
        }
    }
    return @($rows)
}

function Test-LookupResult {
    param([object]$Model,[object]$Entry)
    $products=Get-LookupProducts $Model
    foreach($p in $products){
        $value=Get-PropertyText $p ([string]$Entry.search_source)
        if(Test-StarPattern $value ([string]$Entry.search_value)){
            $target=Get-PropertyText $p ([string]$Entry.target_field)
            if(-not [string]::IsNullOrEmpty($target)){return $true}
        }
    }
    return $false
}

function Test-RelationshipResult {
    param([object]$Model,[object]$Entry)
    $candidate=Get-CandidateFilenames $Model ([string]$Entry.search_source) ([string]$Entry.search_value)
    $rows=New-List
    foreach($filename in $candidate){
        $owners=@($Model.product_files | Where-Object {Matches-Exact $_.filename $filename})
        if($owners.Count -eq 0){
            [void]$rows.Add([pscustomobject]@{id='';title='';date='';note='';filename=$filename})
        } else {
            foreach($owner in $owners){
                [void]$rows.Add([pscustomobject]@{id=$owner.id;title=$owner.title;date=$owner.date;note=$owner.note;filename=$filename})
            }
        }
    }
    return Has-Projection @($rows) ([string]$Entry.fields)
}

function Test-DetailResult {
    param([object]$Model,[object]$Entry)
    $seeds=New-List
    $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $source=[string]$Entry.search_source;$needle=[string]$Entry.search_value
    if($source -eq 'id' -or $source -eq 'title'){
        foreach($f in $Model.product_files){
            $match=$false
            if($source -eq 'id'){
                try{$match=([int64]$f.id -eq [int64]$needle)}catch{$match=$false}
            } else {$match=Matches-Exact $f.title $needle}
            if(-not $match){continue}
            $key=[string]$f.id + [char]0x1f + $f.filename
            if($seen.Add($key)){[void]$seeds.Add([pscustomobject]@{owner=$f;filename=$f.filename})}
        }
    } else {
        foreach($filename in Get-CandidateFilenames $Model $source $needle){
            $owners=@($Model.product_files | Where-Object {Matches-Exact $_.filename $filename} | Group-Object id | ForEach-Object {$_.Group[0]})
            if($owners.Count -eq 0){[void]$seeds.Add([pscustomobject]@{owner=$null;filename=$filename})}
            else{foreach($owner in $owners){[void]$seeds.Add([pscustomobject]@{owner=$owner;filename=$filename})}}
        }
    }
    $rows=New-List
    foreach($seed in $seeds){
        $records=@($Model.hash_records | Where-Object {
            (Matches-Exact $_.filename $seed.filename) -and
            ([string]::IsNullOrEmpty([string]$Entry.algorithm_filter) -or $_.algorithm -eq [string]$Entry.algorithm_filter)
        })
        if($records.Count -eq 0){
            [void]$rows.Add([pscustomobject]@{
                id=$(if($null -ne $seed.owner){$seed.owner.id}else{''});title=$(if($null -ne $seed.owner){$seed.owner.title}else{''})
                date=$(if($null -ne $seed.owner){$seed.owner.date}else{''});note=$(if($null -ne $seed.owner){$seed.owner.note}else{''})
                filename=$seed.filename;hash='';algorithm='';source=''
            })
        } else {
            foreach($record in $records){
                [void]$rows.Add([pscustomobject]@{
                    id=$(if($null -ne $seed.owner){$seed.owner.id}else{''});title=$(if($null -ne $seed.owner){$seed.owner.title}else{''})
                    date=$(if($null -ne $seed.owner){$seed.owner.date}else{''});note=$(if($null -ne $seed.owner){$seed.owner.note}else{''})
                    filename=$record.filename;hash=$record.hash;algorithm=$record.algorithm;source=$record.source
                })
            }
        }
    }
    return Has-Projection @($rows) ([string]$Entry.fields)
}

function Test-VariantResult {
    param([object]$Model,[object]$Entry)
    $rows=@($Model.variants)
    if(-not [string]::IsNullOrEmpty([string]$Entry.search_source)){
        $source=[string]$Entry.search_source;$needle=[string]$Entry.search_value
        $rows=@($rows | Where-Object {
            if($source -eq 'id'){Matches-Exact $_.id $needle}
            elseif($source -eq 'filename'){Matches-Exact $_.filename $needle}
            elseif($source -eq 'hash'){Matches-Exact $_.hash $needle}
            else{$false}
        })
    }
    return Has-Projection $rows ([string]$Entry.fields)
}
function Test-HashResult {
    param([object]$Model,[object]$Entry)

    $algorithmFilter=[string]$Entry.algorithm_filter
    $searchSource=[string]$Entry.search_source
    $searchValue=[string]$Entry.search_value

    $rows=@($Model.hash_records | Where-Object {
        if(-not [string]::IsNullOrEmpty($algorithmFilter)){
            if([string]$_.algorithm -ne $algorithmFilter){ return $false }
        }

        if([string]::IsNullOrEmpty($searchSource)){ return $true }
        if($searchSource -eq 'filename'){
            return (Matches-Exact ([string]$_.filename) $searchValue)
        }
        if($searchSource -eq 'hash'){
            return (Matches-Exact ([string]$_.hash) $searchValue)
        }
        return $false
    })
    return Has-Projection $rows ([string]$Entry.fields)
}
function Test-ProductFileResult {
    param([object]$Model,[object]$Entry)
    $rows=@($Model.product_files)
    if(-not [string]::IsNullOrEmpty([string]$Entry.search_source)){
        $src=[string]$Entry.search_source;$needle=[string]$Entry.search_value
        $rows=@($rows | Where-Object {
            if($src -eq 'id'){try{[int64]$_.id -eq [int64]$needle}catch{$false}}
            else{Matches-Exact $_.title $needle}
        })
    }
    return Has-Projection $rows ([string]$Entry.fields)
}
function Test-ProductSectionResult {
    param([object]$Model,[object]$Entry)
    $rows=@($Model.product_sections)
    if(-not [string]::IsNullOrEmpty([string]$Entry.search_source)){
        $src=[string]$Entry.search_source;$needle=[string]$Entry.search_value
        $rows=@($rows | Where-Object {
            if($src -eq 'id'){try{[int64]$_.id -eq [int64]$needle}catch{$false}}
            else{Matches-Exact $_.title $needle}
        })
    }
    return $rows.Count -gt 0
}
function Test-NoteResult {
    param([object]$Model,[object]$Entry)
    $rows=@($Model.notes)
    if(-not [string]::IsNullOrEmpty([string]$Entry.search_source)){
        $needle=[string]$Entry.search_value
        $rows=@($rows | Where-Object {Matches-Exact $_.title $needle})
    }
    return Has-Projection $rows ([string]$Entry.fields)
}

function Get-SingleStatus {
    param([object]$Model,[object]$Entry)
    $required=Required-Sources $Entry
    if(-not (All-Sources-Exist $Model.root $required)){return [pscustomobject]@{status='SOURCE_MISSING';rc=4}}
    $has=$true
    switch([string]$Entry.family){
        'scalar' {
            if($Model.ids.Count -eq 0){return [pscustomobject]@{status='FAIL';rc=5}}
            $has=$true
        }
        'lookup' { $has=Test-LookupResult $Model $Entry }
        'diagnostic' { $has=$true }
        'relationship' { $has=Test-RelationshipResult $Model $Entry }
        'single-complete' {
            switch([string]$Entry.operation){
                'detail_query' {$has=Test-DetailResult $Model $Entry}
                'variant_query' {$has=Test-VariantResult $Model $Entry}
                'hash_query' {$has=Test-HashResult $Model $Entry}
                'product_file_query' {$has=Test-ProductFileResult $Model $Entry}
                'product_section_query' {$has=Test-ProductSectionResult $Model $Entry}
                'note_query' {$has=Test-NoteResult $Model $Entry}
                'unparsed_query' {$has=$true}
                'hash_diagnostic' {$has=$true}
                'summary_query' {$has=$true}
                default {return [pscustomobject]@{status='FAIL';rc=5}}
            }
        }
        default {return [pscustomobject]@{status='FAIL';rc=5}}
    }
    if($has){return [pscustomobject]@{status='PASS';rc=0}}
    return [pscustomobject]@{status='NO_RESULT';rc=1}
}

function Get-CompareStatus {
    param([object]$Entry,[string]$First,[string]$Second)
    $src=[string]$Entry.source_file
    if([string]::IsNullOrWhiteSpace($src)){return [pscustomobject]@{status='FAIL';rc=5}}
    if(-not (Source-Exists $First $src) -or -not (Source-Exists $Second $src)){
        return [pscustomobject]@{status='SOURCE_MISSING';rc=4}
    }
    return [pscustomobject]@{status='PASS';rc=0}
}

if([string]::IsNullOrWhiteSpace($PlanPath) -or -not (Test-Path -LiteralPath $PlanPath -PathType Leaf)){Fail 2 'Missing plan-slice.tsv.'}
if([string]::IsNullOrWhiteSpace($OutputPath)){Fail 2 'Missing output TSV path.'}
$entries=@(Import-Csv -LiteralPath $PlanPath -Delimiter "`t")
if($entries.Count -eq 0){Fail 2 'Plan slice is empty.'}

try {
    $sb=New-Object Text.StringBuilder
    [void]$sb.Append("index`tstatus`trc`telapsed_ms`n")
    if($Mode -eq 'snapshot'){
        if(-not (Test-Path -LiteralPath $FirstData -PathType Container)){Fail 3 ('Snapshot data folder not found: ' + $FirstData)}
        $model=Read-FastModel $FirstData
        foreach($entry in $entries){
            $sw=[Diagnostics.Stopwatch]::StartNew()
            $result=Get-SingleStatus $model $entry
            $sw.Stop()
            [void]$sb.Append(([string]$entry.index + "`t" + $result.status + "`t" + $result.rc + "`t" + $sw.ElapsedMilliseconds + "`n"))
        }
    } elseif($Mode -eq 'compare'){
        if(-not (Test-Path -LiteralPath $FirstData -PathType Container) -or -not (Test-Path -LiteralPath $SecondData -PathType Container)){Fail 3 'Compare data folder missing.'}
        foreach($entry in $entries){
            $sw=[Diagnostics.Stopwatch]::StartNew()
            $result=Get-CompareStatus $entry $FirstData $SecondData
            $sw.Stop()
            [void]$sb.Append(([string]$entry.index + "`t" + $result.status + "`t" + $result.rc + "`t" + $sw.ElapsedMilliseconds + "`n"))
        }
    } else {Fail 2 ('Unsupported fast mode: ' + $Mode)}
    [IO.File]::WriteAllText($OutputPath,$sb.ToString(),$utf8)
    exit 0
} catch {
    Fail 5 $_.Exception.Message
}
:_MVSFastSweep_end
