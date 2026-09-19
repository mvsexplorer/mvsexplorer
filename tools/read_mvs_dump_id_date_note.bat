@echo off
:setup
set "app.version=0.1.0"
set "app.name=read_mvs_dump_id_date_note"
set "app.rc=0"
:main
call "%~dp0tools\MVS_Query.bat" machine "id,date,note" "%~1" "%~nx0"
set "app.rc=%errorlevel%"
:end
call :SetErrorLevel %app.rc%
GoTo :EOF

:: ============================================================
:: :SetErrorLevel
:: Sets the batch return code.
::
:: Version:
::   1.0.0
::
:: Usage: call :SetErrorLevel code
::
:: Arguments:
::   code  integer return code
::
:: Output:
::   None
::
:: Returns:
::   code
:: ============================================================
:SetErrorLevel
exit /b %~1
