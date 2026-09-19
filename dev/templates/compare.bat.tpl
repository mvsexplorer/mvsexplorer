@echo off
:setup
REM Scoped because this standalone comparison tool embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=@@TOOL_NAME@@"
set "app.rc=0"
set "app.self=%~f0"
set "mvsc_property=@@PROPERTY@@"
set "mvsc_source_file=@@SOURCE_FILE@@"
set "mvsc_id_mode=@@ID_MODE@@"
set "mvsc_first_dump=%~1"
set "mvsc_second_dump=%~2"
set "mvsc_caller=%~nx0"
set "mvsc_script_root=%~dp0"
set "mvsc_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSCompare"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSCompare_start
@@COMPARE_POWERSHELL@@
:_MVSCompare_end
