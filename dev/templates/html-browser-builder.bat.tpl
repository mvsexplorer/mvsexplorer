@echo off
:setup
REM Scoped because this standalone HTML browser builder embeds PowerShell.
setlocal DisableDelayedExpansion
set "app.version=@@TOOL_VERSION@@"
set "app.name=build_mvs_html_browser"
set "app.rc=0"
set "app.self=%~f0"
set "mvshb_index_root=%~1"
set "mvshb_output_file=%~2"
set "mvshb_caller=%~nx0"
set "mvshb_version=%app.version%"
:main
set "RunPowerShellFromLabel.function=MVSHtmlBrowser"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSHtmlBrowser_start
@@HTML_BROWSER_POWERSHELL@@
:_MVSHtmlBrowser_end
