@echo off
:: ============================================================
:: git_commit_and_push_now.bat
:: Reviews all local changes, stages everything, validates the staged
:: result, creates one commit, pushes it, and displays final status.
::
:: Usage:
::   call tools\git_commit_and_push_now.bat
::   call tools\git_commit_and_push_now.bat message "Refactor helpers"
::   call tools\git_commit_and_push_now.bat message "Refactor helpers" fulldiff yes
::   call tools\git_commit_and_push_now.bat message "Refactor helpers" PUBLISH COMMIT
::   call tools\git_commit_and_push_now.bat historyexact yes messagefile "commit-message.txt" PUBLISH COMMIT
::
:: Arguments:
::   message      One-line commit message.
::   messagefile  UTF-8/text commit message file passed to git commit -F.
::   fulldiff     yes or no. Default: no.
::   historyexact yes or no. Default: no. When yes, preserves imported
::                historical bytes by bypassing line/whitespace rejection
::                and staging with core.autocrlf=false. Requires explicit
::                PUBLISH and COMMIT confirmations.
::   PUBLISH   supplies the staging confirmation.
::   COMMIT    supplies the commit-and-push confirmation.
::
:: Workflow:
::   - show short status
::   - check unstaged and already-staged whitespace
::   - show unstaged and staged summaries
::   - require PUBLISH confirmation
::   - stage all changes
::   - show staged stat, name-status, and whitespace check
::   - show the full staged patch only when fulldiff yes is requested
::   - require COMMIT confirmation
::   - commit and push
::   - show final short branch status
::
:: Returns: 0 on successful commit and push, successful push-only,
::             cancellation before committing, or help
::          1 on Git, repository, validation, staging, commit, or push failure
::          2 on invalid arguments
:: Requires: _common.bat, git, :Main, :ParseArgs, :GetCommitMessage,
::           :PushCurrent, :EnsureGitHubPushReady, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_commit_push.message="
set "app.git_commit_push.messagefile="
set "app.git_commit_push.fulldiff=no"
set "app.git_commit_push.historyexact=no"
set "app.git_commit_push.dirty="
set "app.git_commit_push.staged="
set "app.git_commit_push.branch="
set "app.git_commit_push.pushed.by.login="
set "app.git_commit_push.confirm="
set "app.git_commit_push.confirm.publish="
set "app.git_commit_push.confirm.commit="
set "app.git_commit_push.help="
set "app.git_commit_push.rc=0"
call "%~dp0_common.bat" init
set "app.git_commit_push.rc=%errorlevel%"
if "%app.git_commit_push.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.git_commit_push.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_commit_push.rc%
:: ============================================================
:: :Main
:: Performs the complete guarded review, stage, commit, and push
:: workflow, or pushes pending commits when no files changed.
::
:: Usage: call :Main [message TEXT] [fulldiff yes|no]
::
:: Returns: 0 on success, cancellation, push-only success, or help
::          1 on Git, repository, validation, staging, commit, or push failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :GetCommitMessage, :PushCurrent, :ShowHelp, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gcam_ 2^>nul') do set "%%v="
if defined _gcam_rc (set "_gcam_rc=" & exit /b %_gcam_rc%)
call :ParseArgs %*
set "_gcam_rc=%errorlevel%"
if not "%_gcam_rc%"=="0" goto :Main
if defined app.git_commit_push.help goto :_Main_help
call :NormalizeYesNo app.git_commit_push.fulldiff
if errorlevel 1 (echo ERROR: fulldiff must be yes or no. & set "_gcam_rc=2" & goto :Main)
call :NormalizeYesNo app.git_commit_push.historyexact
if errorlevel 1 (echo ERROR: historyexact must be yes or no. & set "_gcam_rc=2" & goto :Main)
if /I not "%app.git_commit_push.historyexact%"=="yes" goto :_Main_historyexact_ready
if not defined app.git_commit_push.confirm.publish (echo ERROR: historyexact yes requires explicit PUBLISH confirmation. & set "_gcam_rc=2" & goto :Main)
if not defined app.git_commit_push.confirm.commit (echo ERROR: historyexact yes requires explicit COMMIT confirmation. & set "_gcam_rc=2" & goto :Main)
if /I not "%HISTORY_IMPORT_EXACT%"=="1" (echo ERROR: historyexact yes is reserved for the history-import tool. & set "_gcam_rc=2" & goto :Main)
echo.
echo HISTORY EXACT MODE: archived bytes will be preserved exactly.
echo Line-ending and whitespace rejection is bypassed for this import commit.
:_Main_historyexact_ready
echo.
echo ============================================================
echo  Review, commit, and push
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gcam_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gcam_rc=1" & goto :Main)
echo Current status:
echo.
git status --short
set "_gcam_status_rc=%errorlevel%"
if not "%_gcam_status_rc%"=="0" (echo ERROR: Git status failed. & set "_gcam_rc=1" & goto :Main)
set "app.git_commit_push.dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_commit_push.dirty=1"
if defined app.git_commit_push.dirty goto :_Main_checks
echo No local file changes need to be committed.
echo Trying push in case local commits are pending...
echo.
call :PushCurrent
set "_gcam_rc=%errorlevel%" & goto :Main
:_Main_checks
echo.
if /I "%app.git_commit_push.historyexact%"=="yes" goto :_Main_summary
echo Checking unstaged whitespace...
git diff --check
set "_gcam_check_rc=%errorlevel%"
if "%_gcam_check_rc%"=="0" goto :_Main_cached_check
echo.
echo ERROR: Unstaged changes contain whitespace errors.
echo Correct the reported lines before publishing.
set "_gcam_rc=1" & goto :Main
:_Main_cached_check
echo Checking already-staged whitespace...
git diff --cached --check
set "_gcam_check_rc=%errorlevel%"
if "%_gcam_check_rc%"=="0" goto :_Main_summary
echo.
echo ERROR: Already-staged changes contain whitespace errors.
echo Correct the reported lines before publishing.
set "_gcam_rc=1" & goto :Main
:_Main_summary
echo.
echo ============================================================
echo  Before staging
echo ============================================================
echo.
echo Unstaged diff summary:
git --no-pager diff --stat
set "_gcam_diff_rc=%errorlevel%"
if not "%_gcam_diff_rc%"=="0" (echo ERROR: Unstaged diff summary failed. & set "_gcam_rc=1" & goto :Main)
echo.
echo Unstaged file status:
git --no-pager diff --name-status
set "_gcam_diff_rc=%errorlevel%"
if not "%_gcam_diff_rc%"=="0" (echo ERROR: Unstaged name-status failed. & set "_gcam_rc=1" & goto :Main)
echo.
echo Already-staged diff summary:
git --no-pager diff --cached --stat
set "_gcam_diff_rc=%errorlevel%"
if not "%_gcam_diff_rc%"=="0" (echo ERROR: Staged diff summary failed. & set "_gcam_rc=1" & goto :Main)
echo.
echo Already-staged file status:
git --no-pager diff --cached --name-status
set "_gcam_diff_rc=%errorlevel%"
if not "%_gcam_diff_rc%"=="0" (echo ERROR: Staged name-status failed. & set "_gcam_rc=1" & goto :Main)
echo.
echo Untracked files are listed in the short status above.
echo.
if defined app.git_commit_push.confirm.publish (
echo Command-line confirmation: PUBLISH
goto :_Main_stage
)
set "app.git_commit_push.confirm="
set /p "app.git_commit_push.confirm=Type PUBLISH to stage all changes: "
if "%app.git_commit_push.confirm%"=="PUBLISH" goto :_Main_stage
echo.
echo Cancelled. Nothing new was staged, committed, or pushed.
set "_gcam_rc=0" & goto :Main
:_Main_stage
if /I "%app.git_commit_push.historyexact%"=="yes" (git -c core.autocrlf=false add --all) else (git add --all)
set "_gcam_stage_rc=%errorlevel%"
if "%_gcam_stage_rc%"=="0" goto :_Main_staged_exists
echo ERROR: git add --all failed.
set "_gcam_rc=1" & goto :Main
:_Main_staged_exists
git diff --cached --quiet
if errorlevel 1 goto :_Main_staged_check
echo.
echo No staged changes remain after staging.
echo Nothing was committed.
set "_gcam_rc=0" & goto :Main
:_Main_staged_check
echo.
if /I "%app.git_commit_push.historyexact%"=="yes" goto :_Main_staged_review
echo Checking final staged whitespace...
git diff --cached --check
set "_gcam_check_rc=%errorlevel%"
if "%_gcam_check_rc%"=="0" goto :_Main_staged_review
echo.
echo ERROR: Final staged changes contain whitespace errors.
echo.
echo The changes remain staged so you can correct or inspect them.
set "_gcam_rc=1" & goto :Main
:_Main_staged_review
echo.
echo ============================================================
echo  Final staged review
echo ============================================================
echo.
echo Staged diff summary:
git --no-pager diff --cached --stat
set "_gcam_diff_rc=%errorlevel%"
if not "%_gcam_diff_rc%"=="0" (echo ERROR: Final staged diff summary failed. & set "_gcam_rc=1" & goto :Main)
echo.
echo Staged file status:
git --no-pager diff --cached --name-status
set "_gcam_diff_rc=%errorlevel%"
if not "%_gcam_diff_rc%"=="0" (echo ERROR: Final staged name-status failed. & set "_gcam_rc=1" & goto :Main)
echo.
if /I "%app.git_commit_push.fulldiff%"=="yes" goto :_Main_full_diff
echo Full staged diff was skipped.
echo Use fulldiff yes when the complete patch is specifically needed.
goto :_Main_after_full_diff
:_Main_full_diff
echo Full staged diff:
echo.
git --no-pager diff --cached
set "_gcam_diff_rc=%errorlevel%"
if not "%_gcam_diff_rc%"=="0" (echo ERROR: Full staged diff failed. & set "_gcam_rc=1" & goto :Main)
:_Main_after_full_diff
echo.
call :GetCommitMessage
set "_gcam_message_rc=%errorlevel%"
if not "%_gcam_message_rc%"=="0" (set "_gcam_rc=%_gcam_message_rc%" & goto :Main)
if defined app.git_commit_push.confirm.commit (
echo Command-line confirmation: COMMIT
goto :_Main_commit
)
set "app.git_commit_push.confirm="
set /p "app.git_commit_push.confirm=Type COMMIT to commit and push these staged changes: "
if "%app.git_commit_push.confirm%"=="COMMIT" goto :_Main_commit
echo.
echo Cancelled before commit.
echo The reviewed changes remain staged.
set "_gcam_rc=0" & goto :Main
:_Main_commit
if defined app.git_commit_push.messagefile goto :_Main_commit_file
git commit -m "%app.git_commit_push.message%"
goto :_Main_commit_done
:_Main_commit_file
git commit -F "%app.git_commit_push.messagefile%"
:_Main_commit_done
set "_gcam_commit_rc=%errorlevel%"
if "%_gcam_commit_rc%"=="0" goto :_Main_push
echo ERROR: git commit failed.
set "_gcam_rc=1" & goto :Main
:_Main_push
call :PushCurrent
set "_gcam_push_rc=%errorlevel%"
if "%_gcam_push_rc%"=="0" goto :_Main_success
echo.
echo ERROR: The commit was saved locally, but push failed.
echo Retry later with:
echo   just_push.bat
echo.
echo Current status:
git status --short --branch
set "_gcam_rc=1" & goto :Main
:_Main_success
echo.
echo ============================================================
echo  Publish complete
echo ============================================================
echo.
git status --short --branch
set "_gcam_status_rc=%errorlevel%"
if "%_gcam_status_rc%"=="0" (set "_gcam_rc=0" & goto :Main)
echo WARNING: Commit and push succeeded, but final status failed.
set "_gcam_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_gcam_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :GetCommitMessage
:: Prompts for a commit message when none was supplied and creates
:: a timestamped default when Enter is pressed.
::
:: Usage: call :GetCommitMessage
::
:: Output:
::   app.git_commit_push.message  final commit message
::
:: Returns: 0
:: Requires: none
:: ============================================================
:GetCommitMessage
for /f "tokens=1 delims==" %%v in ('set gcag_ 2^>nul') do set "%%v="
if defined _gcag_rc (set "_gcag_rc=" & exit /b %_gcag_rc%)
if not defined app.git_commit_push.messagefile goto :_GetCommitMessage_no_file
if exist "%app.git_commit_push.messagefile%" (set "_gcag_rc=0" & goto :GetCommitMessage)
echo ERROR: Commit message file was not found:
echo   "%app.git_commit_push.messagefile%"
set "_gcag_rc=2" & goto :GetCommitMessage
:_GetCommitMessage_no_file
if defined app.git_commit_push.message (set "_gcag_rc=0" & goto :GetCommitMessage)
set /p "app.git_commit_push.message=Commit message, or press Enter for default: "
if defined app.git_commit_push.message (set "_gcag_rc=0" & goto :GetCommitMessage)
set "app.git_commit_push.message=Manual save %APP_DISPLAY_NAME% %DATE% %TIME%"
set "_gcag_rc=0" & goto :GetCommitMessage
:: ============================================================
:: :PushCurrent
:: Pushes the current named branch. For a GitHub origin, it first
:: verifies GitHub CLI authentication. When logged out, just_login
:: owns authentication, repository setup, and the pending push.
::
:: Usage: call :PushCurrent
::
:: Returns: 0 on success
::          1 when authentication, branch, origin, or push fails
:: Requires: git, :EnsureGitHubPushReady
:: ============================================================
:PushCurrent
for /f "tokens=1 delims==" %%v in ('set gcap_ 2^>nul') do set "%%v="
if defined _gcap_rc (set "_gcap_rc=" & exit /b %_gcap_rc%)
set "app.git_commit_push.branch="
set "app.git_commit_push.pushed.by.login="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_commit_push.branch=%%A"
if defined app.git_commit_push.branch goto :_PushCurrent_auth
echo ERROR: A named branch is not checked out.
set "_gcap_rc=1" & goto :PushCurrent
:_PushCurrent_auth
call :EnsureGitHubPushReady
set "gcap_auth_rc=%errorlevel%"
if not "%gcap_auth_rc%"=="0" (set "_gcap_rc=%gcap_auth_rc%" & goto :PushCurrent)
if defined app.git_commit_push.pushed.by.login goto :_PushCurrent_success
:_PushCurrent_tracking
git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>nul
if errorlevel 1 goto :_PushCurrent_new_tracking
git push
set "gcap_push_rc=%errorlevel%"
if "%gcap_push_rc%"=="0" goto :_PushCurrent_success
echo ERROR: Push failed.
set "_gcap_rc=1" & goto :PushCurrent
:_PushCurrent_new_tracking
git remote get-url origin >nul 2>nul
if not errorlevel 1 goto :_PushCurrent_push_origin
echo ERROR: No upstream branch or origin remote is configured.
set "_gcap_rc=1" & goto :PushCurrent
:_PushCurrent_push_origin
git push -u origin "%app.git_commit_push.branch%"
set "gcap_push_rc=%errorlevel%"
if "%gcap_push_rc%"=="0" goto :_PushCurrent_success
echo ERROR: Push failed.
set "_gcap_rc=1" & goto :PushCurrent
:_PushCurrent_success
echo Push complete.
set "_gcap_rc=0" & goto :PushCurrent
:: ============================================================
:: :EnsureGitHubPushReady
:: Detects a github.com origin and verifies GitHub CLI credentials.
:: Successful preparation is silent. When authentication is absent
:: or unusable, just_login.bat performs login, setup, and the push.
::
:: Usage: call :EnsureGitHubPushReady
::
:: Output:
::   app.git_commit_push.pushed.by.login=1 when just_login pushed
::
:: Returns: 0 when direct push is ready or just_login succeeded
::          just_login exit code when login or setup fails
:: Requires: prepare.bat when present, gh for GitHub, just_login.bat
:: ============================================================
:EnsureGitHubPushReady
for /f "tokens=1 delims==" %%v in ('set gcauth_ 2^>nul') do set "%%v="
if defined _gcauth_rc (set "_gcauth_rc=" & exit /b %_gcauth_rc%)
set "app.git_commit_push.pushed.by.login="
set "gcauth_origin="
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "gcauth_origin=%%A"
if not defined gcauth_origin (set "_gcauth_rc=0" & goto :EnsureGitHubPushReady)
echo(%gcauth_origin%| findstr /I /C:"github.com" >nul
if errorlevel 1 (set "_gcauth_rc=0" & goto :EnsureGitHubPushReady)
if exist "%CD%\prepare.bat" call "%CD%\prepare.bat" repository >nul 2>&1
where gh.exe >nul 2>nul
if errorlevel 1 goto :_EnsureGitHubPushReady_login
gh auth status --hostname github.com >nul 2>nul
if errorlevel 1 goto :_EnsureGitHubPushReady_login
gh auth setup-git --hostname github.com >nul 2>nul
if errorlevel 1 goto :_EnsureGitHubPushReady_login
set "_gcauth_rc=0" & goto :EnsureGitHubPushReady
:_EnsureGitHubPushReady_login
echo GitHub authentication is required before pushing.
echo Starting just_login.bat...
echo.
call "%~dp0just_login.bat"
set "gcauth_login_rc=%errorlevel%"
if "%gcauth_login_rc%"=="0" goto :_EnsureGitHubPushReady_done
echo ERROR: GitHub login or repository setup failed.
set "_gcauth_rc=%gcauth_login_rc%" & goto :EnsureGitHubPushReady
:_EnsureGitHubPushReady_done
set "app.git_commit_push.pushed.by.login=1"
set "_gcauth_rc=0" & goto :EnsureGitHubPushReady
:: ============================================================
:: :ParseArgs
:: Parses optional message/messagefile, full-diff, history-exact, and help.
::
:: Usage: call :ParseArgs [message TEXT] [messagefile PATH] [fulldiff yes|no] [historyexact yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="message" goto :_ParseArgs_message
if /I "%~1"=="messagefile" goto :_ParseArgs_messagefile
if /I "%~1"=="fulldiff" goto :_ParseArgs_fulldiff
if /I "%~1"=="historyexact" goto :_ParseArgs_historyexact
if "%~1"=="PUBLISH" (set "app.git_commit_push.confirm.publish=1" & shift & goto :ParseArgs)
if "%~1"=="COMMIT" (set "app.git_commit_push.confirm.commit=1" & shift & goto :ParseArgs)
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_commit_push.message (set "app.git_commit_push.message=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_message
if "%~2"=="" (echo ERROR: message requires text. & exit /b 2)
set "app.git_commit_push.message=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_messagefile
if "%~2"=="" (echo ERROR: messagefile requires a path. & exit /b 2)
set "app.git_commit_push.messagefile=%~f2"
shift
shift
goto :ParseArgs
:_ParseArgs_fulldiff
if "%~2"=="" (echo ERROR: fulldiff requires yes or no. & exit /b 2)
set "app.git_commit_push.fulldiff=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_historyexact
if "%~2"=="" (echo ERROR: historyexact requires yes or no. & exit /b 2)
set "app.git_commit_push.historyexact=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_commit_push.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :NormalizeYesNo
:: Normalizes a named variable to yes or no.
::
:: Usage: call :NormalizeYesNo variableName
::
:: Returns: 0 when valid
::          1 when invalid
:: Requires: none
:: ============================================================
:NormalizeYesNo
for /f "tokens=1 delims==" %%v in ('set gcpy_ 2^>nul') do set "%%v="
if defined _gcpy_rc (set "_gcpy_rc=" & exit /b %_gcpy_rc%)
set "gcpy_name=%~1"
call set "gcpy_value=%%%gcpy_name%%%"
if /I "%gcpy_value%"=="y" set "%gcpy_name%=yes"
if /I "%gcpy_value%"=="yes" set "%gcpy_name%=yes"
if /I "%gcpy_value%"=="true" set "%gcpy_name%=yes"
if /I "%gcpy_value%"=="1" set "%gcpy_name%=yes"
if /I "%gcpy_value%"=="n" set "%gcpy_name%=no"
if /I "%gcpy_value%"=="no" set "%gcpy_name%=no"
if /I "%gcpy_value%"=="false" set "%gcpy_name%=no"
if /I "%gcpy_value%"=="0" set "%gcpy_name%=no"
call set "gcpy_value=%%%gcpy_name%%%"
if /I "%gcpy_value%"=="yes" (set "_gcpy_rc=0" & goto :NormalizeYesNo)
if /I "%gcpy_value%"=="no" (set "_gcpy_rc=0" & goto :NormalizeYesNo)
set "_gcpy_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ShowHelp
:: Displays the complete guarded publish workflow.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_commit_and_push_now.bat
echo.
echo Usage:
echo   git_commit_and_push_now.bat
echo   git_commit_and_push_now.bat message "Refactor helpers"
echo   git_commit_and_push_now.bat message "Refactor helpers" fulldiff yes
echo   git_commit_and_push_now.bat message "Refactor helpers" PUBLISH COMMIT
echo   git_commit_and_push_now.bat historyexact yes messagefile "commit-message.txt" PUBLISH COMMIT
echo.
echo The helper reviews changes, stages everything, validates the
echo final staged result, commits after confirmation, pushes, and
echo displays final branch status.
echo.
echo The complete patch is skipped by default to avoid paging or
echo flooding the console. fulldiff yes prints it without a pager.
echo.
echo Exact uppercase PUBLISH and COMMIT tokens may supply the two
echo confirmations directly from the command line.
echo.
echo historyexact yes is reserved for reviewed archive-history replay.
echo It requires HISTORY_IMPORT_EXACT=1 plus PUBLISH and COMMIT.
echo.
exit /b 0
:: ============================================================
:: :PauseIfNeeded
:: Pauses only when the outermost launcher is the cmd.exe /c target.
::
:: Usage: call :PauseIfNeeded
::
:: Returns: 0
:: Requires: :IsConsole
:: ============================================================
:PauseIfNeeded
for /f "tokens=1 delims==" %%v in ('set pif_ 2^>nul') do set "%%v="
if defined _pif_rc (set "_pif_rc=" & exit /b %_pif_rc%)
call :IsConsole
if not errorlevel 1 (set "_pif_rc=0" & goto :PauseIfNeeded)
echo.
pause
set "_pif_rc=0" & goto :PauseIfNeeded
:: ============================================================
:: :IsConsole
:: Detects whether the outermost launcher is running in an existing
:: interactive console.
::
:: Usage: call :IsConsole
::
:: Returns: 0 when running in an existing console
::          1 when the outermost launcher is the cmd.exe /c target
:: Requires: find.exe
:: ============================================================
:IsConsole
setlocal EnableDelayedExpansion
set "ic_cmdline=!CMDCMDLINE!"
echo(!ic_cmdline!| "%SystemRoot%\System32\find.exe" /I " /c " >nul
if errorlevel 1 (endlocal & exit /b 0)
echo(!ic_cmdline!| "%SystemRoot%\System32\find.exe" /I "!app.launch.name!" >nul
if errorlevel 1 (endlocal & exit /b 0)
endlocal & exit /b 1
