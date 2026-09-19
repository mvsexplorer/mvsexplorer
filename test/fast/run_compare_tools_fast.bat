@echo off
:setup
setlocal DisableDelayedExpansion
set "app.version=0.2.0"
set "app.name=run_compare_tools_fast"
set "app.rc=0"
set "app.self=%~f0"
set "mvsf_mode=compare"
set "mvsf_first_data=%~1"
set "mvsf_second_data=%~2"
set "mvsf_plan=%~3"
set "mvsf_output=%~4"
set "mvsf_cache_root="
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
$CacheRoot = [string]$env:mvsf_cache_root

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



function Get-Sha256File {
    param([string]$Path)
    $sha=[Security.Cryptography.SHA256]::Create()
    $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{
        $hash=$sha.ComputeHash($stream)
        return -join ($hash | ForEach-Object {$_.ToString('x2')})
    } finally {$stream.Dispose();$sha.Dispose()}
}

function Get-Sha256Text {
    param([AllowNull()][AllowEmptyString()][string]$Text)
    if($null-eq$Text){$Text=''}
    $sha=[Security.Cryptography.SHA256]::Create()
    try{
        $hash=$sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))
        return -join ($hash | ForEach-Object {$_.ToString('x2')})
    } finally {$sha.Dispose()}
}

function Get-SnapshotCacheKey {
    param([string]$Root,[string]$Plan,[hashtable]$Inventory,[string]$WorkerVersion)
    $sb=New-Object Text.StringBuilder
    [void]$sb.AppendLine('worker='+$WorkerVersion)
    [void]$sb.AppendLine('plan='+(Get-Sha256File $Plan))
    foreach($name in @('mvs.txt','mvs_ids.txt','mvs_dates.txt','mvs_names.txt','mvs_notes.html','mvs.sha1','mvs.sha256')){
        $meta=$Inventory[$name]
        if($null-eq$meta -or -not[bool]$meta.present){
            [void]$sb.AppendLine($name+'|missing')
        } else {
            $path=Join-Path $Root $name
            [void]$sb.AppendLine($name+'|'+[string]$meta.length+'|'+(Get-Sha256File $path))
        }
    }
    return Get-Sha256Text $sb.ToString()
}

function Get-SourceInventory {
    param([string]$Root)
    $inventory=@{}
    foreach($name in @('mvs.txt','mvs_ids.txt','mvs_dates.txt','mvs_names.txt','mvs_notes.html','mvs.sha1','mvs.sha256')){
        $path=Join-Path $Root $name
        if(Test-Path -LiteralPath $path -PathType Leaf){
            $item=Get-Item -LiteralPath $path -ErrorAction Stop
            $inventory[$name]=[pscustomobject]@{
                present=$true
                length=[int64]$item.Length
                ticks=[int64]$item.LastWriteTimeUtc.Ticks
            }
        } else {
            $inventory[$name]=[pscustomobject]@{present=$false;length=0L;ticks=0L}
        }
    }
    return $inventory
}

function Inventory-SourceExists {
    param([hashtable]$Inventory,[string]$Name)
    if([string]::IsNullOrWhiteSpace($Name)){return $true}
    if($null -eq $Inventory -or -not $Inventory.ContainsKey($Name)){return $false}
    return [bool]$Inventory[$Name].present
}

function Inventory-AllSourcesExist {
    param([hashtable]$Inventory,[string]$Spec)
    if([string]::IsNullOrWhiteSpace($Spec)){return $true}
    foreach($name in $Spec.Split('|')){
        if(-not [string]::IsNullOrWhiteSpace($name) -and -not (Inventory-SourceExists $Inventory $name)){return $false}
    }
    return $true
}

function Assert-SourceInventoryUnchanged {
    param([string]$Root,[hashtable]$Before)
    $after=Get-SourceInventory $Root
    foreach($name in $Before.Keys){
        $a=$Before[$name]
        $b=$after[$name]
        if([bool]$a.present -ne [bool]$b.present){
            throw ('Source availability changed during fast batch: '+$name)
        }
        if([bool]$a.present){
            if([int64]$a.length -ne [int64]$b.length -or [int64]$a.ticks -ne [int64]$b.ticks){
                throw ('Source changed during fast batch: '+$name)
            }
        }
    }
}

function New-Index { return @{} }

function Get-IndexKey {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if($null -eq $Value){return ''}
    return $Value.Trim().ToLowerInvariant()
}

function Add-IndexRow {
    param([hashtable]$Index,[AllowNull()][AllowEmptyString()][string]$Key,[object]$Row)
    $k=Get-IndexKey $Key
    if([string]::IsNullOrEmpty($k)){return}
    if(-not $Index.ContainsKey($k)){$Index[$k]=New-List}
    [void]$Index[$k].Add($Row)
}

function Get-IndexRows {
    param([hashtable]$Index,[AllowNull()][AllowEmptyString()][string]$Key)
    if($null -eq $Index){return @()}
    $k=Get-IndexKey $Key
    if([string]::IsNullOrEmpty($k) -or -not $Index.ContainsKey($k)){return @()}
    return @($Index[$k])
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
        $reader=New-Object System.IO.StreamReader -ArgumentList @($idsPath,[System.Text.Encoding]::UTF8,$true,65536)
        try{
            while($true){
                $line=$reader.ReadLine()
                if($null-eq$line){break}
                if ($line -match '^(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') {
                    [void]$ids.Add([pscustomobject]@{ id=[string][int]$Matches.id; title=Normalize-Title $Matches.title })
                }
            }
        } finally {$reader.Dispose()}
    }

    $dateById = @{}
    $datesPath = Join-Path $Root 'mvs_dates.txt'
    if (Test-Path -LiteralPath $datesPath -PathType Leaf) {
        $reader=New-Object System.IO.StreamReader -ArgumentList @($datesPath,[System.Text.Encoding]::UTF8,$true,65536)
        try{
            while($true){
                $line=$reader.ReadLine()
                if($null-eq$line){break}
                if ($line -match '^(?<date>.*?)\s+-\s+(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') {
                    $id = [string][int]$Matches.id
                    $row = [pscustomobject]@{ id=$id; title=Normalize-Title $Matches.title; date=$Matches.date.Trim() }
                    [void]$dates.Add($row)
                    if (-not $dateById.ContainsKey($id)) { $dateById[$id]=$row.date }
                }
            }
        } finally {$reader.Dispose()}
    }

    $noteByTitle = @{}
    $notesPath = Join-Path $Root 'mvs_notes.html'
    if (Test-Path -LiteralPath $notesPath -PathType Leaf) {
        $html = Get-Content -LiteralPath $notesPath -Raw -Encoding UTF8
        $occurrence = 0
        foreach ($match in [regex]::Matches($html,'(?is)<h[13][^>]*>(?<heading>.*?)</h[13]>(?<body>.*?)(?=<h[13]\b|\z)')) {
            $occurrence++
            $heading = Normalize-Title ([regex]::Replace($match.Groups['heading'].Value,'(?is)<[^>]+>',' '))
            $title = $heading
            if ($heading -match '^(?<title>.*?)\s*\[ID:\s*(?<id>[^\]]+?)\s*\]\s*$') {
                $title = Normalize-Title $Matches.title
            }
            $note = Convert-NoteHtmlToText $match.Groups['body'].Value
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
        $reader=New-Object System.IO.StreamReader -ArgumentList @($mvsPath,[System.Text.Encoding]::UTF8,$true,65536)
        try{
            while($true){
                $line=$reader.ReadLine()
                if($null-eq$line){break}
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
        } finally {$reader.Dispose()}
    }

    $namesPath = Join-Path $Root 'mvs_names.txt'
    if (Test-Path -LiteralPath $namesPath -PathType Leaf) {
        $current=$null
        $occurrence=0
        $hasFile=$false
        $reader=New-Object System.IO.StreamReader -ArgumentList @($namesPath,[System.Text.Encoding]::UTF8,$true,65536)
        try{
            while($true){
                $line=$reader.ReadLine()
                if($null-eq$line){break}
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
        } finally {$reader.Dispose()}
        if ($null -ne $current -and -not $hasFile) {
            [void]$variants.Add([pscustomobject]@{occurrence=$current.occurrence;id=$current.id;variant_title=$current.variant_title;filename='';hash='';algorithm=''})
        }
    }

    foreach ($name in @('mvs.sha1','mvs.sha256')) {
        $length=if($name -eq 'mvs.sha1'){40}else{64}
        $path=Join-Path $Root $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $pattern='^\s*(?<hash>[0-9A-Fa-f]{' + $length + '})\s+\*(?<filename>.+?)\s*$'
        $reader=New-Object System.IO.StreamReader -ArgumentList @($path,[System.Text.Encoding]::UTF8,$true,65536)
        try{
            while($true){
                $line=$reader.ReadLine()
                if($null-eq$line){break}
                if ($line -match $pattern) { Add-HashRecord $hashRecords $name $Matches.filename $Matches.hash '' '' '' }
            }
        } finally {$reader.Dispose()}
    }

    $indexes=[ordered]@{
        product_files_by_id=New-Index
        product_files_by_title=New-Index
        product_files_by_filename=New-Index
        product_sections_by_id=New-Index
        product_sections_by_title=New-Index
        variants_by_id=New-Index
        variants_by_title=New-Index
        variants_by_filename=New-Index
        variants_by_hash=New-Index
        hash_records_by_filename=New-Index
        hash_records_by_hash=New-Index
        notes_by_title=New-Index
    }
    foreach($row in @($productFiles)){
        Add-IndexRow $indexes.product_files_by_id $row.id $row
        Add-IndexRow $indexes.product_files_by_title $row.title $row
        Add-IndexRow $indexes.product_files_by_filename $row.filename $row
    }
    foreach($row in @($productSections)){
        Add-IndexRow $indexes.product_sections_by_id $row.id $row
        Add-IndexRow $indexes.product_sections_by_title $row.title $row
    }
    foreach($row in @($variants)){
        Add-IndexRow $indexes.variants_by_id $row.id $row
        Add-IndexRow $indexes.variants_by_title $row.variant_title $row
        Add-IndexRow $indexes.variants_by_filename $row.filename $row
        Add-IndexRow $indexes.variants_by_hash $row.hash $row
    }
    foreach($row in @($hashRecords)){
        Add-IndexRow $indexes.hash_records_by_filename $row.filename $row
        Add-IndexRow $indexes.hash_records_by_hash $row.hash $row
    }
    foreach($row in @($notes)){Add-IndexRow $indexes.notes_by_title $row.title $row}

    $lookupProducts=New-List
    $lookupDateById=@{}
    foreach($d in @($dates)){if(-not $lookupDateById.ContainsKey([string]$d.id)){$lookupDateById[[string]$d.id]=[string]$d.date}}
    foreach($r in @($ids)){
        $date=$(if($lookupDateById.ContainsKey([string]$r.id)){[string]$lookupDateById[[string]$r.id]}else{''})
        $nk=(Get-IndexKey $r.title)
        $noteValues=New-Object System.Collections.ArrayList
        $noteSeen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach($nr in Get-IndexRows $indexes.notes_by_title $nk){
            $nv=[string]$nr.note
            if(-not [string]::IsNullOrWhiteSpace($nv) -and $noteSeen.Add($nv)){[void]$noteValues.Add($nv)}
        }
        $note=$(if($noteValues.Count -gt 0){(@($noteValues) -join ' || ')}else{''})
        [void]$lookupProducts.Add([pscustomobject]@{id=$r.id;title=$r.title;date=$date;note=$note})
    }

    return [pscustomobject]@{
        root=$Root;ids=@($ids);dates=@($dates);product_sections=@($productSections);product_files=@($productFiles)
        variant_sections=@($variantSections);variants=@($variants);hash_records=@($hashRecords);notes=@($notes)
        indexes=$indexes;lookup_products=@($lookupProducts);source_inventory=$null
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
    return @($Model.lookup_products)
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
    $records=@()
    if($Source -eq 'filename'){$records=@(Get-IndexRows $Model.indexes.hash_records_by_filename $Needle)}
    elseif($Source -eq 'hash'){$records=@(Get-IndexRows $Model.indexes.hash_records_by_hash $Needle)}
    foreach($r in $records){
        if(-not [string]::IsNullOrWhiteSpace([string]$r.filename) -and $seen.Add([string]$r.filename)){[void]$rows.Add([string]$r.filename)}
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
    foreach($filename in Get-CandidateFilenames $Model ([string]$Entry.search_source) ([string]$Entry.search_value)){
        $owners=@(Get-IndexRows $Model.indexes.product_files_by_filename $filename)
        if($owners.Count -eq 0){
            $row=[pscustomobject]@{id='';title='';date='';note='';filename=$filename}
            if(Has-Projection @($row) ([string]$Entry.fields)){return $true}
        } else {
            foreach($owner in $owners){
                $row=[pscustomobject]@{id=$owner.id;title=$owner.title;date=$owner.date;note=$owner.note;filename=$filename}
                if(Has-Projection @($row) ([string]$Entry.fields)){return $true}
            }
        }
    }
    return $false
}


function Test-DetailResult {
    param([object]$Model,[object]$Entry)
    $seeds=New-List
    $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $source=[string]$Entry.search_source
    $needle=[string]$Entry.search_value

    if($source -eq 'id' -or $source -eq 'title'){
        $files=@()
        if($source -eq 'id'){$files=@(Get-IndexRows $Model.indexes.product_files_by_id $needle)}
        else{$files=@(Get-IndexRows $Model.indexes.product_files_by_title $needle)}
        foreach($f in $files){
            $key=[string]$f.id+[char]0x1f+[string]$f.filename
            if($seen.Add($key)){[void]$seeds.Add([pscustomobject]@{owner=$f;filename=$f.filename})}
        }
    } else {
        foreach($filename in Get-CandidateFilenames $Model $source $needle){
            $owners=@(Get-IndexRows $Model.indexes.product_files_by_filename $filename)
            $ownerSeen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
            if($owners.Count -eq 0){
                [void]$seeds.Add([pscustomobject]@{owner=$null;filename=$filename})
            } else {
                foreach($owner in $owners){
                    if($ownerSeen.Add([string]$owner.id)){[void]$seeds.Add([pscustomobject]@{owner=$owner;filename=$filename})}
                }
            }
        }
    }

    $fields=[string]$Entry.fields
    $filter=[string]$Entry.algorithm_filter
    foreach($seed in $seeds){
        $records=@(Get-IndexRows $Model.indexes.hash_records_by_filename ([string]$seed.filename))
        $matchedRecord=$false
        foreach($record in $records){
            if(-not [string]::IsNullOrEmpty($filter) -and [string]$record.algorithm -ne $filter){continue}
            $matchedRecord=$true
            $row=[pscustomobject]@{
                id=$(if($null -ne $seed.owner){$seed.owner.id}else{''})
                title=$(if($null -ne $seed.owner){$seed.owner.title}else{''})
                date=$(if($null -ne $seed.owner){$seed.owner.date}else{''})
                note=$(if($null -ne $seed.owner){$seed.owner.note}else{''})
                filename=$record.filename;hash=$record.hash;algorithm=$record.algorithm;source=$record.source
            }
            if(Has-Projection @($row) $fields){return $true}
        }
        if(-not $matchedRecord){
            $row=[pscustomobject]@{
                id=$(if($null -ne $seed.owner){$seed.owner.id}else{''})
                title=$(if($null -ne $seed.owner){$seed.owner.title}else{''})
                date=$(if($null -ne $seed.owner){$seed.owner.date}else{''})
                note=$(if($null -ne $seed.owner){$seed.owner.note}else{''})
                filename=$seed.filename;hash='';algorithm='';source=''
            }
            if(Has-Projection @($row) $fields){return $true}
        }
    }
    return $false
}


function Test-VariantResult {
    param([object]$Model,[object]$Entry)
    $source=[string]$Entry.search_source
    $rows=@()
    if([string]::IsNullOrEmpty($source)){$rows=@($Model.variants)}
    elseif($source -eq 'id'){$rows=@(Get-IndexRows $Model.indexes.variants_by_id ([string]$Entry.search_value))}
    elseif($source -eq 'filename'){$rows=@(Get-IndexRows $Model.indexes.variants_by_filename ([string]$Entry.search_value))}
    elseif($source -eq 'hash'){$rows=@(Get-IndexRows $Model.indexes.variants_by_hash ([string]$Entry.search_value))}
    return Has-Projection $rows ([string]$Entry.fields)
}


function Test-HashResult {
    param([object]$Model,[object]$Entry)
    $filter=[string]$Entry.algorithm_filter
    $source=[string]$Entry.search_source
    $rows=@()
    if([string]::IsNullOrEmpty($source)){$rows=@($Model.hash_records)}
    elseif($source -eq 'filename'){$rows=@(Get-IndexRows $Model.indexes.hash_records_by_filename ([string]$Entry.search_value))}
    elseif($source -eq 'hash'){$rows=@(Get-IndexRows $Model.indexes.hash_records_by_hash ([string]$Entry.search_value))}
    else{return $false}
    foreach($row in $rows){
        if(-not [string]::IsNullOrEmpty($filter) -and [string]$row.algorithm -ne $filter){continue}
        if(Has-Projection @($row) ([string]$Entry.fields)){return $true}
    }
    return $false
}


function Test-ProductFileResult {
    param([object]$Model,[object]$Entry)
    $source=[string]$Entry.search_source
    $rows=@()
    if([string]::IsNullOrEmpty($source)){$rows=@($Model.product_files)}
    elseif($source -eq 'id'){$rows=@(Get-IndexRows $Model.indexes.product_files_by_id ([string]$Entry.search_value))}
    else{$rows=@(Get-IndexRows $Model.indexes.product_files_by_title ([string]$Entry.search_value))}
    return Has-Projection $rows ([string]$Entry.fields)
}


function Test-ProductSectionResult {
    param([object]$Model,[object]$Entry)
    $source=[string]$Entry.search_source
    $rows=@()
    if([string]::IsNullOrEmpty($source)){$rows=@($Model.product_sections)}
    elseif($source -eq 'id'){$rows=@(Get-IndexRows $Model.indexes.product_sections_by_id ([string]$Entry.search_value))}
    else{$rows=@(Get-IndexRows $Model.indexes.product_sections_by_title ([string]$Entry.search_value))}
    return $rows.Count -gt 0
}


function Test-NoteResult {
    param([object]$Model,[object]$Entry)
    $rows=@()
    if([string]::IsNullOrEmpty([string]$Entry.search_source)){$rows=@($Model.notes)}
    else{$rows=@(Get-IndexRows $Model.indexes.notes_by_title ([string]$Entry.search_value))}
    return Has-Projection $rows ([string]$Entry.fields)
}

function Get-SingleStatus {
    param([object]$Model,[object]$Entry)
    $required=Required-Sources $Entry
    if(-not (Inventory-AllSourcesExist $Model.source_inventory $required)){return [pscustomobject]@{status='SOURCE_MISSING';rc=4}}
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
    param([object]$Entry,[hashtable]$FirstInventory,[hashtable]$SecondInventory)
    $src=[string]$Entry.source_file
    if([string]::IsNullOrWhiteSpace($src)){return [pscustomobject]@{status='FAIL';rc=5}}
    if(-not (Inventory-SourceExists $FirstInventory $src) -or -not (Inventory-SourceExists $SecondInventory $src)){
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
        $inventory=Get-SourceInventory $FirstData
        $cachePath=''
        if(-not[string]::IsNullOrWhiteSpace($CacheRoot)){
            if(-not(Test-Path -LiteralPath $CacheRoot -PathType Container)){[void](New-Item -ItemType Directory -Path $CacheRoot -Force)}
            $cacheKey=Get-SnapshotCacheKey $FirstData $PlanPath $inventory $Version
            Assert-SourceInventoryUnchanged $FirstData $inventory
            $cachePath=Join-Path $CacheRoot ($cacheKey+'.tsv')
            if(Test-Path -LiteralPath $cachePath -PathType Leaf){
                Copy-Item -LiteralPath $cachePath -Destination $OutputPath -Force
                exit 0
            }
        }
        $model=Read-FastModel $FirstData
        $model.source_inventory=$inventory
        foreach($entry in $entries){
            $sw=[Diagnostics.Stopwatch]::StartNew()
            $result=Get-SingleStatus $model $entry
            $sw.Stop()
            [void]$sb.Append(([string]$entry.index + "`t" + $result.status + "`t" + $result.rc + "`t" + $sw.ElapsedMilliseconds + "`n"))
        }
        Assert-SourceInventoryUnchanged $FirstData $inventory
    } elseif($Mode -eq 'compare'){
        if(-not (Test-Path -LiteralPath $FirstData -PathType Container) -or -not (Test-Path -LiteralPath $SecondData -PathType Container)){Fail 3 'Compare data folder missing.'}
        $firstInventory=Get-SourceInventory $FirstData
        $secondInventory=Get-SourceInventory $SecondData
        foreach($entry in $entries){
            $sw=[Diagnostics.Stopwatch]::StartNew()
            $result=Get-CompareStatus $entry $firstInventory $secondInventory
            $sw.Stop()
            [void]$sb.Append(([string]$entry.index + "`t" + $result.status + "`t" + $result.rc + "`t" + $sw.ElapsedMilliseconds + "`n"))
        }
        Assert-SourceInventoryUnchanged $FirstData $firstInventory
        Assert-SourceInventoryUnchanged $SecondData $secondInventory
    } else {Fail 2 ('Unsupported fast mode: ' + $Mode)}
    [IO.File]::WriteAllText($OutputPath,$sb.ToString(),$utf8)
    if($Mode -eq 'snapshot' -and -not[string]::IsNullOrWhiteSpace($cachePath)){
        $tmp=$cachePath+'.tmp.'+[Guid]::NewGuid().ToString('N')
        Copy-Item -LiteralPath $OutputPath -Destination $tmp -Force
        Move-Item -LiteralPath $tmp -Destination $cachePath -Force
    }
    exit 0
} catch {
    Fail 5 $_.Exception.Message
}
:_MVSFastSweep_end
