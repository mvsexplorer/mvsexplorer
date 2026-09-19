@echo off
:setup
setlocal DisableDelayedExpansion
set "app.version=@@VERSION@@"
set "app.name=analyze_test_performance"
set "app.rc=0"
set "app.self=%~f0"
set "mvstp_results=%~1"
set "mvstp_strict=0"
set "mvstp_threshold=30000"
if /i "%~2"=="--strict" set "mvstp_strict=1"
if not "%~2"=="" if /i not "%~2"=="--strict" set "mvstp_threshold=%~2"
if not "%~3"=="" set "mvstp_threshold=%~3"
set "mvstp_caller=%~nx0"
set "mvstp_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSTestPerformance"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSTestPerformance_start
@@TEST_PERFORMANCE_POWERSHELL@@
:_MVSTestPerformance_end
