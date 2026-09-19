@echo off
:setup
setlocal DisableDelayedExpansion
set "app.version=@@VERSION@@"
set "app.name=run_@@MODE@@_tools_fast"
set "app.rc=0"
set "app.self=%~f0"
set "mvsf_mode=@@MODE@@"
@@ARGS@@
set "mvsf_caller=%~nx0"
set "mvsf_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSFastSweep"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSFastSweep_start
@@FAST_POWERSHELL@@
:_MVSFastSweep_end
