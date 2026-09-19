@echo off
:setup
REM Scoped because this standalone product-family query tool embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=@@TOOL_NAME@@"
set "app.rc=0"
set "app.self=%~f0"
set "mvsfq_mode=@@MODE@@"
set "mvsfq_operation=@@OPERATION@@"
set "mvsfq_index=%~1"
set "mvsfq_search=%~2"
set "mvsfq_caller=%~nx0"
set "mvsfq_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSProductFamilyQuery"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSProductFamilyQuery_start
@@PRODUCT_FAMILY_QUERY_POWERSHELL@@
:_MVSProductFamilyQuery_end
