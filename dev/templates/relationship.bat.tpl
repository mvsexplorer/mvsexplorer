@echo off
:setup
REM Scoped because this standalone relationship query embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=@@TOOL_NAME@@"
set "app.rc=0"
set "app.self=%~f0"
set "mvsr_mode=@@MODE@@"
set "mvsr_fields=@@FIELDS@@"
set "mvsr_source=@@SOURCE@@"
set "mvsr_dump=%~1"
set "mvsr_search=%~2"
set "mvsr_caller=%~nx0"
set "mvsr_script_root=%~dp0"
set "mvsr_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSRelationship"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSRelationship_start
@@RELATIONSHIP_POWERSHELL@@
:_MVSRelationship_end
