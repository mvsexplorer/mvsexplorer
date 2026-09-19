@echo off
:setup
REM Generated internal create/update component. It is standalone but orchestrated by create_or_update_mvs_database.bat.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=@@APP_NAME@@"
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
set "mvsdbm_project_version=@@PROJECT_VERSION@@"
:main
set "RunPowerShellFromLabel.function=MVSDatabaseMaintenance"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSDatabaseMaintenance_start
@@POWERSHELL@@
:_MVSDatabaseMaintenance_end
