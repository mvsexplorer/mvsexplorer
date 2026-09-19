@echo off
:setup
REM Scoped because this standalone product-family index builder embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=build_mvs_product_family_index"
set "app.rc=0"
set "app.self=%~f0"
set "mvsf_archive_root=%~1"
set "mvsf_output_root=%~2"
set "mvsf_overrides=%~3"
set "mvsf_caller=%~nx0"
set "mvsf_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSProductFamily"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSProductFamily_start
@@PRODUCT_FAMILY_BUILDER_POWERSHELL@@
:_MVSProductFamily_end
