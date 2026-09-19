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
$Workers=[Math]::Min(4,[Math]::Max(1,[int][Math]::Ceiling([Environment]::ProcessorCount/2.0)))
$ExistingResults=''

function Fail {param([int]$Code,[string]$Message)[Console]::Error.WriteLine('[FAIL] '+$Message);exit $Code}
function Run {
    param([string]$Tool,[object[]]$ToolArgs)
    $script:SuitePhaseIndex++
    $remaining=[Math]::Max(0,$script:SuitePhaseTotal-$script:SuitePhaseIndex)
    [Console]::Out.WriteLine('')
    [Console]::Out.WriteLine('================================================================================')
    [Console]::Out.WriteLine('[PROJECT '+$ProjectVersion+'] [SUITE TEST '+$script:SuitePhaseIndex+'/'+$script:SuitePhaseTotal+' | remaining='+$remaining+'] '+[IO.Path]::GetFileName($Tool))
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
    [Console]::Out.WriteLine('Usage: '+$Caller+' mvs-dumps-root [--full-archive] [--workers N] [--strict-performance] [--archive-results DIR]')
    [Console]::Out.WriteLine('Default: public regression + public performance analysis + fast synthetic acceptance + full archive plan validation.')
    [Console]::Out.WriteLine('--full-archive additionally performs a fresh no-cache archive sweep, quality check, and HTML report.')
    exit 0
}
if([string]::IsNullOrWhiteSpace($ArchiveInput)-or-not(Test-Path -LiteralPath $ArchiveInput -PathType Container)){Fail 2 ('Archive root not found: '+$ArchiveInput)}
$Archive=(Resolve-Path -LiteralPath $ArchiveInput).Path
$args=New-Object System.Collections.ArrayList;foreach($a in $RawArgs){if(-not[string]::IsNullOrWhiteSpace($a)){[void]$args.Add($a)}}
for($i=0;$i-lt$args.Count;$i++){
    $a=[string]$args[$i]
    if($a-eq'--full-archive'){$FullArchive=$true;continue}
    if($a-eq'--strict-performance'){$StrictPerformance=$true;continue}
    if($a-eq'--workers'){$i++;if($i-ge$args.Count){Fail 2 '--workers requires a value'};$n=0;if(-not[int]::TryParse([string]$args[$i],[ref]$n)-or$n-lt1-or$n-gt32){Fail 2 'invalid --workers'};$Workers=$n;continue}
    if($a-eq'--archive-results'){$i++;if($i-ge$args.Count){Fail 2 '--archive-results requires a folder'};$ExistingResults=[string]$args[$i];continue}
    Fail 2 ('Unknown option: '+$a)
}

$script:SuitePhaseTotal=4
if(-not[string]::IsNullOrWhiteSpace($ExistingResults)){$script:SuitePhaseTotal++}
if($FullArchive){$script:SuitePhaseTotal+=2}
[Console]::Out.WriteLine('MVS Explorer Toolkit comprehensive test suite')
[Console]::Out.WriteLine('Project version: '+$ProjectVersion)
[Console]::Out.WriteLine('Suite tool version: '+$Version)
[Console]::Out.WriteLine('Planned suite tests: '+$script:SuitePhaseTotal)

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

$planFolder=New-TempFolder 'mvs-everything-plan'
try{
    Run $sweep @($Archive,$planFolder,'--plan-only','--workers',[string]$Workers,'--no-report','--no-cache')
} finally {if(Test-Path -LiteralPath $planFolder){Remove-Item -LiteralPath $planFolder -Recurse -Force -ErrorAction SilentlyContinue}}

if(-not[string]::IsNullOrWhiteSpace($ExistingResults)){
    $qr=@($ExistingResults);if($StrictPerformance){$qr+=@('--strict-performance')};Run $quality $qr
}

if($FullArchive){
    $tag=Get-Date -Format 'yyyyMMdd-HHmmss'
    $archiveResult=Join-Path $ScriptRoot ('everything-archive-results-'+$tag)
    Run $sweep @($Archive,$archiveResult,'--workers',[string]$Workers,'--no-cache')
    $qr=@($archiveResult);if($StrictPerformance){$qr+=@('--strict-performance')};Run $quality $qr
}

[Console]::Out.WriteLine('')
[Console]::Out.WriteLine('SUMMARY: comprehensive regression/quality/performance checks passed.')
exit 0
