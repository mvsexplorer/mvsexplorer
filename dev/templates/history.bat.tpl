@echo off
:setup
REM Scoped because this standalone archive-history tool embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=@@TOOL_NAME@@"
set "app.rc=0"
set "app.self=%~f0"
set "mvsh_mode=@@MODE@@"
set "mvsh_archive_root=%~1"
set "mvsh_output_root=%~2"
set "mvsh_caller=%~nx0"
set "mvsh_script_root=%~dp0"
set "mvsh_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSHistory"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSHistory_start
@@HISTORY_POWERSHELL@@
:_MVSHistory_end
