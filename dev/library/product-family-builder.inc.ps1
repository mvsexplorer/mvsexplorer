$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$ArchiveInput = [string]$env:mvsf_archive_root
$OutputInput = [string]$env:mvsf_output_root
$OverrideInput = [string]$env:mvsf_overrides
$Caller = [string]$env:mvsf_caller
$Version = [string]$env:mvsf_version

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
    Write-Line ('MVS Explorer Toolkit product-family index builder ' + $Version)
    Write-Line ('Usage: ' + $Caller + ' mvs-dumps-root output-folder [overrides.tsv]')
    Write-Line 'Builds an analytical product-family DAG and source-backed product fact index.'
    Write-Line 'Optional overrides are exact-title set/exclude decisions; source evidence is never rewritten.'
}

function Is-HelpToken {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    return @('--help','-h','-?','/h','/?') -contains $Value
}

function Convert-TsvField {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    return $Value.Replace("`t",' ').Replace("`r",' ').Replace("`n",' ')
}

function Normalize-Scalar {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    return ([regex]::Replace($Value.Trim(),'\s+',' '))
}

function Convert-HtmlToText {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return '' }
    $withoutTags = [regex]::Replace($Value,'(?is)<[^>]+>',' ')
    $decoded = [System.Net.WebUtility]::HtmlDecode($withoutTags)
    return Normalize-Scalar $decoded
}

function New-IgnoreCaseSet {
    return ,(New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase))
}

function New-OrdinalSet {
    return ,(New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal))
}

function New-IgnoreCaseDictionary {
    return ,(New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase))
}

function New-Utf8Writer {
    param([string]$Path,[string]$Header)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }
    $writer = New-Object System.IO.StreamWriter -ArgumentList @($Path,$false,$utf8,65536)
    $writer.WriteLine($Header)
    return $writer
}

function Get-Sha256String {
    param([AllowEmptyString()][string]$Text)
    $bytes = $utf8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
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

function Resolve-OutputPath {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    $path = $Name
    if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path (Get-Location).Path $path }
    return [IO.Path]::GetFullPath($path)
}

function Get-Snapshots {
    param([string]$Root)
    $items = New-Object System.Collections.ArrayList
    foreach ($dir in @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction Stop)) {
        if ($dir.Name -notmatch '^mvs_(?<date>\d{4}-\d{2}-\d{2})(?:-(?<time>\d{4}))?(?:_(?<revision>\d+))?$') { continue }
        $dateKey = $Matches.date.Replace('-','')
        $timeKey = if ([string]::IsNullOrWhiteSpace([string]$Matches.time)) { '0000' } else { [string]$Matches.time }
        $revision = 0
        if (-not [string]::IsNullOrWhiteSpace([string]$Matches.revision)) { $revision = [int]$Matches.revision }
        $sortKey = $dateKey + $timeKey + $revision.ToString('D8') + '|' + $dir.Name.ToLowerInvariant()
        [void]$items.Add([pscustomobject]@{ name=$dir.Name; path=$dir.FullName; sort_key=$sortKey })
    }
    return @($items | Sort-Object sort_key,name)
}

function Get-SnapshotSourcePath {
    param([object]$Snapshot,[string]$SourceFile)
    $direct = Join-Path ([string]$Snapshot.path) $SourceFile
    if (Test-Path -LiteralPath $direct -PathType Leaf) { return $direct }
    $nested = Join-Path (Join-Path ([string]$Snapshot.path) 'mvs_dmp') $SourceFile
    if (Test-Path -LiteralPath $nested -PathType Leaf) { return $nested }
    return $null
}

function Get-ReleaseToken {
    param([string]$Title)
    if ($Title -match '(?i)(?<!\d)((?:19|20)\d{2})(?!\d)') { return [string]$Matches[1] }
    if ($Title -match '(?i)(?<![\d.])(\d+\.\d+(?:\.\d+)?)(?![\d.])') { return [string]$Matches[1] }
    return ''
}

function New-Classification {
    param(
        [string]$Title,[string]$Broad,[string]$ProductFamily,[string]$Release,
        [string]$SpecificRelease,[string]$BroadRelease,[string]$Confidence,
        [string]$Basis,[string]$RuleId,[string]$Status='classified'
    )
    return [pscustomobject]@{
        product_title=$Title
        broad_family=$Broad
        product_family=$ProductFamily
        release=$Release
        specific_release_family=$SpecificRelease
        broad_release_family=$BroadRelease
        confidence=$Confidence
        basis=$Basis
        rule_id=$RuleId
        status=$Status
    }
}

$RuleRows = @(
    [pscustomobject]@{rule_id='OFFICE_OCS';priority='10';confidence='high';description='Microsoft/Office Communications Server prefix'},
    [pscustomobject]@{rule_id='OFFICE_PROOFING';priority='20';confidence='high';description='Office YEAR Proofing Tools prefix'},
    [pscustomobject]@{rule_id='OFFICE_SDK';priority='30';confidence='high';description='Microsoft Office System Developer Kit prefix'},
    [pscustomobject]@{rule_id='OFFICE_COMPONENT';priority='35';confidence='high';description='Curated Microsoft Office component/edition prefix'},
    [pscustomobject]@{rule_id='OFFICE_GENERIC';priority='40';confidence='high';description='Microsoft Office or Office YEAR prefix'},
    [pscustomobject]@{rule_id='CURATED_MICROSOFT';priority='50';confidence='high';description='Curated Microsoft product-family prefix'},
    [pscustomobject]@{rule_id='CURATED_ALIAS_PREFIX';priority='60';confidence='high';description='Curated leading alias mapped to canonical Microsoft broad/product family'},
    [pscustomobject]@{rule_id='GENERIC_MICROSOFT_REVIEW';priority='900';confidence='review';description='Generic Microsoft-leading title; review before canonical use'}
)

$CuratedPrefixes = @(
    'Microsoft SQL Server',
    'Microsoft Visual Studio',
    'Microsoft Exchange Server',
    'Microsoft Windows Server',
    'Microsoft System Center',
    'Microsoft Dynamics',
    'Microsoft BizTalk Server',
    'Microsoft SharePoint Server',
    'Microsoft SharePoint',
    'Microsoft Commerce Server',
    'Microsoft ISA Server',
    'Microsoft Forefront',
    'Microsoft Project',
    'Microsoft Visio',
    'Microsoft Windows'
)

$OfficeComponentPrefixes = @(
    'Microsoft Office Communications Server',
    'Microsoft Office Online Server',
    'Microsoft Office SharePoint Server',
    'Microsoft Office PerformancePoint Server',
    'Microsoft Office Forms Server',
    'Microsoft Office Project',
    'Microsoft Office Visio',
    'Microsoft Office Accounting',
    'Microsoft Office Communicator',
    'Microsoft Office Proofing Tools',
    'Microsoft Office Professional Plus',
    'Microsoft Office Professional',
    'Microsoft Office Standard',
    'Microsoft Office Enterprise',
    'Microsoft Office Ultimate',
    'Microsoft Office Home and Student',
    'Microsoft Office Home and Business',
    'Microsoft Office Small Business',
    'Microsoft Office Access',
    'Microsoft Office Excel',
    'Microsoft Office Word',
    'Microsoft Office Outlook',
    'Microsoft Office PowerPoint',
    'Microsoft Office Publisher',
    'Microsoft Office OneNote',
    'Microsoft Office Groove',
    'Microsoft Office InfoPath'
)

# These are structural aliases only: they must occur at the beginning of the
# normalized title and on a token boundary. They intentionally do not perform
# substring ownership inference.
$AliasPrefixRules = @(
    [pscustomobject]@{prefix='Microsoft Windows Small Business Server'; broad='Microsoft Windows'; family='Microsoft Windows Small Business Server'},
    [pscustomobject]@{prefix='Microsoft Windows Server'; broad='Microsoft Windows'; family='Microsoft Windows Server'},
    [pscustomobject]@{prefix='Microsoft Windows Embedded'; broad='Microsoft Windows'; family='Microsoft Windows Embedded'},
    [pscustomobject]@{prefix='Windows Small Business Server'; broad='Microsoft Windows'; family='Microsoft Windows Small Business Server'},
    [pscustomobject]@{prefix='Windows Server'; broad='Microsoft Windows'; family='Microsoft Windows Server'},
    [pscustomobject]@{prefix='Windows Embedded'; broad='Microsoft Windows'; family='Microsoft Windows Embedded'},

    [pscustomobject]@{prefix='Microsoft SharePoint Server'; broad='Microsoft SharePoint'; family='Microsoft SharePoint Server'},
    [pscustomobject]@{prefix='SharePoint Server'; broad='Microsoft SharePoint'; family='Microsoft SharePoint Server'},
    [pscustomobject]@{prefix='Microsoft BizTalk Server'; broad='Microsoft BizTalk'; family='Microsoft BizTalk Server'},
    [pscustomobject]@{prefix='Microsoft Exchange Server'; broad='Microsoft Exchange'; family='Microsoft Exchange Server'},
    [pscustomobject]@{prefix='Exchange Server'; broad='Microsoft Exchange'; family='Microsoft Exchange Server'},
    [pscustomobject]@{prefix='Microsoft Lync Server'; broad='Microsoft Lync'; family='Microsoft Lync Server'},
    [pscustomobject]@{prefix='Lync Server'; broad='Microsoft Lync'; family='Microsoft Lync Server'},

    [pscustomobject]@{prefix='Microsoft System Center Configuration Manager'; broad='Microsoft System Center'; family='Microsoft System Center Configuration Manager'},
    [pscustomobject]@{prefix='Microsoft System Center Operations Manager'; broad='Microsoft System Center'; family='Microsoft System Center Operations Manager'},
    [pscustomobject]@{prefix='Microsoft System Center Virtual Machine Manager'; broad='Microsoft System Center'; family='Microsoft System Center Virtual Machine Manager'},
    [pscustomobject]@{prefix='Microsoft System Center Data Protection Manager'; broad='Microsoft System Center'; family='Microsoft System Center Data Protection Manager'},
    [pscustomobject]@{prefix='Microsoft System Center Service Manager'; broad='Microsoft System Center'; family='Microsoft System Center Service Manager'},
    [pscustomobject]@{prefix='Microsoft System Center Orchestrator'; broad='Microsoft System Center'; family='Microsoft System Center Orchestrator'},
    [pscustomobject]@{prefix='System Center Configuration Manager'; broad='Microsoft System Center'; family='Microsoft System Center Configuration Manager'},
    [pscustomobject]@{prefix='System Center Operations Manager'; broad='Microsoft System Center'; family='Microsoft System Center Operations Manager'},
    [pscustomobject]@{prefix='System Center Virtual Machine Manager'; broad='Microsoft System Center'; family='Microsoft System Center Virtual Machine Manager'},
    [pscustomobject]@{prefix='System Center Data Protection Manager'; broad='Microsoft System Center'; family='Microsoft System Center Data Protection Manager'},
    [pscustomobject]@{prefix='System Center Service Manager'; broad='Microsoft System Center'; family='Microsoft System Center Service Manager'},
    [pscustomobject]@{prefix='System Center Orchestrator'; broad='Microsoft System Center'; family='Microsoft System Center Orchestrator'},

    [pscustomobject]@{prefix='Office Online Server'; broad='Microsoft Office'; family='Microsoft Office Online Server'},
    [pscustomobject]@{prefix='Agents for Visual Studio'; broad='Microsoft Visual Studio'; family='Microsoft Visual Studio Agents'},
    [pscustomobject]@{prefix='Remote Tools for Visual Studio'; broad='Microsoft Visual Studio'; family='Microsoft Visual Studio Remote Tools'},
    [pscustomobject]@{prefix='Release Management'; broad='Microsoft Visual Studio'; family='Microsoft Visual Studio Release Management'},
    [pscustomobject]@{prefix='Build Tools for Visual Studio'; broad='Microsoft Visual Studio'; family='Microsoft Visual Studio Build Tools'},
    [pscustomobject]@{prefix='Performance Tools for Visual Studio'; broad='Microsoft Visual Studio'; family='Microsoft Visual Studio Performance Tools'},
    [pscustomobject]@{prefix='Feedback Client for Visual Studio'; broad='Microsoft Visual Studio'; family='Microsoft Visual Studio Feedback Client'},
    [pscustomobject]@{prefix='Web Tools Extensions for Visual Studio'; broad='Microsoft Visual Studio'; family='Microsoft Visual Studio Web Tools'},
    [pscustomobject]@{prefix='Team Explorer Everywhere'; broad='Microsoft Visual Studio'; family='Microsoft Visual Studio Team Explorer Everywhere'},
    [pscustomobject]@{prefix='Team Foundation'; broad='Microsoft Visual Studio'; family='Microsoft Visual Studio Team Foundation'},
    [pscustomobject]@{prefix='IntelliTrace'; broad='Microsoft Visual Studio'; family='Microsoft Visual Studio IntelliTrace'},
    [pscustomobject]@{prefix='Intellitrace'; broad='Microsoft Visual Studio'; family='Microsoft Visual Studio IntelliTrace'},
    [pscustomobject]@{prefix='Visual Studio.NET'; broad='Microsoft Visual Studio'; family='Microsoft Visual Studio'},
    [pscustomobject]@{prefix='Visual Studio'; broad='Microsoft Visual Studio'; family='Microsoft Visual Studio'},
    [pscustomobject]@{prefix='Visual SourceSafe'; broad='Microsoft Visual SourceSafe'; family='Microsoft Visual SourceSafe'},
    [pscustomobject]@{prefix='Visual FoxPro'; broad='Microsoft Visual FoxPro'; family='Microsoft Visual FoxPro'},
    [pscustomobject]@{prefix='Visual Basic'; broad='Microsoft Visual Basic'; family='Microsoft Visual Basic'},
    [pscustomobject]@{prefix='Visual C++'; broad='Microsoft Visual C++'; family='Microsoft Visual C++'},
    [pscustomobject]@{prefix='Visual J#'; broad='Microsoft Visual J#'; family='Microsoft Visual J#'},

    [pscustomobject]@{prefix='Office Communications Server'; broad='Microsoft Office'; family='Microsoft Office Communications Server'},
    [pscustomobject]@{prefix='Office Online'; broad='Microsoft Office'; family='Microsoft Office Online'},
    [pscustomobject]@{prefix='Office Professional Plus'; broad='Microsoft Office'; family='Microsoft Office Professional Plus'},
    [pscustomobject]@{prefix='Office Professional'; broad='Microsoft Office'; family='Microsoft Office Professional'},
    [pscustomobject]@{prefix='Office Accounting'; broad='Microsoft Office'; family='Microsoft Office Accounting'},
    [pscustomobject]@{prefix='Office Communicator'; broad='Microsoft Office'; family='Microsoft Office Communicator'},
    [pscustomobject]@{prefix='Office Project'; broad='Microsoft Office'; family='Microsoft Office Project'},
    [pscustomobject]@{prefix='Office SharePoint'; broad='Microsoft Office'; family='Microsoft Office SharePoint'},
    [pscustomobject]@{prefix='Office Visio'; broad='Microsoft Office'; family='Microsoft Office Visio'},
    [pscustomobject]@{prefix='Office Standard'; broad='Microsoft Office'; family='Microsoft Office Standard'},
    [pscustomobject]@{prefix='Office Enterprise'; broad='Microsoft Office'; family='Microsoft Office Enterprise'},
    [pscustomobject]@{prefix='Office Ultimate'; broad='Microsoft Office'; family='Microsoft Office Ultimate'},
    [pscustomobject]@{prefix='Office Home'; broad='Microsoft Office'; family='Microsoft Office Home'},
    [pscustomobject]@{prefix='Office Small Business'; broad='Microsoft Office'; family='Microsoft Office Small Business'},
    [pscustomobject]@{prefix='Office Groove'; broad='Microsoft Office'; family='Microsoft Office Groove'},
    [pscustomobject]@{prefix='Office OneNote'; broad='Microsoft Office'; family='Microsoft Office OneNote'},
    [pscustomobject]@{prefix='Office Access'; broad='Microsoft Office'; family='Microsoft Office Access'},
    [pscustomobject]@{prefix='Office InfoPath'; broad='Microsoft Office'; family='Microsoft Office InfoPath'},
    [pscustomobject]@{prefix='Office Outlook'; broad='Microsoft Office'; family='Microsoft Office Outlook'},
    [pscustomobject]@{prefix='Office Publisher'; broad='Microsoft Office'; family='Microsoft Office Publisher'},
    [pscustomobject]@{prefix='Office Web'; broad='Microsoft Office'; family='Microsoft Office Web'},
    [pscustomobject]@{prefix='Office Forms'; broad='Microsoft Office'; family='Microsoft Office Forms'},
    [pscustomobject]@{prefix='Office PerformancePoint'; broad='Microsoft Office'; family='Microsoft Office PerformancePoint'},
    [pscustomobject]@{prefix='Office FrontPage'; broad='Microsoft Office'; family='Microsoft Office FrontPage'},
    [pscustomobject]@{prefix='Office InterConnect'; broad='Microsoft Office'; family='Microsoft Office InterConnect'},
    [pscustomobject]@{prefix='Office'; broad='Microsoft Office'; family='Microsoft Office'},
    [pscustomobject]@{prefix='OneNote'; broad='Microsoft Office'; family='Microsoft Office OneNote'},
    [pscustomobject]@{prefix='Outlook'; broad='Microsoft Office'; family='Microsoft Office Outlook'},
    [pscustomobject]@{prefix='Access'; broad='Microsoft Office'; family='Microsoft Office Access'},
    [pscustomobject]@{prefix='InfoPath'; broad='Microsoft Office'; family='Microsoft Office InfoPath'},
    [pscustomobject]@{prefix='Publisher'; broad='Microsoft Office'; family='Microsoft Office Publisher'},
    [pscustomobject]@{prefix='Groove'; broad='Microsoft Office'; family='Microsoft Office Groove'},

    [pscustomobject]@{prefix='SQL Server'; broad='Microsoft SQL Server'; family='Microsoft SQL Server'},
    [pscustomobject]@{prefix='BizTalk Server'; broad='Microsoft BizTalk'; family='Microsoft BizTalk Server'},
    [pscustomobject]@{prefix='BizTalk'; broad='Microsoft BizTalk'; family='Microsoft BizTalk'},
    [pscustomobject]@{prefix='System Center'; broad='Microsoft System Center'; family='Microsoft System Center'},
    [pscustomobject]@{prefix='Systems Management Server'; broad='Microsoft Systems Management Server'; family='Microsoft Systems Management Server'},
    [pscustomobject]@{prefix='Windows'; broad='Microsoft Windows'; family='Microsoft Windows'},
    [pscustomobject]@{prefix='SharePoint'; broad='Microsoft SharePoint'; family='Microsoft SharePoint'},
    [pscustomobject]@{prefix='Project'; broad='Microsoft Project'; family='Microsoft Project'},
    [pscustomobject]@{prefix='Visio'; broad='Microsoft Visio'; family='Microsoft Visio'},
    [pscustomobject]@{prefix='Forefront'; broad='Microsoft Forefront'; family='Microsoft Forefront'},
    [pscustomobject]@{prefix='DirectX'; broad='Microsoft DirectX'; family='Microsoft DirectX'},
    [pscustomobject]@{prefix='Commerce Server'; broad='Microsoft Commerce Server'; family='Microsoft Commerce Server'},
    [pscustomobject]@{prefix='Expression'; broad='Microsoft Expression'; family='Microsoft Expression'},
    [pscustomobject]@{prefix='MapPoint'; broad='Microsoft MapPoint'; family='Microsoft MapPoint'},
    [pscustomobject]@{prefix='ISA Server'; broad='Microsoft ISA Server'; family='Microsoft ISA Server'},
    [pscustomobject]@{prefix='Internet Security and Acceleration'; broad='Microsoft ISA Server'; family='Microsoft ISA Server'},
    [pscustomobject]@{prefix='Internet Explorer'; broad='Microsoft Internet Explorer'; family='Microsoft Internet Explorer'},
    [pscustomobject]@{prefix='Lync'; broad='Microsoft Lync'; family='Microsoft Lync'},
    [pscustomobject]@{prefix='Live Communications Server'; broad='Microsoft Live Communications Server'; family='Microsoft Live Communications Server'},
    [pscustomobject]@{prefix='Azure'; broad='Microsoft Azure'; family='Microsoft Azure'},
    [pscustomobject]@{prefix='Kinect for Windows'; broad='Microsoft Kinect'; family='Microsoft Kinect for Windows'},
    [pscustomobject]@{prefix='.NET'; broad='Microsoft .NET'; family='Microsoft .NET'},
    [pscustomobject]@{prefix='ASP.NET'; broad='Microsoft ASP.NET'; family='Microsoft ASP.NET'},
    [pscustomobject]@{prefix='Application Virtualization'; broad='Microsoft Application Virtualization'; family='Microsoft Application Virtualization'},
    [pscustomobject]@{prefix='Solver Foundation'; broad='Microsoft Solver Foundation'; family='Microsoft Solver Foundation'},
    [pscustomobject]@{prefix='MSDN'; broad='Microsoft MSDN'; family='Microsoft MSDN'},
    [pscustomobject]@{prefix='Host Integration Server'; broad='Microsoft Host Integration Server'; family='Microsoft Host Integration Server'},
    [pscustomobject]@{prefix='Speech'; broad='Microsoft Speech'; family='Microsoft Speech'},
    [pscustomobject]@{prefix='Virtual PC'; broad='Microsoft Virtual PC'; family='Microsoft Virtual PC'},
    [pscustomobject]@{prefix='Virtual Server'; broad='Microsoft Virtual Server'; family='Microsoft Virtual Server'},
    [pscustomobject]@{prefix='Machine Learning Server'; broad='Microsoft Machine Learning Server'; family='Microsoft Machine Learning Server'},
    [pscustomobject]@{prefix='Advanced Threat Analytics'; broad='Microsoft Advanced Threat Analytics'; family='Microsoft Advanced Threat Analytics'},
    [pscustomobject]@{prefix='Content Management Server'; broad='Microsoft Content Management Server'; family='Microsoft Content Management Server'},
    [pscustomobject]@{prefix='Desktop Optimization Pack'; broad='Microsoft Desktop Optimization Pack'; family='Microsoft Desktop Optimization Pack'},
    [pscustomobject]@{prefix='Hyper-V'; broad='Microsoft Hyper-V'; family='Microsoft Hyper-V'},
    [pscustomobject]@{prefix='Robotics Developer Studio'; broad='Microsoft Robotics Developer Studio'; family='Microsoft Robotics Developer Studio'},
    [pscustomobject]@{prefix='Antigen'; broad='Microsoft Antigen'; family='Microsoft Antigen'},
    [pscustomobject]@{prefix='Search Server'; broad='Microsoft Search Server'; family='Microsoft Search Server'},
    [pscustomobject]@{prefix='Compute Cluster Server'; broad='Microsoft Compute Cluster Server'; family='Microsoft Compute Cluster Server'},
    [pscustomobject]@{prefix='ProClarity'; broad='Microsoft ProClarity'; family='Microsoft ProClarity'},
    [pscustomobject]@{prefix='ESP'; broad='Microsoft ESP'; family='Microsoft ESP'},
    [pscustomobject]@{prefix='Customer Care Framework'; broad='Microsoft Customer Care Framework'; family='Microsoft Customer Care Framework'},
    [pscustomobject]@{prefix='Small Business Accounting'; broad='Microsoft Small Business Accounting'; family='Microsoft Small Business Accounting'},
    [pscustomobject]@{prefix='Connected Services Framework'; broad='Microsoft Connected Services Framework'; family='Microsoft Connected Services Framework'},

    [pscustomobject]@{prefix='Dynamics CRM'; broad='Microsoft Dynamics'; family='Microsoft Dynamics CRM'},
    [pscustomobject]@{prefix='Dynamics GP'; broad='Microsoft Dynamics'; family='Microsoft Dynamics GP'},
    [pscustomobject]@{prefix='Dynamics AX'; broad='Microsoft Dynamics'; family='Microsoft Dynamics AX'},
    [pscustomobject]@{prefix='Dynamics NAV'; broad='Microsoft Dynamics'; family='Microsoft Dynamics NAV'},
    [pscustomobject]@{prefix='Dynamics SL'; broad='Microsoft Dynamics'; family='Microsoft Dynamics SL'},
    [pscustomobject]@{prefix='Dynamics 365'; broad='Microsoft Dynamics'; family='Microsoft Dynamics 365'},
    [pscustomobject]@{prefix='Dynamics Great Plains'; broad='Microsoft Dynamics'; family='Microsoft Dynamics Great Plains'},
    [pscustomobject]@{prefix='Dynamics'; broad='Microsoft Dynamics'; family='Microsoft Dynamics'},
    [pscustomobject]@{prefix='GP'; broad='Microsoft Dynamics'; family='Microsoft Dynamics GP'},
    [pscustomobject]@{prefix='Great Plains'; broad='Microsoft Dynamics'; family='Microsoft Dynamics Great Plains'},
    [pscustomobject]@{prefix='CRM'; broad='Microsoft Dynamics'; family='Microsoft Dynamics CRM'},
    [pscustomobject]@{prefix='Solomon'; broad='Microsoft Dynamics'; family='Microsoft Dynamics Solomon'},
    [pscustomobject]@{prefix='Navision'; broad='Microsoft Dynamics'; family='Microsoft Dynamics NAV'}
)

function Classify-TitleAutomatic {
    param([string]$InputTitle)
    $title = Normalize-Scalar $InputTitle
    if ([string]::IsNullOrEmpty($title)) { return $null }

    if ($title -match '(?i)^(?:Microsoft\s+)?Office Communications Server\b') {
        $broad = 'Microsoft Office'
        $family = 'Microsoft Office Communications Server'
        $release = Get-ReleaseToken $title
        $specific = if ([string]::IsNullOrEmpty($release)) { '' } else { $family + ' ' + $release }
        $broadRelease = if ($release -match '^(?:19|20)\d{2}$') { $broad + ' ' + $release } else { '' }
        return New-Classification $title $broad $family $release $specific $broadRelease 'high' 'curated-prefix' 'OFFICE_OCS'
    }

    if ($title -match '(?i)^Office\s+(?<release>(?:19|20)\d{2})\s+Proofing Tools\b') {
        $broad = 'Microsoft Office'
        $family = 'Microsoft Office Proofing Tools'
        $release = [string]$Matches.release
        return New-Classification $title $broad $family $release ($family+' '+$release) ($broad+' '+$release) 'high' 'curated-prefix' 'OFFICE_PROOFING'
    }

    if ($title -match '(?i)^Microsoft Office System Developer Kit\b') {
        $broad = 'Microsoft Office'
        $family = 'Microsoft Office System Developer Kit'
        $release = Get-ReleaseToken $title
        $specific = if ([string]::IsNullOrEmpty($release)) { '' } else { $family + ' ' + $release }
        return New-Classification $title $broad $family $release $specific '' 'high' 'curated-prefix' 'OFFICE_SDK'
    }

    foreach ($officePrefix in $OfficeComponentPrefixes) {
        if ($title.StartsWith($officePrefix,[StringComparison]::OrdinalIgnoreCase)) {
            if ($title.Length -gt $officePrefix.Length) {
                $next = $title.Substring($officePrefix.Length,1)
                if ($next -notmatch '[\s:,\-\(\[]') { continue }
            }
            $broad = 'Microsoft Office'
            $release = Get-ReleaseToken $title
            $specific = if ([string]::IsNullOrEmpty($release)) { '' } else { $officePrefix + ' ' + $release }
            $broadRelease = if ($release -match '^(?:19|20)\d{2}$') { $broad + ' ' + $release } else { '' }
            return New-Classification $title $broad $officePrefix $release $specific $broadRelease 'high' 'curated-prefix' 'OFFICE_COMPONENT'
        }
    }

    if ($title -match '(?i)^Microsoft Office\b') {
        $broad = 'Microsoft Office'
        $release = Get-ReleaseToken $title
        $broadRelease = if ($release -match '^(?:19|20)\d{2}$') { $broad + ' ' + $release } else { '' }
        return New-Classification $title $broad $broad $release $broadRelease $broadRelease 'high' 'curated-prefix' 'OFFICE_GENERIC'
    }

    if ($title -match '(?i)^Office\s+(?<release>(?:19|20)\d{2})\b') {
        $broad = 'Microsoft Office'
        $release = [string]$Matches.release
        $broadRelease = $broad + ' ' + $release
        return New-Classification $title $broad $broad $release $broadRelease $broadRelease 'high' 'curated-alias-prefix' 'OFFICE_GENERIC'
    }

    foreach ($aliasRule in $AliasPrefixRules) {
        $prefix = [string]$aliasRule.prefix
        if (-not $title.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($title.Length -gt $prefix.Length) {
            $next = $title.Substring($prefix.Length,1)
            if ($next -notmatch '[\s:,\-\(\[]') { continue }
        }
        $broad = [string]$aliasRule.broad
        $family = [string]$aliasRule.family
        $release = Get-ReleaseToken $title
        $specific = if ([string]::IsNullOrEmpty($release)) { '' } else { $family + ' ' + $release }
        $broadRelease = if ($release -match '^(?:19|20)\d{2}$') { $broad + ' ' + $release } else { '' }
        if ([string]::IsNullOrEmpty($broadRelease) -and -not [string]::IsNullOrEmpty($release) -and $broad.Equals($family,[StringComparison]::OrdinalIgnoreCase)) {
            $broadRelease = $specific
        }
        return New-Classification $title $broad $family $release $specific $broadRelease 'high' 'curated-alias-prefix' 'CURATED_ALIAS_PREFIX'
    }

    foreach ($prefix in $CuratedPrefixes) {
        if ($title.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) {
            if ($title.Length -gt $prefix.Length) {
                $next = $title.Substring($prefix.Length,1)
                if ($next -notmatch '[\s:,\-\(\[]') { continue }
            }
            $release = Get-ReleaseToken $title
            $specific = if ([string]::IsNullOrEmpty($release)) { '' } else { $prefix + ' ' + $release }
            return New-Classification $title $prefix $prefix $release $specific $specific 'high' 'curated-prefix' 'CURATED_MICROSOFT'
        }
    }

    if ($title -match '(?i)^Microsoft\s+(?<stem>[A-Za-z0-9][A-Za-z0-9+.#-]*)\b') {
        $family = 'Microsoft ' + [string]$Matches.stem
        $release = Get-ReleaseToken $title
        $specific = if ([string]::IsNullOrEmpty($release)) { '' } else { $family + ' ' + $release }
        return New-Classification $title $family $family $release $specific $specific 'review' 'generic-leading-microsoft-stem' 'GENERIC_MICROSOFT_REVIEW' 'review'
    }

    return $null
}

if (Is-HelpToken $ArchiveInput) {
    Show-Usage
    exit 0
}
if ([string]::IsNullOrWhiteSpace($ArchiveInput) -or [string]::IsNullOrWhiteSpace($OutputInput)) {
    Show-Usage
    Fail 2 'archive root and output folder are required'
}

$ArchiveRoot = Resolve-ArchiveRoot $ArchiveInput
if ($null -eq $ArchiveRoot) { Fail 3 ('Archive root not found or contains no snapshots: ' + $ArchiveInput) }
$OutputRoot = Resolve-OutputPath $OutputInput
if ($null -eq $OutputRoot) { Fail 2 'Invalid output folder.' }
$Snapshots = @(Get-Snapshots $ArchiveRoot)
if ($Snapshots.Count -eq 0) { Fail 3 'No snapshot folders found.' }

$Overrides = New-IgnoreCaseDictionary
$OverridePath = ''
if (-not [string]::IsNullOrWhiteSpace($OverrideInput)) {
    try {
        $OverridePath = (Resolve-Path -LiteralPath $OverrideInput -ErrorAction Stop).Path
    } catch {
        Fail 3 ('Override file not found: ' + $OverrideInput)
    }
    $overrideRows = @(Import-Csv -LiteralPath $OverridePath -Delimiter "`t" -Encoding UTF8)
    foreach ($row in $overrideRows) {
        $title = Normalize-Scalar ([string]$row.product_title)
        $action = ([string]$row.action).Trim().ToLowerInvariant()
        if ([string]::IsNullOrEmpty($title) -or @('set','exclude') -notcontains $action) {
            Fail 2 ('Invalid override row; expected product_title and action=set|exclude: ' + $title)
        }
        if ($Overrides.ContainsKey($title)) { Fail 2 ('Duplicate override product_title: ' + $title) }
        $Overrides.Add($title,$row)
    }
}

if (Test-Path -LiteralPath $OutputRoot) {
    Fail 2 ('Output folder already exists; choose a new folder or remove the existing index first: ' + $OutputRoot)
}
$parent = Split-Path -Parent $OutputRoot
if ([string]::IsNullOrWhiteSpace($parent)) { $parent = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $parent -PathType Container)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
$stage = Join-Path $parent ((Split-Path -Leaf $OutputRoot) + '.building-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $stage -Force)
$rawRoot = Join-Path $stage 'raw-html'
[void](New-Item -ItemType Directory -Path $rawRoot -Force)

$Writers = @{}
$SeenRows = @{}
$Counts = @{}
function Add-Table {
    param([string]$Name,[string]$Header)
    $Writers[$Name] = New-Utf8Writer (Join-Path $stage $Name) $Header
    $SeenRows[$Name] = New-OrdinalSet
    $Counts[$Name] = 0L
}
function Write-UniqueRow {
    param([string]$Table,[object[]]$Fields)
    $safe = New-Object 'string[]' $Fields.Count
    for ($i=0; $i -lt $Fields.Count; $i++) { $safe[$i] = Convert-TsvField ([string]$Fields[$i]) }
    $line = $safe -join [char]9
    if ($SeenRows[$Table].Add($line)) {
        $Writers[$Table].WriteLine($line)
        $Counts[$Table] = [int64]$Counts[$Table] + 1L
    }
}

Add-Table 'product-classifications.tsv' "product_title`tbroad_family`tproduct_family`trelease`tspecific_release_family`tbroad_release_family`tconfidence`tbasis`trule_id`tstatus"
Add-Table 'product-family-memberships.tsv' "product_title`tfamily`trelationship_type`tconfidence`tbasis`trule_id"
Add-Table 'product-ids.tsv' "snapshot`tsource_file`tproduct_title`tid"
Add-Table 'product-dates.tsv' "snapshot`tsource_file`tproduct_title`tdate`tid"
Add-Table 'product-files.tsv' "snapshot`tsource_file`tproduct_title`tproduct_id`tfilename"
Add-Table 'product-hashes.tsv' "snapshot`tsource_file`tproduct_title`tproduct_id`tfilename`talgorithm`thash"
Add-Table 'product-notes.tsv' "snapshot`tsource_file`tproduct_title`tsource_id`tnote_text`traw_html_sha256"
Add-Table 'product-snapshots.tsv' "snapshot`tproduct_title`tevidence_sources"
Add-Table 'unclassified-products.tsv' "product_title`tfirst_seen_dump`tclassification_status`treason"
Add-Table 'overrides-applied.tsv' "product_title`taction`tbroad_family`tproduct_family`trelease`tspecific_release_family`tbroad_release_family`tconfidence`treason"

$Classifications = New-IgnoreCaseDictionary
$FirstSeen = @{}
$NodeRows = New-Object System.Collections.ArrayList
$NodeSeen = New-OrdinalSet
$RelationRows = New-Object System.Collections.ArrayList
$RelationSeen = New-OrdinalSet

function Add-Node {
    param([string]$Family,[string]$NodeType,[string]$Broad,[string]$Release,[string]$Confidence,[string]$Basis)
    if ([string]::IsNullOrWhiteSpace($Family)) { return }
    $key = $Family + [char]9 + $NodeType
    if ($NodeSeen.Add($key)) {
        [void]$NodeRows.Add([pscustomobject]@{
            family=$Family; node_type=$NodeType; broad_family=$Broad; release=$Release; confidence=$Confidence; basis=$Basis
        })
    }
}
function Add-Relation {
    param([string]$Child,[string]$Parent,[string]$Relationship,[string]$Confidence,[string]$Basis)
    if ([string]::IsNullOrWhiteSpace($Child) -or [string]::IsNullOrWhiteSpace($Parent) -or
        $Child.Equals($Parent,[StringComparison]::OrdinalIgnoreCase)) { return }
    $key = $Child + [char]9 + $Parent + [char]9 + $Relationship
    if ($RelationSeen.Add($key)) {
        [void]$RelationRows.Add([pscustomobject]@{
            child_family=$Child; parent_family=$Parent; relationship_type=$Relationship; confidence=$Confidence; basis=$Basis
        })
    }
}

function Ensure-Classification {
    param([string]$InputTitle,[string]$SnapshotName)
    $title = Normalize-Scalar $InputTitle
    if ([string]::IsNullOrEmpty($title)) { return $null }
    if (-not $FirstSeen.ContainsKey($title)) { $FirstSeen[$title] = $SnapshotName }
    if ($Classifications.ContainsKey($title)) { return $Classifications[$title] }

    $classification = $null
    if ($Overrides.ContainsKey($title)) {
        $row = $Overrides[$title]
        $action = ([string]$row.action).Trim().ToLowerInvariant()
        $reason = Normalize-Scalar ([string]$row.reason)
        if ($action -eq 'exclude') {
            Write-UniqueRow 'overrides-applied.tsv' @($title,'exclude','','','','','',([string]$row.confidence),$reason)
            Write-UniqueRow 'unclassified-products.tsv' @($title,$SnapshotName,'excluded',('override: '+$reason))
            $classification = New-Classification $title '' '' '' '' '' 'override' ('override-exclude: '+$reason) 'OVERRIDE' 'excluded'
            $Classifications.Add($title,$classification)
            return $classification
        }
        $broad = Normalize-Scalar ([string]$row.broad_family)
        $family = Normalize-Scalar ([string]$row.product_family)
        $release = Normalize-Scalar ([string]$row.release)
        $specific = Normalize-Scalar ([string]$row.specific_release_family)
        $broadRelease = Normalize-Scalar ([string]$row.broad_release_family)
        $confidence = Normalize-Scalar ([string]$row.confidence)
        if ([string]::IsNullOrEmpty($confidence)) { $confidence = 'override' }
        if ([string]::IsNullOrEmpty($broad) -and [string]::IsNullOrEmpty($family)) {
            Fail 2 ('set override needs broad_family and/or product_family: ' + $title)
        }
        if ([string]::IsNullOrEmpty($broad)) { $broad = $family }
        if ([string]::IsNullOrEmpty($family)) { $family = $broad }
        $classification = New-Classification $title $broad $family $release $specific $broadRelease $confidence ('override-set: '+$reason) 'OVERRIDE'
        Write-UniqueRow 'overrides-applied.tsv' @($title,'set',$broad,$family,$release,$specific,$broadRelease,$confidence,$reason)
    } else {
        $classification = Classify-TitleAutomatic $title
    }

    if ($null -eq $classification) {
        Write-UniqueRow 'unclassified-products.tsv' @($title,$SnapshotName,'unclassified','no conservative family rule matched')
        $classification = New-Classification $title '' '' '' '' '' 'unclassified' 'no-rule' 'NONE' 'unclassified'
        $Classifications.Add($title,$classification)
        return $classification
    }

    $Classifications.Add($title,$classification)
    Write-UniqueRow 'product-classifications.tsv' @(
        $classification.product_title,$classification.broad_family,$classification.product_family,$classification.release,
        $classification.specific_release_family,$classification.broad_release_family,$classification.confidence,
        $classification.basis,$classification.rule_id,$classification.status
    )

    $membershipMap = @{}
    function Add-MembershipType {
        param([string]$Family,[string]$Type)
        if ([string]::IsNullOrWhiteSpace($Family)) { return }
        if (-not $membershipMap.ContainsKey($Family)) { $membershipMap[$Family] = New-Object System.Collections.ArrayList }
        if (-not $membershipMap[$Family].Contains($Type)) { [void]$membershipMap[$Family].Add($Type) }
    }
    Add-MembershipType $classification.broad_family 'broad_family'
    Add-MembershipType $classification.product_family 'product_family'
    Add-MembershipType $classification.broad_release_family 'broad_release'
    Add-MembershipType $classification.specific_release_family 'specific_release'
    foreach ($familyName in @($membershipMap.Keys | Sort-Object)) {
        Write-UniqueRow 'product-family-memberships.tsv' @(
            $title,$familyName,($membershipMap[$familyName] -join '|'),$classification.confidence,$classification.basis,$classification.rule_id
        )
    }

    Add-Node $classification.broad_family 'broad_family' $classification.broad_family '' $classification.confidence $classification.basis
    Add-Node $classification.product_family 'product_family' $classification.broad_family '' $classification.confidence $classification.basis
    Add-Node $classification.broad_release_family 'broad_release' $classification.broad_family $classification.release $classification.confidence $classification.basis
    Add-Node $classification.specific_release_family 'specific_release' $classification.broad_family $classification.release $classification.confidence $classification.basis

    Add-Relation $classification.product_family $classification.broad_family 'product_family_of' $classification.confidence $classification.basis
    Add-Relation $classification.broad_release_family $classification.broad_family 'release_rollup_of' $classification.confidence $classification.basis
    Add-Relation $classification.specific_release_family $classification.product_family 'specific_release_of' $classification.confidence $classification.basis
    Add-Relation $classification.specific_release_family $classification.broad_release_family 'member_of_release_rollup' $classification.confidence $classification.basis

    return $classification
}

function Add-SnapshotEvidence {
    param([hashtable]$Evidence,[System.Collections.ArrayList]$Order,[string]$Title,[string]$Source,[string]$SnapshotName)
    $normalized = Normalize-Scalar $Title
    if ([string]::IsNullOrEmpty($normalized)) { return }
    [void](Ensure-Classification $normalized $SnapshotName)
    if (-not $Evidence.ContainsKey($normalized)) {
        $Evidence[$normalized] = New-Object System.Collections.ArrayList
        [void]$Order.Add($normalized)
    }
    if (-not $Evidence[$normalized].Contains($Source)) { [void]$Evidence[$normalized].Add($Source) }
}

function Parse-ProductFile {
    param([object]$Snapshot,[string]$Path,[hashtable]$Evidence,[System.Collections.ArrayList]$Order)
    $reader = New-Object System.IO.StreamReader -ArgumentList @($Path,$utf8,$true,65536)
    $title = ''
    $id = ''
    try {
        while (($line = $reader.ReadLine()) -ne $null) {
            if ($line -match '^---\s*(?<title>.*?)\s*\[ID:\s*(?<id>[^\]]+?)\s*\]\s*---\s*$') {
                $title = Normalize-Scalar ([string]$Matches.title)
                $id = Normalize-Scalar ([string]$Matches.id)
                Add-SnapshotEvidence $Evidence $Order $title 'mvs.txt' ([string]$Snapshot.name)
                Write-UniqueRow 'product-ids.tsv' @([string]$Snapshot.name,'mvs.txt',$title,$id)
                continue
            }
            if ([string]::IsNullOrEmpty($title)) { continue }
            if ($line -match '^\s*(?<hash>[0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})\s+\*(?<filename>.+?)\s*$') {
                $hash = ([string]$Matches.hash).ToLowerInvariant()
                $filename = Normalize-Scalar ([string]$Matches.filename)
                $algorithm = if ($hash.Length -eq 40) { 'sha1' } else { 'sha256' }
                Write-UniqueRow 'product-files.tsv' @([string]$Snapshot.name,'mvs.txt',$title,$id,$filename)
                Write-UniqueRow 'product-hashes.tsv' @([string]$Snapshot.name,'mvs.txt',$title,$id,$filename,$algorithm,$hash)
            }
        }
    } finally {
        $reader.Dispose()
    }
}

function Parse-IdsFile {
    param([object]$Snapshot,[string]$Path,[hashtable]$Evidence,[System.Collections.ArrayList]$Order)
    $reader = New-Object System.IO.StreamReader -ArgumentList @($Path,$utf8,$true,65536)
    try {
        while (($line = $reader.ReadLine()) -ne $null) {
            if ($line -match '^(?<title>.*?)\s*\[ID:\s*(?<id>[^\]]+?)\s*\]\s*$') {
                $title = Normalize-Scalar ([string]$Matches.title)
                $id = Normalize-Scalar ([string]$Matches.id)
                Add-SnapshotEvidence $Evidence $Order $title 'mvs_ids.txt' ([string]$Snapshot.name)
                Write-UniqueRow 'product-ids.tsv' @([string]$Snapshot.name,'mvs_ids.txt',$title,$id)
            }
        }
    } finally {
        $reader.Dispose()
    }
}

function Parse-DatesFile {
    param([object]$Snapshot,[string]$Path,[hashtable]$Evidence,[System.Collections.ArrayList]$Order)
    $reader = New-Object System.IO.StreamReader -ArgumentList @($Path,$utf8,$true,65536)
    try {
        while (($line = $reader.ReadLine()) -ne $null) {
            if ($line -match '^(?<date>.*?)\s+-\s+(?<title>.*?)\s*\[ID:\s*(?<id>[^\]]+?)\s*\]\s*$') {
                $date = Normalize-Scalar ([string]$Matches.date)
                $title = Normalize-Scalar ([string]$Matches.title)
                $id = Normalize-Scalar ([string]$Matches.id)
                Add-SnapshotEvidence $Evidence $Order $title 'mvs_dates.txt' ([string]$Snapshot.name)
                Write-UniqueRow 'product-ids.tsv' @([string]$Snapshot.name,'mvs_dates.txt',$title,$id)
                Write-UniqueRow 'product-dates.tsv' @([string]$Snapshot.name,'mvs_dates.txt',$title,$date,$id)
            }
        }
    } finally {
        $reader.Dispose()
    }
}

function Parse-NotesFile {
    param([object]$Snapshot,[string]$Path,[hashtable]$Evidence,[System.Collections.ArrayList]$Order)
    $html = [IO.File]::ReadAllText($Path,$utf8)
    $matches = [regex]::Matches($html,'(?is)<h[13][^>]*>(?<heading>.*?)</h[13]>(?<body>.*?)(?=<h[13]\b|\z)')
    foreach ($match in $matches) {
        $heading = Convert-HtmlToText ([string]$match.Groups['heading'].Value)
        $sourceId = ''
        $title = $heading
        if ($heading -match '^(?<title>.*?)\s*\[ID:\s*(?<id>[^\]]+?)\s*\]\s*$') {
            $title = Normalize-Scalar ([string]$Matches.title)
            $sourceId = Normalize-Scalar ([string]$Matches.id)
        }
        if ([string]::IsNullOrEmpty($title)) { continue }
        Add-SnapshotEvidence $Evidence $Order $title 'mvs_notes.html' ([string]$Snapshot.name)
        if (-not [string]::IsNullOrEmpty($sourceId)) {
            Write-UniqueRow 'product-ids.tsv' @([string]$Snapshot.name,'mvs_notes.html',$title,$sourceId)
        }
        $body = [string]$match.Groups['body'].Value
        $noteText = Convert-HtmlToText $body
        $rawHtml = [string]$match.Value
        $sha = Get-Sha256String $rawHtml
        $rawPath = Join-Path $rawRoot ($sha + '.html')
        if (-not (Test-Path -LiteralPath $rawPath -PathType Leaf)) {
            [IO.File]::WriteAllText($rawPath,$rawHtml,$utf8)
        }
        Write-UniqueRow 'product-notes.tsv' @([string]$Snapshot.name,'mvs_notes.html',$title,$sourceId,$noteText,$sha)
    }
}

$success = $false
$runStart = Get-Date
try {
    Write-Line ('Archive: ' + $ArchiveRoot)
    Write-Line ('Output: ' + $OutputRoot)
    Write-Line ('Snapshots discovered: ' + $Snapshots.Count)
    if (-not [string]::IsNullOrEmpty($OverridePath)) { Write-Line ('Overrides: ' + $OverridePath) }

    for ($i=0; $i -lt $Snapshots.Count; $i++) {
        $snapshot = $Snapshots[$i]
        $evidence = @{}
        $order = New-Object System.Collections.ArrayList

        $mvsPath = Get-SnapshotSourcePath $snapshot 'mvs.txt'
        if ($null -ne $mvsPath) { Parse-ProductFile $snapshot $mvsPath $evidence $order }
        $idsPath = Get-SnapshotSourcePath $snapshot 'mvs_ids.txt'
        if ($null -ne $idsPath) { Parse-IdsFile $snapshot $idsPath $evidence $order }
        $datesPath = Get-SnapshotSourcePath $snapshot 'mvs_dates.txt'
        if ($null -ne $datesPath) { Parse-DatesFile $snapshot $datesPath $evidence $order }
        $notesPath = Get-SnapshotSourcePath $snapshot 'mvs_notes.html'
        if ($null -ne $notesPath) { Parse-NotesFile $snapshot $notesPath $evidence $order }

        foreach ($title in $order) {
            Write-UniqueRow 'product-snapshots.tsv' @([string]$snapshot.name,[string]$title,($evidence[$title] -join '|'))
        }
        foreach ($writer in $Writers.Values) { $writer.Flush() }
        Write-Line ('Family index snapshot ' + ($i+1) + '/' + $Snapshots.Count + ': ' + $snapshot.name)
    }

    foreach ($writer in $Writers.Values) { $writer.Dispose() }
    $Writers = @{}

    $nodeWriter = New-Utf8Writer (Join-Path $stage 'family-nodes.tsv') "family`tnode_type`tbroad_family`trelease`tconfidence`tbasis"
    try {
        foreach ($row in @($NodeRows | Sort-Object family,node_type,broad_family,release)) {
            $fields = @([string]$row.family,[string]$row.node_type,[string]$row.broad_family,[string]$row.release,[string]$row.confidence,[string]$row.basis)
            for ($f=0; $f -lt $fields.Count; $f++) { $fields[$f] = Convert-TsvField $fields[$f] }
            $nodeWriter.WriteLine(($fields -join [char]9))
        }
    } finally { $nodeWriter.Dispose() }

    $relationWriter = New-Utf8Writer (Join-Path $stage 'family-parent-relationships.tsv') "child_family`tparent_family`trelationship_type`tconfidence`tbasis"
    try {
        foreach ($row in @($RelationRows | Sort-Object child_family,parent_family,relationship_type)) {
            $fields = @([string]$row.child_family,[string]$row.parent_family,[string]$row.relationship_type,[string]$row.confidence,[string]$row.basis)
            for ($f=0; $f -lt $fields.Count; $f++) { $fields[$f] = Convert-TsvField $fields[$f] }
            $relationWriter.WriteLine(($fields -join [char]9))
        }
    } finally { $relationWriter.Dispose() }

    $rulesWriter = New-Utf8Writer (Join-Path $stage 'classification-rules.tsv') "rule_id`tpriority`tconfidence`tdescription"
    try {
        foreach ($row in $RuleRows) {
            $fields = @([string]$row.rule_id,[string]$row.priority,[string]$row.confidence,[string]$row.description)
            for ($f=0; $f -lt $fields.Count; $f++) { $fields[$f] = Convert-TsvField $fields[$f] }
            $rulesWriter.WriteLine(($fields -join [char]9))
        }
    } finally { $rulesWriter.Dispose() }

    $elapsed = [int64]((Get-Date)-$runStart).TotalMilliseconds
    $summary = @(
        ('MVS Explorer Toolkit product-family index ' + $Version),
        ('Archive: ' + $ArchiveRoot),
        ('Snapshots: ' + $Snapshots.Count),
        ('Classified/review products: ' + $Counts['product-classifications.tsv']),
        ('Family memberships: ' + $Counts['product-family-memberships.tsv']),
        ('Product ID observations: ' + $Counts['product-ids.tsv']),
        ('Product date observations: ' + $Counts['product-dates.tsv']),
        ('Product file observations: ' + $Counts['product-files.tsv']),
        ('Product hash observations: ' + $Counts['product-hashes.tsv']),
        ('Product note observations: ' + $Counts['product-notes.tsv']),
        ('Product snapshot observations: ' + $Counts['product-snapshots.tsv']),
        ('Unclassified/excluded products: ' + $Counts['unclassified-products.tsv']),
        ('Family nodes: ' + $NodeRows.Count),
        ('Family parent relationships: ' + $RelationRows.Count),
        ('Raw note HTML blobs: ' + @(Get-ChildItem -LiteralPath $rawRoot -File -Filter '*.html').Count),
        ('Elapsed milliseconds: ' + $elapsed)
    ) -join [Environment]::NewLine
    [IO.File]::WriteAllText((Join-Path $stage 'family-index-summary.txt'),$summary + [Environment]::NewLine,$utf8)

    Move-Item -LiteralPath $stage -Destination $OutputRoot
    $success = $true
    Write-Line ('Family index complete: products=' + $Counts['product-classifications.tsv'] + ' memberships=' + $Counts['product-family-memberships.tsv'])
    Write-Line ('Results: ' + $OutputRoot)
    exit 0
} catch {
    Write-Err ('ERROR: ' + $_.Exception.Message)
    exit 5
} finally {
    foreach ($writer in $Writers.Values) {
        try { $writer.Dispose() } catch {}
    }
    if (-not $success -and (Test-Path -LiteralPath $stage)) {
        try { Remove-Item -LiteralPath $stage -Recurse -Force } catch {}
    }
}
