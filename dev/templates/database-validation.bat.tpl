@echo off
:setup
REM Validates freshly generated archive/full-family/compact-family databases and executes every family query tool.
setlocal DisableDelayedExpansion
set "app.version=0.1.2"
set "app.name=test_generated_databases"
set "app.rc=0"
set "app.self=%~f0"
set "mvsdb_archive=%~1"
set "mvsdb_family=%~2"
set "mvsdb_compact=%~3"
set "mvsdb_output=%~4"
set "mvsdb_project_version=%~5"
set "mvsdb_project_root=%~dp0.."
set "mvsdb_caller=%~nx0"
set "mvsdb_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSDatabaseValidation"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSDatabaseValidation_start
@@DATABASE_VALIDATION_POWERSHELL@@
:_MVSDatabaseValidation_end
