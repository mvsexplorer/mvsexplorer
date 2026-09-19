@echo off
:setup
REM Scoped because this standalone single-dump tool embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=@@TOOL_NAME@@"
set "app.rc=0"
set "app.self=%~f0"
set "mvsx_mode=@@MODE@@"
set "mvsx_operation=@@OPERATION@@"
set "mvsx_fields=@@FIELDS@@"
set "mvsx_search_source=@@SEARCH_SOURCE@@"
set "mvsx_algorithm_filter=@@ALGORITHM_FILTER@@"
set "mvsx_source_file=@@SOURCE_FILE@@"
set "mvsx_diagnostic_kind=@@DIAGNOSTIC_KIND@@"
set "mvsx_dump=%~1"
set "mvsx_search=%~2"
set "mvsx_caller=%~nx0"
set "mvsx_script_root=%~dp0"
set "mvsx_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSSingleDump"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSSingleDump_start
@@SINGLE_DUMP_POWERSHELL@@
:_MVSSingleDump_end
