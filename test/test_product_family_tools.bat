@echo off
:setup
REM Standalone product-family feature regression.
setlocal DisableDelayedExpansion
set "app.version=0.1.3"
set "app.name=test_product_family_tools"
set "app.rc=0"
set "app.self=%~f0"
set "mvspf_caller=%~nx0"
set "mvspf_version=%app.version%"
set "mvspf_project_version=0.16.4"
for %%I in ("%~dp0..") do set "mvspf_root=%%~fI"
:main
set "RunPowerShellFromLabel.function=MVSProductFamilyTest"
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

:_MVSProductFamilyTest_start
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$Root = [string]$env:mvspf_root
$Caller = [string]$env:mvspf_caller
$Version = [string]$env:mvspf_version
$ProjectVersion = [string]$env:mvspf_project_version
$script:Total = 106
$script:Index = 0
$script:Passed = 0
$script:Failed = 0

function Write-Line { param([AllowEmptyString()][string]$Text) [Console]::Out.WriteLine($Text) }
function Progress-Prefix {
    $remaining=[Math]::Max(0,$script:Total-$script:Index)
    return ('[MVS '+$ProjectVersion+'] [TEST '+$script:Index+'/'+$script:Total+' | remaining='+$remaining+']')
}
function Pass { param([string]$Name) $script:Passed++; $script:Index++; Write-Line ((Progress-Prefix) + ' [PASS] ' + $Name) }
function FailCase { param([string]$Name,[string]$Reason) $script:Failed++; $script:Index++; Write-Line ((Progress-Prefix) + ' [FAIL] ' + $Name + ' - ' + $Reason) }

function Invoke-Batch {
    param([string]$ToolPath,[object[]]$ToolArgs)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = if ([string]::IsNullOrWhiteSpace($env:ComSpec)) { 'cmd.exe' } else { $env:ComSpec }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.EnvironmentVariables['PF_TOOL'] = $ToolPath
    $parts = New-Object System.Collections.ArrayList
    [void]$parts.Add('"%PF_TOOL%"')
    for ($i=0; $i -lt $ToolArgs.Count; $i++) {
        $name = 'PF_ARG' + $i
        $psi.EnvironmentVariables[$name] = [string]$ToolArgs[$i]
        [void]$parts.Add(('"%'+$name+'%"'))
    }
    $psi.Arguments = '/d /s /c "' + ($parts -join ' ') + '"'
    if ($psi.PSObject.Properties.Name -contains 'StandardOutputEncoding') {
        $psi.StandardOutputEncoding = $utf8
        $psi.StandardErrorEncoding = $utf8
    }
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()
    $outTask = $process.StandardOutput.ReadToEndAsync()
    $errTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $outTask.Result.Replace("`r`n","`n").TrimEnd("`r","`n")
    $stderr = $errTask.Result.Replace("`r`n","`n").TrimEnd("`r","`n")
    return [pscustomobject]@{rc=$process.ExitCode;stdout=$stdout;stderr=$stderr}
}

function Assert-Exists {
    param([string]$Name,[string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Leaf) { Pass $Name } else { FailCase $Name ('missing: ' + $Path) }
}
function Assert-Semantic {
    param([string]$Name,[bool]$Condition,[string]$Reason)
    if ($Condition) { Pass $Name } else { FailCase $Name $Reason }
}
function Assert-QueryPositive {
    param([string]$ToolName,[string]$Pattern)
    $run = Invoke-Batch (Join-Path $Root ($ToolName+'.bat')) @($OutputRoot,$Pattern)
    if ($run.rc -eq 0 -and -not [string]::IsNullOrWhiteSpace($run.stdout) -and [string]::IsNullOrWhiteSpace($run.stderr)) {
        Pass ($ToolName+' positive')
    } else {
        FailCase ($ToolName+' positive') ('rc='+$run.rc+' stdout='+$run.stdout+' stderr='+$run.stderr)
    }
}
function Assert-QueryNoResult {
    param([string]$ToolName)
    $run = Invoke-Batch (Join-Path $Root ($ToolName+'.bat')) @($OutputRoot,'__MVS_FAMILY_NO_MATCH_9E3779B97F4A7C15__')
    if ($run.rc -eq 1 -and [string]::IsNullOrWhiteSpace($run.stdout) -and [string]::IsNullOrWhiteSpace($run.stderr)) {
        Pass ($ToolName+' no-result')
    } else {
        FailCase ($ToolName+' no-result') ('rc='+$run.rc+' stdout='+$run.stdout+' stderr='+$run.stderr)
    }
}

Write-Line ('Project: MVS Explorer Toolkit '+$ProjectVersion)
Write-Line ('Test suite: '+$Caller+' | test version '+$Version+' | expected assertions '+$script:Total)
$Fixture = Join-Path (Join-Path $Root 'test') 'test-mvs-product-family'
if (Test-Path -LiteralPath $Fixture -PathType Container) { Pass 'product-family synthetic archive present' } else { FailCase 'product-family synthetic archive present' ('missing: '+$Fixture) }

$OutputRoot = Join-Path $env:TEMP ('mvs-product-family-test-'+[guid]::NewGuid().ToString('N'))
$Builder = Join-Path $Root 'build_mvs_product_family_index.bat'
$Overrides = Join-Path $Fixture 'family-overrides.tsv'
$buildRun = Invoke-Batch $Builder @($Fixture,$OutputRoot,$Overrides)
if ($buildRun.rc -eq 0 -and [string]::IsNullOrWhiteSpace($buildRun.stderr)) {
    Pass 'build_mvs_product_family_index'
} else {
    FailCase 'build_mvs_product_family_index' ('rc='+$buildRun.rc+' stderr='+$buildRun.stderr)
}

$required = @(
    'family-nodes.tsv',
    'family-parent-relationships.tsv',
    'classification-rules.tsv',
    'product-classifications.tsv',
    'product-family-memberships.tsv',
    'product-ids.tsv',
    'product-dates.tsv',
    'product-files.tsv',
    'product-hashes.tsv',
    'product-notes.tsv',
    'product-snapshots.tsv',
    'unclassified-products.tsv',
    'overrides-applied.tsv',
    'family-index-summary.txt'
)
foreach ($name in $required) { Assert-Exists ('index file '+$name) (Join-Path $OutputRoot $name) }

try {
    $classifications = @(Import-Csv -LiteralPath (Join-Path $OutputRoot 'product-classifications.tsv') -Delimiter "`t" -Encoding UTF8)
    $memberships = @(Import-Csv -LiteralPath (Join-Path $OutputRoot 'product-family-memberships.tsv') -Delimiter "`t" -Encoding UTF8)
    $unclassified = @(Import-Csv -LiteralPath (Join-Path $OutputRoot 'unclassified-products.tsv') -Delimiter "`t" -Encoding UTF8)
    $overrides = @(Import-Csv -LiteralPath (Join-Path $OutputRoot 'overrides-applied.tsv') -Delimiter "`t" -Encoding UTF8)
    $notes = @(Import-Csv -LiteralPath (Join-Path $OutputRoot 'product-notes.tsv') -Delimiter "`t" -Encoding UTF8)

    $ocs = @($classifications | Where-Object { $_.product_title -eq 'Microsoft Office Communications Server 2007 Standard Edition (English)' })
    Assert-Semantic 'OCS broad/product/release hierarchy' ($ocs.Count -eq 1 -and $ocs[0].broad_family -eq 'Microsoft Office' -and $ocs[0].product_family -eq 'Microsoft Office Communications Server' -and $ocs[0].release -eq '2007' -and $ocs[0].specific_release_family -eq 'Microsoft Office Communications Server 2007' -and $ocs[0].broad_release_family -eq 'Microsoft Office 2007') 'unexpected OCS classification'

    $proof = @($classifications | Where-Object { $_.product_title -like 'Office 2007 Proofing Tools*' })
    Assert-Semantic 'Proofing Tools remains distinct family' ($proof.Count -eq 1 -and $proof[0].product_family -eq 'Microsoft Office Proofing Tools' -and $proof[0].broad_release_family -eq 'Microsoft Office 2007') 'unexpected proofing classification'

    $sdk = @($classifications | Where-Object { $_.product_title -like 'Microsoft Office System Developer Kit 3.0*' })
    Assert-Semantic 'Office SDK remains distinct family' ($sdk.Count -eq 1 -and $sdk[0].product_family -eq 'Microsoft Office System Developer Kit' -and $sdk[0].release -eq '3.0' -and [string]::IsNullOrEmpty($sdk[0].broad_release_family)) 'unexpected SDK classification'

    $sqlAlias = @($classifications | Where-Object { $_.product_title -eq 'SQL Server 2019 Standard Edition (English)' })
    Assert-Semantic 'SQL Server leading alias canonicalizes' ($sqlAlias.Count -eq 1 -and $sqlAlias[0].broad_family -eq 'Microsoft SQL Server' -and $sqlAlias[0].product_family -eq 'Microsoft SQL Server' -and $sqlAlias[0].rule_id -eq 'CURATED_ALIAS_PREFIX') 'unexpected SQL Server alias classification'

    $windowsAlias = @($classifications | Where-Object { $_.product_title -eq 'Windows Server 2019 Standard (English)' })
    Assert-Semantic 'Windows leading alias canonicalizes' ($windowsAlias.Count -eq 1 -and $windowsAlias[0].broad_family -eq 'Microsoft Windows' -and $windowsAlias[0].product_family -eq 'Microsoft Windows Server' -and $windowsAlias[0].rule_id -eq 'CURATED_ALIAS_PREFIX') 'unexpected Windows alias classification'

    $agentsAlias = @($classifications | Where-Object { $_.product_title -eq 'Agents for Visual Studio 2012 (English)' })
    Assert-Semantic 'Visual Studio agent alias keeps broad and product family' ($agentsAlias.Count -eq 1 -and $agentsAlias[0].broad_family -eq 'Microsoft Visual Studio' -and $agentsAlias[0].product_family -eq 'Microsoft Visual Studio Agents' -and $agentsAlias[0].broad_release_family -eq 'Microsoft Visual Studio 2012') 'unexpected Visual Studio agent classification'

    $officeOnlineAlias = @($classifications | Where-Object { $_.product_title -eq 'Office Online Server (Updated November 2018) (x64) - DVD (English)' })
    $officeOnlineExplicit = @($classifications | Where-Object { $_.product_title -eq 'Office Online Server 2019 (x64) - DVD (English)' })
    Assert-Semantic 'Office Online update stamp is not a release' ($officeOnlineAlias.Count -eq 1 -and $officeOnlineAlias[0].broad_family -eq 'Microsoft Office' -and $officeOnlineAlias[0].product_family -eq 'Microsoft Office Online Server' -and [string]::IsNullOrEmpty($officeOnlineAlias[0].release) -and [string]::IsNullOrEmpty($officeOnlineAlias[0].specific_release_family) -and [string]::IsNullOrEmpty($officeOnlineAlias[0].broad_release_family) -and $officeOnlineExplicit.Count -eq 1 -and $officeOnlineExplicit[0].release -eq '2019' -and $officeOnlineExplicit[0].specific_release_family -eq 'Microsoft Office Online Server 2019' -and $officeOnlineExplicit[0].broad_release_family -eq 'Microsoft Office 2019') 'Office Online update/explicit release distinction failed'

    $windowsUpdated = @($classifications | Where-Object { $_.product_title -eq 'Windows 10 (business editions), version 1809 (Updated Jan 2020) (x64) - DVD (English)' })
    Assert-Semantic 'Windows leading release beats update year' ($windowsUpdated.Count -eq 1 -and $windowsUpdated[0].broad_family -eq 'Microsoft Windows' -and $windowsUpdated[0].release -eq '10' -and $windowsUpdated[0].broad_release_family -eq 'Microsoft Windows 10') 'Windows update year leaked into release hierarchy'

    $dotnetVersion = @($classifications | Where-Object { $_.product_title -eq '.NET Framework 4.6 ClickOnce Bootstrapper for Visual Studio 2013 (x86 and x64) - (Multiple Languages)' })
    Assert-Semantic '.NET semantic version beats referenced year' ($dotnetVersion.Count -eq 1 -and $dotnetVersion[0].broad_family -eq 'Microsoft .NET' -and $dotnetVersion[0].release -eq '4.6' -and $dotnetVersion[0].broad_release_family -eq 'Microsoft .NET 4.6') '.NET referenced year incorrectly became release'

    $rUpdated = @($classifications | Where-Object { $_.product_title -eq 'Microsoft R Client 3.3.2 (Updated Dec 2016) (x64) - (English)' })
    Assert-Semantic 'semantic version beats update timestamp' ($rUpdated.Count -eq 1 -and $rUpdated[0].status -eq 'review' -and $rUpdated[0].release -eq '3.3.2' -and $rUpdated[0].broad_release_family -eq 'Microsoft R 3.3.2') 'update timestamp incorrectly became generic release'

    $serverVersion = @($classifications | Where-Object { $_.product_title -eq 'Windows Server, version 1809 (updated March 2019) (x64) - DVD (English)' })
    Assert-Semantic 'explicit non-year version beats update timestamp' ($serverVersion.Count -eq 1 -and $serverVersion[0].product_family -eq 'Microsoft Windows Server' -and $serverVersion[0].release -eq '1809' -and $serverVersion[0].specific_release_family -eq 'Microsoft Windows Server 1809' -and [string]::IsNullOrEmpty($serverVersion[0].broad_release_family)) 'Windows Server version/update distinction failed'

    Assert-Semantic 'embedded Office reference is not ownership' (@($unclassified | Where-Object { $_.product_title -eq 'Contoso Security for Microsoft Office Communications Server 2007' }).Count -eq 1) 'embedded Office reference was classified'
    Assert-Semantic 'FabriKam embedded Office reference is not ownership' (@($unclassified | Where-Object { $_.product_title -like 'FabriKam 3.1:*' }).Count -eq 1) 'FabriKam reference was classified'

    $review = @($classifications | Where-Object { $_.product_title -eq 'Microsoft Mystery Suite 1.0' })
    Assert-Semantic 'generic Microsoft stem is review confidence' ($review.Count -eq 1 -and $review[0].status -eq 'review' -and $review[0].confidence -eq 'review') 'generic Microsoft title did not enter review tier'

    Assert-Semantic 'exact-title override applied' (@($overrides | Where-Object { $_.product_title -eq 'Contoso Office Add-in 1.0' -and $_.action -eq 'set' }).Count -eq 1 -and @($memberships | Where-Object { $_.product_title -eq 'Contoso Office Add-in 1.0' -and $_.family -eq 'Microsoft Office Add-ins' }).Count -eq 1) 'override classification missing'

    $rawOkay = $true
    foreach ($note in $notes) {
        $sha = [string]$note.raw_html_sha256
        $path = Join-Path (Join-Path $OutputRoot 'raw-html') ($sha+'.html')
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $rawOkay=$false; break }
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        try { $actual = ([BitConverter]::ToString($hasher.ComputeHash([IO.File]::ReadAllBytes($path)))).Replace('-','').ToLowerInvariant() } finally { $hasher.Dispose() }
        if ($actual -ne $sha) { $rawOkay=$false; break }
    }
    Assert-Semantic 'raw note HTML references are content-addressed' $rawOkay 'raw HTML reference/hash mismatch'
} catch {
    for ($i=0; $i -lt 16; $i++) { FailCase ('semantic assertion '+($i+1)) $_.Exception.Message }
}


$CompactRoot = Join-Path $env:TEMP ('mvs-product-family-compact-test-'+[guid]::NewGuid().ToString('N'))
$CompactBuilder = Join-Path $Root 'build_mvs_product_family_compact_index.bat'
$compactRun = Invoke-Batch $CompactBuilder @($OutputRoot,$CompactRoot)
if ($compactRun.rc -eq 0 -and [string]::IsNullOrWhiteSpace($compactRun.stderr)) {
    Pass 'build_mvs_product_family_compact_index'
} else {
    FailCase 'build_mvs_product_family_compact_index' ('rc='+$compactRun.rc+' stderr='+$compactRun.stderr)
}

$compactReason = ''
$requiredCompactOkay = $false
$collapsedOkay = $false
$snapshotRefsOkay = $false
$metadataOkay = $false
$rawCompactOkay = $false
$filenameCollisionOkay = $false
$productConflictOkay = $false
$aliasOkay = $false
$uniqueGlobalHashOkay = $false
try {
    $compactRequired = @(
        'compact-index-summary.txt',
        'snapshot-catalog.tsv',
        'snapshot-sets.tsv',
        'product-ids-all-ever.tsv',
        'product-dates-all-ever.tsv',
        'product-files-all-ever.tsv',
        'product-file-hashes-all-ever.tsv',
        'file-hashes-all-ever.tsv',
        'product-notes-all-ever.tsv',
        'product-presence-all-ever.tsv',
        'filename-hash-conflicts.tsv',
        'filename-hash-conflict-details.tsv',
        'product-file-hash-conflicts.tsv',
        'hash-filename-aliases.tsv',
        'product-classifications.tsv',
        'product-family-memberships.tsv'
    )
    $requiredCompactOkay = $true
    foreach ($name in $compactRequired) {
        if (-not (Test-Path -LiteralPath (Join-Path $CompactRoot $name) -PathType Leaf)) { $requiredCompactOkay=$false; break }
    }

    $rawHashRows = @(Import-Csv -LiteralPath (Join-Path $OutputRoot 'product-hashes.tsv') -Delimiter "`t" -Encoding UTF8)
    $compactHashRows = @(Import-Csv -LiteralPath (Join-Path $CompactRoot 'product-file-hashes-all-ever.tsv') -Delimiter "`t" -Encoding UTF8)
    $collapsedOkay = ($compactHashRows.Count -lt $rawHashRows.Count)

    $snapshotSets = @(Import-Csv -LiteralPath (Join-Path $CompactRoot 'snapshot-sets.tsv') -Delimiter "`t" -Encoding UTF8)
    $setIds = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($s in $snapshotSets) { [void]$setIds.Add([string]$s.snapshot_set_id) }
    $snapshotRefsOkay = $true
    foreach ($r in $compactHashRows) {
        if (-not $setIds.Contains([string]$r.snapshot_set_id)) { $snapshotRefsOkay=$false; break }
    }

    $sourceClassBytes = [IO.File]::ReadAllBytes((Join-Path $OutputRoot 'product-classifications.tsv'))
    $compactClassBytes = [IO.File]::ReadAllBytes((Join-Path $CompactRoot 'product-classifications.tsv'))
    $metadataOkay = [Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($sourceClassBytes,$compactClassBytes)

    $rawCompactOkay = $true
    $sourceRaw = @(Get-ChildItem -LiteralPath (Join-Path $OutputRoot 'raw-html') -File | Sort-Object Name)
    $compactRaw = @(Get-ChildItem -LiteralPath (Join-Path $CompactRoot 'raw-html') -File | Sort-Object Name)
    if ($sourceRaw.Count -ne $compactRaw.Count) { $rawCompactOkay=$false }
    if ($rawCompactOkay) {
        for ($i=0; $i -lt $sourceRaw.Count; $i++) {
            if ($sourceRaw[$i].Name -ne $compactRaw[$i].Name -or $sourceRaw[$i].Length -ne $compactRaw[$i].Length) { $rawCompactOkay=$false; break }
        }
    }

    $filenameConflicts = @(Import-Csv -LiteralPath (Join-Path $CompactRoot 'filename-hash-conflicts.tsv') -Delimiter "`t" -Encoding UTF8)
    $filenameCollisionOkay = (@($filenameConflicts | Where-Object { $_.filename -eq 'shared-collision.bin' -and $_.conflict_type -eq 'CROSS_PRODUCT_FILENAME_REUSE' }).Count -eq 1)

    $productConflicts = @(Import-Csv -LiteralPath (Join-Path $CompactRoot 'product-file-hash-conflicts.tsv') -Delimiter "`t" -Encoding UTF8)
    $productConflictOkay = (@($productConflicts | Where-Object { $_.product_title -eq 'Office 2007 Proofing Tools (x86) - DVD (English)' -and $_.filename -eq 'office2007-proofing.iso' -and [int]$_.distinct_hashes -eq 2 }).Count -eq 1)

    $aliases = @(Import-Csv -LiteralPath (Join-Path $CompactRoot 'hash-filename-aliases.tsv') -Delimiter "`t" -Encoding UTF8)
    $aliasOkay = (@($aliases | Where-Object { $_.hash -eq 'abababababababababababababababababababab' -and $_.filenames -like '*same-payload-a.bin*' -and $_.filenames -like '*same-payload-b.bin*' }).Count -eq 1)

    $globalHashes = @(Import-Csv -LiteralPath (Join-Path $CompactRoot 'file-hashes-all-ever.tsv') -Delimiter "`t" -Encoding UTF8)
    $seenGlobal = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $uniqueGlobalHashOkay = $true
    foreach ($r in $globalHashes) {
        $key = ([string]$r.filename)+[char]31+([string]$r.algorithm)+[char]31+([string]$r.hash)
        if (-not $seenGlobal.Add($key)) { $uniqueGlobalHashOkay=$false; break }
    }
} catch {
    $compactReason = $_.Exception.Message
}
Assert-Semantic 'compact index required normalized files' $requiredCompactOkay $compactReason
Assert-Semantic 'compact hash rows collapse repeated observations' $collapsedOkay $compactReason
Assert-Semantic 'compact snapshot-set references resolve' $snapshotRefsOkay $compactReason
Assert-Semantic 'compact index preserves classification metadata byte-for-byte' $metadataOkay $compactReason
Assert-Semantic 'compact raw-note store is preserved' $rawCompactOkay $compactReason
Assert-Semantic 'compact filename collision distinguishes cross-product reuse' $filenameCollisionOkay $compactReason
Assert-Semantic 'compact same-product hash disagreement is highlighted' $productConflictOkay $compactReason
Assert-Semantic 'compact hash alias across filenames is highlighted' $aliasOkay $compactReason
Assert-Semantic 'compact global file-hash keys are unique' $uniqueGlobalHashOkay $compactReason

$queries = @(
    [pscustomobject]@{base='product_titles_from_family';pattern='Microsoft Office'},
    [pscustomobject]@{base='product_families_from_title';pattern='Microsoft Office Communications Server 2007 Standard Edition (English)'},
    [pscustomobject]@{base='product_ids_from_family';pattern='Microsoft Office Communications Server'},
    [pscustomobject]@{base='product_families_from_id';pattern='101'},
    [pscustomobject]@{base='product_dates_from_family';pattern='Microsoft Office 2007'},
    [pscustomobject]@{base='product_families_from_date';pattern='2007-10-01T00:00:00Z'},
    [pscustomobject]@{base='product_filenames_from_family';pattern='Microsoft Office 2007'},
    [pscustomobject]@{base='product_families_from_filename';pattern='ocs2007-standard.iso'},
    [pscustomobject]@{base='product_hashes_from_family';pattern='Microsoft Office Communications Server'},
    [pscustomobject]@{base='product_families_from_hash';pattern='1111111111111111111111111111111111111111'},
    [pscustomobject]@{base='product_snapshots_from_family';pattern='Microsoft Office'},
    [pscustomobject]@{base='product_families_from_snapshot';pattern='mvs_2020-01-02'},
    [pscustomobject]@{base='product_family_parents_from_family';pattern='Microsoft Office Communications Server 2007'},
    [pscustomobject]@{base='product_family_children_from_family';pattern='Microsoft Office'},
    [pscustomobject]@{base='product_notes_from_family';pattern='Microsoft Office Communications Server'},
    [pscustomobject]@{base='product_releases_from_family';pattern='Microsoft Office'}
)

foreach ($q in $queries) {
    foreach ($prefix in @('print','read')) {
        Assert-QueryPositive ($prefix+'_mvs_'+$q.base) $q.pattern
    }
}
foreach ($q in $queries) {
    foreach ($prefix in @('print','read')) {
        Assert-QueryNoResult ($prefix+'_mvs_'+$q.base)
    }
}

Write-Line ('SUMMARY: passed='+$script:Passed+' failed='+$script:Failed)
if ($script:Passed + $script:Failed -ne 106) {
    FailCase 'assertion accounting' ('expected 106 assertions, got '+($script:Passed+$script:Failed))
}
if ($script:Failed -gt 0) {
    Write-Line ('Artifacts retained at: '+$OutputRoot)
    if (Test-Path -LiteralPath $CompactRoot) { Write-Line ('Compact artifacts retained at: '+$CompactRoot) }
    exit 1
}
if (Test-Path -LiteralPath $OutputRoot) { Remove-Item -LiteralPath $OutputRoot -Recurse -Force }
if (Test-Path -LiteralPath $CompactRoot) { Remove-Item -LiteralPath $CompactRoot -Recurse -Force }
exit 0
:_MVSProductFamilyTest_end
