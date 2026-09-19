@echo off
:setup
REM MVS database create/update launcher. Components live in create_or_update_mvs_database\.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=create_or_update_mvs_database"
set "app.rc=0"
set "app.self=%~f0"
set "mvscu_project_root=%~dp0"
set "mvscu_invocation_dir=%CD%"
set "mvscu_version=%app.version%"
set "mvscu_arg1=%~1"
set "mvscu_arg2=%~2"
set "mvscu_arg3=%~3"
set "mvscu_arg4=%~4"
:main
set "RunPowerShellFromLabel.function=MVSCreateOrUpdateDatabase"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSCreateOrUpdateDatabase_start
@@POWERSHELL@@
:_MVSCreateOrUpdateDatabase_end
