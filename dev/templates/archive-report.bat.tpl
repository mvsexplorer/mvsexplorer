@echo off
:setup
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=build_archive_html_report"
set "app.rc=0"
set "app.self=%~f0"
set "mvsrep_results=%~1"
set "mvsrep_output=%~2"
set "mvsrep_exclusions=%~3"
set "mvsrep_script_root=%~dp0"
set "mvsrep_caller=%~nx0"
set "mvsrep_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSArchiveReport"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSArchiveReport_start
@@ARCHIVE_REPORT_POWERSHELL@@
:_MVSArchiveReport_end
