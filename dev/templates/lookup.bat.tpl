@echo off
:setup
REM Scoped because this standalone tool embeds PowerShell and should not leak state.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=@@TOOL_NAME@@"
set "app.rc=0"
set "app.self=%~f0"
set "mvsl_source=@@SOURCE@@"
set "mvsl_target=@@TARGET@@"
set "mvsl_dump=%~1"
set "mvsl_pattern=%~2"
set "mvsl_caller=%~nx0"
set "mvsl_script_root=%~dp0"
set "mvsl_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSLookup"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSLookup_start
@@LOOKUP_POWERSHELL@@
:_MVSLookup_end
