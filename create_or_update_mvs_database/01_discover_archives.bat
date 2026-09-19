@echo off
:setup
REM Generated internal create/update component. It is standalone but orchestrated by create_or_update_mvs_database.bat.
setlocal DisableDelayedExpansion
set "app.version=0.2.0"
set "app.name=01_discover_archives"
set "app.rc=0"
set "app.self=%~f0"
set "mvsdbm_arg1=%~1"
set "mvsdbm_arg2=%~2"
set "mvsdbm_arg3=%~3"
set "mvsdbm_arg4=%~4"
set "mvsdbm_arg5=%~5"
set "mvsdbm_arg6=%~6"
set "mvsdbm_arg7=%~7"
set "mvsdbm_arg8=%~8"
set "mvsdbm_version=%app.version%"
set "mvsdbm_project_version=0.20.0"
:main
set "RunPowerShellFromLabel.function=MVSDatabaseMaintenance"
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

:_MVSDatabaseMaintenance_start
$ErrorActionPreference='Stop'
$utf8=New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8
$ProjectRoot=[IO.Path]::GetFullPath([string]$env:mvsdbm_arg1)
$InvocationDir=[IO.Path]::GetFullPath([string]$env:mvsdbm_arg2)
$Manifest=[IO.Path]::GetFullPath([string]$env:mvsdbm_arg3)
$Pattern='^mvs_\d{4}-\d{2}-\d{2}(?:-\d{4})?(?:_\d+)?$'
function Write-Line{param([string]$Text)[Console]::Out.WriteLine($Text)}
function Get-Sha256Text{param([string]$Text)$sha=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($Text)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}}
$roots=New-Object System.Collections.ArrayList
[void]$roots.Add($InvocationDir)
$parent=Split-Path -Parent $InvocationDir
if($parent    -and       -not   [StringComparer]::OrdinalIgnoreCase.Equals($parent,$InvocationDir)){[void]$roots.Add($parent)}
$seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$found=New-Object System.Collections.ArrayList
foreach($root in $roots){
    foreach($dir in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue|Where-Object{$_.Name  -like  'mvs_dumps_archive*'}|Sort-Object Name)){
        $resolved=(Resolve-Path -LiteralPath $dir.FullName).Path
        if($seen.Add($resolved)){
            $snaps=@(Get-ChildItem -LiteralPath $resolved -Directory -ErrorAction SilentlyContinue|Where-Object{$_.Name  -match  $Pattern})
            [void]$found.Add([pscustomobject]@{name=$dir.Name;path=$resolved;snapshot_count=$snaps.Count})
        }
    }
}
if($found.Count -eq 0){[Console]::Error.WriteLine('ERROR: No mvs_dumps_archive* folders found in current or parent folder.');[Environment]::Exit(3)}
$nameCounts=@{}
foreach($item in $found){$k=$item.name.ToLowerInvariant();if(   -not   $nameCounts.ContainsKey($k)){$nameCounts[$k]=0};$nameCounts[$k]++}
$lines=New-Object System.Collections.ArrayList
[void]$lines.Add("slot`tname`tpath`tsnapshot_count")
foreach($item in @($found|Sort-Object path)){
    $slot=[regex]::Replace($item.name,'[^A-Za-z0-9._-]+','_').Trim('_')
    if([string]::IsNullOrWhiteSpace($slot)){$slot='archive'}
    if($nameCounts[$item.name.ToLowerInvariant()] -gt 1){$slot+='-'+(Get-Sha256Text $item.path).Substring(0,8)}
    [void]$lines.Add(($slot+"`t"+$item.name+"`t"+$item.path+"`t"+$item.snapshot_count))
    Write-Line ('Found archive: '+$item.path+' ['+$item.snapshot_count+' snapshots] -> '+$slot)
}
[IO.File]::WriteAllText($Manifest,(($lines -join "`r`n")+"`r`n"),$utf8)
Write-Line ('Discovery manifest: '+$Manifest)
:_MVSDatabaseMaintenance_end
