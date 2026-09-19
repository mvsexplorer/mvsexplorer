@echo off
:setup
REM Scoped because this standalone archive sweep harness embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=test_all_dumps"
set "app.rc=0"
set "app.self=%~f0"
REM Freeze caller identity before SHIFT mutates the positional parameter frame.
set "mvsa_caller=%~nx0"
set "mvsa_script_root=%~dp0"
set "mvsa_argc=0"
:mvsa_capture_args
if "%~1"=="" goto :mvsa_capture_done
set "mvsa_arg_%mvsa_argc%=%~1"
set /a mvsa_argc+=1
shift
goto :mvsa_capture_args
:mvsa_capture_done
set "mvsa_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSArchiveSweep"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSArchiveSweep_start
@@ARCHIVE_SWEEP_POWERSHELL@@
:_MVSArchiveSweep_end
