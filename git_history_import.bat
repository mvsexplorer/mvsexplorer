@echo off
call "%~dp0tools\git_history_import.bat" %*
exit /b %errorlevel%
