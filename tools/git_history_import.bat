@echo off
setlocal EnableExtensions

if "%~1"=="" goto :run
if /I "%~1"=="/?" goto :run
if /I "%~1"=="/h" goto :run
if /I "%~1"=="-?" goto :run
if /I "%~1"=="-h" goto :run
if /I "%~1"=="--help" goto :run

:run
where py.exe >nul 2>nul
if errorlevel 1 goto :try_python
py.exe -3 "%~dp0git_history_import.py" %*
exit /b %errorlevel%

:try_python
where python.exe >nul 2>nul
if errorlevel 1 goto :missing
python.exe "%~dp0git_history_import.py" %*
exit /b %errorlevel%

:missing
echo.
echo ERROR: Python 3 was not found.
echo git_history_import currently requires Python 3.
echo.
exit /b 1
