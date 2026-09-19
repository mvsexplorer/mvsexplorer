@echo off
:setup
REM Scoped because this standalone compact product-family index builder embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=build_mvs_product_family_compact_index"
set "app.rc=0"
set "app.self=%~f0"
set "mvspfc_index_root=%~1"
set "mvspfc_output_root=%~2"
set "mvspfc_caller=%~nx0"
set "mvspfc_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSProductFamilyCompact"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSProductFamilyCompact_start
@@PRODUCT_FAMILY_COMPACT_POWERSHELL@@
:_MVSProductFamilyCompact_end
