@echo off
:setup
REM Scoped because this standalone MVS Explorer GUI embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=mvs_explorer_gui"
set "app.rc=0"
set "app.self=%~f0"
set "mvsgui_index_root=%~1"
set "mvsgui_caller=%~nx0"
set "mvsgui_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSExplorerGui"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSExplorerGui_start
@@GUI_POWERSHELL@@
:_MVSExplorerGui_end
