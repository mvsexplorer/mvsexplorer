@echo off
:setup
REM Displays health/completeness for the latest mvs_databases* folder in current/parent.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=display_mvs_database_summary"
set "app.rc=0"
set "app.self=%~f0"
set "mvsdisp_invocation_dir=%CD%"
set "mvsdisp_version=%app.version%"
set "mvsdisp_project_version=@@PROJECT_VERSION@@"
:main
set "RunPowerShellFromLabel.function=MVSDisplayDatabaseSummary"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSDisplayDatabaseSummary_start
@@POWERSHELL@@
:_MVSDisplayDatabaseSummary_end
