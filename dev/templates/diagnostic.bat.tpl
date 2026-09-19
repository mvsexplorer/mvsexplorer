@echo off
:setup
REM Scoped because this standalone diagnostic embeds PowerShell and must not leak state.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=@@TOOL_NAME@@"
set "app.rc=0"
set "app.self=%~f0"
set "mvsd_operation=@@OPERATION@@"
set "mvsd_property=@@PROPERTY@@"
set "mvsd_source=@@SOURCE@@"
set "mvsd_target=@@TARGET@@"
set "mvsd_dump=%~1"
set "mvsd_caller=%~nx0"
set "mvsd_script_root=%~dp0"
set "mvsd_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSDiagnostic"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSDiagnostic_start
@@DIAGNOSTIC_POWERSHELL@@
:_MVSDiagnostic_end
