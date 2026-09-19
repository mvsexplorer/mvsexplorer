$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
$IndexInput = [string]$env:mvsgui_index_root
$Caller = [string]$env:mvsgui_caller
$Version = [string]$env:mvsgui_version
$Tab = [char]9
$US = [char]31
$OtherRelease = '(Other / unversioned)'
$OtherLanguage = '(Language not specified)'
$Unclassified = '(Unclassified / historical)'
$started = [Diagnostics.Stopwatch]::StartNew()

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

function Write-Line {
    param([AllowEmptyString()][string]$Text)
    [Console]::Out.WriteLine($Text)
}
function Write-Err {
    param([AllowEmptyString()][string]$Text)
    [Console]::Error.WriteLine($Text)
}
function Is-HelpToken {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    return @('--help','-h','-?','/h','/?') -contains $Value
}
function Show-Usage {
    Write-Line ('MVS Explorer Toolkit PowerShell GUI '+$Version)
    Write-Line ('Usage: '+$Caller+' [compact-family-index]')
    Write-Line 'With no argument, current and parent folders are searched for compact MVS databases.'
    Write-Line 'One match is opened automatically; multiple matches are presented for selection; Browse remains available.'
}
function Resolve-IndexRoot {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    try {
        if (-not (Test-Path -LiteralPath $Name -PathType Container)) { return $null }
        $resolved = (Resolve-Path -LiteralPath $Name).Path
        foreach ($need in @(
            'product-classifications.tsv','unclassified-products.tsv',
            'product-presence-all-ever.tsv','product-ids-all-ever.tsv',
            'product-dates-all-ever.tsv','product-files-all-ever.tsv',
            'product-file-hashes-all-ever.tsv','product-notes-all-ever.tsv'
        )) {
            if (-not (Test-Path -LiteralPath (Join-Path $resolved $need) -PathType Leaf)) { return $null }
        }
        return $resolved
    } catch {
        return $null
    }
}

function Find-CompactIndexCandidates {
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $items = New-Object System.Collections.ArrayList
    $roots = New-Object System.Collections.ArrayList
    $current = (Get-Location).Path
    [void]$roots.Add($current)
    $parent = Split-Path -Parent $current
    if ($parent -and -not [StringComparer]::OrdinalIgnoreCase.Equals($parent,$current)) { [void]$roots.Add($parent) }

    function Add-IndexCandidate {
        param([string]$Path)
        $resolved = Resolve-IndexRoot $Path
        if ($null -eq $resolved) { return }
        if ($seen.Add($resolved)) {
            $stamp = ''
            try { $stamp = (Get-Item -LiteralPath $resolved).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') } catch {}
            [void]$items.Add([pscustomobject]@{Path=$resolved;Stamp=$stamp})
        }
    }

    foreach ($root in @($roots)) {
        Add-IndexCandidate $root
        $dirs = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)
        foreach ($dir in $dirs) {
            if ($dir.Name -like 'mvs-family-index-compact-*') { Add-IndexCandidate $dir.FullName }
            if ($dir.Name -like 'mvs_databases*') {
                foreach ($slot in @(Get-ChildItem -LiteralPath $dir.FullName -Directory -ErrorAction SilentlyContinue)) {
                    Add-IndexCandidate $slot.FullName
                    foreach ($compactName in @('compact-index','compact-family-database','compact-database')) {
                        Add-IndexCandidate (Join-Path $slot.FullName $compactName)
                    }
                    foreach ($child in @(Get-ChildItem -LiteralPath $slot.FullName -Directory -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -like 'mvs-family-index-compact-*' })) {
                        Add-IndexCandidate $child.FullName
                    }
                }
            }
        }
    }
    return @($items | Sort-Object @{Expression={$_.Stamp};Descending=$true}, @{Expression={$_.Path};Descending=$false})
}
function Pick-CompactIndexFolder {
    param([AllowNull()][string]$InitialPath)
    $picker = New-Object Windows.Forms.FolderBrowserDialog
    $picker.Description = 'Select the MVS compact product-family database folder'
    $picker.ShowNewFolderButton = $false
    if (-not [string]::IsNullOrWhiteSpace($InitialPath) -and (Test-Path -LiteralPath $InitialPath -PathType Container)) {
        $picker.SelectedPath = $InitialPath
    }
    $pickResult = $picker.ShowDialog()
    $picked = [string]$picker.SelectedPath
    $picker.Dispose()
    if ($pickResult -ne [Windows.Forms.DialogResult]::OK) { return $null }
    return Resolve-IndexRoot $picked
}
function Choose-CompactIndex {
    param([object[]]$Candidates)
    if ($Candidates.Count -eq 0) { return Pick-CompactIndexFolder $null }
    if ($Candidates.Count -eq 1) {
        Write-Line ('Auto-selected compact database: ' + [string]$Candidates[0].Path)
        return [string]$Candidates[0].Path
    }

    $choice = New-Object Windows.Forms.Form
    $choice.Text = 'Choose MVS database'
    $choice.StartPosition = 'CenterScreen'
    $choice.MinimizeBox = $false
    $choice.MaximizeBox = $false
    $choice.ClientSize = New-Object Drawing.Size(850,360)

    $label = New-Object Windows.Forms.Label
    $label.Text = 'More than one compact MVS database was found in the current/parent folders. Choose one, or browse elsewhere.'
    $label.AutoSize = $false
    $label.Location = New-Object Drawing.Point(12,12)
    $label.Size = New-Object Drawing.Size(826,36)
    $choice.Controls.Add($label)

    $list = New-Object Windows.Forms.ListBox
    $list.Location = New-Object Drawing.Point(12,52)
    $list.Size = New-Object Drawing.Size(826,250)
    $list.HorizontalScrollbar = $true
    foreach ($candidate in $Candidates) {
        [void]$list.Items.Add(('[{0}]  {1}' -f $candidate.Stamp,$candidate.Path))
    }
    if ($list.Items.Count -gt 0) { $list.SelectedIndex = 0 }
    $choice.Controls.Add($list)

    $open = New-Object Windows.Forms.Button
    $open.Text = 'Open'
    $open.Location = New-Object Drawing.Point(576,316)
    $open.Size = New-Object Drawing.Size(82,30)
    $open.DialogResult = [Windows.Forms.DialogResult]::OK
    $choice.AcceptButton = $open
    $choice.Controls.Add($open)

    $browse = New-Object Windows.Forms.Button
    $browse.Text = 'Browse...'
    $browse.Location = New-Object Drawing.Point(664,316)
    $browse.Size = New-Object Drawing.Size(82,30)
    $choice.Controls.Add($browse)

    $cancel = New-Object Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Location = New-Object Drawing.Point(752,316)
    $cancel.Size = New-Object Drawing.Size(82,30)
    $cancel.DialogResult = [Windows.Forms.DialogResult]::Cancel
    $choice.CancelButton = $cancel
    $choice.Controls.Add($cancel)

    $script:ChosenBrowsePath = $null
    $browse.Add_Click({
        $initial = if ($list.SelectedIndex -ge 0) { [string]$Candidates[$list.SelectedIndex].Path } else { $null }
        $picked = Pick-CompactIndexFolder $initial
        if ($null -ne $picked) {
            $script:ChosenBrowsePath = $picked
            $choice.DialogResult = [Windows.Forms.DialogResult]::Yes
            $choice.Close()
        }
    })
    $list.Add_DoubleClick({
        if ($list.SelectedIndex -ge 0) {
            $choice.DialogResult = [Windows.Forms.DialogResult]::OK
            $choice.Close()
        }
    })

    $result = $choice.ShowDialog()
    $selectedIndex = $list.SelectedIndex
    $choice.Dispose()
    if ($result -eq [Windows.Forms.DialogResult]::Yes) { return [string]$script:ChosenBrowsePath }
    if ($result -ne [Windows.Forms.DialogResult]::OK -or $selectedIndex -lt 0) { return $null }
    return [string]$Candidates[$selectedIndex].Path
}
function New-OrdinalObjectDictionary {
    return ,(New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal))
}
function New-OrdinalIntDictionary {
    return ,(New-Object 'System.Collections.Generic.Dictionary[string,int]' ([StringComparer]::Ordinal))
}
function New-OrdinalStringSet {
    return ,(New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal))
}
function New-IgnoreCaseStringSet {
    return ,(New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase))
}
function New-StringList {
    return ,(New-Object 'System.Collections.Generic.List[string]')
}
function Sort-Strings {
    param([System.Collections.IEnumerable]$Values)
    [string[]]$a = @($Values)
    [Array]::Sort($a,[StringComparer]::OrdinalIgnoreCase)
    return ,$a
}
function Get-ExplicitLanguageLabel {
    param([AllowNull()][AllowEmptyString()][string]$Title)
    if ([string]::IsNullOrWhiteSpace($Title)) { return '' }

    # Language is a fifth analytical/UI layer only when the source title states it
    # explicitly in a trailing parenthetical label. Do not infer language from
    # filenames, locale-looking tokens, geography, or neighbouring titles.
    $languagePattern = '(?:Arabic|Brazilian Portuguese|Chinese(?:\s*-\s*(?:Simplified|Traditional)|\s+\((?:Simplified|Traditional)\))?|Czech|Danish|Dutch|English|Finnish|French|German|Greek|Hebrew|Hungarian|Italian|Japanese|Korean|Norwegian(?: Bokmal| Nynorsk)?|Polish|Portuguese(?:\s*-\s*Brazil| \(Brazil\))?|Romanian|Russian|Slovak|Slovenian|Spanish|Swedish|Thai|Turkish|Ukrainian|Vietnamese|Multiple Languages|Multi-Language|Multilanguage)'
    $m = [regex]::Match($Title,'(?i)\((?<language>'+$languagePattern+')\)\s*$')
    if (-not $m.Success) { return '' }
    return [string]$m.Groups['language'].Value.Trim()
}
function Contains-Text {
    param([AllowNull()][string]$Value,[AllowNull()][string]$Needle)
    if ([string]::IsNullOrWhiteSpace($Needle)) { return $true }
    if ($null -eq $Value) { return $false }
    return $Value.IndexOf($Needle,[StringComparison]::OrdinalIgnoreCase) -ge 0
}
function Open-Tsv {
    param([string]$Name)
    $path = Join-Path $script:IndexRoot $Name
    $reader = New-Object IO.StreamReader($path,$utf8,$true,65536)
    $header = $reader.ReadLine()
    if ($null -eq $header) {
        $reader.Dispose()
        throw ('Compact family table is empty: '+$Name)
    }
    $headers = [string[]]$header.Split([char]9)
    $cols = New-OrdinalIntDictionary
    for ($i=0; $i-lt $headers.Count; $i++) {
        $cols[[string]$headers[$i]] = $i
    }
    return [pscustomobject]@{ Reader=$reader; Cols=$cols; Name=$Name }
}
function Col {
    param([object]$Table,[string]$Name)
    if (-not $Table.Cols.ContainsKey($Name)) {
        throw ('Missing required column "'+$Name+'" in '+$Table.Name)
    }
    return [int]$Table.Cols[$Name]
}
function Ensure-Product {
    param([string]$Title)
    if (-not $script:ProductsByTitle.ContainsKey($Title)) {
        $p = [pscustomobject]@{
            Title=$Title
            Broad=$Unclassified
            Family=$Unclassified
            Release=''
            ReleaseDisplay=$OtherRelease
            Language=(Get-ExplicitLanguageLabel $Title)
            LanguageDisplay=''
            Confidence=''
            Status='unclassified'
            First=''
            Last=''
            Ids=(New-OrdinalStringSet)
            Dates=(New-OrdinalStringSet)
        }
        $p.LanguageDisplay = if([string]::IsNullOrWhiteSpace([string]$p.Language)){$OtherLanguage}else{[string]$p.Language}
        $script:ProductsByTitle[$Title] = $p
        [void]$script:ProductList.Add($p)
    }
    return ,($script:ProductsByTitle[$Title])
}
function Update-ObservedRange {
    param([object]$Product,[string]$First,[string]$Last)
    if ($First -and ((-not $Product.First) -or [StringComparer]::Ordinal.Compare($First,[string]$Product.First) -lt 0)) {
        $Product.First = $First
    }
    if ($Last -and ((-not $Product.Last) -or [StringComparer]::Ordinal.Compare($Last,[string]$Product.Last) -gt 0)) {
        $Product.Last = $Last
    }
}
function Get-OrCreateSet {
    param([object]$Dictionary,[string]$Key)
    if (-not $Dictionary.ContainsKey($Key)) {
        $Dictionary[$Key] = New-OrdinalStringSet
    }
    return ,($Dictionary[$Key])
}
function Get-OrCreateList {
    param([object]$Dictionary,[string]$Key)
    if (-not $Dictionary.ContainsKey($Key)) {
        $Dictionary[$Key] = New-StringList
    }
    return ,($Dictionary[$Key])
}
function Convert-SetDictionaryToArrays {
    param([object]$Source)
    $dest = New-OrdinalObjectDictionary
    foreach ($key in $Source.Keys) {
        $dest[$key] = Sort-Strings $Source[$key]
    }
    return ,$dest
}
function Set-LoadingStatus {
    param([string]$Text)
    if ($null -ne $script:LoadingLabel) {
        $script:LoadingLabel.Text = $Text
        [Windows.Forms.Application]::DoEvents()
    }
}
function Close-Loading {
    if ($null -ne $script:LoadingForm) {
        try { $script:LoadingForm.Close() } catch {}
        try { $script:LoadingForm.Dispose() } catch {}
        $script:LoadingForm = $null
        $script:LoadingLabel = $null
    }
}

if (Is-HelpToken $IndexInput) {
    Show-Usage
    [Environment]::Exit(0)
}

if (-not [string]::IsNullOrWhiteSpace($IndexInput)) {
    $script:IndexRoot = Resolve-IndexRoot $IndexInput
    if ($null -eq $script:IndexRoot) {
        $script:IndexRoot = Pick-CompactIndexFolder $IndexInput
    }
} else {
    $script:IndexRoot = Choose-CompactIndex @(Find-CompactIndexCandidates)
}
if ($null -eq $script:IndexRoot) { [Environment]::Exit(0) }

$script:LoadingForm = New-Object Windows.Forms.Form
$script:LoadingForm.Text = 'MVS Explorer'
$script:LoadingForm.StartPosition = 'CenterScreen'
$script:LoadingForm.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedDialog
$script:LoadingForm.ControlBox = $false
$script:LoadingForm.ClientSize = New-Object Drawing.Size(520,120)
$script:LoadingForm.TopMost = $true
$script:LoadingLabel = New-Object Windows.Forms.Label
$script:LoadingLabel.Dock = [Windows.Forms.DockStyle]::Top
$script:LoadingLabel.Height = 60
$script:LoadingLabel.Padding = New-Object Windows.Forms.Padding(12,14,12,4)
$script:LoadingLabel.Text = 'Loading MVS compact database ...'
$progress = New-Object Windows.Forms.ProgressBar
$progress.Dock = [Windows.Forms.DockStyle]::Top
$progress.Height = 18
$progress.Style = [Windows.Forms.ProgressBarStyle]::Marquee
$progress.MarqueeAnimationSpeed = 24
$script:LoadingForm.Controls.Add($progress)
$script:LoadingForm.Controls.Add($script:LoadingLabel)
$script:LoadingForm.Show()
[Windows.Forms.Application]::DoEvents()

try {
    Write-Line ('MVS Explorer Toolkit PowerShell GUI '+$Version)
    Write-Line ('Compact family index: '+$script:IndexRoot)

    $script:ProductsByTitle = New-OrdinalObjectDictionary
    $script:ProductList = New-Object 'System.Collections.Generic.List[object]'

    Set-LoadingStatus 'Loading classifications ...'
    $t = Open-Tsv 'product-classifications.tsv'
    try {
        $iTitle=Col $t 'product_title'
        $iBroad=Col $t 'broad_family'
        $iFamily=Col $t 'product_family'
        $iRelease=Col $t 'release'
        $iConfidence=Col $t 'confidence'
        $iStatus=Col $t 'status'
        while (($line=$t.Reader.ReadLine()) -ne $null) {
            $parts=[string[]]$line.Split([char]9)
            $title=[string]$parts[$iTitle]
            if (-not $title) { continue }
            $p=Ensure-Product $title
            $p.Broad=if($iBroad-lt$parts.Count -and $parts[$iBroad]){[string]$parts[$iBroad]}else{$Unclassified}
            $p.Family=if($iFamily-lt$parts.Count -and $parts[$iFamily]){[string]$parts[$iFamily]}else{$Unclassified}
            $p.Release=if($iRelease-lt$parts.Count){[string]$parts[$iRelease]}else{''}
            $p.ReleaseDisplay=if($p.Release){[string]$p.Release}else{$OtherRelease}
            $p.Confidence=if($iConfidence-lt$parts.Count){[string]$parts[$iConfidence]}else{''}
            $p.Status=if($iStatus-lt$parts.Count){[string]$parts[$iStatus]}else{'classified'}
        }
    } finally { $t.Reader.Dispose() }

    Set-LoadingStatus 'Loading unclassified/historical products ...'
    $t = Open-Tsv 'unclassified-products.tsv'
    try {
        $iTitle=Col $t 'product_title'
        while (($line=$t.Reader.ReadLine()) -ne $null) {
            $parts=[string[]]$line.Split([char]9)
            if ($iTitle-lt$parts.Count -and $parts[$iTitle]) {
                [void](Ensure-Product ([string]$parts[$iTitle]))
            }
        }
    } finally { $t.Reader.Dispose() }

    Set-LoadingStatus 'Loading observation ranges ...'
    $t = Open-Tsv 'product-presence-all-ever.tsv'
    try {
        $iTitle=Col $t 'product_title'
        $iFirst=Col $t 'first_seen'
        $iLast=Col $t 'last_seen'
        while (($line=$t.Reader.ReadLine()) -ne $null) {
            $parts=[string[]]$line.Split([char]9)
            if ($iTitle-ge$parts.Count -or -not $parts[$iTitle]) { continue }
            $p=Ensure-Product ([string]$parts[$iTitle])
            $first=if($iFirst-lt$parts.Count){[string]$parts[$iFirst]}else{''}
            $last=if($iLast-lt$parts.Count){[string]$parts[$iLast]}else{''}
            Update-ObservedRange $p $first $last
        }
    } finally { $t.Reader.Dispose() }

    Set-LoadingStatus 'Loading product IDs ...'
    $t = Open-Tsv 'product-ids-all-ever.tsv'
    try {
        $iTitle=Col $t 'product_title'
        $iId=Col $t 'id'
        while (($line=$t.Reader.ReadLine()) -ne $null) {
            $parts=[string[]]$line.Split([char]9)
            if ($iTitle-ge$parts.Count -or -not $parts[$iTitle]) { continue }
            $p=Ensure-Product ([string]$parts[$iTitle])
            if ($iId-lt$parts.Count -and $parts[$iId]) { [void]$p.Ids.Add([string]$parts[$iId]) }
        }
    } finally { $t.Reader.Dispose() }

    Set-LoadingStatus 'Loading product dates ...'
    $t = Open-Tsv 'product-dates-all-ever.tsv'
    try {
        $iTitle=Col $t 'product_title'
        $iDate=Col $t 'date'
        $iId=Col $t 'id'
        while (($line=$t.Reader.ReadLine()) -ne $null) {
            $parts=[string[]]$line.Split([char]9)
            if ($iTitle-ge$parts.Count -or -not $parts[$iTitle]) { continue }
            $p=Ensure-Product ([string]$parts[$iTitle])
            $date=if($iDate-lt$parts.Count){[string]$parts[$iDate]}else{''}
            $id=if($iId-lt$parts.Count){[string]$parts[$iId]}else{''}
            if ($date) { [void]$p.Dates.Add($date+$US+$id) }
        }
    } finally { $t.Reader.Dispose() }

    Set-LoadingStatus 'Indexing product-backed filenames ...'
    $fileSets = New-OrdinalObjectDictionary
    $t = Open-Tsv 'product-files-all-ever.tsv'
    try {
        $iTitle=Col $t 'product_title'
        $iFilename=Col $t 'filename'
        while (($line=$t.Reader.ReadLine()) -ne $null) {
            $parts=[string[]]$line.Split([char]9)
            if ($iTitle-ge$parts.Count -or $iFilename-ge$parts.Count) { continue }
            $title=[string]$parts[$iTitle]
            $filename=[string]$parts[$iFilename]
            if (-not $title -or -not $filename) { continue }
            [void](Ensure-Product $title)
            $set=Get-OrCreateSet $fileSets $title
            [void]$set.Add($filename)
        }
    } finally { $t.Reader.Dispose() }
    $script:FilesByTitle = Convert-SetDictionaryToArrays $fileSets
    $fileSets = $null

    Set-LoadingStatus 'Indexing source-backed file hashes ...'
    $hashSets = New-OrdinalObjectDictionary
    $hashedFilenameSets = New-OrdinalObjectDictionary
    $t = Open-Tsv 'product-file-hashes-all-ever.tsv'
    try {
        $iTitle=Col $t 'product_title'
        $iFilename=Col $t 'filename'
        $iAlgorithm=Col $t 'algorithm'
        $iHash=Col $t 'hash'
        while (($line=$t.Reader.ReadLine()) -ne $null) {
            $parts=[string[]]$line.Split([char]9)
            if ($iTitle-ge$parts.Count -or $iFilename-ge$parts.Count -or $iAlgorithm-ge$parts.Count -or $iHash-ge$parts.Count) { continue }
            $title=[string]$parts[$iTitle]
            $filename=[string]$parts[$iFilename]
            $algorithm=[string]$parts[$iAlgorithm]
            $hash=[string]$parts[$iHash]
            if (-not $title -or -not $filename -or -not $hash) { continue }
            [void](Ensure-Product $title)
            $set=Get-OrCreateSet $hashSets $title
            [void]$set.Add($filename+$US+$algorithm+$US+$hash)
            $fnSet=Get-OrCreateSet $hashedFilenameSets $title
            [void]$fnSet.Add($filename)
        }
    } finally { $t.Reader.Dispose() }
    $script:HashesByTitle = Convert-SetDictionaryToArrays $hashSets
    $hashSets = $null

    Set-LoadingStatus 'Finding product files without a recorded product-section hash ...'
    $script:NoHashFilesByTitle = New-OrdinalObjectDictionary
    foreach ($title in $script:FilesByTitle.Keys) {
        $missing = New-StringList
        $hashed = if($hashedFilenameSets.ContainsKey($title)){$hashedFilenameSets[$title]}else{$null}
        foreach ($filename in [string[]]$script:FilesByTitle[$title]) {
            if ($null-eq$hashed -or -not $hashed.Contains($filename)) { [void]$missing.Add($filename) }
        }
        if ($missing.Count -gt 0) { $script:NoHashFilesByTitle[$title] = [string[]]$missing.ToArray() }
    }
    $hashedFilenameSets = $null

    Set-LoadingStatus 'Indexing normalized historical notes ...'
    $noteSets = New-OrdinalObjectDictionary
    $t = Open-Tsv 'product-notes-all-ever.tsv'
    try {
        $iTitle=Col $t 'product_title'
        $iText=Col $t 'note_text'
        $iRaw=Col $t 'raw_html_sha256'
        $iFirst=Col $t 'first_seen'
        $iLast=Col $t 'last_seen'
        while (($line=$t.Reader.ReadLine()) -ne $null) {
            $parts=[string[]]$line.Split([char]9)
            if ($iTitle-ge$parts.Count -or $iText-ge$parts.Count) { continue }
            $title=[string]$parts[$iTitle]
            $text=[string]$parts[$iText]
            if (-not $title -or -not $text) { continue }
            [void](Ensure-Product $title)
            $raw=if($iRaw-lt$parts.Count){[string]$parts[$iRaw]}else{''}
            $first=if($iFirst-lt$parts.Count){[string]$parts[$iFirst]}else{''}
            $last=if($iLast-lt$parts.Count){[string]$parts[$iLast]}else{''}
            $set=Get-OrCreateSet $noteSets $title
            [void]$set.Add($text+$US+$raw+$US+$first+$US+$last)
        }
    } finally { $t.Reader.Dispose() }
    $script:NotesByTitle = Convert-SetDictionaryToArrays $noteSets
    $noteSets = $null

    Set-LoadingStatus 'Finalizing in-memory indexes ...'
    $script:ProductArray = @($script:ProductList | Sort-Object -Property Title)
    $script:ProductList = $null
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()

    $script:Selected = @{
        broad=(New-OrdinalStringSet)
        family=(New-OrdinalStringSet)
        release=(New-OrdinalStringSet)
        title=(New-OrdinalStringSet)
        language=(New-OrdinalStringSet)
    }
    $script:HierarchyKinds = @('broad','family','release','title','language')
    $script:ColumnControls = @{}
    $script:SuppressEvents = $false
    $script:MatchedProducts = @()
    $script:ProductPage = 0
    $script:FilePage = 0
    $script:PageSize = 300
    $script:ProductDetailFilter = ''
    $script:FileDetailFilter = ''
    $script:NoteDetailFilter = ''

    function Product-Matches {
        param([object]$P,[string]$UpTo)
        if ($script:Selected.broad.Count -gt 0 -and -not $script:Selected.broad.Contains([string]$P.Broad)) { return $false }
        if ($UpTo -eq 'broad') { return $true }
        if ($script:Selected.family.Count -gt 0 -and -not $script:Selected.family.Contains([string]$P.Family)) { return $false }
        if ($UpTo -eq 'family') { return $true }
        if ($script:Selected.release.Count -gt 0 -and -not $script:Selected.release.Contains([string]$P.ReleaseDisplay)) { return $false }
        if ($UpTo -eq 'release') { return $true }
        if ($script:Selected.title.Count -gt 0 -and -not $script:Selected.title.Contains([string]$P.Title)) { return $false }
        if ($UpTo -eq 'title') { return $true }
        if ($script:Selected.language.Count -gt 0 -and -not $script:Selected.language.Contains([string]$P.LanguageDisplay)) { return $false }
        return $true
    }
    function Get-AvailableMap {
        param([string]$Kind)
        $map=New-OrdinalIntDictionary
        foreach($p in $script:ProductArray) {
            $v=$null
            if($Kind-eq'broad') {
                $v=[string]$p.Broad
            } elseif($Kind-eq'family') {
                if(-not(Product-Matches $p 'broad')){continue}
                $v=[string]$p.Family
            } elseif($Kind-eq'release') {
                if(-not(Product-Matches $p 'family')){continue}
                $v=[string]$p.ReleaseDisplay
            } elseif($Kind-eq'title') {
                if(-not(Product-Matches $p 'release')){continue}
                $v=[string]$p.Title
            } elseif($Kind-eq'language') {
                if(-not(Product-Matches $p 'title')){continue}
                $v=[string]$p.LanguageDisplay
            } else {
                throw ('Unknown hierarchy column: '+$Kind)
            }
            if($map.ContainsKey($v)){$map[$v]=[int]$map[$v]+1}else{$map[$v]=1}
        }
        return ,$map
    }
    function Prune-Selection {
        param([string]$Kind,[object]$Allowed)
        $set=$script:Selected[$Kind]
        foreach($v in @($set)) {
            if(-not$Allowed.ContainsKey([string]$v)){[void]$set.Remove([string]$v)}
        }
    }
    function Get-MatchedProducts {
        $list=New-Object 'System.Collections.Generic.List[object]'
        foreach($p in $script:ProductArray) {
            if(Product-Matches $p 'all'){[void]$list.Add($p)}
        }
        return ,($list.ToArray())
    }
    function New-HierarchyControls {
        param([string]$Title,[string]$Placeholder)
        $group=New-Object Windows.Forms.GroupBox
        $group.Text=$Title
        $group.Dock=[Windows.Forms.DockStyle]::Fill
        $group.Padding=New-Object Windows.Forms.Padding(8)

        $layout=New-Object Windows.Forms.TableLayoutPanel
        $layout.Dock=[Windows.Forms.DockStyle]::Fill
        $layout.ColumnCount=1
        $layout.RowCount=4
        [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,28)))
        [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,30)))
        [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,34)))
        [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)))

        $filter=New-Object Windows.Forms.TextBox
        $filter.Dock=[Windows.Forms.DockStyle]::Fill
        $filter.Tag=$Placeholder

        $sortControls=New-Object Windows.Forms.FlowLayoutPanel
        $sortControls.Dock=[Windows.Forms.DockStyle]::Fill
        $sortControls.FlowDirection=[Windows.Forms.FlowDirection]::LeftToRight
        $sortControls.WrapContents=$false
        $sortLabel=New-Object Windows.Forms.Label
        $sortLabel.Text='Order:'
        $sortLabel.AutoSize=$true
        $sortLabel.Margin=New-Object Windows.Forms.Padding(0,6,2,0)
        $sortBox=New-Object Windows.Forms.ComboBox
        $sortBox.DropDownStyle=[Windows.Forms.ComboBoxStyle]::DropDownList
        $sortBox.Width=82
        [void]$sortBox.Items.Add('A-Z')
        [void]$sortBox.Items.Add('Item count')
        $sortBox.SelectedIndex=0
        $reverseBox=New-Object Windows.Forms.CheckBox
        $reverseBox.Text='Reverse'
        $reverseBox.AutoSize=$true
        $reverseBox.Margin=New-Object Windows.Forms.Padding(5,5,0,0)
        [void]$sortControls.Controls.Add($sortLabel)
        [void]$sortControls.Controls.Add($sortBox)
        [void]$sortControls.Controls.Add($reverseBox)

        $buttons=New-Object Windows.Forms.FlowLayoutPanel
        $buttons.Dock=[Windows.Forms.DockStyle]::Fill
        $buttons.FlowDirection=[Windows.Forms.FlowDirection]::LeftToRight
        $buttons.WrapContents=$false
        $buttons.Margin=New-Object Windows.Forms.Padding(0)
        $selectButton=New-Object Windows.Forms.Button
        $selectButton.Text='Select all'
        $selectButton.AutoSize=$true
        $clearButton=New-Object Windows.Forms.Button
        $clearButton.Text='Clear'
        $clearButton.AutoSize=$true
        $copyButton=New-Object Windows.Forms.Button
        $copyButton.Text='Copy list'
        $copyButton.AutoSize=$true
        [void]$buttons.Controls.Add($selectButton)
        [void]$buttons.Controls.Add($clearButton)
        [void]$buttons.Controls.Add($copyButton)

        $list=New-Object Windows.Forms.CheckedListBox
        $list.Dock=[Windows.Forms.DockStyle]::Fill
        $list.CheckOnClick=$true
        $list.IntegralHeight=$false
        $list.DisplayMember='Display'
        $list.HorizontalScrollbar=$true

        [void]$layout.Controls.Add($filter,0,0)
        [void]$layout.Controls.Add($sortControls,0,1)
        [void]$layout.Controls.Add($buttons,0,2)
        [void]$layout.Controls.Add($list,0,3)
        [void]$group.Controls.Add($layout)
        return [pscustomobject]@{
            Group=$group
            BaseTitle=$Title
            Filter=$filter
            List=$list
            SortBox=$sortBox
            ReverseBox=$reverseBox
            SelectButton=$selectButton
            ClearButton=$clearButton
            CopyButton=$copyButton
        }
    }
    function Get-OrderedHierarchyRows {
        param([string]$Kind,[object]$Available,[string]$Query)
        $ctrl=$script:ColumnControls[$Kind]
        $rows=New-Object 'System.Collections.Generic.List[object]'
        foreach($key in $Available.Keys){
            $v=[string]$key
            if(-not(Contains-Text $v $Query)){continue}
            [void]$rows.Add([pscustomobject]@{Value=$v;Count=[int]$Available[$v]})
        }
        $reverse=[bool]$ctrl.ReverseBox.Checked
        if($ctrl.SortBox.SelectedIndex-eq 1){
            # Count order is most-useful-first by default. Reverse means least-first.
            $countDescending=-not$reverse
            return @($rows | Sort-Object @{Expression={$_.Count};Descending=$countDescending},@{Expression={$_.Value};Descending=$reverse})
        }
        [string[]]$names=@($rows | ForEach-Object {[string]$_.Value})
        [Array]::Sort($names,[StringComparer]::OrdinalIgnoreCase)
        if($reverse){[Array]::Reverse($names)}
        $ordered=New-Object 'System.Collections.Generic.List[object]'
        foreach($name in $names){
            [void]$ordered.Add([pscustomobject]@{Value=$name;Count=[int]$Available[$name]})
        }
        return ,($ordered.ToArray())
    }
    function Render-Column {
        param([string]$Kind)
        $ctrl=$script:ColumnControls[$Kind]
        if($null-eq$ctrl){return}
        $available=Get-AvailableMap $Kind
        $query=[string]$ctrl.Filter.Text
        $rows=@(Get-OrderedHierarchyRows $Kind $available $query)
        $visible=$rows.Count
        $script:SuppressEvents=$true
        try {
            $ctrl.List.BeginUpdate()
            $ctrl.List.Items.Clear()
            foreach($row in $rows) {
                $v=[string]$row.Value
                $count=[int]$row.Count
                $display=$v+'    ['+$count+']'
                $item=[pscustomobject]@{Value=$v;Display=$display;Count=$count}
                [void]$ctrl.List.Items.Add($item,$script:Selected[$Kind].Contains($v))
            }
            $ctrl.Group.Text=$ctrl.BaseTitle+'  ('+$visible+'/'+$available.Count+')'
        } finally {
            $ctrl.List.EndUpdate()
            $script:SuppressEvents=$false
        }
    }
    function Refresh-Hierarchy {
        $b=Get-AvailableMap 'broad'
        Prune-Selection 'broad' $b
        $g=Get-AvailableMap 'family'
        Prune-Selection 'family' $g
        $r=Get-AvailableMap 'release'
        Prune-Selection 'release' $r
        $tt=Get-AvailableMap 'title'
        Prune-Selection 'title' $tt
        $ll=Get-AvailableMap 'language'
        Prune-Selection 'language' $ll
        foreach($kind in $script:HierarchyKinds){Render-Column $kind}
        $script:MatchedProducts=@(Get-MatchedProducts)
        $script:ProductPage=0
        $script:FilePage=0
        Refresh-Details
    }
    function Handle-ItemCheck {
        param([string]$Kind,[object]$Sender,[object]$Event)
        if($script:SuppressEvents){return}
        if($Event.Index-lt 0 -or $Event.Index-ge$Sender.Items.Count){return}
        $item=$Sender.Items[$Event.Index]
        $value=[string]$item.Value
        if($Event.NewValue-eq[Windows.Forms.CheckState]::Checked){
            [void]$script:Selected[$Kind].Add($value)
        } else {
            [void]$script:Selected[$Kind].Remove($value)
        }
        $script:HierarchyTimer.Stop()
        $script:HierarchyTimer.Start()
    }
    function Select-All {
        param([string]$Kind)
        $available=Get-AvailableMap $Kind
        foreach($value in $available.Keys){[void]$script:Selected[$Kind].Add([string]$value)}
        Refresh-Hierarchy
    }
    function Copy-HierarchyList {
        param([string]$Kind)
        $ctrl=$script:ColumnControls[$Kind]
        $values=New-Object 'System.Collections.Generic.List[string]'
        foreach($item in $ctrl.List.Items){[void]$values.Add([string]$item.Value)}
        if($values.Count-eq 0){return}
        [Windows.Forms.Clipboard]::SetText([string]::Join([Environment]::NewLine,$values.ToArray()))
        $script:StatusMatched.Text=('{0:N0} {1} list entr{2} copied to clipboard' -f $values.Count,$Kind,$(if($values.Count-eq1){'y'}else{'ies'}))
    }
    function Clear-Column {
        param([string]$Kind)
        $start=[Array]::IndexOf([string[]]$script:HierarchyKinds,$Kind)
        if($start-lt0){return}
        # A hierarchy clear is a cascade reset: stale selections to the right
        # would otherwise continue to constrain the result and make the next
        # column appear not to refresh.
        for($i=$start;$i-lt$script:HierarchyKinds.Count;$i++){
            $script:Selected[[string]$script:HierarchyKinds[$i]].Clear()
        }
        Refresh-Hierarchy
    }
    function Join-Set {
        param([object]$Set)
        if($null-eq$Set -or $Set.Count-eq 0){return ''}
        return [string]::Join(', ',(Sort-Strings $Set))
    }
    function Get-DateDisplay {
        param([object]$Product)
        $set=New-OrdinalStringSet
        foreach($raw in $Product.Dates){
            $pos=$raw.IndexOf([char]31)
            $date=if($pos-ge 0){$raw.Substring(0,$pos)}else{$raw}
            if($date){[void]$set.Add($date)}
        }
        return Join-Set $set
    }
    function New-ReadOnlyGrid {
        $grid=New-Object Windows.Forms.DataGridView
        $grid.Dock=[Windows.Forms.DockStyle]::Fill
        $grid.ReadOnly=$true
        $grid.AllowUserToAddRows=$false
        $grid.AllowUserToDeleteRows=$false
        $grid.AllowUserToOrderColumns=$true
        $grid.RowHeadersVisible=$false
        $grid.SelectionMode=[Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
        $grid.MultiSelect=$true
        $grid.AutoSizeColumnsMode=[Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
        $grid.ClipboardCopyMode=[Windows.Forms.DataGridViewClipboardCopyMode]::EnableAlwaysIncludeHeaderText
        return ,$grid
    }
    function Add-GridColumns {
        param([object]$Grid,[string[]]$Names)
        foreach($name in $Names){[void]$Grid.Columns.Add($name,$name)}
    }
    function Set-Metric {
        param([string]$Key,[string]$Caption,[object]$Value)
        $script:MetricLabels[$Key].Text=$Caption+[Environment]::NewLine+[string]$Value
    }
    function Refresh-Metrics {
        $fileCount=0L
        $hashCount=0L
        $noteTexts=New-OrdinalStringSet
        $ids=New-OrdinalStringSet
        $dates=New-OrdinalStringSet
        foreach($p in $script:MatchedProducts){
            if($script:FilesByTitle.ContainsKey($p.Title)){$fileCount += [long]([string[]]$script:FilesByTitle[$p.Title]).Count}
            if($script:HashesByTitle.ContainsKey($p.Title)){$hashCount += [long]([string[]]$script:HashesByTitle[$p.Title]).Count}
            if($script:NotesByTitle.ContainsKey($p.Title)){
                foreach($raw in [string[]]$script:NotesByTitle[$p.Title]){
                    $pos=$raw.IndexOf([char]31)
                    $text=if($pos-ge 0){$raw.Substring(0,$pos)}else{$raw}
                    if($text){[void]$noteTexts.Add($text)}
                }
            }
            foreach($id in $p.Ids){[void]$ids.Add([string]$id)}
            foreach($rawDate in $p.Dates){
                $pos=$rawDate.IndexOf([char]31)
                $date=if($pos-ge 0){$rawDate.Substring(0,$pos)}else{$rawDate}
                if($date){[void]$dates.Add($date)}
            }
        }
        Set-Metric 'products' 'Products' ('{0:N0}' -f $script:MatchedProducts.Count)
        Set-Metric 'files' 'Files' ('{0:N0}' -f $fileCount)
        Set-Metric 'hashes' 'Hashes' ('{0:N0}' -f $hashCount)
        Set-Metric 'notes' 'Notes' ('{0:N0}' -f $noteTexts.Count)
        Set-Metric 'idsdates' 'Distinct IDs / dates' (('{0:N0} / {1:N0}' -f $ids.Count,$dates.Count))
        $script:StatusMatched.Text=('{0:N0} exact product title(s) matched' -f $script:MatchedProducts.Count)
    }
    function Escape-ClipboardCell {
        param([AllowNull()][AllowEmptyString()][string]$Value)
        if($null-eq$Value){return ''}
        return $Value.Replace("`t",' ').Replace("`r",' ').Replace("`n",' ')
    }
    function New-ResultRow {
        param([string[]]$Cells,[AllowNull()][object]$Tag)
        return [pscustomobject]@{Cells=$Cells;Tag=$Tag}
    }
    function Get-ProductResultRows {
        $rows=New-Object 'System.Collections.Generic.List[object]'
        $q=$script:ProductDetailFilter
        foreach($p in $script:MatchedProducts){
            if(-not((Contains-Text $p.Title $q)-or(Contains-Text $p.Family $q)-or(Contains-Text $p.ReleaseDisplay $q)-or(Contains-Text $p.LanguageDisplay $q))){continue}
            $class=if($p.Confidence){$p.Confidence}else{$p.Status}
            [void]$rows.Add((New-ResultRow ([string[]]@(
                [string]$p.Title,
                [string]$p.Family,
                [string]$p.ReleaseDisplay,
                [string]$p.LanguageDisplay,
                ([string]$p.First+' -> '+[string]$p.Last),
                (Join-Set $p.Ids),
                (Get-DateDisplay $p),
                [string]$class
            )) $p))
        }
        return ,($rows.ToArray())
    }
    function Get-FileResultRows {
        $rows=New-Object 'System.Collections.Generic.List[object]'
        $q=$script:FileDetailFilter
        foreach($p in $script:MatchedProducts){
            $title=[string]$p.Title
            if($script:HashesByTitle.ContainsKey($title)){
                foreach($raw in [string[]]$script:HashesByTitle[$title]){
                    if($q -and -not(Contains-Text $title $q) -and -not(Contains-Text $raw $q)){continue}
                    $parts=[string[]]$raw.Split([char]31)
                    $fn=if($parts.Count-gt 0){$parts[0]}else{''}
                    $alg=if($parts.Count-gt 1){$parts[1]}else{''}
                    $hash=if($parts.Count-gt 2){$parts[2]}else{''}
                    [void]$rows.Add((New-ResultRow ([string[]]@($title,$fn,$alg,$hash)) $null))
                }
            }
            if($script:NoHashFilesByTitle.ContainsKey($title)){
                foreach($fn in [string[]]$script:NoHashFilesByTitle[$title]){
                    if($q -and -not(Contains-Text $title $q) -and -not(Contains-Text $fn $q)){continue}
                    [void]$rows.Add((New-ResultRow ([string[]]@($title,[string]$fn,'','(no product-section hash recorded)')) $null))
                }
            }
        }
        return ,($rows.ToArray())
    }
    function Get-NoteResultRows {
        $map=New-OrdinalObjectDictionary
        $q=$script:NoteDetailFilter
        foreach($p in $script:MatchedProducts){
            $title=[string]$p.Title
            if(-not$script:NotesByTitle.ContainsKey($title)){continue}
            foreach($raw in [string[]]$script:NotesByTitle[$title]){
                $parts=[string[]]$raw.Split([char]31)
                $text=if($parts.Count-gt 0){$parts[0]}else{''}
                if($q -and -not(Contains-Text $text $q) -and -not(Contains-Text $title $q)){continue}
                $hash=if($parts.Count-gt 1){$parts[1]}else{''}
                $first=if($parts.Count-gt 2){$parts[2]}else{''}
                $last=if($parts.Count-gt 3){$parts[3]}else{''}
                if(-not$map.ContainsKey($text)){
                    $map[$text]=[pscustomobject]@{
                        Text=$text
                        Titles=(New-OrdinalStringSet)
                        Hashes=(New-OrdinalStringSet)
                        First=$first
                        Last=$last
                    }
                }
                $x=$map[$text]
                [void]$x.Titles.Add($title)
                if($hash){[void]$x.Hashes.Add($hash)}
                if($first -and ((-not$x.First)-or[StringComparer]::Ordinal.Compare($first,[string]$x.First)-lt 0)){$x.First=$first}
                if($last -and ((-not$x.Last)-or[StringComparer]::Ordinal.Compare($last,[string]$x.Last)-gt 0)){$x.Last=$last}
            }
        }
        $rows=New-Object 'System.Collections.Generic.List[object]'
        foreach($x in @($map.Values | Sort-Object -Property Text)){
            $hashDisplay=if($x.Hashes.Count){([string]::Join(', ',(Sort-Strings $x.Hashes)))}else{''}
            [void]$rows.Add((New-ResultRow ([string[]]@(
                [string]$x.Text,
                [string]('{0:N0}' -f $x.Titles.Count),
                ([string]$x.First+' -> '+[string]$x.Last),
                $hashDisplay
            )) $x))
        }
        return ,($rows.ToArray())
    }
    function Get-ResultRows {
        param([string]$Kind)
        switch($Kind){
            'product' { return ,(Get-ProductResultRows) }
            'file' { return ,(Get-FileResultRows) }
            'note' { return ,(Get-NoteResultRows) }
            default { throw ('Unknown result table: '+$Kind) }
        }
    }
    function Copy-ResultData {
        param([string]$Kind,[int]$ColumnIndex)
        $rows=@(Get-ResultRows $Kind)
        $headers=[string[]]$script:ResultHeaders[$Kind]
        if($ColumnIndex-ge$headers.Count){return}
        $sb=New-Object Text.StringBuilder
        if($ColumnIndex-lt0){
            [void]$sb.AppendLine(([string]::Join([char]9,$headers)))
            foreach($row in $rows){
                $cells=[string[]]$row.Cells
                $clean=New-Object 'System.Collections.Generic.List[string]'
                foreach($cell in $cells){[void]$clean.Add((Escape-ClipboardCell $cell))}
                [void]$sb.AppendLine(([string]::Join([char]9,$clean.ToArray())))
            }
        } else {
            foreach($row in $rows){
                $cells=[string[]]$row.Cells
                $value=if($ColumnIndex-lt$cells.Count){[string]$cells[$ColumnIndex]}else{''}
                [void]$sb.AppendLine((Escape-ClipboardCell $value))
            }
        }
        if($sb.Length-eq0){return}
        [Windows.Forms.Clipboard]::SetText($sb.ToString())
        $what=if($ColumnIndex-lt0){'complete table'}else{'"'+$headers[$ColumnIndex]+'" column'}
        $script:StatusMatched.Text=('{0:N0} row(s) copied from {1} {2}' -f $rows.Count,$Kind,$what)
    }
    function New-CopyMenuButton {
        param([string]$Kind,[string[]]$Headers)
        $button=New-Object Windows.Forms.Button
        $button.Text='Copy...'
        $button.AutoSize=$true
        $menu=New-Object Windows.Forms.ContextMenuStrip
        $all=$menu.Items.Add('Copy complete table - all pages')
        $all.Tag=[pscustomobject]@{Kind=$Kind;Column=-1}
        $all.Add_Click({param($sender,$e) Copy-ResultData ([string]$sender.Tag.Kind) ([int]$sender.Tag.Column)})
        [void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
        for($i=0;$i-lt$Headers.Count;$i++){
            $item=$menu.Items.Add('Copy column: '+$Headers[$i])
            $item.Tag=[pscustomobject]@{Kind=$Kind;Column=$i}
            $item.Add_Click({param($sender,$e) Copy-ResultData ([string]$sender.Tag.Kind) ([int]$sender.Tag.Column)})
        }
        $button.Tag=$menu
        $button.Add_Click({
            param($sender,$e)
            $m=[Windows.Forms.ContextMenuStrip]$sender.Tag
            $m.Show($sender,0,$sender.Height)
        })
        return ,$button
    }

    function Refresh-ProductGrid {
        $grid=$script:UI.ProductGrid
        $grid.SuspendLayout()
        try {
            $grid.Rows.Clear()
            $rows=@(Get-ProductResultRows)
            $total=$rows.Count
            $pages=[Math]::Max(1,[int][Math]::Ceiling($total/[double]$script:PageSize))
            if($script:ProductPage-ge$pages){$script:ProductPage=$pages-1}
            if($script:ProductPage-lt0){$script:ProductPage=0}
            $start=$script:ProductPage*$script:PageSize
            $end=[Math]::Min($total,$start+$script:PageSize)
            for($i=$start;$i-lt$end;$i++){
                $row=$rows[$i]
                $ri=$grid.Rows.Add([object[]]$row.Cells)
                $grid.Rows[$ri].Tag=$row.Tag
            }
            $script:UI.ProductPageLabel.Text=('Page {0} of {1}  -  {2:N0} rows' -f ($script:ProductPage+1),$pages,$total)
            $script:UI.ProductPrev.Enabled=$script:ProductPage-gt0
            $script:UI.ProductNext.Enabled=$script:ProductPage-lt($pages-1)
        } finally {$grid.ResumeLayout()}
    }
    function Refresh-FileGrid {
        $grid=$script:UI.FileGrid
        $grid.SuspendLayout()
        try {
            $grid.Rows.Clear()
            $rows=@(Get-FileResultRows)
            $total=$rows.Count
            $pages=[Math]::Max(1,[int][Math]::Ceiling($total/[double]$script:PageSize))
            if($script:FilePage-ge$pages){$script:FilePage=$pages-1}
            if($script:FilePage-lt0){$script:FilePage=0}
            $start=$script:FilePage*$script:PageSize
            $end=[Math]::Min($total,$start+$script:PageSize)
            for($i=$start;$i-lt$end;$i++){
                [void]$grid.Rows.Add([object[]]$rows[$i].Cells)
            }
            $script:UI.FilePageLabel.Text=('Page {0} of {1}  -  {2:N0} rows' -f ($script:FilePage+1),$pages,$total)
            $script:UI.FilePrev.Enabled=$script:FilePage-gt0
            $script:UI.FileNext.Enabled=$script:FilePage-lt($pages-1)
        } finally {$grid.ResumeLayout()}
    }
    function Refresh-Notes {
        $grid=$script:UI.NoteGrid
        $grid.SuspendLayout()
        try {
            $grid.Rows.Clear()
            $rows=@(Get-NoteResultRows)
            $show=[Math]::Min(300,$rows.Count)
            for($i=0;$i-lt$show;$i++){
                $row=$rows[$i]
                $ri=$grid.Rows.Add([object[]]$row.Cells)
                $grid.Rows[$ri].Tag=$row.Tag
            }
            $suffix=if($rows.Count-gt300){' (showing first 300; Copy can export all rows)'}else{''}
            $script:UI.NoteCountLabel.Text=('{0:N0} distinct applicable notes{1}' -f $rows.Count,$suffix)
            if($grid.Rows.Count-gt0){$grid.Rows[0].Selected=$true;Update-NoteDetail}else{$script:UI.NoteDetail.Text='No applicable notes.'}
        } finally {$grid.ResumeLayout()}
    }
    function Update-NoteDetail {
        $grid=$script:UI.NoteGrid
        if($grid.SelectedRows.Count-eq 0){return}
        $x=$grid.SelectedRows[0].Tag
        if($null-eq$x){return}
        $titles=Sort-Strings $x.Titles
        $hashes=Sort-Strings $x.Hashes
        $text=@()
        $text += [string]$x.Text
        $text += ''
        $text += ('Observed: '+[string]$x.First+' -> '+[string]$x.Last)
        $text += ('Applies to '+$x.Titles.Count+' matched title(s):')
        $text += [string]::Join([Environment]::NewLine,$titles)
        $text += ''
        $text += 'Raw HTML evidence SHA-256:'
        $text += if($hashes.Count){[string]::Join([Environment]::NewLine,$hashes)}else{'(none recorded)'}
        $script:UI.NoteDetail.Text=[string]::Join([Environment]::NewLine,$text)
    }
    function Selected-Label {
        param([string]$Kind)
        $set=$script:Selected[$Kind]
        if($set.Count-eq 0){return 'All'}
        $vals=Sort-Strings $set
        if($vals.Count-le 8){return [string]::Join(', ',$vals)}
        return ([string]::Join(', ',$vals[0..7])+' +'+($vals.Count-8)+' more')
    }
    function Refresh-SelectionText {
        $lines=@(
            'ACTIVE HIERARCHY',
            '',
            ('Basic families: '+(Selected-Label 'broad')),
            ('Products: '+(Selected-Label 'family')),
            ('Releases: '+(Selected-Label 'release')),
            ('Variants / exact titles: '+(Selected-Label 'title')),
            ('Languages: '+(Selected-Label 'language')),
            '',
            ('Matched exact product titles: '+$script:MatchedProducts.Count),
            '',
            'SEMANTICS',
            '',
            'Empty selection in a hierarchy column means all values still available from the columns to its left.',
            'Language is populated only when the source title explicitly states a recognized trailing language label; otherwise it is shown as language not specified.',
            'Typing in a hierarchy filter changes list visibility only; it does not silently select evidence.',
            '',
            'Family/release membership comes from the analytical product-family classification.',
            'Files and hashes come only from actual mvs.txt product-section evidence represented in the compact family database.',
            'Notes remain title-level historical evidence.',
            'Standalone manifest filenames are not joined to products merely because the filename matches.',
            '',
            ('Database: '+$script:IndexRoot)
        )
        $script:UI.SelectionText.Text=[string]::Join([Environment]::NewLine,$lines)
    }
    function Refresh-ActiveTab {
        switch($script:UI.Tabs.SelectedIndex){
            0 { Refresh-ProductGrid }
            1 { Refresh-FileGrid }
            2 { Refresh-Notes }
            3 { Refresh-SelectionText }
        }
    }
    function Refresh-Details {
        Refresh-Metrics
        Refresh-ActiveTab
    }

    Set-LoadingStatus 'Creating PowerShell/WinForms interface ...'
    $form=New-Object Windows.Forms.Form
    $form.Text='MVS Explorer '+$Version
    $form.StartPosition=[Windows.Forms.FormStartPosition]::CenterScreen
    $form.WindowState=[Windows.Forms.FormWindowState]::Maximized
    $form.MinimumSize=New-Object Drawing.Size(1280,760)
    $form.AutoScaleMode=[Windows.Forms.AutoScaleMode]::Dpi
    $form.Font=New-Object Drawing.Font('Segoe UI',9)

    $header=New-Object Windows.Forms.Panel
    $header.Dock=[Windows.Forms.DockStyle]::Top
    $header.Height=58
    $header.Padding=New-Object Windows.Forms.Padding(8)

    $clearAll=New-Object Windows.Forms.Button
    $clearAll.Text='Clear all selections'
    $clearAll.AutoSize=$true
    $clearAll.Dock=[Windows.Forms.DockStyle]::Right
    $statusPanel=New-Object Windows.Forms.Panel
    $statusPanel.Dock=[Windows.Forms.DockStyle]::Fill
    $script:StatusMatched=New-Object Windows.Forms.Label
    $script:StatusMatched.Dock=[Windows.Forms.DockStyle]::Top
    $script:StatusMatched.Height=22
    $script:StatusMatched.Font=New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Bold)
    $dbLabel=New-Object Windows.Forms.Label
    $dbLabel.Dock=[Windows.Forms.DockStyle]::Top
    $dbLabel.Height=22
    $dbLabel.ForeColor=[Drawing.SystemColors]::GrayText
    $dbLabel.Text='Database: '+$script:IndexRoot
    [void]$statusPanel.Controls.Add($dbLabel)
    [void]$statusPanel.Controls.Add($script:StatusMatched)
    [void]$header.Controls.Add($statusPanel)
    [void]$header.Controls.Add($clearAll)

    $split=New-Object Windows.Forms.SplitContainer
    $split.Dock=[Windows.Forms.DockStyle]::Fill
    $split.Orientation=[Windows.Forms.Orientation]::Horizontal
    $split.SplitterDistance=390
    $split.Panel1MinSize=270
    $split.Panel2MinSize=260

    $hier=New-Object Windows.Forms.TableLayoutPanel
    $hier.Dock=[Windows.Forms.DockStyle]::Fill
    $hier.ColumnCount=5
    $hier.RowCount=1
    for($i=0;$i-lt 5;$i++){[void]$hier.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,20)))}

    $script:ColumnControls.broad=New-HierarchyControls '1. Basic families' 'Filter families'
    $script:ColumnControls.family=New-HierarchyControls '2. Products' 'Filter product families'
    $script:ColumnControls.release=New-HierarchyControls '3. Releases' 'Filter releases / years'
    $script:ColumnControls.title=New-HierarchyControls '4. Variants / exact titles' 'Filter exact product titles'
    $script:ColumnControls.language=New-HierarchyControls '5. Languages' 'Filter explicit languages'
    [void]$hier.Controls.Add($script:ColumnControls.broad.Group,0,0)
    [void]$hier.Controls.Add($script:ColumnControls.family.Group,1,0)
    [void]$hier.Controls.Add($script:ColumnControls.release.Group,2,0)
    [void]$hier.Controls.Add($script:ColumnControls.title.Group,3,0)
    [void]$hier.Controls.Add($script:ColumnControls.language.Group,4,0)
    [void]$split.Panel1.Controls.Add($hier)

    $detail=New-Object Windows.Forms.Panel
    $detail.Dock=[Windows.Forms.DockStyle]::Fill

    $metricLayout=New-Object Windows.Forms.TableLayoutPanel
    $metricLayout.Dock=[Windows.Forms.DockStyle]::Top
    $metricLayout.Height=52
    $metricLayout.ColumnCount=5
    $metricLayout.RowCount=1
    for($i=0;$i-lt 5;$i++){[void]$metricLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,20)))}
    $script:MetricLabels=@{}
    $metricKeys=@('products','files','hashes','notes','idsdates')
    for($i=0;$i-lt$metricKeys.Count;$i++){
        $lab=New-Object Windows.Forms.Label
        $lab.Dock=[Windows.Forms.DockStyle]::Fill
        $lab.TextAlign=[Drawing.ContentAlignment]::MiddleCenter
        $lab.BorderStyle=[Windows.Forms.BorderStyle]::FixedSingle
        $lab.Font=New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Bold)
        $script:MetricLabels[$metricKeys[$i]]=$lab
        [void]$metricLayout.Controls.Add($lab,$i,0)
    }

    $script:ResultHeaders=@{
        product=[string[]]@('Exact product title / variant','Product family','Release','Language','Observed','IDs','Dates','Classification')
        file=[string[]]@('Product title','Filename','Algorithm','Hash')
        note=[string[]]@('Note','Applies to titles','Observed','Raw HTML evidence SHA-256')
    }

    $tabs=New-Object Windows.Forms.TabControl
    $tabs.Dock=[Windows.Forms.DockStyle]::Fill

    $productTab=New-Object Windows.Forms.TabPage
    $productTab.Text='Products'
    $productToolbar=New-Object Windows.Forms.Panel
    $productToolbar.Dock=[Windows.Forms.DockStyle]::Top
    $productToolbar.Height=34
    $productFilter=New-Object Windows.Forms.TextBox
    $productFilter.Width=420
    $productFilter.Left=6
    $productFilter.Top=5
    $productFilter.Anchor=[Windows.Forms.AnchorStyles]::Left
    $productPrev=New-Object Windows.Forms.Button
    $productPrev.Text='Previous'
    $productPrev.AutoSize=$true
    $productPrev.Left=440
    $productPrev.Top=3
    $productNext=New-Object Windows.Forms.Button
    $productNext.Text='Next'
    $productNext.AutoSize=$true
    $productNext.Left=520
    $productNext.Top=3
    $productPageLabel=New-Object Windows.Forms.Label
    $productPageLabel.AutoSize=$true
    $productPageLabel.Left=595
    $productPageLabel.Top=9
    $productCopy=New-CopyMenuButton 'product' $script:ResultHeaders.product
    $productCopy.Left=850
    $productCopy.Top=3
    [void]$productToolbar.Controls.Add($productFilter)
    [void]$productToolbar.Controls.Add($productPrev)
    [void]$productToolbar.Controls.Add($productNext)
    [void]$productToolbar.Controls.Add($productPageLabel)
    [void]$productToolbar.Controls.Add($productCopy)
    $productGrid=New-ReadOnlyGrid
    Add-GridColumns $productGrid $script:ResultHeaders.product
    $productGrid.Columns[0].FillWeight=170
    $productGrid.Columns[1].FillWeight=120
    $productGrid.Columns[2].FillWeight=70
    $productGrid.Columns[3].FillWeight=80
    $productGrid.Columns[4].FillWeight=90
    $productGrid.Columns[5].FillWeight=70
    $productGrid.Columns[6].FillWeight=110
    $productGrid.Columns[7].FillWeight=70
    [void]$productTab.Controls.Add($productGrid)
    [void]$productTab.Controls.Add($productToolbar)

    $fileTab=New-Object Windows.Forms.TabPage
    $fileTab.Text='Files & hashes'
    $fileToolbar=New-Object Windows.Forms.Panel
    $fileToolbar.Dock=[Windows.Forms.DockStyle]::Top
    $fileToolbar.Height=34
    $fileFilter=New-Object Windows.Forms.TextBox
    $fileFilter.Width=420
    $fileFilter.Left=6
    $fileFilter.Top=5
    $filePrev=New-Object Windows.Forms.Button
    $filePrev.Text='Previous'
    $filePrev.AutoSize=$true
    $filePrev.Left=440
    $filePrev.Top=3
    $fileNext=New-Object Windows.Forms.Button
    $fileNext.Text='Next'
    $fileNext.AutoSize=$true
    $fileNext.Left=520
    $fileNext.Top=3
    $filePageLabel=New-Object Windows.Forms.Label
    $filePageLabel.AutoSize=$true
    $filePageLabel.Left=595
    $filePageLabel.Top=9
    $fileCopy=New-CopyMenuButton 'file' $script:ResultHeaders.file
    $fileCopy.Left=850
    $fileCopy.Top=3
    [void]$fileToolbar.Controls.Add($fileFilter)
    [void]$fileToolbar.Controls.Add($filePrev)
    [void]$fileToolbar.Controls.Add($fileNext)
    [void]$fileToolbar.Controls.Add($filePageLabel)
    [void]$fileToolbar.Controls.Add($fileCopy)
    $fileGrid=New-ReadOnlyGrid
    Add-GridColumns $fileGrid $script:ResultHeaders.file
    $fileGrid.Columns[0].FillWeight=120
    $fileGrid.Columns[1].FillWeight=160
    $fileGrid.Columns[2].FillWeight=45
    $fileGrid.Columns[3].FillWeight=190
    $fileGrid.DefaultCellStyle.Font=New-Object Drawing.Font('Consolas',8.5)
    [void]$fileTab.Controls.Add($fileGrid)
    [void]$fileTab.Controls.Add($fileToolbar)

    $noteTab=New-Object Windows.Forms.TabPage
    $noteTab.Text='Notes'
    $noteToolbar=New-Object Windows.Forms.Panel
    $noteToolbar.Dock=[Windows.Forms.DockStyle]::Top
    $noteToolbar.Height=34
    $noteFilter=New-Object Windows.Forms.TextBox
    $noteFilter.Width=420
    $noteFilter.Left=6
    $noteFilter.Top=5
    $noteCountLabel=New-Object Windows.Forms.Label
    $noteCountLabel.AutoSize=$true
    $noteCountLabel.Left=440
    $noteCountLabel.Top=9
    $noteCopy=New-CopyMenuButton 'note' $script:ResultHeaders.note
    $noteCopy.Left=850
    $noteCopy.Top=3
    [void]$noteToolbar.Controls.Add($noteFilter)
    [void]$noteToolbar.Controls.Add($noteCountLabel)
    [void]$noteToolbar.Controls.Add($noteCopy)
    $noteSplit=New-Object Windows.Forms.SplitContainer
    $noteSplit.Dock=[Windows.Forms.DockStyle]::Fill
    $noteSplit.Orientation=[Windows.Forms.Orientation]::Horizontal
    $noteSplit.SplitterDistance=220
    $noteGrid=New-ReadOnlyGrid
    Add-GridColumns $noteGrid $script:ResultHeaders.note
    $noteGrid.Columns[0].FillWeight=230
    $noteGrid.Columns[1].FillWeight=50
    $noteGrid.Columns[2].FillWeight=90
    $noteGrid.Columns[3].FillWeight=150
    $noteDetail=New-Object Windows.Forms.RichTextBox
    $noteDetail.Dock=[Windows.Forms.DockStyle]::Fill
    $noteDetail.ReadOnly=$true
    $noteDetail.WordWrap=$true
    $noteDetail.DetectUrls=$false
    $noteDetail.BackColor=[Drawing.SystemColors]::Window
    $noteDetail.ForeColor=[Drawing.SystemColors]::WindowText
    [void]$noteSplit.Panel1.Controls.Add($noteGrid)
    [void]$noteSplit.Panel2.Controls.Add($noteDetail)
    [void]$noteTab.Controls.Add($noteSplit)
    [void]$noteTab.Controls.Add($noteToolbar)

    $selectionTab=New-Object Windows.Forms.TabPage
    $selectionTab.Text='Selection'
    $selectionText=New-Object Windows.Forms.RichTextBox
    $selectionText.Dock=[Windows.Forms.DockStyle]::Fill
    $selectionText.ReadOnly=$true
    $selectionText.WordWrap=$true
    $selectionText.BackColor=[Drawing.SystemColors]::Window
    $selectionText.ForeColor=[Drawing.SystemColors]::WindowText
    [void]$selectionTab.Controls.Add($selectionText)

    [void]$tabs.TabPages.Add($productTab)
    [void]$tabs.TabPages.Add($fileTab)
    [void]$tabs.TabPages.Add($noteTab)
    [void]$tabs.TabPages.Add($selectionTab)

    [void]$detail.Controls.Add($tabs)
    [void]$detail.Controls.Add($metricLayout)
    [void]$split.Panel2.Controls.Add($detail)
    [void]$form.Controls.Add($split)
    [void]$form.Controls.Add($header)

    $script:UI=[pscustomobject]@{
        Tabs=$tabs
        ProductFilter=$productFilter
        ProductGrid=$productGrid
        ProductPrev=$productPrev
        ProductNext=$productNext
        ProductPageLabel=$productPageLabel
        FileFilter=$fileFilter
        FileGrid=$fileGrid
        FilePrev=$filePrev
        FileNext=$fileNext
        FilePageLabel=$filePageLabel
        NoteFilter=$noteFilter
        NoteGrid=$noteGrid
        NoteDetail=$noteDetail
        NoteCountLabel=$noteCountLabel
        SelectionText=$selectionText
    }

    $script:HierarchyTimer=New-Object Windows.Forms.Timer
    $script:HierarchyTimer.Interval=1
    $script:HierarchyTimer.Add_Tick({
        $script:HierarchyTimer.Stop()
        Refresh-Hierarchy
    })

    $script:FileFilterTimer=New-Object Windows.Forms.Timer
    $script:FileFilterTimer.Interval=250
    $script:FileFilterTimer.Add_Tick({
        $script:FileFilterTimer.Stop()
        $script:FileDetailFilter=[string]$script:UI.FileFilter.Text
        $script:FilePage=0
        if($script:UI.Tabs.SelectedIndex-eq 1){Refresh-FileGrid}
    })

    $script:NoteFilterTimer=New-Object Windows.Forms.Timer
    $script:NoteFilterTimer.Interval=180
    $script:NoteFilterTimer.Add_Tick({
        $script:NoteFilterTimer.Stop()
        $script:NoteDetailFilter=[string]$script:UI.NoteFilter.Text
        if($script:UI.Tabs.SelectedIndex-eq 2){Refresh-Notes}
    })

    foreach($kind in $script:HierarchyKinds){
        $ctrl=$script:ColumnControls[$kind]
        $ctrl.Filter.Tag=$kind
        $ctrl.SortBox.Tag=$kind
        $ctrl.ReverseBox.Tag=$kind
        $ctrl.SelectButton.Tag=$kind
        $ctrl.ClearButton.Tag=$kind
        $ctrl.CopyButton.Tag=$kind

        $ctrl.Filter.Add_TextChanged({param($sender,$e) Render-Column ([string]$sender.Tag)})
        $ctrl.SortBox.Add_SelectedIndexChanged({param($sender,$e) Render-Column ([string]$sender.Tag)})
        $ctrl.ReverseBox.Add_CheckedChanged({param($sender,$e) Render-Column ([string]$sender.Tag)})
        $ctrl.List.Tag=$kind
        $ctrl.List.Add_ItemCheck({param($sender,$e) Handle-ItemCheck ([string]$sender.Tag) $sender $e})
        $ctrl.SelectButton.Add_Click({param($sender,$e) Select-All ([string]$sender.Tag)})
        $ctrl.ClearButton.Add_Click({param($sender,$e) Clear-Column ([string]$sender.Tag)})
        $ctrl.CopyButton.Add_Click({param($sender,$e) Copy-HierarchyList ([string]$sender.Tag)})
    }

    $clearAll.Add_Click({
        foreach($kind in $script:HierarchyKinds){$script:Selected[$kind].Clear();$script:ColumnControls[$kind].Filter.Text=''}
        Refresh-Hierarchy
    })
    $tabs.Add_SelectedIndexChanged({Refresh-ActiveTab})
    $productFilter.Add_TextChanged({
        $script:ProductDetailFilter=[string]$script:UI.ProductFilter.Text
        $script:ProductPage=0
        if($script:UI.Tabs.SelectedIndex-eq 0){Refresh-ProductGrid}
    })
    $productPrev.Add_Click({if($script:ProductPage-gt 0){$script:ProductPage--;Refresh-ProductGrid}})
    $productNext.Add_Click({$script:ProductPage++;Refresh-ProductGrid})
    $fileFilter.Add_TextChanged({$script:FileFilterTimer.Stop();$script:FileFilterTimer.Start()})
    $filePrev.Add_Click({if($script:FilePage-gt 0){$script:FilePage--;Refresh-FileGrid}})
    $fileNext.Add_Click({$script:FilePage++;Refresh-FileGrid})
    $noteFilter.Add_TextChanged({$script:NoteFilterTimer.Stop();$script:NoteFilterTimer.Start()})
    $noteGrid.Add_SelectionChanged({Update-NoteDetail})

    Close-Loading
    Refresh-Hierarchy
    $started.Stop()
    $form.Text=('MVS Explorer '+$Version+' - '+$script:ProductArray.Count+' products')
    Write-Line ('Products loaded: '+$script:ProductArray.Count)
    Write-Line ('GUI ready in '+$started.Elapsed.TotalSeconds.ToString('0.00')+' seconds.')
    [void]$form.ShowDialog()
    $form.Dispose()
    [Environment]::Exit(0)
} catch {
    Close-Loading
    $message=$_.Exception.Message
    try {
        [void][Windows.Forms.MessageBox]::Show(
            $message,
            'MVS Explorer error',
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        )
    } catch {}
    Write-Err ('ERROR: '+$message)
    throw
}
