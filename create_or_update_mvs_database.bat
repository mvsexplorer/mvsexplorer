@echo off
:setup
REM MVS database create/update launcher. Components live in create_or_update_mvs_database\.
setlocal DisableDelayedExpansion
set "app.version=0.2.3"
set "app.name=create_or_update_mvs_database"
set "app.rc=0"
set "app.self=%~f0"
set "mvscu_project_root=%~dp0"
set "mvscu_invocation_dir=%CD%"
set "mvscu_version=%app.version%"
set "mvscu_project_version=0.21.1"
set "mvscu_arg1=%~1"
set "mvscu_arg2=%~2"
set "mvscu_arg3=%~3"
set "mvscu_arg4=%~4"
set "mvscu_arg5=%~5"
set "mvscu_arg6=%~6"
:main
set "RunPowerShellFromLabel.function=MVSCreateOrUpdateDatabase"
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

:_MVSCreateOrUpdateDatabase_start
$ErrorActionPreference='Stop'
$utf8=New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8
$ProjectRoot=[IO.Path]::GetFullPath([string]$env:mvscu_project_root)
$InvocationDir=[IO.Path]::GetFullPath([string]$env:mvscu_invocation_dir)
$ToolVersion=[string]$env:mvscu_version
$ProjectVersion=[string]$env:mvscu_project_version
$raw=@([string]$env:mvscu_arg1,[string]$env:mvscu_arg2,[string]$env:mvscu_arg3,[string]$env:mvscu_arg4,[string]$env:mvscu_arg5,[string]$env:mvscu_arg6)
$LogicalCores=[Math]::Max(1,[Environment]::ProcessorCount)
$WorkerStart=[Math]::Max(1,[int][Math]::Ceiling($LogicalCores/4.0))
$WorkerMax=$LogicalCores
$WorkerMode='adaptive'
$WorkersOptionSeen=$false
$StartWorkersOptionSeen=$false
$MaxWorkersOptionSeen=$false
$ForceValidate=$false
for($i=0;$i  -lt  $raw.Count;$i++){
    $a=$raw[$i]
    if([string]::IsNullOrWhiteSpace($a)){continue}
    if($a  -in  @('--help','-h','-?','/h','/?')){
        [Console]::Out.WriteLine('MVS Explorer Toolkit create/update database '+$ToolVersion)
        [Console]::Out.WriteLine('Usage: create_or_update_mvs_database.bat [--start-workers N] [--max-workers N] [--workers N] [--force-validate]')
        [Console]::Out.WriteLine('Searches current and parent folders for every mvs_dumps_archive* directory.')
        [Console]::Out.WriteLine('Default worker policy is adaptive: start=ceil(logical CPUs / 4), max=logical CPUs; --workers N retains fixed mode.')
        [Environment]::Exit(0)
    }
    if($a  -eq  '--force-validate'){
        $ForceValidate=$true
        continue
    }
    if($a  -eq  '--workers'){
        if($StartWorkersOptionSeen -or $MaxWorkersOptionSeen){throw '--workers cannot be combined with --start-workers/--max-workers.'}
        if($i+1  -ge  $raw.Count){throw '--workers requires a value.'}
        $n=0;$i++;if(   -not   [int]::TryParse($raw[$i],[ref]$n)   -or   $n -lt 1 -or $n -gt 256){throw 'Invalid --workers value.'}
        $WorkerStart=$n;$WorkerMax=$n;$WorkerMode='fixed';$WorkersOptionSeen=$true
        continue
    }
    if($a  -eq  '--start-workers'){
        if($WorkersOptionSeen){throw '--start-workers cannot be combined with --workers.'}
        if($i+1  -ge  $raw.Count){throw '--start-workers requires a value.'}
        $n=0;$i++;if(   -not   [int]::TryParse($raw[$i],[ref]$n)   -or   $n -lt 1 -or $n -gt 256){throw 'Invalid --start-workers value.'}
        $WorkerStart=$n;$StartWorkersOptionSeen=$true
        continue
    }
    if($a  -eq  '--max-workers'){
        if($WorkersOptionSeen){throw '--max-workers cannot be combined with --workers.'}
        if($i+1  -ge  $raw.Count){throw '--max-workers requires a value.'}
        $n=0;$i++;if(   -not   [int]::TryParse($raw[$i],[ref]$n)   -or   $n -lt 1 -or $n -gt 256){throw 'Invalid --max-workers value.'}
        $WorkerMax=$n;$MaxWorkersOptionSeen=$true
        continue
    }
    throw ('Unknown argument: '+$a)
}
if($WorkerMode -eq 'adaptive' -and $MaxWorkersOptionSeen -and -not $StartWorkersOptionSeen -and $WorkerStart -gt $WorkerMax){$WorkerStart=$WorkerMax}
if($WorkerMode -eq 'adaptive' -and $StartWorkersOptionSeen -and -not $MaxWorkersOptionSeen -and $WorkerStart -gt $WorkerMax){$WorkerMax=$WorkerStart}
if($WorkerStart -gt $WorkerMax){throw '--start-workers cannot exceed --max-workers.'}
$WorkerSpec=if($WorkerMode -eq 'fixed'){'fixed:'+$WorkerStart}else{'adaptive:'+$WorkerStart+':'+$WorkerMax}
$RunId=Get-Date -Format 'yyyyMMdd-HHmmss'
$LogsRoot=Join-Path $ProjectRoot 'logs'
if(   -not   (Test-Path -LiteralPath $LogsRoot -PathType Container)){[void](New-Item -ItemType Directory -Path $LogsRoot -Force)}
$RunLogs=Join-Path $LogsRoot ('create-or-update-'+$RunId)
[void](New-Item -ItemType Directory -Path $RunLogs -Force)
$MasterPath=Join-Path $RunLogs 'console.log'
$script:MasterWriter=New-Object IO.StreamWriter($MasterPath,$false,$utf8,65536)
$script:MasterWriter.AutoFlush=$true
$script:Failures=0
$script:ArchiveResults=New-Object System.Collections.ArrayList
$script:TransientWidth=0
$script:TransientPrefix='__MVS_TRANSIENT__'

function Clear-TransientConsole{
    if($script:TransientWidth-le0){return}
    if(-not[Console]::IsOutputRedirected){
        try{[Console]::Out.Write("`r"+(' ' * $script:TransientWidth)+"`r")}catch{}
    }
    $script:TransientWidth=0
}
function Write-TransientConsole{
    param([AllowEmptyString()][string]$Text)
    if([Console]::IsOutputRedirected){return}
    try{
        $width=[Math]::Max($script:TransientWidth,$Text.Length)
        [Console]::Out.Write("`r"+$Text+(' ' * ($width-$Text.Length)))
        $script:TransientWidth=$width
    }catch{$script:TransientWidth=0}
}
function Write-Line{
    param([AllowEmptyString()][string]$Text,[ConsoleColor]$Color=[ConsoleColor]::Gray)
    Clear-TransientConsole
    $old=[Console]::ForegroundColor
    try{if(   -not   [Console]::IsOutputRedirected){[Console]::ForegroundColor=$Color};[Console]::Out.WriteLine($Text)}
    finally{if(   -not   [Console]::IsOutputRedirected){[Console]::ForegroundColor=$old}}
    if($null  -ne  $script:MasterWriter){$script:MasterWriter.WriteLine($Text)}
}
function Safe-Name{param([string]$Text)return([regex]::Replace($Text,'[^A-Za-z0-9._-]+','_').Trim('_'))}
function Invoke-Component{
    param([string]$Path,[string[]]$Arguments,[string]$LogName)
    if(   -not   (Test-Path -LiteralPath $Path -PathType Leaf)){Write-Line ('Missing component: '+$Path) Red;return 4}
    $logPath=Join-Path $RunLogs $LogName
    $writer=New-Object IO.StreamWriter($logPath,$false,$utf8,65536)
    $oldTransientProtocol=[string]$env:MVS_TRANSIENT_PROTOCOL
    try{
        # Nested archive/family tools inherit this marker and can retain detailed
        # status in logs while the launcher renders it as one overwriteable
        # bottom-of-console line.
        $env:MVS_TRANSIENT_PROTOCOL='1'
        & $Path @Arguments 2>&1 | ForEach-Object{
            $line=[string]$_
            if($line.StartsWith($script:TransientPrefix,[StringComparison]::Ordinal)){
                $render=$line.Substring($script:TransientPrefix.Length)
                Write-TransientConsole $render
                $writer.WriteLine($render)
                if($null  -ne  $script:MasterWriter){$script:MasterWriter.WriteLine($render)}
            } else {
                Clear-TransientConsole
                [Console]::Out.WriteLine($line)
                $writer.WriteLine($line)
                if($null  -ne  $script:MasterWriter){$script:MasterWriter.WriteLine($line)}
            }
        }
        $rc=$LASTEXITCODE
    }catch{
        Clear-TransientConsole
        $line='ERROR: '+[string]$_
        [Console]::Error.WriteLine($line);$writer.WriteLine($line);if($null  -ne  $script:MasterWriter){$script:MasterWriter.WriteLine($line)}
        $rc=1
    }finally{
        if([string]::IsNullOrEmpty($oldTransientProtocol)){Remove-Item Env:MVS_TRANSIENT_PROTOCOL -ErrorAction SilentlyContinue}else{$env:MVS_TRANSIENT_PROTOCOL=$oldTransientProtocol}
        $writer.Flush();$writer.Dispose()
    }
    return [int]$rc
}
function Finish-LogsZip{
    param([string]$Status)
    $summary=@(
        'MVS Explorer Toolkit create/update database',
        ('Project version: '+$ProjectVersion),
        ('Run ID: '+$RunId),
        ('Status: '+$Status),
        ('Invocation directory: '+$InvocationDir),
        ('Worker mode: '+$WorkerMode),
        ('Worker start: '+$WorkerStart),
        ('Worker max: '+$WorkerMax),
        ('Force validation: '+$ForceValidate),
        ('Archives attempted: '+$script:ArchiveResults.Count),
        ('Failures: '+$script:Failures)
    )
    foreach($r in $script:ArchiveResults){$summary+=($r.slot+"`t"+$r.status+"`t"+$r.path)}
    [IO.File]::WriteAllText((Join-Path $RunLogs 'run-summary.txt'),(($summary-join"`r`n")+"`r`n"),$utf8)
    if($null  -ne  $script:MasterWriter){$script:MasterWriter.Flush();$script:MasterWriter.Dispose();$script:MasterWriter=$null}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipPath=$RunLogs+'.zip'
    if(Test-Path -LiteralPath $zipPath){Remove-Item -LiteralPath $zipPath -Force}
    [IO.Compression.ZipFile]::CreateFromDirectory($RunLogs,$zipPath,[IO.Compression.CompressionLevel]::Optimal,$false)
    [Console]::Out.WriteLine('Run logs: '+$RunLogs)
    [Console]::Out.WriteLine('Run logs ZIP: '+$zipPath)
}
try{
    Write-Line ('MVS Explorer Toolkit create/update database '+$ToolVersion) Cyan
    Write-Line ('Project root: '+$ProjectRoot)
    Write-Line ('Invocation directory: '+$InvocationDir)
    Write-Line ('Logs: '+$RunLogs)
    Write-Line ('Worker mode: '+$WorkerMode+' start='+$WorkerStart+' max='+$WorkerMax+' logical_cores='+$LogicalCores)
    Write-Line ('Force validation: '+$ForceValidate)
    $components=Join-Path $ProjectRoot 'create_or_update_mvs_database'
    $manifest=Join-Path $RunLogs 'archives.tsv'
    $discover=Join-Path $components '01_discover_archives.bat'
    $rc=Invoke-Component $discover @($ProjectRoot,$InvocationDir,$manifest) '01_discover_archives.log'
    if($rc -ne 0){throw ('Archive discovery failed with rc='+$rc)}
    $archives=@(Import-Csv -LiteralPath $manifest -Delimiter "`t")
    if($archives.Count -eq 0){throw 'Archive discovery returned no archives.'}

    $invParent=Split-Path -Parent $InvocationDir
    $hasParent=$false
    foreach($a in $archives){if([StringComparer]::OrdinalIgnoreCase.Equals((Split-Path -Parent ([string]$a.path)),$invParent)){$hasParent=$true;break}}
    $workspace=if($hasParent){$invParent}else{$InvocationDir}
    $DatabaseRoot=Join-Path $workspace 'mvs_databases'
    if(   -not   (Test-Path -LiteralPath $DatabaseRoot -PathType Container)){[void](New-Item -ItemType Directory -Path $DatabaseRoot -Force)}
    Write-Line ('Database root: '+$DatabaseRoot) Cyan

    $sequence=@(
        @('02_prepare_archive_update.bat','prepare'),
        @('03_run_archive_update.bat','archive'),
        @('04_rebuild_family_index.bat','family'),
        @('05_rebuild_compact_index.bat','compact'),
        @('06_validate_database.bat','validate'),
        @('07_create_html_browser.bat','html')
    )
    foreach($archive in $archives){
        $slot=[string]$archive.slot;$archivePath=[string]$archive.path
        $slotRoot=Join-Path $DatabaseRoot $slot
        if(   -not   (Test-Path -LiteralPath $slotRoot -PathType Container)){[void](New-Item -ItemType Directory -Path $slotRoot -Force)}
        $slotLog=Join-Path $RunLogs $slot
        if(   -not   (Test-Path -LiteralPath $slotLog -PathType Container)){[void](New-Item -ItemType Directory -Path $slotLog -Force)}
        Write-Line '' 
        Write-Line ('=== '+$slot+' ===') Cyan
        Write-Line ('Source: '+$archivePath)
        $status='PASS'
        foreach($step in $sequence){
            $path=Join-Path $components $step[0]
            Write-Line ('Starting '+$step[1]+' ...') DarkCyan
            $componentExtra=if($step[1] -eq 'validate' -and $ForceValidate){'force-validate'}else{''}
            $args=@($ProjectRoot,$archivePath,$DatabaseRoot,$slotRoot,$RunId,$WorkerSpec,$RunLogs,$componentExtra)
            $rc=Invoke-Component $path $args ((Safe-Name $slot)+'_'+$step[0]+'.log')
            if($rc -ne 0){
                Write-Line (($step[1])+' FAILED for '+$slot+' rc='+$rc) Red
                $status='FAIL';$script:Failures++;break
            }else{Write-Line (($step[1])+' PASS for '+$slot) Green}
        }
        $statePath=Join-Path $components '08_write_database_summary.bat'
        $stateArgs=@($ProjectRoot,$archivePath,$DatabaseRoot,$slotRoot,$RunId,$WorkerSpec,$RunLogs,$status)
        $stateRc=Invoke-Component $statePath $stateArgs ((Safe-Name $slot)+'_08_write_database_summary.bat.log')
        if($stateRc -ne 0  -and  $status  -eq  'PASS'){$status='FAIL';$script:Failures++;Write-Line ('summary state FAILED for '+$slot+' rc='+$stateRc) Red}
        [void]$script:ArchiveResults.Add([pscustomobject]@{slot=$slot;status=$status;path=$archivePath})
    }
    $overall=if($script:Failures -eq 0){'PASS'}else{'FAIL'}
    Write-Line ''
    Write-Line ('FINAL STATUS: '+$overall) $(if($overall  -eq  'PASS'){'Green'}else{'Red'})
    Finish-LogsZip $overall
    if($overall  -ne  'PASS'){[Environment]::Exit(1)}
    [Environment]::Exit(0)
}catch{
    $script:Failures++
    Write-Line ('FATAL: '+[string]$_) Red
    try{Finish-LogsZip 'FAIL'}catch{[Console]::Error.WriteLine('Log ZIP failure: '+[string]$_)}
    [Environment]::Exit(1)
}
:_MVSCreateOrUpdateDatabase_end
