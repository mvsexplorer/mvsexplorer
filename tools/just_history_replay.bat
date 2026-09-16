@echo off
:: ============================================================
:: just_history_replay.bat
:: Dry-runs, rehearses, or publishes an inspected archive history.
::
:: All arguments are forwarded to:
::   tools\history_import.py replay
::
:: Requires: Python 3 available as py.exe or python.exe.
:: ============================================================
where py.exe >nul 2>nul
if errorlevel 1 goto :try_python
py.exe -3 "%~dp0history_import.py" replay %*
exit /b %errorlevel%

:try_python
where python.exe >nul 2>nul
if errorlevel 1 goto :missing
python.exe "%~dp0history_import.py" replay %*
exit /b %errorlevel%

:missing
echo.
echo ERROR: Python 3 was not found.
echo Install/provide Python 3, then run this command again.
echo.
exit /b 1
