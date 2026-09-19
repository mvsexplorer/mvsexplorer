@echo off
:setup
setlocal DisableDelayedExpansion
set "app.version=@@VERSION@@"
set "app.name=analyze_archive_sweep_performance"
set "app.rc=0"
set "app.self=%~f0"
set "mvsp_results=%~1"
set "mvsp_caller=%~nx0"
set "mvsp_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSPerformance"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSPerformance_start
@@PERFORMANCE_POWERSHELL@@
:_MVSPerformance_end
