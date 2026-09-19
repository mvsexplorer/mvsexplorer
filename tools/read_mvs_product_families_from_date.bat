@echo off
:setup
REM Scoped because this standalone product-family query tool embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=0.1.0"
set "app.name=read_mvs_product_families_from_date"
set "app.rc=0"
set "app.self=%~f0"
set "mvsfq_mode=machine"
set "mvsfq_operation=families_from_date"
set "mvsfq_index=%~1"
set "mvsfq_search=%~2"
set "mvsfq_caller=%~nx0"
set "mvsfq_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSProductFamilyQuery"
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

:_MVSProductFamilyQuery_start
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$Mode = [string]$env:mvsfq_mode
$Operation = [string]$env:mvsfq_operation
$IndexInput = [string]$env:mvsfq_index
$Needle = [string]$env:mvsfq_search
$Caller = [string]$env:mvsfq_caller
$Version = [string]$env:mvsfq_version
$script:Emitted = 0
$script:SeenOutput = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)

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
function Is-HelpToken {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    return @('--help','-h','-?','/h','/?') -contains $Value
}
function Show-Usage {
    Write-Line ('MVS Explorer Toolkit product-family query ' + $Version)
    Write-Line ('Usage: ' + $Caller + ' family-index search-pattern')
    Write-Line ('Operation: ' + $Operation)
    Write-Line 'Search patterns use PowerShell wildcard syntax (* and ?); matching is case-insensitive.'
    Write-Line 'read_* emits tab-separated machine rows; print_* emits labeled human-readable rows.'
}
function Resolve-IndexRoot {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    try {
        if (-not (Test-Path -LiteralPath $Name -PathType Container)) { return $null }
        $resolved = (Resolve-Path -LiteralPath $Name).Path
        if (-not (Test-Path -LiteralPath (Join-Path $resolved 'product-family-memberships.tsv') -PathType Leaf)) { return $null }
        return $resolved
    } catch {
        return $null
    }
}
function Read-Table {
    param([string]$Name)
    $path = Join-Path $IndexRoot $Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail 3 ('Family index table missing: ' + $Name) }
    return @(Import-Csv -LiteralPath $path -Delimiter "`t" -Encoding UTF8)
}
function Matches-Pattern {
    param([AllowNull()][AllowEmptyString()][string]$Value,[string]$Pattern)
    if ($null -eq $Value) { return $false }
    return $Value -like $Pattern
}
function New-TitleMembershipMap {
    param([object[]]$Rows)
    $map = @{}
    foreach ($row in $Rows) {
        $title = [string]$row.product_title
        if (-not $map.ContainsKey($title)) { $map[$title] = New-Object System.Collections.ArrayList }
        [void]$map[$title].Add($row)
    }
    return $map
}
function Emit-Row {
    param([object[]]$Fields,[string]$Human)
    $safe = New-Object 'string[]' $Fields.Count
    for ($i=0; $i -lt $Fields.Count; $i++) {
        $value = if ($null -eq $Fields[$i]) { '' } else { [string]$Fields[$i] }
        $safe[$i] = $value.Replace("`t",' ').Replace("`r",' ').Replace("`n",' ')
    }
    $machine = $safe -join [char]9
    if (-not $script:SeenOutput.Add($machine)) { return }
    if ($Mode -eq 'machine') { Write-Line $machine } else { Write-Line $Human }
    $script:Emitted++
}
function Get-FamilyMembershipMatches {
    $memberships = Read-Table 'product-family-memberships.tsv'
    return @($memberships | Where-Object { Matches-Pattern ([string]$_.family) $Needle })
}
function Get-AllMembershipMap {
    return New-TitleMembershipMap (Read-Table 'product-family-memberships.tsv')
}
function Emit-FactsFromFamily {
    param([string]$Table,[scriptblock]$Emitter)
    $matches = @(Get-FamilyMembershipMatches)
    if ($matches.Count -eq 0) { return }
    $map = New-TitleMembershipMap $matches
    foreach ($fact in @(Read-Table $Table)) {
        $title = [string]$fact.product_title
        if (-not $map.ContainsKey($title)) { continue }
        foreach ($membership in $map[$title]) {
            & $Emitter $membership $fact
        }
    }
}
function Emit-FamiliesFromFact {
    param([string]$Table,[string]$Field,[scriptblock]$Emitter)
    $membershipMap = Get-AllMembershipMap
    foreach ($fact in @(Read-Table $Table)) {
        $value = [string]$fact.$Field
        if (-not (Matches-Pattern $value $Needle)) { continue }
        $title = [string]$fact.product_title
        if (-not $membershipMap.ContainsKey($title)) { continue }
        foreach ($membership in $membershipMap[$title]) {
            & $Emitter $fact $membership
        }
    }
}

if (Is-HelpToken $IndexInput) {
    Show-Usage
    exit 0
}
if ([string]::IsNullOrWhiteSpace($IndexInput) -or [string]::IsNullOrWhiteSpace($Needle)) {
    Show-Usage
    Fail 2 'family index and search pattern are required'
}
$IndexRoot = Resolve-IndexRoot $IndexInput
if ($null -eq $IndexRoot) { Fail 3 ('Family index not found or incomplete: ' + $IndexInput) }
if (@('human','machine') -notcontains $Mode) { Fail 2 ('Unsupported output mode: ' + $Mode) }

try {
    switch ($Operation) {
        'titles_from_family' {
            foreach ($m in @(Get-FamilyMembershipMatches)) {
                Emit-Row (@($m.family,$m.relationship_type,$m.confidence,$m.product_title)) (
                    'Family: '+$m.family+' | Product: '+$m.product_title+' | Relationship: '+$m.relationship_type+' | Confidence: '+$m.confidence
                )
            }
        }
        'families_from_title' {
            foreach ($m in @(Read-Table 'product-family-memberships.tsv')) {
                if (-not (Matches-Pattern ([string]$m.product_title) $Needle)) { continue }
                Emit-Row (@($m.product_title,$m.family,$m.relationship_type,$m.confidence)) (
                    'Product: '+$m.product_title+' | Family: '+$m.family+' | Relationship: '+$m.relationship_type+' | Confidence: '+$m.confidence
                )
            }
        }
        'ids_from_family' {
            Emit-FactsFromFamily 'product-ids.tsv' {
                param($m,$f)
                Emit-Row (@($m.family,$f.product_title,$f.snapshot,$f.source_file,$f.id,$m.confidence)) (
                    'Family: '+$m.family+' | Product: '+$f.product_title+' | ID: '+$f.id+' | Snapshot: '+$f.snapshot+' | Source: '+$f.source_file+' | Confidence: '+$m.confidence
                )
            }
        }
        'families_from_id' {
            Emit-FamiliesFromFact 'product-ids.tsv' 'id' {
                param($f,$m)
                Emit-Row (@($f.id,$f.snapshot,$f.source_file,$f.product_title,$m.family,$m.relationship_type,$m.confidence)) (
                    'ID: '+$f.id+' | Snapshot: '+$f.snapshot+' | Source: '+$f.source_file+' | Product: '+$f.product_title+' | Family: '+$m.family+' | Relationship: '+$m.relationship_type
                )
            }
        }
        'dates_from_family' {
            Emit-FactsFromFamily 'product-dates.tsv' {
                param($m,$f)
                Emit-Row (@($m.family,$f.product_title,$f.snapshot,$f.source_file,$f.date,$f.id,$m.confidence)) (
                    'Family: '+$m.family+' | Product: '+$f.product_title+' | Date: '+$f.date+' | ID: '+$f.id+' | Snapshot: '+$f.snapshot+' | Source: '+$f.source_file
                )
            }
        }
        'families_from_date' {
            Emit-FamiliesFromFact 'product-dates.tsv' 'date' {
                param($f,$m)
                Emit-Row (@($f.date,$f.snapshot,$f.source_file,$f.id,$f.product_title,$m.family,$m.relationship_type,$m.confidence)) (
                    'Date: '+$f.date+' | Snapshot: '+$f.snapshot+' | Product: '+$f.product_title+' | Family: '+$m.family+' | Relationship: '+$m.relationship_type
                )
            }
        }
        'filenames_from_family' {
            Emit-FactsFromFamily 'product-files.tsv' {
                param($m,$f)
                Emit-Row (@($m.family,$f.product_title,$f.snapshot,$f.source_file,$f.product_id,$f.filename,$m.confidence)) (
                    'Family: '+$m.family+' | Product: '+$f.product_title+' | Filename: '+$f.filename+' | Snapshot: '+$f.snapshot+' | ID: '+$f.product_id
                )
            }
        }
        'families_from_filename' {
            Emit-FamiliesFromFact 'product-files.tsv' 'filename' {
                param($f,$m)
                Emit-Row (@($f.filename,$f.snapshot,$f.source_file,$f.product_id,$f.product_title,$m.family,$m.relationship_type,$m.confidence)) (
                    'Filename: '+$f.filename+' | Snapshot: '+$f.snapshot+' | Product: '+$f.product_title+' | Family: '+$m.family+' | Relationship: '+$m.relationship_type
                )
            }
        }
        'hashes_from_family' {
            Emit-FactsFromFamily 'product-hashes.tsv' {
                param($m,$f)
                Emit-Row (@($m.family,$f.product_title,$f.snapshot,$f.source_file,$f.product_id,$f.filename,$f.algorithm,$f.hash,$m.confidence)) (
                    'Family: '+$m.family+' | Product: '+$f.product_title+' | '+$f.algorithm.ToUpperInvariant()+': '+$f.hash+' | Filename: '+$f.filename+' | Snapshot: '+$f.snapshot
                )
            }
        }
        'families_from_hash' {
            Emit-FamiliesFromFact 'product-hashes.tsv' 'hash' {
                param($f,$m)
                Emit-Row (@($f.hash,$f.algorithm,$f.filename,$f.snapshot,$f.source_file,$f.product_id,$f.product_title,$m.family,$m.relationship_type,$m.confidence)) (
                    $f.algorithm.ToUpperInvariant()+': '+$f.hash+' | Filename: '+$f.filename+' | Product: '+$f.product_title+' | Family: '+$m.family+' | Snapshot: '+$f.snapshot
                )
            }
        }
        'snapshots_from_family' {
            Emit-FactsFromFamily 'product-snapshots.tsv' {
                param($m,$f)
                Emit-Row (@($m.family,$f.product_title,$f.snapshot,$f.evidence_sources,$m.confidence)) (
                    'Family: '+$m.family+' | Product: '+$f.product_title+' | Snapshot: '+$f.snapshot+' | Evidence: '+$f.evidence_sources
                )
            }
        }
        'families_from_snapshot' {
            Emit-FamiliesFromFact 'product-snapshots.tsv' 'snapshot' {
                param($f,$m)
                Emit-Row (@($f.snapshot,$f.product_title,$f.evidence_sources,$m.family,$m.relationship_type,$m.confidence)) (
                    'Snapshot: '+$f.snapshot+' | Product: '+$f.product_title+' | Family: '+$m.family+' | Evidence: '+$f.evidence_sources
                )
            }
        }
        'family_parents_from_family' {
            foreach ($r in @(Read-Table 'family-parent-relationships.tsv')) {
                if (-not (Matches-Pattern ([string]$r.child_family) $Needle)) { continue }
                Emit-Row (@($r.child_family,$r.parent_family,$r.relationship_type,$r.confidence,$r.basis)) (
                    'Child: '+$r.child_family+' | Parent: '+$r.parent_family+' | Relationship: '+$r.relationship_type+' | Confidence: '+$r.confidence
                )
            }
        }
        'family_children_from_family' {
            foreach ($r in @(Read-Table 'family-parent-relationships.tsv')) {
                if (-not (Matches-Pattern ([string]$r.parent_family) $Needle)) { continue }
                Emit-Row (@($r.parent_family,$r.child_family,$r.relationship_type,$r.confidence,$r.basis)) (
                    'Parent: '+$r.parent_family+' | Child: '+$r.child_family+' | Relationship: '+$r.relationship_type+' | Confidence: '+$r.confidence
                )
            }
        }
        'notes_from_family' {
            Emit-FactsFromFamily 'product-notes.tsv' {
                param($m,$f)
                Emit-Row (@($m.family,$f.product_title,$f.snapshot,$f.source_file,$f.source_id,$f.note_text,$f.raw_html_sha256,$m.confidence)) (
                    'Family: '+$m.family+' | Product: '+$f.product_title+' | Snapshot: '+$f.snapshot+' | Note: '+$f.note_text+' | Raw SHA256: '+$f.raw_html_sha256
                )
            }
        }
        'releases_from_family' {
            $matches = @(Get-FamilyMembershipMatches)
            $map = New-TitleMembershipMap $matches
            foreach ($c in @(Read-Table 'product-classifications.tsv')) {
                if ([string]::IsNullOrWhiteSpace([string]$c.release)) { continue }
                if (-not $map.ContainsKey([string]$c.product_title)) { continue }
                foreach ($m in $map[[string]$c.product_title]) {
                    Emit-Row (@($m.family,$c.product_title,$c.release,$c.specific_release_family,$c.broad_release_family,$c.confidence)) (
                        'Family: '+$m.family+' | Product: '+$c.product_title+' | Release: '+$c.release+' | Specific release family: '+$c.specific_release_family+' | Broad release: '+$c.broad_release_family
                    )
                }
            }
        }
        default {
            Fail 2 ('Unsupported operation: ' + $Operation)
        }
    }
    if ($script:Emitted -eq 0) { exit 1 }
    exit 0
} catch {
    Fail 5 $_.Exception.Message
}
:_MVSProductFamilyQuery_end
