@echo off
:: ============================================================
:: just_publish.bat
:: Reviews line endings, then starts the existing publish workflow.
::
:: This tools-level launcher is intended to live at:
::   tools\just_publish.bat
::
:: A generic root stub named just_publish.bat may call this file.
::
:: Before staging or committing, normal publishing calls:
::   tools\just_diff_check.bat
::
:: History-import exact mode is a deliberately narrow exception:
::   historyexact yes
::
:: It is accepted only when HISTORY_IMPORT_EXACT=1 is also present.
:: In that mode the normal pre-publish line-ending/whitespace checker is
:: bypassed so archived historical bytes are not silently rewritten or
:: rejected. The downstream publisher independently enforces the same
:: guard plus explicit PUBLISH and COMMIT confirmations.
::
:: If the check succeeds (or guarded history-exact mode is active), all
:: original arguments are forwarded unchanged to:
::   tools\git_commit_and_push_now.bat
::
:: Examples:
::   just_publish.bat
::   just_publish.bat message "Describe the update"
::   just_publish.bat fulldiff yes message "Describe the update"
::   just_publish.bat historyexact yes messagefile "commit-message.txt" PUBLISH COMMIT
::
:: Returns: line-ending/diff-check result when normal review fails
::          2 when guarded history-exact arguments are invalid
::          git_commit_and_push_now.bat result otherwise
:: Requires: tools\just_diff_check.bat
::           tools\git_commit_and_push_now.bat
:: ============================================================
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
if not defined GIT_PROJECT_ROOT for %%A in ("%~dp0..") do set "GIT_PROJECT_ROOT=%%~fA"
set "app.just_publish.historyexact=no"
call :DetectHistoryExact %*
if errorlevel 1 exit /b %errorlevel%
if /I not "%app.just_publish.historyexact%"=="yes" goto :normal_check
if /I "%HISTORY_IMPORT_EXACT%"=="1" goto :history_exact
echo.
echo ERROR: historyexact yes is reserved for the history-import tool.
echo HISTORY_IMPORT_EXACT=1 was not supplied.
echo.
exit /b 2

:history_exact
echo.
echo HISTORY EXACT MODE: skipping the normal pre-publish diff checker.
echo Archived line endings and historical whitespace will be preserved.
echo.
goto :publish

:normal_check
if exist "%~dp0just_diff_check.bat" goto :check
echo.
echo ERROR: Required pre-publish checker was not found:
echo   "%~dp0just_diff_check.bat"
echo.
exit /b 1

:check
call "%~dp0just_diff_check.bat"
set "just_publish_check_rc=%errorlevel%"
if "%just_publish_check_rc%"=="0" goto :publish
echo.
echo Publish stopped before staging or committing.
echo Fix or review the reported issue, then run just_publish.bat again.
echo.
exit /b %just_publish_check_rc%

:publish
if exist "%~dp0git_commit_and_push_now.bat" goto :publish_call
echo.
echo ERROR: Publish implementation was not found:
echo   "%~dp0git_commit_and_push_now.bat"
echo.
exit /b 1

:publish_call
call "%~dp0git_commit_and_push_now.bat" %*
set "just_publish_rc=%errorlevel%"
exit /b %just_publish_rc%

:: ============================================================
:: :DetectHistoryExact
:: Finds historyexact yes|no without consuming the arguments later
:: forwarded to git_commit_and_push_now.bat.
:: ============================================================
:DetectHistoryExact
if "%~1"=="" exit /b 0
if /I "%~1"=="historyexact" goto :_DetectHistoryExact_value
shift
goto :DetectHistoryExact

:_DetectHistoryExact_value
if "%~2"=="" (
  echo ERROR: historyexact requires yes or no.
  exit /b 2
)
if /I "%~2"=="yes" (
  set "app.just_publish.historyexact=yes"
  shift
  shift
  goto :DetectHistoryExact
)
if /I "%~2"=="no" (
  set "app.just_publish.historyexact=no"
  shift
  shift
  goto :DetectHistoryExact
)
echo ERROR: historyexact must be yes or no.
exit /b 2
