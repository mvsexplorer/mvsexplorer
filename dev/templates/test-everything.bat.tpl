@echo off
:setup
setlocal DisableDelayedExpansion
set "app.version=@@VERSION@@"
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
set "mvste_project_version=@@PROJECT_VERSION@@"
:main
set "RunPowerShellFromLabel.function=MVSTestEverything"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSTestEverything_start
@@TEST_EVERYTHING_POWERSHELL@@
:_MVSTestEverything_end
