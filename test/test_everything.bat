@echo off
:setup
setlocal DisableDelayedExpansion
set "app.version=0.2.2"
set "app.name=test_everything"
set "app.rc=0"
set "app.self=%~f0"
set "mvste_archive=%~1"
set "mvste_arg2=%~2"
set "mvste_arg3=%~3"
set "mvste_arg4=%~4"
set "mvste_arg5=%~5"
set "mvste_arg6=%~6"
set "mvste_arg7=%~7"
set "mvste_script_root=%~dp0"
set "mvste_caller=%~nx0"
set "mvste_version=%app.version%"
set "mvste_project_version=0.21.0"
:main
set "RunPowerShellFromLabel.function=MVSTestEverything"
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

:_MVSTestEverything_start
$ErrorActionPreference='Stop'
$utf8=New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8
$ArchiveInput=[string]$env:mvste_archive
$RawArgs=@([string]$env:mvste_arg2,[string]$env:mvste_arg3,[string]$env:mvste_arg4,[string]$env:mvste_arg5,[string]$env:mvste_arg6,[string]$env:mvste_arg7)
$ScriptRoot=([string]$env:mvste_script_root).TrimEnd('\','/')
$Caller=[string]$env:mvste_caller
$Version=[string]$env:mvste_version
$ProjectVersion=[string]$env:mvste_project_version
$script:SuitePhaseIndex=0
$script:SuitePhaseTotal=0
$FullArchive=$false
$StrictPerformance=$false
$LogicalCores=[Math]::Max(1,[Environment]::ProcessorCount)
$WorkerStart=[Math]::Max(1,[int][Math]::Ceiling($LogicalCores/4.0))
$WorkerMax=$LogicalCores
$WorkerMode='adaptive'
$WorkersOptionSeen=$false
$StartWorkersOptionSeen=$false
$MaxWorkersOptionSeen=$false
$ExistingResults=''
$SkipRealArchivePlan=$false

function Fail {param([int]$Code,[string]$Message)[Console]::Error.WriteLine('[FAIL] '+$Message);exit $Code}
function Run {
    param([string]$Tool,[object[]]$ToolArgs)
    $script:SuitePhaseIndex++
    [Console]::Out.WriteLine('')
    [Console]::Out.WriteLine('================================================================================')
    [Console]::Out.WriteLine('[PROJECT '+$ProjectVersion+'] [SUITE TEST '+$script:SuitePhaseIndex+'/'+$script:SuitePhaseTotal+'] '+[IO.Path]::GetFileName($Tool))
    [Console]::Out.WriteLine('>>> '+[IO.Path]::GetFileName($Tool)+' '+(@($ToolArgs)-join' '))
    $global:LASTEXITCODE=0
    & $Tool @ToolArgs
    $rc=if($null-eq$LASTEXITCODE){0}else{[int]$LASTEXITCODE}
    if($rc-ne0){Fail 1 ([IO.Path]::GetFileName($Tool)+' returned '+$rc)}
}
function New-TempFolder {
    param([string]$Prefix)
    return Join-Path ([IO.Path]::GetTempPath()) ($Prefix+'-'+[Guid]::NewGuid().ToString('N'))
}

if(@('--help','-h','-?','/h','/?')-contains$ArchiveInput){
    [Console]::Out.WriteLine('MVS Explorer Toolkit comprehensive quality/performance tester '+$Version)
    [Console]::Out.WriteLine('Usage: '+$Caller+' mvs-dumps-root [--skip-real-archive-plan] [--full-archive] [--start-workers N] [--max-workers N] [--workers N] [--strict-performance] [--archive-results DIR]')
    [Console]::Out.WriteLine('Default: public regression + public performance analysis + fast synthetic acceptance + full archive plan validation.')
    [Console]::Out.WriteLine('Default worker policy is adaptive: start=ceil(logical CPUs / 4), max=logical CPUs; --workers N retains fixed mode.')
    [Console]::Out.WriteLine('--full-archive additionally performs a fresh no-cache archive sweep, quality check, and HTML report.')
    exit 0
}
if([string]::IsNullOrWhiteSpace($ArchiveInput)-or-not(Test-Path -LiteralPath $ArchiveInput -PathType Container)){Fail 2 ('Archive root not found: '+$ArchiveInput)}
$Archive=(Resolve-Path -LiteralPath $ArchiveInput).Path
$args=New-Object System.Collections.ArrayList;foreach($a in $RawArgs){if(-not[string]::IsNullOrWhiteSpace($a)){[void]$args.Add($a)}}
for($i=0;$i-lt$args.Count;$i++){
    $a=[string]$args[$i]
    if($a-eq'--full-archive'){$FullArchive=$true;continue}
    if($a-eq'--skip-real-archive-plan'){$SkipRealArchivePlan=$true;continue}
    if($a-eq'--strict-performance'){$StrictPerformance=$true;continue}
    if($a-eq'--workers'){
        if($StartWorkersOptionSeen -or $MaxWorkersOptionSeen){Fail 2 '--workers cannot be combined with --start-workers/--max-workers'}
        $i++;if($i-ge$args.Count){Fail 2 '--workers requires a value'};$n=0;if(-not[int]::TryParse([string]$args[$i],[ref]$n)-or$n-lt1-or$n-gt256){Fail 2 'invalid --workers'}
        $WorkerStart=$n;$WorkerMax=$n;$WorkerMode='fixed';$WorkersOptionSeen=$true;continue
    }
    if($a-eq'--start-workers'){
        if($WorkersOptionSeen){Fail 2 '--start-workers cannot be combined with --workers'}
        $i++;if($i-ge$args.Count){Fail 2 '--start-workers requires a value'};$n=0;if(-not[int]::TryParse([string]$args[$i],[ref]$n)-or$n-lt1-or$n-gt256){Fail 2 'invalid --start-workers'}
        $WorkerStart=$n;$StartWorkersOptionSeen=$true;continue
    }
    if($a-eq'--max-workers'){
        if($WorkersOptionSeen){Fail 2 '--max-workers cannot be combined with --workers'}
        $i++;if($i-ge$args.Count){Fail 2 '--max-workers requires a value'};$n=0;if(-not[int]::TryParse([string]$args[$i],[ref]$n)-or$n-lt1-or$n-gt256){Fail 2 'invalid --max-workers'}
        $WorkerMax=$n;$MaxWorkersOptionSeen=$true;continue
    }
    if($a-eq'--archive-results'){$i++;if($i-ge$args.Count){Fail 2 '--archive-results requires a folder'};$ExistingResults=[string]$args[$i];continue}
    Fail 2 ('Unknown option: '+$a)
}

if($WorkerMode -eq 'adaptive' -and $MaxWorkersOptionSeen -and -not $StartWorkersOptionSeen -and $WorkerStart -gt $WorkerMax){$WorkerStart=$WorkerMax}
if($WorkerMode -eq 'adaptive' -and $StartWorkersOptionSeen -and -not $MaxWorkersOptionSeen -and $WorkerStart -gt $WorkerMax){$WorkerMax=$WorkerStart}
if($WorkerStart -gt $WorkerMax){Fail 2 '--start-workers cannot exceed --max-workers'}

$script:SuitePhaseTotal=if($SkipRealArchivePlan){3}else{4}
if(-not[string]::IsNullOrWhiteSpace($ExistingResults)){$script:SuitePhaseTotal++}
if($FullArchive){$script:SuitePhaseTotal+=2}
[Console]::Out.WriteLine('MVS Explorer Toolkit comprehensive test suite')
[Console]::Out.WriteLine('Project version: '+$ProjectVersion)
[Console]::Out.WriteLine('Suite tool version: '+$Version)
[Console]::Out.WriteLine('Planned suite tests: '+$script:SuitePhaseTotal)

$workerArgs=if($WorkerMode -eq 'fixed'){@('--workers',[string]$WorkerStart)}else{@('--start-workers',[string]$WorkerStart,'--max-workers',[string]$WorkerMax)}
[Console]::Out.WriteLine('Worker mode: '+$WorkerMode+' start='+$WorkerStart+' max='+$WorkerMax+' logical_cores='+$LogicalCores)

$testAll=Join-Path $ScriptRoot 'test_all.bat'
$perf=Join-Path $ScriptRoot 'analyze_test_performance.bat'
$fastTest=Join-Path $ScriptRoot 'test_fast_archive_sweep.bat'
$sweep=Join-Path $ScriptRoot 'test_all_dumps.bat'
$quality=Join-Path $ScriptRoot 'check_archive_sweep_quality.bat'
foreach($p in @($testAll,$perf,$fastTest,$sweep,$quality)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){Fail 4 ('Missing tester: '+$p)}}

$representative=Join-Path $Archive 'mvs_2019-03-19'
if(-not(Test-Path -LiteralPath $representative -PathType Container)){
    $representative=@(Get-ChildItem -LiteralPath $Archive -Directory|Where-Object{$_.Name-match'^mvs_\d{4}-\d{2}-\d{2}'}|Sort-Object Name|Select-Object -First 1).FullName
}
if([string]::IsNullOrWhiteSpace($representative)){Fail 3 'No representative snapshot found.'}

$before=@(Get-ChildItem -LiteralPath $ScriptRoot -Directory -Filter 'test-results-*' -ErrorAction SilentlyContinue|ForEach-Object{$_.FullName})
Run $testAll @($representative)
$latest=@(Get-ChildItem -LiteralPath $ScriptRoot -Directory -Filter 'test-results-*' | Where-Object {$before -notcontains $_.FullName} | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)
if($latest.Count-eq0){Fail 5 'Could not locate the new test_all result folder.'}
$perfArgs=@($latest[0].FullName)
if($StrictPerformance){$perfArgs+=@('--strict')}
Run $perf $perfArgs

Run $fastTest @()

if(-not $SkipRealArchivePlan){
    $planFolder=New-TempFolder 'mvs-everything-plan'
    try{
        Run $sweep (@($Archive,$planFolder,'--plan-only','--quiet-plan')+@($workerArgs)+@('--no-report','--no-cache'))
    } finally {if(Test-Path -LiteralPath $planFolder){Remove-Item -LiteralPath $planFolder -Recurse -Force -ErrorAction SilentlyContinue}}
}else{
    [Console]::Out.WriteLine('Real-archive plan-only preflight: skipped because the calling fresh-build pipeline will immediately perform the stronger full plan + execution phase.')
}

if(-not[string]::IsNullOrWhiteSpace($ExistingResults)){
    $qr=@($ExistingResults);if($StrictPerformance){$qr+=@('--strict-performance')};Run $quality $qr
}

if($FullArchive){
    $tag=Get-Date -Format 'yyyyMMdd-HHmmss'
    $archiveResult=Join-Path $ScriptRoot ('everything-archive-results-'+$tag)
    Run $sweep (@($Archive,$archiveResult)+@($workerArgs)+@('--no-cache'))
    $qr=@($archiveResult);if($StrictPerformance){$qr+=@('--strict-performance')};Run $quality $qr
}

[Console]::Out.WriteLine('')
[Console]::Out.WriteLine('SUMMARY: comprehensive regression/quality/performance checks passed.')
exit 0
:_MVSTestEverything_end
