@echo off
:: ============================================================
:: Generic root helper dispatcher
:: Dispatches to the matching helper under tools and preserves
:: the helper's exit code.
::
:: Usage: call THIS_FILE [arguments]
::
:: Returns: matching tools helper exit code
:: Requires: tools\THIS_FILE
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.roothelper.target=%~dp0tools\%~nx0"
set "app.roothelper.rc=0"
if exist "%app.roothelper.target%" goto :run
echo.
echo ERROR: Matching helper not found:
echo   "%app.roothelper.target%"
echo.
set "app.roothelper.rc=1"
goto :end
:run
call "%app.roothelper.target%" %*
set "app.roothelper.rc=%errorlevel%"
:end
exit /b %app.roothelper.rc%
