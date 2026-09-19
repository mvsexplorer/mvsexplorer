@echo off
:setup
REM One-command full test -> database build -> database validation -> all family query tools -> ZIP/hardlink pipeline.
setlocal DisableDelayedExpansion
set "app.version=1.1.0"
set "app.name=all_test_then_all_database_then_test_database_and_all_tools"
set "app.rc=0"
set "app.self=%~f0"
set "mvspipe_project_version=0.20.0"
set "mvspipe_project_root=%~dp0"
set "mvspipe_caller=%~nx0"
set "mvspipe_arg1=%~1"
set "mvspipe_arg2=%~2"
set "mvspipe_arg3=%~3"
set "mvspipe_arg4=%~4"
set "mvspipe_arg5=%~5"
set "mvspipe_arg6=%~6"
set "mvspipe_arg7=%~7"
set "mvspipe_arg8=%~8"
set "mvspipe_arg9=%~9"
:main
set "RunPowerShellFromLabel.function=MVSAllPipeline"
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

:_MVSAllPipeline_start
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

$ProjectRoot = ([string]$env:mvspipe_project_root).TrimEnd('\','/')
$ProjectVersion = [string]$env:mvspipe_project_version
$Caller = [string]$env:mvspipe_caller
$RawArgs = @(
    [string]$env:mvspipe_arg1,[string]$env:mvspipe_arg2,[string]$env:mvspipe_arg3,[string]$env:mvspipe_arg4,
    [string]$env:mvspipe_arg5,[string]$env:mvspipe_arg6,[string]$env:mvspipe_arg7,[string]$env:mvspipe_arg8,
    [string]$env:mvspipe_arg9
)
$InvocationDirectory = (Get-Location).Path
$HardLinkRoot = $ProjectRoot
$PipelineStarted = Get-Date
$PipelineStopwatch = [Diagnostics.Stopwatch]::StartNew()
$PhaseTotal = 10
$script:PhaseIndex = 0
$script:MasterWriter = $null
$script:PhaseWriter = $null
$script:LogsRoot = $null
$script:LogZip = $null
$script:HardLinks = New-Object System.Collections.ArrayList
$script:DatabaseRecords = New-Object System.Collections.ArrayList
$script:TestResults = ''
$script:ResumeStructureResults = ''
$script:DbValidationRoot = ''
$script:ArchiveDatabase = ''
$script:FamilyDatabase = ''
$script:CompactDatabase = ''
$StrictPerformance = $false
$LogicalCores = [Math]::Max(1,[Environment]::ProcessorCount)
$WorkerStart = [Math]::Max(1,[int][Math]::Ceiling($LogicalCores / 4.0))
$WorkerMax = $LogicalCores
$WorkerMode = 'adaptive'
$WorkersOptionSeen = $false
$StartWorkersOptionSeen = $false
$MaxWorkersOptionSeen = $false
$ArchiveInput = ''
$OutputInput = ''
$ResumeMode = $false
$ResumeArchiveInput = ''
$ResumeFamilyInput = ''
$ResumeCompactInput = ''
$ResumeTestResultsInput = ''

function Get-StatusTokenColor {
    param([string]$Token,[string]$Suffix)
    $t=$Token.ToUpperInvariant()
    if($t-eq'PASS'){return 'Green'}
    if($t-eq'FAIL'-or$t-eq'FAILED'){
        if($Suffix-match'^\s*=\s*0(?:\D|$)'){return ''}
        return 'Red'
    }
    if($t-eq'ERROR'-or$t-eq'ERRORS'){
        if($Suffix-match'^\s*:\s*0(?:\D|$)'){return ''}
        return 'Red'
    }
    if($t-eq'WARN'-or$t-eq'WARNING'-or$t-eq'WARNINGS'-or$t-eq'SKIP'-or$t-eq'QUALITY FLAGS'){
        if($t-eq'WARNINGS'-and$Suffix-match'^\s*:\s*0(?:\D|$)'){return ''}
        return 'Yellow'
    }
    return ''
}
function Write-ConsoleTokenized {
    param([AllowEmptyString()][string]$Text,[switch]$ErrorStream)
    $writer=if($ErrorStream){[Console]::Error}else{[Console]::Out}
    $redirected=if($ErrorStream){[Console]::IsErrorRedirected}else{[Console]::IsOutputRedirected}
    if($redirected){$writer.WriteLine($Text);return}
    $matches=[regex]::Matches($Text,'(?i)\bPASS\b|\bFAIL(?:ED)?\b|\bWARN(?:ING|INGS)?\b|\bERRORS?\b|\bSKIP\b|quality flags')
    if($matches.Count-eq0){$writer.WriteLine($Text);return}
    try{
        $old=[Console]::ForegroundColor
        $pos=0
        foreach($m in $matches){
            if($m.Index-gt$pos){$writer.Write($Text.Substring($pos,$m.Index-$pos))}
            $suffix=$Text.Substring($m.Index+$m.Length)
            $color=Get-StatusTokenColor $m.Value $suffix
            if(-not[string]::IsNullOrWhiteSpace($color)){[Console]::ForegroundColor=[System.ConsoleColor]$color}
            $writer.Write($m.Value)
            [Console]::ForegroundColor=$old
            $pos=$m.Index+$m.Length
        }
        if($pos-lt$Text.Length){$writer.Write($Text.Substring($pos))}
        $writer.WriteLine()
        [Console]::ForegroundColor=$old
    }catch{
        try{[Console]::ResetColor()}catch{}
        $writer.WriteLine($Text)
    }
}
function Write-Console {
    param([AllowEmptyString()][string]$Text)
    Write-ConsoleTokenized $Text
}
function Write-Log {
    param([AllowEmptyString()][string]$Text)
    Write-ConsoleTokenized $Text
    if($null-ne$script:MasterWriter){$script:MasterWriter.WriteLine($Text);$script:MasterWriter.Flush()}
}
function Write-ErrLog {
    param([string]$Text)
    Write-ConsoleTokenized $Text -ErrorStream
    if($null-ne$script:MasterWriter){$script:MasterWriter.WriteLine($Text);$script:MasterWriter.Flush()}
}
function Clean-Tsv {
    param([AllowNull()][object]$Value)
    if($null-eq$Value){return ''}
    return ([string]$Value).Replace("`t",' ').Replace("`r",' ').Replace("`n",' ')
}
function Show-Usage {
    Write-Console ('MVS Explorer Toolkit all-test/database/all-tools pipeline '+$ProjectVersion)
    Write-Console ('Usage: '+$Caller+' [mvs-dumps-root] [--start-workers N] [--max-workers N] [--workers N] [--output-root DIR] [--strict-performance]')
    Write-Console ('       '+$Caller+' [mvs-dumps-root] --resume-built ARCHIVE_DB FAMILY_DB COMPACT_DB [--resume-test-results DIR] [--output-root DIR]')
    Write-Console ('Default archive: '+(Join-Path (Split-Path -Parent $ProjectRoot) 'mvs_dumps_archive'))
    Write-Console ('Default output root: '+(Split-Path -Parent $ProjectRoot))
    Write-Console ('Default worker policy: adaptive, start=ceil(logical CPUs / 4), max=logical CPUs. --workers N retains fixed-concurrency compatibility.')
    Write-Console 'Runs all tests first. Database generation starts only after the test gate passes.'
    Write-Console 'Creates archive-analysis, full family, and compact family databases; validates them; runs all family query tools; zips outputs and hardlinks the ZIPs into the invocation directory.'
    Write-Console 'Resume mode reuses already-built databases, revalidates them, runs all 32 family query tools, then performs ZIP/log/hardlink packaging without rebuilding.'
}
function Get-WorkerArguments {
    if($WorkerMode -eq 'fixed'){return @('--workers',[string]$WorkerStart)}
    return @('--start-workers',[string]$WorkerStart,'--max-workers',[string]$WorkerMax)
}
function Resolve-FullPath {
    param([string]$Value,[string]$Base)
    if([IO.Path]::IsPathRooted($Value)){return [IO.Path]::GetFullPath($Value)}
    return [IO.Path]::GetFullPath((Join-Path $Base $Value))
}
function New-UniquePath {
    param([string]$Base)
    if(-not(Test-Path -LiteralPath $Base)){return $Base}
    for($i=2;$i-lt1000;$i++){
        $candidate=$Base+'-'+$i
        if(-not(Test-Path -LiteralPath $candidate)){return $candidate}
    }
    throw ('Could not allocate unique path from '+$Base)
}
function Begin-Phase {
    param([string]$Name)
    $script:PhaseIndex++
    Write-Log ''
    Write-Log ('================================================================================')
    Write-Log ('[PROJECT '+$ProjectVersion+'] [PHASE '+$script:PhaseIndex+'/'+$PhaseTotal+'] '+$Name)
    Write-Log ('Started: '+(Get-Date).ToString('o'))
    return [Diagnostics.Stopwatch]::StartNew()
}
function Record-Phase {
    param([string]$Name,[string]$Status,[Diagnostics.Stopwatch]$Stopwatch,[int]$Rc,[string]$Detail)
    $Stopwatch.Stop()
    if($null-ne$script:PhaseWriter){
        $script:PhaseWriter.WriteLine((
            @($script:PhaseIndex,$Name,$Status,$Rc,[long]$Stopwatch.ElapsedMilliseconds,(Get-Date).ToString('o'),$Detail) |
            ForEach-Object { Clean-Tsv $_ }
        ) -join "`t")
        $script:PhaseWriter.Flush()
    }
    Write-Log ('Finished: status='+$Status+' rc='+$Rc+' elapsed='+$Stopwatch.Elapsed.ToString())
}
function Invoke-ChildPhase {
    param([string]$Name,[string]$Tool,[object[]]$ToolArgs)
    $sw=Begin-Phase $Name
    $rc=1
    try{
        Write-Log ('Command: '+$Tool+' '+(@($ToolArgs)-join' '))
        $global:LASTEXITCODE=0
        $oldPreference=$ErrorActionPreference
        $ErrorActionPreference='Continue'
        & $Tool @ToolArgs 2>&1 | ForEach-Object { Write-Log ([string]$_) }
        $ErrorActionPreference=$oldPreference
        $rc=if($null-eq$LASTEXITCODE){0}else{[int]$LASTEXITCODE}
        if($rc-ne0){
            Record-Phase $Name 'FAIL' $sw $rc ('child returned '+$rc)
            throw ($Name+' failed with return code '+$rc)
        }
        Record-Phase $Name 'PASS' $sw $rc ''
    } catch {
        if($sw.IsRunning){Record-Phase $Name 'FAIL' $sw $rc $_.Exception.Message}
        throw
    }
}
function Invoke-InternalPhase {
    param([string]$Name,[scriptblock]$Action,[string]$Detail)
    $sw=Begin-Phase $Name
    try{
        & $Action
        Record-Phase $Name 'PASS' $sw 0 $Detail
    } catch {
        Record-Phase $Name 'FAIL' $sw 1 $_.Exception.Message
        throw
    }
}
function Get-NewestNewDirectory {
    param([string]$Parent,[string]$Filter,[string[]]$Before)
    $rows=@(Get-ChildItem -LiteralPath $Parent -Directory -Filter $Filter -ErrorAction SilentlyContinue |
        Where-Object {$Before -notcontains $_.FullName} |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1)
    if($rows.Count-eq0){return $null}
    return $rows[0].FullName
}
function Capture-TestResults {
    param([string]$TestParent,[string[]]$Before)
    $found=Get-NewestNewDirectory $TestParent 'test-results-*' $Before
    if([string]::IsNullOrWhiteSpace($found)){return ''}
    $script:TestResults=$found
    if(-not[string]::IsNullOrWhiteSpace($script:LogsRoot)-and(Test-Path -LiteralPath $found -PathType Container)){
        Copy-DirectoryTree $found (Join-Path $script:LogsRoot 'test-results')
    }
    return $found
}
function New-ZipFromDirectory {
    param([string]$Directory,[string]$ZipPath)
    Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    if(Test-Path -LiteralPath $ZipPath){Remove-Item -LiteralPath $ZipPath -Force}
    $dir=(Resolve-Path -LiteralPath $Directory).Path.TrimEnd('\','/')
    $base=[IO.Path]::GetFileName($dir)

    # ZIP entry timestamps are package metadata, not database evidence. In prior
    # resume runs archive-quality validation recreated deterministic text files
    # under quality-check/, changing only their LastWriteTime. CreateEntryFromFile
    # copied those dates into the ZIP and therefore changed the package SHA256
    # even when every file name and byte was identical. Normalize entry dates so
    # the ZIP checksum reflects content/order rather than validation wall-clock.
    $fixedZipTime=[DateTimeOffset]::ParseExact(
        '1980-01-01T00:00:00+00:00',
        'yyyy-MM-ddTHH:mm:sszzz',
        [Globalization.CultureInfo]::InvariantCulture
    )

    $fs=New-Object IO.FileStream($ZipPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $zip=New-Object IO.Compression.ZipArchive($fs,[IO.Compression.ZipArchiveMode]::Create,$false,$utf8)
    try{
        foreach($file in @(Get-ChildItem -LiteralPath $dir -File -Recurse | Sort-Object FullName)){
            $rel=$file.FullName.Substring($dir.Length).TrimStart('\','/').Replace('\','/')
            $entryName=$base+'/'+$rel
            $entry=$zip.CreateEntry($entryName,[IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime=$fixedZipTime
            $input=New-Object IO.FileStream($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
            try{
                $output=$entry.Open()
                try{
                    $input.CopyTo($output,65536)
                } finally {
                    $output.Dispose()
                }
            } finally {
                $input.Dispose()
            }
        }
    } finally {
        $zip.Dispose()
        $fs.Dispose()
    }
}
function Get-DirectoryStats {
    param([string]$Directory)
    $files=@(Get-ChildItem -LiteralPath $Directory -File -Recurse -ErrorAction Stop)
    $bytes=[long]0
    foreach($f in $files){$bytes+=[long]$f.Length}
    return [pscustomobject]@{files=$files.Count;bytes=$bytes}
}
function Add-DatabaseRecord {
    param([string]$Name,[string]$Path,[string]$ZipPath)
    $stats=Get-DirectoryStats $Path
    $zipHash=if(Test-Path -LiteralPath $ZipPath -PathType Leaf){(Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()}else{''}
    [void]$script:DatabaseRecords.Add([pscustomobject]@{
        name=$Name;path=$Path;zip_path=$ZipPath;zip_sha256=$zipHash;file_count=$stats.files;bytes=$stats.bytes
    })
}
function New-HardLink {
    param([string]$Target,[string]$Label)
    $link=Join-Path $HardLinkRoot ('SEND-ME-'+$Label+'-'+[IO.Path]::GetFileName($Target))
    if(Test-Path -LiteralPath $link){Remove-Item -LiteralPath $link -Force}
    [void](New-Item -ItemType HardLink -Path $link -Target $Target)
    [void]$script:HardLinks.Add($link)
    return $link
}
function Copy-DirectoryTree {
    param([string]$Source,[string]$Destination)
    if(Test-Path -LiteralPath $Destination){Remove-Item -LiteralPath $Destination -Recurse -Force}
    [void](New-Item -ItemType Directory -Path $Destination -Force)
    foreach($item in @(Get-ChildItem -LiteralPath $Source -Force)){
        Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
    }
}
function Read-KeyValueSummary {
    param([string]$Path)
    $map=@{}
    if([string]::IsNullOrWhiteSpace($Path)-or-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $map}
    foreach($line in [IO.File]::ReadAllLines($Path,$utf8)){
        $idx=$line.IndexOf(':')
        if($idx-le0){continue}
        $map[$line.Substring(0,$idx).Trim()]=$line.Substring($idx+1).Trim()
    }
    return $map
}
function Add-SummarySection {
    param([Collections.ArrayList]$Lines,[string]$Title,[hashtable]$Map,[string[]]$Keys)
    [void]$Lines.Add('')
    [void]$Lines.Add($Title)
    foreach($key in $Keys){if($Map.ContainsKey($key)){[void]$Lines.Add($key+': '+$Map[$key])}}
}
function Write-FinalFiles {
    param([string]$Status,[AllowEmptyString()][string]$ErrorMessage)
    if([string]::IsNullOrWhiteSpace($script:LogsRoot)){return }
    $summaryPath=Join-Path $script:LogsRoot 'pipeline-summary.txt'
    $pathsPath=Join-Path $script:LogsRoot 'database-paths.tsv'
    $lines=New-Object System.Collections.ArrayList
    [void]$lines.Add('MVS Explorer Toolkit complete pipeline summary')
    [void]$lines.Add('Project version: '+$ProjectVersion)
    [void]$lines.Add('Status: '+$Status)
    [void]$lines.Add('Started: '+$PipelineStarted.ToString('o'))
    [void]$lines.Add('Finished: '+(Get-Date).ToString('o'))
    [void]$lines.Add('Overall elapsed milliseconds: '+[long]$PipelineStopwatch.ElapsedMilliseconds)
    [void]$lines.Add('Overall duration: '+$PipelineStopwatch.Elapsed.ToString())
    [void]$lines.Add('Archive: '+$ArchiveRoot)
    [void]$lines.Add('Output root: '+$OutputRoot)
    [void]$lines.Add('Workers: '+$Workers)
    [void]$lines.Add('Strict performance: '+$StrictPerformance)
    if(-not[string]::IsNullOrWhiteSpace($ErrorMessage)){[void]$lines.Add('Error: '+$ErrorMessage)}
    if(-not[string]::IsNullOrWhiteSpace($script:TestResults)){[void]$lines.Add('Test results folder: '+$script:TestResults)}
    if(-not[string]::IsNullOrWhiteSpace($script:ResumeStructureResults)){[void]$lines.Add('Resume structure results folder: '+$script:ResumeStructureResults)}
    if(-not[string]::IsNullOrWhiteSpace($script:DbValidationRoot)){[void]$lines.Add('Database validation folder: '+$script:DbValidationRoot)}
    $testMap=Read-KeyValueSummary $(if(-not[string]::IsNullOrWhiteSpace($script:TestResults)){Join-Path $script:TestResults 'summary.txt'}else{''})
    Add-SummarySection $lines 'TEST ASSERTION SUMMARY' $testMap @('Passed','Failed','Skipped','Total assertions','Expected assertions')
    $archiveMap=Read-KeyValueSummary $(if(-not[string]::IsNullOrWhiteSpace($script:ArchiveDatabase)){Join-Path $script:ArchiveDatabase 'summary.txt'}else{''})
    Add-SummarySection $lines 'ARCHIVE LOGICAL CHECK SUMMARY' $archiveMap @('Planned invocations','Completed invocations','Remaining invocations','PASS','NO_RESULT','SOURCE_MISSING','FAIL')
    $dbMap=Read-KeyValueSummary $(if(-not[string]::IsNullOrWhiteSpace($script:DbValidationRoot)){Join-Path $script:DbValidationRoot 'summary.txt'}else{''})
    Add-SummarySection $lines 'GENERATED DATABASE VALIDATION SUMMARY' $dbMap @('Passed','Failed','Total','Family query tools executed','Duration')
    $familyMap=Read-KeyValueSummary $(if(-not[string]::IsNullOrWhiteSpace($script:FamilyDatabase)){Join-Path $script:FamilyDatabase 'family-index-summary.txt'}else{''})
    Add-SummarySection $lines 'FULL FAMILY DATABASE SUMMARY' $familyMap @('Snapshots','Classified/review products','Family memberships','Product file observations','Product hash observations','Product note observations','Unclassified/excluded products','Raw note HTML blobs')
    $compactMap=Read-KeyValueSummary $(if(-not[string]::IsNullOrWhiteSpace($script:CompactDatabase)){Join-Path $script:CompactDatabase 'compact-index-summary.txt'}else{''})
    Add-SummarySection $lines 'COMPACT FAMILY DATABASE SUMMARY' $compactMap @('Snapshots','Snapshot sets','Product files all-ever','Product file hashes all-ever','Global file-hash tuples','Filename+algorithm conflicts','Product+filename+algorithm hash disagreements','Hash aliases across filenames','Product notes all-ever','Raw note HTML blobs')
    [void]$lines.Add('')
    [void]$lines.Add('DATABASES')
    foreach($r in $script:DatabaseRecords){
        [void]$lines.Add($r.name+': '+$r.path)
        [void]$lines.Add($r.name+' ZIP: '+$r.zip_path)
        [void]$lines.Add($r.name+' ZIP SHA256: '+$r.zip_sha256)
        [void]$lines.Add($r.name+' files: '+$r.file_count)
        [void]$lines.Add($r.name+' bytes: '+$r.bytes)
    }
    [void]$lines.Add('')
    [void]$lines.Add('LOGS')
    [void]$lines.Add('Log folder: '+$script:LogsRoot)
    if(-not[string]::IsNullOrWhiteSpace($script:LogZip)){[void]$lines.Add('Log ZIP: '+$script:LogZip)}
    [void]$lines.Add('Master console log: '+(Join-Path $script:LogsRoot 'console.log'))
    [void]$lines.Add('Phase performance: '+(Join-Path $script:LogsRoot 'phase-performance.tsv'))
    [void]$lines.Add('')
    [void]$lines.Add('HARDLINKS IN TOOLKIT DIRECTORY')
    [void]$lines.Add('Hardlink folder: '+$HardLinkRoot)
    foreach($link in $script:HardLinks){[void]$lines.Add([string]$link)}
    [IO.File]::WriteAllText($summaryPath,(($lines -join [Environment]::NewLine)+[Environment]::NewLine),$utf8)

    $sw=New-Object IO.StreamWriter($pathsPath,$false,$utf8)
    $sw.NewLine="`r`n"
    try{
        $sw.WriteLine("name`tpath`tzip_path`tzip_sha256`tfile_count`tbytes")
        foreach($r in $script:DatabaseRecords){
            $sw.WriteLine((@($r.name,$r.path,$r.zip_path,$r.zip_sha256,$r.file_count,$r.bytes)|ForEach-Object{Clean-Tsv $_})-join"`t")
        }
    } finally {$sw.Dispose()}
}
function Finish-LogZip {
    if([string]::IsNullOrWhiteSpace($script:LogsRoot)){return }
    if([string]::IsNullOrWhiteSpace($script:LogZip)){return }
    New-ZipFromDirectory $script:LogsRoot $script:LogZip
}
function Print-FinalSummary {
    param([string]$Status)
    Write-Console ''
    Write-Console '================================================================================'
    Write-Console ('FINAL SUMMARY - MVS Explorer Toolkit '+$ProjectVersion)
    Write-Console ('Status: '+$Status)
    Write-Console ('Overall duration: '+$PipelineStopwatch.Elapsed.ToString())
    if(-not[string]::IsNullOrWhiteSpace($script:TestResults)){
        $tm=Read-KeyValueSummary (Join-Path $script:TestResults 'summary.txt')
        Write-Console ('Tests: passed='+$tm['Passed']+' failed='+$tm['Failed']+' skipped='+$tm['Skipped']+' total='+$tm['Total assertions'])
        Write-Console ('Test results: '+$script:TestResults)
    }
    if(-not[string]::IsNullOrWhiteSpace($script:ResumeStructureResults)){
        Write-Console ('Resume structure results: '+$script:ResumeStructureResults)
    }
    if(-not[string]::IsNullOrWhiteSpace($script:ArchiveDatabase)){
        $archiveSummaryPath=Join-Path $script:ArchiveDatabase 'summary.txt'
        if(Test-Path -LiteralPath $archiveSummaryPath -PathType Leaf){
            $am=Read-KeyValueSummary $archiveSummaryPath
            Write-Console ('Archive logical checks: completed='+$am['Completed invocations']+'/'+$am['Planned invocations']+' PASS='+$am['PASS']+' NO_RESULT='+$am['NO_RESULT']+' SOURCE_MISSING='+$am['SOURCE_MISSING']+' FAIL='+$am['FAIL'])
        } else {
            $testFailed=$false
            if(-not[string]::IsNullOrWhiteSpace($script:TestResults)){
                $tmForGate=Read-KeyValueSummary (Join-Path $script:TestResults 'summary.txt')
                if($tmForGate.ContainsKey('Failed') -and ([int]$tmForGate['Failed'] -gt 0)){$testFailed=$true}
            }
            if($testFailed){
                Write-Console 'Archive logical checks: NOT RUN - gated by failed test phase'
            } else {
                Write-Console 'Archive logical checks: NOT RUN - archive database summary unavailable'
            }
        }
    }
    if(-not[string]::IsNullOrWhiteSpace($script:DbValidationRoot)){
        $dm=Read-KeyValueSummary (Join-Path $script:DbValidationRoot 'summary.txt')
        Write-Console ('Database validation: passed='+$dm['Passed']+' failed='+$dm['Failed']+' total='+$dm['Total']+' family_query_tools='+$dm['Family query tools executed'])
    }
    foreach($r in $script:DatabaseRecords){
        Write-Console ($r.name+': '+$r.path)
        Write-Console ($r.name+' ZIP: '+$r.zip_path)
        Write-Console ($r.name+' ZIP SHA256: '+$r.zip_sha256)
    }
    Write-Console ('Logs: '+$script:LogsRoot)
    if(-not[string]::IsNullOrWhiteSpace($script:LogZip)){Write-Console ('Logs ZIP: '+$script:LogZip)}
    Write-Console ('Hardlink folder: '+$HardLinkRoot)
    Write-Console 'Hardlinks ready to grab/send:'
    foreach($link in $script:HardLinks){Write-Console ('  '+$link)}
}

# Parse arguments.
$args=New-Object System.Collections.ArrayList
foreach($a in $RawArgs){if(-not[string]::IsNullOrWhiteSpace($a)){[void]$args.Add($a)}}
for($i=0;$i-lt$args.Count;$i++){
    $a=[string]$args[$i]
    if(@('--help','-h','-?','/h','/?')-contains$a){Show-Usage;exit 0}
    if($a-eq'--workers'){
        if($StartWorkersOptionSeen -or $MaxWorkersOptionSeen){Write-Console 'ERROR: --workers cannot be combined with --start-workers/--max-workers';exit 2}
        $i++;if($i-ge$args.Count){Write-Console 'ERROR: --workers requires a value';exit 2}
        $n=0;if(-not[int]::TryParse([string]$args[$i],[ref]$n)-or$n-lt1-or$n-gt256){Write-Console 'ERROR: --workers must be 1..256';exit 2}
        $WorkerStart=$n;$WorkerMax=$n;$WorkerMode='fixed';$WorkersOptionSeen=$true;continue
    }
    if($a-eq'--start-workers'){
        if($WorkersOptionSeen){Write-Console 'ERROR: --start-workers cannot be combined with --workers';exit 2}
        $i++;if($i-ge$args.Count){Write-Console 'ERROR: --start-workers requires a value';exit 2}
        $n=0;if(-not[int]::TryParse([string]$args[$i],[ref]$n)-or$n-lt1-or$n-gt256){Write-Console 'ERROR: --start-workers must be 1..256';exit 2}
        $WorkerStart=$n;$StartWorkersOptionSeen=$true;continue
    }
    if($a-eq'--max-workers'){
        if($WorkersOptionSeen){Write-Console 'ERROR: --max-workers cannot be combined with --workers';exit 2}
        $i++;if($i-ge$args.Count){Write-Console 'ERROR: --max-workers requires a value';exit 2}
        $n=0;if(-not[int]::TryParse([string]$args[$i],[ref]$n)-or$n-lt1-or$n-gt256){Write-Console 'ERROR: --max-workers must be 1..256';exit 2}
        $WorkerMax=$n;$MaxWorkersOptionSeen=$true;continue
    }
    if($a-eq'--output-root'){
        $i++;if($i-ge$args.Count){Write-Console 'ERROR: --output-root requires a directory';exit 2}
        $OutputInput=[string]$args[$i];continue
    }
    if($a-eq'--resume-built'){
        if($ResumeMode){Write-Console 'ERROR: --resume-built may be specified only once';exit 2}
        if(($i+3)-ge$args.Count){Write-Console 'ERROR: --resume-built requires ARCHIVE_DB FAMILY_DB COMPACT_DB';exit 2}
        $ResumeMode=$true
        $ResumeArchiveInput=[string]$args[$i+1]
        $ResumeFamilyInput=[string]$args[$i+2]
        $ResumeCompactInput=[string]$args[$i+3]
        $i+=3
        continue
    }
    if($a-eq'--resume-test-results'){
        $i++;if($i-ge$args.Count){Write-Console 'ERROR: --resume-test-results requires a directory';exit 2}
        $ResumeTestResultsInput=[string]$args[$i];continue
    }
    if($a-eq'--strict-performance'){$StrictPerformance=$true;continue}
    if($a.StartsWith('-')){Write-Console ('ERROR: unknown option '+$a);exit 2}
    if(-not[string]::IsNullOrWhiteSpace($ArchiveInput)){Write-Console ('ERROR: unexpected argument '+$a);exit 2}
    $ArchiveInput=$a
}

if($WorkerMode -eq 'adaptive' -and $MaxWorkersOptionSeen -and -not $StartWorkersOptionSeen -and $WorkerStart -gt $WorkerMax){$WorkerStart=$WorkerMax}
if($WorkerMode -eq 'adaptive' -and $StartWorkersOptionSeen -and -not $MaxWorkersOptionSeen -and $WorkerStart -gt $WorkerMax){$WorkerMax=$WorkerStart}
if($WorkerStart -gt $WorkerMax){Write-Console 'ERROR: --start-workers cannot exceed --max-workers';exit 2}
$ParentRoot=Split-Path -Parent $ProjectRoot
if([string]::IsNullOrWhiteSpace($ArchiveInput)){$ArchiveInput=Join-Path $ParentRoot 'mvs_dumps_archive'}
$ArchiveRoot=Resolve-FullPath $ArchiveInput $InvocationDirectory
if(-not(Test-Path -LiteralPath $ArchiveRoot -PathType Container)){Write-Console ('ERROR: archive root not found: '+$ArchiveRoot);exit 2}
$OutputRoot=if([string]::IsNullOrWhiteSpace($OutputInput)){$ParentRoot}else{Resolve-FullPath $OutputInput $InvocationDirectory}
if(-not(Test-Path -LiteralPath $OutputRoot -PathType Container)){[void](New-Item -ItemType Directory -Path $OutputRoot -Force)}

$tag=Get-Date -Format 'yyyyMMdd-HHmmss'
$runStem=('mvs-'+$ProjectVersion+'-'+$tag)
if($ResumeMode){
    $PhaseTotal=7
    $ArchiveDatabase=Resolve-FullPath $ResumeArchiveInput $InvocationDirectory
    $FamilyDatabase=Resolve-FullPath $ResumeFamilyInput $InvocationDirectory
    $CompactDatabase=Resolve-FullPath $ResumeCompactInput $InvocationDirectory
    $resumePaths=@(
        [pscustomobject]@{name='archive database';path=$ArchiveDatabase},
        [pscustomobject]@{name='family database';path=$FamilyDatabase},
        [pscustomobject]@{name='compact database';path=$CompactDatabase}
    )
    foreach($pair in $resumePaths){
        if(-not(Test-Path -LiteralPath $pair.path -PathType Container)){
            Write-Console ('ERROR: resume '+$pair.name+' not found: '+$pair.path)
            exit 2
        }
    }
    if(-not[string]::IsNullOrWhiteSpace($ResumeTestResultsInput)){
        $resumeTests=Resolve-FullPath $ResumeTestResultsInput $InvocationDirectory
        if(-not(Test-Path -LiteralPath $resumeTests -PathType Container)){
            Write-Console ('ERROR: resume test-results folder not found: '+$resumeTests)
            exit 2
        }
        $script:TestResults=$resumeTests
    }
}else{
    $PhaseTotal=10
    $ArchiveDatabase=New-UniquePath (Join-Path $OutputRoot ('mvs-archive-database-'+$ProjectVersion+'-'+$tag))
    $FamilyDatabase=New-UniquePath (Join-Path $OutputRoot ('mvs-family-index-'+$ProjectVersion+'-'+$tag))
    $CompactDatabase=New-UniquePath (Join-Path $OutputRoot ('mvs-family-index-compact-'+$ProjectVersion+'-'+$tag))
}
$script:ArchiveDatabase=$ArchiveDatabase
$script:FamilyDatabase=$FamilyDatabase
$script:CompactDatabase=$CompactDatabase
$script:LogsRoot=New-UniquePath (Join-Path $OutputRoot ('mvs-pipeline-logs-'+$ProjectVersion+'-'+$tag))
[void](New-Item -ItemType Directory -Path $script:LogsRoot -Force)
$script:LogZip=$script:LogsRoot+'.zip'

$masterPath=Join-Path $script:LogsRoot 'console.log'
$phasePath=Join-Path $script:LogsRoot 'phase-performance.tsv'
$masterStream=New-Object IO.FileStream($masterPath,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
$script:MasterWriter=New-Object IO.StreamWriter($masterStream,$utf8,65536)
$script:MasterWriter.NewLine="`r`n";$script:MasterWriter.AutoFlush=$true
$phaseStream=New-Object IO.FileStream($phasePath,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
$script:PhaseWriter=New-Object IO.StreamWriter($phaseStream,$utf8,65536)
$script:PhaseWriter.NewLine="`r`n";$script:PhaseWriter.AutoFlush=$true
$script:PhaseWriter.WriteLine("phase`tname`tstatus`trc`telapsed_ms`tfinished`tdetail")

$completed=$false
$errorMessage=''
try{
    Write-Log ('MVS Explorer Toolkit complete pipeline '+$ProjectVersion)
    Write-Log ('Archive: '+$ArchiveRoot)
    Write-Log ('Output root: '+$OutputRoot)
    Write-Log ('Invocation directory: '+$InvocationDirectory)
    Write-Log ('Worker mode: '+$WorkerMode+' start='+$WorkerStart+' max='+$WorkerMax+' logical_cores='+$LogicalCores)
    Write-Log ('Strict performance: '+$StrictPerformance)
    Write-Log ('Resume existing databases: '+$ResumeMode)
    if($ResumeMode){
        Write-Log 'Resume mode: build/test phases already completed by a prior run are not repeated; existing databases are revalidated before packaging.'
    }else{
        Write-Log 'Database generation is gated on successful completion of the test phase.'
    }
    # Keep the toolkit root dedicated to artifacts from this run. Removing a hardlink
    # does not remove its ZIP target under the output root.
    foreach($oldLink in @(Get-ChildItem -LiteralPath $HardLinkRoot -File -Filter 'SEND-ME-*.zip' -ErrorAction SilentlyContinue)){
        Remove-Item -LiteralPath $oldLink.FullName -Force
    }

    $testEverything=Join-Path (Join-Path $ProjectRoot 'test') 'test_everything.bat'
    $testStructure=Join-Path (Join-Path $ProjectRoot 'test') 'test_structure.bat'
    $sweep=Join-Path (Join-Path $ProjectRoot 'test') 'test_all_dumps.bat'
    $quality=Join-Path (Join-Path $ProjectRoot 'test') 'check_archive_sweep_quality.bat'
    $familyBuilder=Join-Path (Join-Path $ProjectRoot 'tools') 'build_mvs_product_family_index.bat'
    $compactBuilder=Join-Path (Join-Path $ProjectRoot 'tools') 'build_mvs_product_family_compact_index.bat'
    $dbValidator=Join-Path (Join-Path $ProjectRoot 'test') 'test_generated_databases.bat'
    foreach($tool in @($testEverything,$testStructure,$sweep,$quality,$familyBuilder,$compactBuilder,$dbValidator)){
        if(-not(Test-Path -LiteralPath $tool -PathType Leaf)){throw ('Required pipeline tool missing: '+$tool)}
    }

    if($ResumeMode){
        $testParent=Join-Path $ProjectRoot 'test'
        $beforeResumeStructure=@(Get-ChildItem -LiteralPath $testParent -Directory -Filter 'test-results-*' -ErrorAction SilentlyContinue|ForEach-Object{$_.FullName})
        Invoke-ChildPhase 'RESUME PRECHECK: STRUCTURE + DATABASE-VALIDATOR GUARDS' $testStructure @()
        $script:ResumeStructureResults=Get-NewestNewDirectory $testParent 'test-results-*' $beforeResumeStructure

        $qualityArgs=@($ArchiveDatabase)
        if($StrictPerformance){$qualityArgs+=@('--strict-performance')}
        Invoke-ChildPhase 'VALIDATE EXISTING ARCHIVE ANALYSIS DATABASE' $quality $qualityArgs

        $dbValidationRoot=Join-Path $script:LogsRoot 'database-validation'
        $script:DbValidationRoot=$dbValidationRoot
        Invoke-ChildPhase 'TEST EXISTING FINAL DATABASES + RUN ALL 32 FAMILY QUERY TOOLS' $dbValidator @($ArchiveDatabase,$FamilyDatabase,$CompactDatabase,$dbValidationRoot,$ProjectVersion)
    }else{
        $testParent=Join-Path $ProjectRoot 'test'
        $beforeTests=@(Get-ChildItem -LiteralPath $testParent -Directory -Filter 'test-results-*' -ErrorAction SilentlyContinue|ForEach-Object{$_.FullName})
        $testArgs=@($ArchiveRoot)+@(Get-WorkerArguments)
        if($StrictPerformance){$testArgs+=@('--strict-performance')}
        try{
            Invoke-ChildPhase 'ALL TESTS' $testEverything $testArgs
        } finally {
            $testResults=Capture-TestResults $testParent $beforeTests
        }
        if([string]::IsNullOrWhiteSpace($testResults)){throw 'Could not locate test_all result folder after test gate.'}

        $archiveBuildArgs=@($ArchiveRoot,$ArchiveDatabase)+@(Get-WorkerArguments)+@('--no-cache')
        Invoke-ChildPhase 'BUILD ARCHIVE ANALYSIS DATABASE (34,822 logical archive checks on current known archive)' $sweep $archiveBuildArgs

        $qualityArgs=@($ArchiveDatabase)
        if($StrictPerformance){$qualityArgs+=@('--strict-performance')}
        Invoke-ChildPhase 'VALIDATE ARCHIVE ANALYSIS DATABASE' $quality $qualityArgs

        Invoke-ChildPhase 'BUILD FULL PRODUCT-FAMILY EVIDENCE DATABASE' $familyBuilder @($ArchiveRoot,$FamilyDatabase)

        Invoke-ChildPhase 'BUILD COMPACT ALL-EVER PRODUCT-FAMILY DATABASE' $compactBuilder @($FamilyDatabase,$CompactDatabase)

        $dbValidationRoot=Join-Path $script:LogsRoot 'database-validation'
        $script:DbValidationRoot=$dbValidationRoot
        Invoke-ChildPhase 'TEST FINAL DATABASES + RUN ALL 32 FAMILY QUERY TOOLS' $dbValidator @($ArchiveDatabase,$FamilyDatabase,$CompactDatabase,$dbValidationRoot,$ProjectVersion)
    }

    $ArchiveZip=$ArchiveDatabase+'.zip'
    Invoke-InternalPhase 'ZIP ARCHIVE ANALYSIS DATABASE' {New-ZipFromDirectory $ArchiveDatabase $ArchiveZip} $ArchiveZip
    Add-DatabaseRecord 'archive_database' $ArchiveDatabase $ArchiveZip

    $FamilyZip=$FamilyDatabase+'.zip'
    Invoke-InternalPhase 'ZIP FULL PRODUCT-FAMILY EVIDENCE DATABASE' {New-ZipFromDirectory $FamilyDatabase $FamilyZip} $FamilyZip
    Add-DatabaseRecord 'family_database' $FamilyDatabase $FamilyZip

    $CompactZip=$CompactDatabase+'.zip'
    Invoke-InternalPhase 'ZIP COMPACT PRODUCT-FAMILY DATABASE' {New-ZipFromDirectory $CompactDatabase $CompactZip} $CompactZip
    Add-DatabaseRecord 'compact_family_database' $CompactDatabase $CompactZip

    $sw=Begin-Phase 'COLLECT LOGS, CREATE DATABASE HARDLINKS, PREPARE FINAL PACKAGE'
    try{
        if(-not[string]::IsNullOrWhiteSpace($script:TestResults)-and(Test-Path -LiteralPath $script:TestResults -PathType Container)){
            $testDest=Join-Path $script:LogsRoot 'test-results'
            Copy-DirectoryTree $script:TestResults $testDest
        }
        if(-not[string]::IsNullOrWhiteSpace($script:ResumeStructureResults)-and(Test-Path -LiteralPath $script:ResumeStructureResults -PathType Container)){
            $resumeTestDest=Join-Path $script:LogsRoot 'resume-structure-results'
            Copy-DirectoryTree $script:ResumeStructureResults $resumeTestDest
        }
        $archiveLogDest=Join-Path $script:LogsRoot 'archive-database-logs'
        [void](New-Item -ItemType Directory -Path $archiveLogDest -Force)
        foreach($f in @(Get-ChildItem -LiteralPath $ArchiveDatabase -File -ErrorAction SilentlyContinue)){
            Copy-Item -LiteralPath $f.FullName -Destination $archiveLogDest -Force
        }
        foreach($sub in @('quality-check','failures')){
            $srcSub=Join-Path $ArchiveDatabase $sub
            if(Test-Path -LiteralPath $srcSub -PathType Container){Copy-DirectoryTree $srcSub (Join-Path $archiveLogDest $sub)}
        }
        $archivePerfDest=Join-Path $archiveLogDest 'archive-output-performance'
        [void](New-Item -ItemType Directory -Path $archivePerfDest -Force)
        foreach($rel in @('archive-output\fast-archive-summary.txt','archive-output\evolution\fast-archive-timings.tsv','archive-output\evolution\summary.tsv','archive-output\evolution\per-dump-quality.tsv')){
            $srcFile=Join-Path $ArchiveDatabase $rel
            if(Test-Path -LiteralPath $srcFile -PathType Leaf){Copy-Item -LiteralPath $srcFile -Destination $archivePerfDest -Force}
        }
        $meta=@(
            'MVS Explorer Toolkit pipeline metadata',
            ('Project version: '+$ProjectVersion),
            ('Archive: '+$ArchiveRoot),
            ('Archive database: '+$ArchiveDatabase),
            ('Family database: '+$FamilyDatabase),
            ('Compact database: '+$CompactDatabase),
            ('Test results: '+$script:TestResults),
            ('Resume structure results: '+$script:ResumeStructureResults),
            ('Invocation directory: '+$InvocationDirectory),
            ('Hardlink folder: '+$HardLinkRoot),
            ('Computer: '+$env:COMPUTERNAME),
            ('User: '+$env:USERNAME),
            ('OS: '+[Environment]::OSVersion.VersionString),
            ('PowerShell: '+$PSVersionTable.PSVersion.ToString()),
            ('CLR: '+[Environment]::Version.ToString())
        )
        [IO.File]::WriteAllText((Join-Path $script:LogsRoot 'run-metadata.txt'),(($meta-join[Environment]::NewLine)+[Environment]::NewLine),$utf8)

        foreach($r in $script:DatabaseRecords){
            $hash=(Get-FileHash -LiteralPath $r.zip_path -Algorithm SHA256).Hash.ToLowerInvariant()
            Write-Log ($r.name+' ZIP SHA256: '+$hash)
        }

        # Do not ZIP the live log directory here. console.log and phase-performance.tsv
        # are still open by design. Final log packaging runs only after the outer finally
        # block has flushed and disposed both writers.
        [void](New-HardLink $ArchiveZip 'ARCHIVE-DATABASE')
        [void](New-HardLink $FamilyZip 'FAMILY-DATABASE')
        [void](New-HardLink $CompactZip 'COMPACT-DATABASE')
        Record-Phase 'COLLECT LOGS, CREATE DATABASE HARDLINKS, PREPARE FINAL PACKAGE' 'PASS' $sw 0 $script:LogsRoot
        $completed=$true
    } catch {
        if($sw.IsRunning){Record-Phase 'COLLECT LOGS, CREATE DATABASE HARDLINKS, PREPARE FINAL PACKAGE' 'FAIL' $sw 1 $_.Exception.Message}
        throw
    }
} catch {
    $errorMessage=$_.Exception.Message
    Write-ErrLog ('PIPELINE FAILED: '+$errorMessage)
} finally {
    if($null-ne$script:PhaseWriter){$script:PhaseWriter.Flush();$script:PhaseWriter.Dispose();$script:PhaseWriter=$null}
    if($null-ne$script:MasterWriter){$script:MasterWriter.Flush();$script:MasterWriter.Dispose();$script:MasterWriter=$null}
}

if($completed){
    # The active log writers are closed above. Only now is it safe to read console.log
    # and phase-performance.tsv into the sendable log ZIP on Windows.
    if($PipelineStopwatch.IsRunning){$PipelineStopwatch.Stop()}
    Write-FinalFiles 'PASS' ''
    try{
        Write-Console 'Finalizing log ZIP after active log writers are closed ...'
        Finish-LogZip
        [void](New-HardLink $script:LogZip 'LOGS')
        Write-FinalFiles 'PASS' ''
    } catch {
        $completed=$false
        $errorMessage='FINAL LOG PACKAGING failed: '+$_.Exception.Message
        Write-Console ('PIPELINE FAILED: '+$errorMessage)
    }
    if($completed){
        Print-FinalSummary 'PASS'
        exit 0
    }
}

# Failure path: preserve as much logging as possible and provide a sendable log ZIP.
try{
    if($PipelineStopwatch.IsRunning){$PipelineStopwatch.Stop()}
    Write-FinalFiles 'FAIL' $errorMessage
    if(-not[string]::IsNullOrWhiteSpace($script:LogsRoot)){
        Finish-LogZip
        [void](New-HardLink $script:LogZip 'LOGS')
    }
} catch {
    Write-Console ('WARNING: could not package failure logs: '+$_.Exception.Message)
}
Print-FinalSummary 'FAIL'
exit 1
:_MVSAllPipeline_end
