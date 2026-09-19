@echo off
:setup
setlocal DisableDelayedExpansion
set "app.version=@@VERSION@@"
set "app.name=run_archive_tools_fast"
set "app.rc=0"
set "app.self=%~f0"
set "mvsfa_archive_root=%~1"
set "mvsfa_output_root=%~2"
set "mvsfa_caller=%~nx0"
set "mvsfa_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSFastArchive"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSFastArchive_start
@@FAST_ARCHIVE_POWERSHELL@@
:_MVSFastArchive_end
