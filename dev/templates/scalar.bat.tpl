@echo off
:setup
REM Scoped because this standalone tool embeds PowerShell and should not leak state.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=@@TOOL_NAME@@"
set "app.rc=0"
set "app.self=%~f0"
set "mvsq_mode=@@MODE@@"
set "mvsq_fields=@@FIELDS@@"
set "mvsq_sort=@@SORT@@"
set "mvsq_dump=%~1"
set "mvsq_caller=%~nx0"
set "mvsq_script_root=%~dp0"
set "mvsq_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSQuery"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSQuery_start
@@SCALAR_POWERSHELL@@
:_MVSQuery_end
