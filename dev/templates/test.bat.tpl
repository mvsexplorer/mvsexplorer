@echo off
:setup
REM Scoped because this standalone test embeds PowerShell and must not leak state.
setlocal DisableDelayedExpansion
set "app.version=@@TEST_VERSION@@"
set "app.name=@@TEST_NAME@@"
set "app.rc=0"
set "app.self=%~f0"
set "mvst_mode=@@TEST_MODE@@"
set "mvst_dump=%~1"
set "mvst_caller=%~nx0"
set "mvst_version=%app.version%"
for %%I in ("%~dp0..") do set "mvst_root=%%~fI"
:main
set "RunPowerShellFromLabel.function=MVSTest"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSTest_start
@@TEST_POWERSHELL@@
:_MVSTest_end
