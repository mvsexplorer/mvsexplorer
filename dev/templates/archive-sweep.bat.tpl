@echo off
:setup
REM Scoped because this standalone archive sweep harness embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=test_all_dumps"
set "app.rc=0"
set "app.self=%~f0"
set "mvsa_archive_root=%~1"
set "mvsa_arg2=%~2"
set "mvsa_arg3=%~3"
set "mvsa_arg4=%~4"
set "mvsa_arg5=%~5"
set "mvsa_arg6=%~6"
set "mvsa_arg7=%~7"
set "mvsa_arg8=%~8"
set "mvsa_arg9=%~9"
set "mvsa_caller=%~nx0"
set "mvsa_script_root=%~dp0"
set "mvsa_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSArchiveSweep"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSArchiveSweep_start
@@ARCHIVE_SWEEP_POWERSHELL@@
:_MVSArchiveSweep_end
