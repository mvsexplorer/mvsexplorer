@echo off
:setup
setlocal DisableDelayedExpansion
set "app.version=@@VERSION@@"
set "app.name=check_archive_sweep_quality"
set "app.rc=0"
set "app.self=%~f0"
set "mvsq_results=%~1"
set "mvsq_strict_performance=0"
if /i "%~2"=="--strict-performance" set "mvsq_strict_performance=1"
set "mvsq_caller=%~nx0"
set "mvsq_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSArchiveQuality"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSArchiveQuality_start
@@QUALITY_POWERSHELL@@
:_MVSArchiveQuality_end
