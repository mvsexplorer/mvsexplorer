@echo off
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_create_repo.version=git-create-repository-v2.9-safe-generated-folder-exclusions"
set "app.git_create_repo.root="
set "app.git_create_repo.provider=github"
set "app.git_create_repo.owner="
set "app.git_create_repo.name="
set "app.git_create_repo.slug="
set "app.git_create_repo.url="
set "app.git_create_repo.web="
set "app.git_create_repo.visibility=private"
set "app.git_create_repo.branch="
set "app.git_create_repo.message="
set "app.git_create_repo.description="
set "app.git_create_repo.login.mode=ask"
set "app.git_create_repo.login="
set "app.git_create_repo.browser.request=ask"
set "app.git_create_repo.identity.mode=defaults"
set "app.git_create_repo.git.name="
set "app.git_create_repo.git.email="
set "app.git_create_repo.source.mode=none"
set "app.git_create_repo.source.input="
set "app.git_create_repo.source.slug="
set "app.git_create_repo.source.url="
set "app.git_create_repo.old.slug="
set "app.git_create_repo.old.name="
set "app.git_create_repo.references=all"
set "app.git_create_repo.rename.name=yes"
set "app.git_create_repo.folder.rename=yes"
set "app.git_create_repo.folder.current.name="
set "app.git_create_repo.folder.parent="
set "app.git_create_repo.folder.target="
set "app.git_create_repo.folder.rename.required="
set "app.git_create_repo.folder.rename.ready="
set "app.git_create_repo.folder.rename.helper="
set "app.git_create_repo.confirm="
set "app.git_create_repo.prepared=no"
set "app.git_create_repo.dryrun="
set "app.git_create_repo.help="
set "app.git_create_repo.report="
set "app.git_create_repo.backup="
set "app.git_create_repo.original.head="
set "app.git_create_repo.original.branch="
set "app.git_create_repo.original.origin="
set "app.git_create_repo.original.upstream="
set "app.git_create_repo.original.git.name="
set "app.git_create_repo.original.git.email="
set "app.git_create_repo.created="
set "app.git_create_repo.commit.created="
set "app.git_create_repo.branch.created="
set "app.git_create_repo.rc=0"
set "app.git_create_repo.input="
set "app.git_create_repo.timestamp="
set "app.git_create_repo.rewrite=%~dp0git_create_repository_rewrite.ps1"
goto :main

:main
call :RunMain %*
set "app.git_create_repo.rc=%errorlevel%"
if "%app.git_create_repo.rc%"=="0" if defined app.git_create_repo.folder.rename.required if defined app.git_create_repo.folder.rename.ready goto :rename_project_folder
goto :end

:end
call :PauseIfNeeded
exit /b %app.git_create_repo.rc%

:rename_project_folder
call :PauseIfNeeded
echo.
echo Renaming project folder:
echo   %app.git_create_repo.root%
echo to:
echo   %app.git_create_repo.folder.target%
echo.
del /q "%TEMP%\git_create_repository_rename_*.bat" >nul 2>nul
set "app.git_create_repo.folder.rename.helper=%TEMP%\git_create_repository_rename_%RANDOM%_%RANDOM%.bat"
>"%app.git_create_repo.folder.rename.helper%" echo @echo off
>>"%app.git_create_repo.folder.rename.helper%" echo cd /d "%app.git_create_repo.folder.parent%"
>>"%app.git_create_repo.folder.rename.helper%" echo if errorlevel 1 goto :rename_failed
>>"%app.git_create_repo.folder.rename.helper%" echo ren "%app.git_create_repo.root%" "%app.git_create_repo.name%"
>>"%app.git_create_repo.folder.rename.helper%" echo if errorlevel 1 goto :rename_failed
>>"%app.git_create_repo.folder.rename.helper%" echo cd /d "%app.git_create_repo.folder.target%"
>>"%app.git_create_repo.folder.rename.helper%" echo if errorlevel 1 goto :rename_failed
>>"%app.git_create_repo.folder.rename.helper%" echo echo OK: Project folder renamed.
>>"%app.git_create_repo.folder.rename.helper%" echo echo DIR: %app.git_create_repo.folder.target%
>>"%app.git_create_repo.folder.rename.helper%" echo exit /b 0
>>"%app.git_create_repo.folder.rename.helper%" echo :rename_failed
>>"%app.git_create_repo.folder.rename.helper%" echo echo ERROR: The repository was created and pushed, but the project folder could not be renamed.
>>"%app.git_create_repo.folder.rename.helper%" echo echo Expected folder:
>>"%app.git_create_repo.folder.rename.helper%" echo echo   %app.git_create_repo.folder.target%
>>"%app.git_create_repo.folder.rename.helper%" echo exit /b 1
if not exist "%app.git_create_repo.folder.rename.helper%" (echo ERROR: Could not create the temporary folder-rename helper. & exit /b 1)
REM Do not CALL this helper. It replaces the creator batch context so cmd.exe
REM never resumes a batch file whose parent folder has just been renamed.
"%app.git_create_repo.folder.rename.helper%"

:: ============================================================
:: Function RunMain
:: Purpose
::   Runs the complete new-repository migration workflow.
:: Usage
::   call Main with supported command-line arguments
:: Returns
::   0 success, cancellation, or dry run
::   1 operational failure
::   2 invalid arguments
:: ============================================================
:RunMain
call :ParseArgs %*
set "gcrm_rc=%errorlevel%"
if not "%gcrm_rc%"=="0" exit /b %gcrm_rc%
if defined app.git_create_repo.help (call :ShowHelp & exit /b %errorlevel%)
call :ResolveProjectRoot
if errorlevel 1 exit /b 1
pushd "%app.git_create_repo.root%" >nul 2>&1
if errorlevel 1 (echo ERROR: Could not enter the project root. & exit /b 1)
call :PrepareDependencies
if errorlevel 1 (popd & exit /b 1)
call :AuthenticateGitHub
if errorlevel 1 (popd & exit /b 1)
call :ResolveSourceRepository
if errorlevel 1 (popd & exit /b 1)
call :ResolveTargetRepository
if errorlevel 1 (popd & exit /b 1)
call :ResolveOptions
if errorlevel 1 (popd & exit /b 1)
call :ResolveFolderRename
if errorlevel 1 (popd & exit /b 1)
call :ValidateWorkspace
if errorlevel 1 (popd & exit /b 1)
call :BuildMigrationPlan
if errorlevel 1 (popd & exit /b 1)
call :ShowPlan
if errorlevel 1 (popd & exit /b 1)
if defined app.git_create_repo.dryrun (echo. & echo DRY RUN: dependencies may have been prepared; no project files, commits, remotes, or repositories were changed. & popd & exit /b 0)
call :ConfirmCreation
if errorlevel 1 (popd & exit /b 0)
call :CaptureOriginalState
if errorlevel 1 (popd & exit /b 1)
call :EnsureTargetBranch
if errorlevel 1 (popd & exit /b 1)
call :ApplyReferenceChanges
if errorlevel 1 (call :RollbackLocalMigration & popd & exit /b 1)
call :EnsureGitIdentity
if errorlevel 1 (call :RollbackLocalMigration & popd & exit /b 1)
call :CreateMigrationCommit
if errorlevel 1 (call :RollbackLocalMigration & popd & exit /b 1)
call :CreateGitHubRepository
if errorlevel 1 (call :RollbackLocalMigration & popd & exit /b 1)
call :ConfigureRemotes
if errorlevel 1 (call :RestoreRemotes & popd & exit /b 1)
call :PushBranch
if errorlevel 1 (popd & exit /b 1)
call :ShowSuccess
set "gcrm_rc=%errorlevel%"
if "%gcrm_rc%"=="0" set "app.git_create_repo.folder.rename.ready=1"
popd
exit /b %gcrm_rc%

:: ============================================================
:: Function PrepareDependencies
:: Purpose
::   Prepares Git and GitHub CLI without authenticating.
:: Usage
::   call PrepareDependencies
:: Returns
::   0 dependencies ready
::   1 preparation or dependency failure
:: ============================================================
:PrepareDependencies
if not exist "%app.git_create_repo.root%\prepare.bat" (echo ERROR: prepare.bat was not found in the project root. & exit /b 1)
if not exist "%app.git_create_repo.rewrite%" (echo ERROR: Rewrite helper was not found: & echo   %app.git_create_repo.rewrite% & exit /b 1)
if not exist "%~dp0git_login.bat" (echo ERROR: Shared GitHub login helper was not found: & echo   %~dp0git_login.bat & exit /b 1)
if /I "%app.git_create_repo.prepared%"=="yes" goto :PrepareDependenciesCheck
echo.
echo Preparing Git and GitHub CLI...
call "%app.git_create_repo.root%\prepare.bat" repository
set "gcrpd_rc=%errorlevel%"
if not "%gcrpd_rc%"=="0" (echo ERROR: Repository dependency preparation failed. & exit /b 1)
:PrepareDependenciesCheck
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git is unavailable after preparation. & exit /b 1)
where gh.exe >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI is unavailable after preparation. & exit /b 1)
where powershell.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Windows PowerShell is unavailable. & exit /b 1)
exit /b 0

:: ============================================================
:: Function AuthenticateGitHub
:: Purpose
::   Uses git_login.bat authentication-only mode to reuse or establish
::   GitHub CLI authentication without changing repository state.
:: Usage
::   call AuthenticateGitHub
:: Output
::   app.git_create_repo.login
:: Returns
::   0 authenticated and Git credentials configured
::   1 shared authentication failed or was cancelled
:: Requires
::   git_login.bat
:: ============================================================
:AuthenticateGitHub
echo.
call "%~dp0git_login.bat" authenticate prepared yes pause no login "%app.git_create_repo.login.mode%" browser "%app.git_create_repo.browser.request%"
set "gcra_rc=%errorlevel%"
if not "%gcra_rc%"=="0" (echo ERROR: GitHub authentication failed or was cancelled. & exit /b 1)
set "app.git_create_repo.login=%app.git_login.login%"
if not defined app.git_create_repo.login (echo ERROR: Shared GitHub login did not return an authenticated account. & exit /b 1)
exit /b 0

:: ============================================================
:: Function ResolveSourceRepository
:: Purpose
::   Resolves the old repository identity used for reference changes.
::   An existing upstream is preferred over origin.
:: Usage
::   call ResolveSourceRepository
:: Output
::   app.git_create_repo.old.slug
::   app.git_create_repo.source.slug and source.url
:: Returns
::   0 source resolved
::   1 source input is invalid
:: ============================================================
:ResolveSourceRepository
set "gcrsr_input=%app.git_create_repo.source.input%"
if /I "%gcrsr_input%"=="none" set "gcrsr_input="
if /I "%gcrsr_input%"=="keep" set "gcrsr_input="
if not defined gcrsr_input for /f "delims=" %%A in ('git remote get-url upstream 2^>nul') do set "gcrsr_input=%%A"
if not defined gcrsr_input for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "gcrsr_input=%%A"
if not defined gcrsr_input if defined app.repo_slug set "gcrsr_input=%app.repo_slug%"
if not defined gcrsr_input if defined CFG_REPO_URL set "gcrsr_input=%CFG_REPO_URL%"
if not defined gcrsr_input (echo ERROR: Could not determine the current repository. & echo Supply source OWNER/REPOSITORY. & exit /b 1)
set "GCR_SOURCE_INPUT=%gcrsr_input%"
set "gcrsr_slug="
for /f "delims=" %%A in ('powershell.exe -NoProfile -Command "$u=$env:GCR_SOURCE_INPUT.Trim(); if($u -match 'github\.com[:/](?<o>[^/]+)/(?<r>[^/]+?)(?:\.git)?/?$'){Write-Output ($Matches.o+'/'+$Matches.r)} elseif($u -match '^[^/]+/[^/]+$'){Write-Output $u}" 2^>nul') do set "gcrsr_slug=%%A"
set "GCR_SOURCE_INPUT="
if not defined gcrsr_slug (echo ERROR: Source repository is not a supported GitHub URL or OWNER/REPOSITORY slug: & echo   %gcrsr_input% & exit /b 1)
set "app.git_create_repo.source.slug="
set "app.git_create_repo.source.url="
for /f "delims=" %%A in ('gh repo view "%gcrsr_slug%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_create_repo.source.slug=%%A"
for /f "delims=" %%A in ('gh repo view "%gcrsr_slug%" --json url --jq ".url" 2^>nul') do set "app.git_create_repo.source.url=%%A.git"
if not defined app.git_create_repo.source.slug (echo ERROR: Source repository was not found or is not visible: & echo   %gcrsr_slug% & exit /b 1)
set "app.git_create_repo.old.slug=%app.git_create_repo.source.slug%"
for /f "tokens=2 delims=/" %%A in ("%app.git_create_repo.old.slug%") do set "app.git_create_repo.old.name=%%A"
if /I "%app.git_create_repo.source.input%"=="none" set "app.git_create_repo.source.mode=none"
exit /b 0

:: ============================================================
:: Function ResolveTargetRepository
:: Purpose
::   Resolves and validates the new GitHub owner and repository name.
:: Usage
::   call ResolveTargetRepository
:: Output
::   app.git_create_repo.slug, url, and web
:: Returns
::   0 target is valid and absent
::   1 target is invalid, unauthorized, or already exists
:: ============================================================
:ResolveTargetRepository
if not defined app.git_create_repo.owner set "app.git_create_repo.owner=%app.git_create_repo.login%"
if not defined app.git_create_repo.name set /p "app.git_create_repo.name=New repository name: "
if not defined app.git_create_repo.owner (echo ERROR: Repository owner is required. & exit /b 1)
if not defined app.git_create_repo.name (echo ERROR: Repository name is required. & exit /b 1)
echo(%app.git_create_repo.name%| findstr /R /X "[A-Za-z0-9._-][A-Za-z0-9._-]*" >nul
if errorlevel 1 (echo ERROR: Repository name contains unsupported characters. & exit /b 1)
set "app.git_create_repo.slug=%app.git_create_repo.owner%/%app.git_create_repo.name%"
set "app.git_create_repo.url=https://github.com/%app.git_create_repo.slug%.git"
set "app.git_create_repo.web=https://github.com/%app.git_create_repo.slug%"
if /I "%app.git_create_repo.slug%"=="%app.git_create_repo.old.slug%" (echo ERROR: The new repository must differ from the source repository. & exit /b 1)
set "gcrtr_owner_type="
for /f "delims=" %%A in ('gh api "users/%app.git_create_repo.owner%" --jq ".type" 2^>nul') do set "gcrtr_owner_type=%%A"
if not defined gcrtr_owner_type (echo ERROR: Target user or organization was not found: & echo   %app.git_create_repo.owner% & exit /b 1)
if /I "%gcrtr_owner_type%"=="User" if /I not "%app.git_create_repo.owner%"=="%app.git_create_repo.login%" (echo ERROR: You are logged in as %app.git_create_repo.login% but targeted user %app.git_create_repo.owner%. & exit /b 1)
gh repo view "%app.git_create_repo.slug%" >nul 2>nul
if not errorlevel 1 (echo ERROR: The target repository already exists: & echo   %app.git_create_repo.web% & exit /b 1)
exit /b 0

:: ============================================================
:: Function ResolveOptions
:: Purpose
::   Resolves branch, visibility, source-remote, and rewrite options.
:: Usage
::   call ResolveOptions
:: Returns
::   0 options are valid
::   1 an option is invalid
:: ============================================================
:ResolveOptions
if not defined app.git_create_repo.branch for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_create_repo.branch=%%A"
if not defined app.git_create_repo.branch set "app.git_create_repo.branch=main"
git check-ref-format --branch "%app.git_create_repo.branch%" >nul 2>nul
if errorlevel 1 (echo ERROR: Invalid branch name: %app.git_create_repo.branch% & exit /b 1)
if /I "%app.git_create_repo.visibility%"=="private" goto :ResolveOptionsVisibilityDone
if /I "%app.git_create_repo.visibility%"=="public" goto :ResolveOptionsVisibilityDone
if /I "%app.git_create_repo.visibility%"=="internal" goto :ResolveOptionsVisibilityDone
echo ERROR: Visibility must be private, public, or internal.
exit /b 1
:ResolveOptionsVisibilityDone
if /I "%app.git_create_repo.source.mode%"=="keep" goto :ResolveOptionsSourceDone
if /I "%app.git_create_repo.source.mode%"=="none" goto :ResolveOptionsSourceDone
echo ERROR: Source mode must be keep or none.
exit /b 1
:ResolveOptionsSourceDone
if /I "%app.git_create_repo.references%"=="all" goto :ResolveOptionsReferencesDone
if /I "%app.git_create_repo.references%"=="urls" goto :ResolveOptionsReferencesDone
if /I "%app.git_create_repo.references%"=="none" goto :ResolveOptionsReferencesDone
echo ERROR: References must be all, urls, or none.
exit /b 1
:ResolveOptionsReferencesDone
if /I "%app.git_create_repo.rename.name%"=="yes" goto :ResolveOptionsRenameDone
if /I "%app.git_create_repo.rename.name%"=="no" goto :ResolveOptionsRenameDone
echo ERROR: rename must be yes or no.
exit /b 1
:ResolveOptionsRenameDone
if /I "%app.git_create_repo.identity.mode%"=="ask" goto :ResolveOptionsIdentityDone
if /I "%app.git_create_repo.identity.mode%"=="defaults" goto :ResolveOptionsIdentityDone
echo ERROR: identity must be ask or defaults.
exit /b 1
:ResolveOptionsIdentityDone
if /I "%app.git_create_repo.login.mode%"=="ask" goto :ResolveOptionsLoginDone
if /I "%app.git_create_repo.login.mode%"=="yes" goto :ResolveOptionsLoginDone
if /I "%app.git_create_repo.login.mode%"=="no" goto :ResolveOptionsLoginDone
echo ERROR: login must be ask, yes, or no.
exit /b 1
:ResolveOptionsLoginDone
if /I "%app.git_create_repo.prepared%"=="yes" goto :ResolveOptionsPreparedDone
if /I "%app.git_create_repo.prepared%"=="no" goto :ResolveOptionsPreparedDone
echo ERROR: prepared must be yes or no.
exit /b 1
:ResolveOptionsPreparedDone
if /I "%app.git_create_repo.folder.rename%"=="yes" exit /b 0
if /I "%app.git_create_repo.folder.rename%"=="no" exit /b 0
echo ERROR: folderrename must be yes or no.
exit /b 1

:: ============================================================
:: Function ResolveFolderRename
:: Purpose
::   Resolves and validates the final leaf-folder rename. The ren
::   command receives a full source path and only a new folder name.
:: Usage
::   call ResolveFolderRename
:: Output
::   app.git_create_repo.folder.current.name
::   app.git_create_repo.folder.parent
::   app.git_create_repo.folder.target
::   app.git_create_repo.folder.rename.required
:: Returns
::   0 rename is unnecessary, disabled, or safe
::   1 target name or target folder is invalid
:: Requires
::   none
:: ============================================================
:ResolveFolderRename
set "app.git_create_repo.folder.current.name="
set "app.git_create_repo.folder.parent="
set "app.git_create_repo.folder.target="
set "app.git_create_repo.folder.rename.required="
for %%A in ("%app.git_create_repo.root%") do set "app.git_create_repo.folder.current.name=%%~nxA"
for %%A in ("%app.git_create_repo.root%") do set "app.git_create_repo.folder.parent=%%~dpA"
if not defined app.git_create_repo.folder.current.name (echo ERROR: Could not resolve the current project folder name. & exit /b 1)
if not defined app.git_create_repo.folder.parent (echo ERROR: Could not resolve the project parent folder. & exit /b 1)
if not "%app.git_create_repo.name:\=%"=="%app.git_create_repo.name%" (echo ERROR: The new folder name cannot contain backslashes. & exit /b 1)
if not "%app.git_create_repo.name:/=%"=="%app.git_create_repo.name%" (echo ERROR: The new folder name cannot contain forward slashes. & exit /b 1)
if "%app.git_create_repo.name%"=="." (echo ERROR: The new folder name cannot be a dot. & exit /b 1)
if "%app.git_create_repo.name%"==".." (echo ERROR: The new folder name cannot be two dots. & exit /b 1)
set "app.git_create_repo.folder.target=%app.git_create_repo.folder.parent%%app.git_create_repo.name%"
if /I "%app.git_create_repo.folder.rename%"=="no" exit /b 0
if /I "%app.git_create_repo.folder.current.name%"=="%app.git_create_repo.name%" exit /b 0
if exist "%app.git_create_repo.folder.target%\" (echo ERROR: The target project folder already exists: & echo   %app.git_create_repo.folder.target% & exit /b 1)
if exist "%app.git_create_repo.folder.target%" (echo ERROR: A file already uses the target project-folder path: & echo   %app.git_create_repo.folder.target% & exit /b 1)
set "app.git_create_repo.folder.rename.required=1"
exit /b 0

:: ============================================================
:: Function ValidateWorkspace
:: Purpose
::   Requires a Git worktree with no tracked staged or unstaged edits.
::   Untracked non-ignored files are allowed and will be included.
:: Usage
::   call ValidateWorkspace
:: Returns
::   0 workspace is safe for reversible migration
::   1 worktree is unsuitable
:: ============================================================
:ValidateWorkspace
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: The project root is not a Git worktree. & exit /b 1)
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (echo ERROR: The source repository has no commit history. & exit /b 1)
git diff --quiet --ignore-submodules --
if errorlevel 1 (echo ERROR: Tracked files have unstaged changes. & echo Commit or restore them before creating a new repository. & exit /b 1)
git diff --cached --quiet --ignore-submodules --
if errorlevel 1 (echo ERROR: The index already contains staged changes. & echo Commit or unstage them before continuing. & exit /b 1)
if exist ".git\MERGE_HEAD" (echo ERROR: A merge is in progress. & exit /b 1)
if exist ".git\rebase-merge" (echo ERROR: A rebase is in progress. & exit /b 1)
if exist ".git\rebase-apply" (echo ERROR: A rebase is in progress. & exit /b 1)
exit /b 0

:: ============================================================
:: Function BuildMigrationPlan
:: Purpose
::   Scans tracked and untracked non-ignored text files and reports
::   every old-repository reference that would be changed.
:: Usage
::   call BuildMigrationPlan
:: Output
::   app.git_create_repo.report and backup
:: Returns
::   0 plan generated
::   1 scan or encoding safety failure
:: ============================================================
:BuildMigrationPlan
call :CreateTimestamp
if errorlevel 1 exit /b 1
set "app.git_create_repo.report=%TEMP%\git_create_repository.%app.git_create_repo.timestamp%.plan.txt"
set "app.git_create_repo.backup=%TEMP%\git_create_repository.%app.git_create_repo.timestamp%.backup"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%app.git_create_repo.rewrite%" -Mode Plan -Root "%app.git_create_repo.root%" -OldSlug "%app.git_create_repo.old.slug%" -NewSlug "%app.git_create_repo.slug%" -References "%app.git_create_repo.references%" -RenameName "%app.git_create_repo.rename.name%" -Report "%app.git_create_repo.report%"
set "gcrbp_rc=%errorlevel%"
if not "%gcrbp_rc%"=="0" (echo ERROR: Repository reference scan failed. & echo Report: %app.git_create_repo.report% & exit /b 1)
exit /b 0

:: ============================================================
:: Function ShowPlan
:: Purpose
::   Displays the complete repository creation and migration plan.
:: Usage
::   call ShowPlan
:: Returns
::   0
:: ============================================================
:ShowPlan
echo.
echo ============================================================
echo  Planned new repository
echo ============================================================
echo.
echo Authenticated GitHub account:
echo   %app.git_create_repo.login%
echo.
echo Source repository:
echo   %app.git_create_repo.old.slug%
echo.
echo New repository:
echo   %app.git_create_repo.slug%
echo.
echo Visibility:
echo   %app.git_create_repo.visibility%
if /I "%app.git_create_repo.visibility%"=="private" echo   ^(private is the default^)
echo.
echo Branch:
echo   %app.git_create_repo.branch%
echo.
echo Current project folder:
echo   %app.git_create_repo.root%
echo.
if defined app.git_create_repo.folder.rename.required (echo Project folder after success: & echo   %app.git_create_repo.folder.target% & echo.) else (echo Project folder rename: & echo   not required & echo.)
echo Reference migration:
echo   %app.git_create_repo.references%
echo.
echo Rename standalone repository name:
echo   %app.git_create_repo.rename.name%
echo.
echo Remotes after creation:
echo   origin: %app.git_create_repo.url%
if /I "%app.git_create_repo.source.mode%"=="keep" (echo   upstream: %app.git_create_repo.source.url%) else (echo   upstream: none)
echo.
echo Files included:
echo   tracked files and untracked non-ignored files
echo   excluding generated root folders: build_*, source_*, oldbuilds
echo.
echo Reference report:
echo   %app.git_create_repo.report%
echo.
type "%app.git_create_repo.report%"
echo.
echo Safety:
echo   tracked worktree is clean
echo   modified files will be backed up before commit
echo   the GitHub repository is created only after local validation
echo   the new repository is created normally, never as a fork
exit /b 0

:: ============================================================
:: Function ConfirmCreation
:: Purpose
::   Requires the exact CREATE token unless preconfirmed.
:: Usage
::   call ConfirmCreation
:: Returns
::   0 confirmed
::   1 cancelled
:: ============================================================
:ConfirmCreation
if "%app.git_create_repo.confirm%"=="CREATE" exit /b 0
set "app.git_create_repo.input="
set /p "app.git_create_repo.input=Type CREATE to create and push the new repository: "
if "%app.git_create_repo.input%"=="CREATE" exit /b 0
echo.
echo Cancelled. No files, commits, remotes, or repositories were changed.
exit /b 1

:: ============================================================
:: Function CaptureOriginalState
:: Purpose
::   Records the original commit, branch, and primary remotes.
:: Usage
::   call CaptureOriginalState
:: Returns
::   0 state captured
::   1 HEAD or branch unavailable
:: ============================================================
:CaptureOriginalState
for /f "delims=" %%A in ('git rev-parse HEAD 2^>nul') do set "app.git_create_repo.original.head=%%A"
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_create_repo.original.branch=%%A"
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_create_repo.original.origin=%%A"
for /f "delims=" %%A in ('git remote get-url upstream 2^>nul') do set "app.git_create_repo.original.upstream=%%A"
for /f "delims=" %%A in ('git config --local --get user.name 2^>nul') do set "app.git_create_repo.original.git.name=%%A"
for /f "delims=" %%A in ('git config --local --get user.email 2^>nul') do set "app.git_create_repo.original.git.email=%%A"
if not defined app.git_create_repo.original.head (echo ERROR: Could not capture the original HEAD. & exit /b 1)
if not defined app.git_create_repo.original.branch (echo ERROR: Detached HEAD is not supported. & exit /b 1)
exit /b 0

:: ============================================================
:: Function EnsureTargetBranch
:: Purpose
::   Selects or creates the branch that will be pushed.
:: Usage
::   call EnsureTargetBranch
:: Returns
::   0 branch selected
::   1 branch selection failed
:: ============================================================
:EnsureTargetBranch
if /I "%app.git_create_repo.original.branch%"=="%app.git_create_repo.branch%" exit /b 0
git show-ref --verify --quiet "refs/heads/%app.git_create_repo.branch%"
if errorlevel 1 goto :EnsureTargetBranchCreate
git switch "%app.git_create_repo.branch%"
if errorlevel 1 (echo ERROR: Could not switch to branch %app.git_create_repo.branch%. & exit /b 1)
exit /b 0
:EnsureTargetBranchCreate
git switch -c "%app.git_create_repo.branch%"
if errorlevel 1 (echo ERROR: Could not create branch %app.git_create_repo.branch%. & exit /b 1)
set "app.git_create_repo.branch.created=1"
exit /b 0

:: ============================================================
:: Function ApplyReferenceChanges
:: Purpose
::   Applies the reviewed reference migration with byte backups,
::   excludes disposable generated root folders, stages project files,
::   and checks whitespace.
:: Usage
::   call ApplyReferenceChanges
:: Returns
::   0 changes staged safely
::   1 rewrite, staging, or whitespace check failure
:: ============================================================
:ApplyReferenceChanges
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%app.git_create_repo.rewrite%" -Mode Apply -Root "%app.git_create_repo.root%" -OldSlug "%app.git_create_repo.old.slug%" -NewSlug "%app.git_create_repo.slug%" -References "%app.git_create_repo.references%" -RenameName "%app.git_create_repo.rename.name%" -Report "%app.git_create_repo.report%" -BackupRoot "%app.git_create_repo.backup%"
set "gcra_rc=%errorlevel%"
if not "%gcra_rc%"=="0" (echo ERROR: Repository reference migration failed. & exit /b 1)
REM Stage the normal migration first. Git's ignore rules keep untracked
REM generated output out of the index. Then explicitly remove any generated
REM root folders that were already tracked in the template. --cached preserves
REM the local files while excluding them from the new repository.
REM
REM Directory pathspecs intentionally avoid matching legitimate root files
REM such as build_config.bat and build_noop.bat.
git add --all
if errorlevel 1 (echo ERROR: git add --all failed. & exit /b 1)
git rm -r -f --cached --ignore-unmatch -- ":(glob)build_*/**" ":(glob)source_*/**" ":(glob)oldbuilds/**" >nul 2>nul
if errorlevel 1 (echo ERROR: Could not exclude generated project folders from the new repository. & exit /b 1)
git diff --cached --check
if errorlevel 1 (echo ERROR: Staged whitespace validation failed. & exit /b 1)
exit /b 0

:: ============================================================
:: Function EnsureGitIdentity
:: Purpose
::   Resolves local Git identity from arguments, Git, or GitHub.
:: Usage
::   call EnsureGitIdentity
:: Returns
::   0 identity stored locally
::   1 identity unavailable or cannot be stored
:: ============================================================
:EnsureGitIdentity
if defined app.git_create_repo.git.name goto :EnsureGitIdentityEmail
if /I "%app.git_create_repo.identity.mode%"=="defaults" goto :EnsureGitIdentityGitHub
for /f "delims=" %%A in ('git config --local --get user.name 2^>nul') do set "app.git_create_repo.git.name=%%A"
if not defined app.git_create_repo.git.name for /f "delims=" %%A in ('git config --global --get user.name 2^>nul') do set "app.git_create_repo.git.name=%%A"
:EnsureGitIdentityEmail
if defined app.git_create_repo.git.email goto :EnsureGitIdentityPrompt
if /I "%app.git_create_repo.identity.mode%"=="defaults" goto :EnsureGitIdentityGitHub
for /f "delims=" %%A in ('git config --local --get user.email 2^>nul') do set "app.git_create_repo.git.email=%%A"
if not defined app.git_create_repo.git.email for /f "delims=" %%A in ('git config --global --get user.email 2^>nul') do set "app.git_create_repo.git.email=%%A"
goto :EnsureGitIdentityPrompt
:EnsureGitIdentityGitHub
if not defined app.git_create_repo.git.name set "app.git_create_repo.git.name=%app.git_create_repo.login%"
set "gcre_id="
for /f "delims=" %%A in ('gh api user --jq ".id" 2^>nul') do set "gcre_id=%%A"
if not defined app.git_create_repo.git.email for /f "delims=" %%A in ('gh api user --jq ".email // empty" 2^>nul') do set "app.git_create_repo.git.email=%%A"
if not defined app.git_create_repo.git.email if defined gcre_id set "app.git_create_repo.git.email=%gcre_id%+%app.git_create_repo.login%@users.noreply.github.com"
:EnsureGitIdentityPrompt
if /I "%app.git_create_repo.identity.mode%"=="defaults" goto :EnsureGitIdentityValidate
set "app.git_create_repo.input="
set /p "app.git_create_repo.input=Git name [%app.git_create_repo.git.name%]: "
if defined app.git_create_repo.input set "app.git_create_repo.git.name=%app.git_create_repo.input%"
set "app.git_create_repo.input="
set /p "app.git_create_repo.input=Git email [%app.git_create_repo.git.email%]: "
if defined app.git_create_repo.input set "app.git_create_repo.git.email=%app.git_create_repo.input%"
:EnsureGitIdentityValidate
if not defined app.git_create_repo.git.name (echo ERROR: Git name is required. & exit /b 1)
if not defined app.git_create_repo.git.email (echo ERROR: Git email is required. & exit /b 1)
git config --local user.name "%app.git_create_repo.git.name%"
if errorlevel 1 (echo ERROR: Could not store local Git user.name. & exit /b 1)
git config --local user.email "%app.git_create_repo.git.email%"
if errorlevel 1 (echo ERROR: Could not store local Git user.email. & exit /b 1)
echo Git identity:
echo   Name: %app.git_create_repo.git.name%
echo   Email: %app.git_create_repo.git.email%
exit /b 0

:: ============================================================
:: Function CreateMigrationCommit
:: Purpose
::   Creates the migration commit when staged changes exist.
:: Usage
::   call CreateMigrationCommit
:: Returns
::   0 valid HEAD ready
::   1 commit failure
:: ============================================================
:CreateMigrationCommit
git diff --cached --quiet
if not errorlevel 1 (echo No file-content changes were required. Existing HEAD will be pushed. & exit /b 0)
if not defined app.git_create_repo.message set "app.git_create_repo.message=Create %app.git_create_repo.slug% repository"
git commit -m "%app.git_create_repo.message%"
if errorlevel 1 (echo ERROR: Could not create the migration commit. & exit /b 1)
set "app.git_create_repo.commit.created=1"
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (echo ERROR: HEAD verification failed after commit. & exit /b 1)
exit /b 0

:: ============================================================
:: Function CreateGitHubRepository
:: Purpose
::   Creates a normal empty GitHub repository, never a fork.
:: Usage
::   call CreateGitHubRepository
:: Returns
::   0 repository created and verified as non-fork
::   1 creation or verification failure
:: ============================================================
:CreateGitHubRepository
echo.
echo Creating new GitHub repository:
echo   %app.git_create_repo.slug%
if /I "%app.git_create_repo.visibility%"=="private" gh repo create "%app.git_create_repo.slug%" --private --description "%app.git_create_repo.description%"
if /I "%app.git_create_repo.visibility%"=="public" gh repo create "%app.git_create_repo.slug%" --public --description "%app.git_create_repo.description%"
if /I "%app.git_create_repo.visibility%"=="internal" gh repo create "%app.git_create_repo.slug%" --internal --description "%app.git_create_repo.description%"
set "gcrg_rc=%errorlevel%"
if not "%gcrg_rc%"=="0" (echo ERROR: GitHub repository creation failed. & exit /b 1)
set "app.git_create_repo.created=1"
set "gcrg_is_fork="
for /f "delims=" %%A in ('gh repo view "%app.git_create_repo.slug%" --json isFork --jq ".isFork" 2^>nul') do set "gcrg_is_fork=%%A"
if /I not "%gcrg_is_fork%"=="false" (echo ERROR: The new repository could not be verified as a non-fork. & exit /b 1)
exit /b 0

:: ============================================================
:: Function ConfigureRemotes
:: Purpose
::   Makes the new repository origin and optionally preserves the
::   old repository as upstream.
:: Usage
::   call ConfigureRemotes
:: Returns
::   0 remotes configured
::   1 remote update failure
:: ============================================================
:ConfigureRemotes
git remote get-url origin >nul 2>nul
if errorlevel 1 goto :ConfigureRemotesAddOrigin
git remote set-url origin "%app.git_create_repo.url%"
if errorlevel 1 (echo ERROR: Could not update origin. & exit /b 1)
goto :ConfigureRemotesUpstream
:ConfigureRemotesAddOrigin
git remote add origin "%app.git_create_repo.url%"
if errorlevel 1 (echo ERROR: Could not add origin. & exit /b 1)
:ConfigureRemotesUpstream
if /I "%app.git_create_repo.source.mode%"=="none" (git remote remove upstream >nul 2>nul & exit /b 0)
git remote get-url upstream >nul 2>nul
if errorlevel 1 goto :ConfigureRemotesAddUpstream
git remote set-url upstream "%app.git_create_repo.source.url%"
if errorlevel 1 (echo ERROR: Could not update upstream. & exit /b 1)
exit /b 0
:ConfigureRemotesAddUpstream
git remote add upstream "%app.git_create_repo.source.url%"
if errorlevel 1 (echo ERROR: Could not add upstream. & exit /b 1)
exit /b 0

:: ============================================================
:: Function RestoreRemotes
:: Purpose
::   Restores the original origin and upstream after local remote
::   configuration fails.
:: Usage
::   call RestoreRemotes
:: Returns
::   0 best-effort restoration attempted
:: ============================================================
:RestoreRemotes
git remote remove origin >nul 2>nul
git remote remove upstream >nul 2>nul
if defined app.git_create_repo.original.origin git remote add origin "%app.git_create_repo.original.origin%" >nul 2>nul
if defined app.git_create_repo.original.upstream git remote add upstream "%app.git_create_repo.original.upstream%" >nul 2>nul
exit /b 0

:: ============================================================
:: Function PushBranch
:: Purpose
::   Performs the first push and configures upstream tracking.
:: Usage
::   call PushBranch
:: Returns
::   0 push completed
::   1 push failed while remote repository remains available
:: ============================================================
:PushBranch
echo.
echo First push:
echo   %app.git_create_repo.branch% to origin
git push -u origin "%app.git_create_repo.branch%"
if not errorlevel 1 exit /b 0
echo.
echo ERROR: The GitHub repository exists, but the first push failed.
echo Repository:
echo   %app.git_create_repo.web%
echo Retry with:
echo   git push -u origin "%app.git_create_repo.branch%"
exit /b 1

:: ============================================================
:: Function RollbackLocalMigration
:: Purpose
::   Restores rewritten files, index, and original branch before
::   a remote repository has been created.
:: Usage
::   call RollbackLocalMigration
:: Returns
::   0 best-effort rollback attempted
:: ============================================================
:RollbackLocalMigration
if defined app.git_create_repo.created exit /b 0
if exist "%app.git_create_repo.backup%\" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%app.git_create_repo.rewrite%" -Mode Restore -Root "%app.git_create_repo.root%" -BackupRoot "%app.git_create_repo.backup%"
if defined app.git_create_repo.original.head git reset --mixed "%app.git_create_repo.original.head%" >nul 2>nul
if defined app.git_create_repo.original.branch git switch "%app.git_create_repo.original.branch%" >nul 2>nul
if defined app.git_create_repo.branch.created if /I not "%app.git_create_repo.original.branch%"=="%app.git_create_repo.branch%" git branch -D "%app.git_create_repo.branch%" >nul 2>nul
if defined app.git_create_repo.original.git.name (git config --local user.name "%app.git_create_repo.original.git.name%" >nul 2>nul) else (git config --local --unset-all user.name >nul 2>nul)
if defined app.git_create_repo.original.git.email (git config --local user.email "%app.git_create_repo.original.git.email%" >nul 2>nul) else (git config --local --unset-all user.email >nul 2>nul)
echo Local repository migration was rolled back.
exit /b 0

:: ============================================================
:: Function ShowSuccess
:: Purpose
::   Displays the created repository, remotes, identity, and commit.
:: Usage
::   call ShowSuccess
:: Returns
::   0
:: ============================================================
:ShowSuccess
echo.
echo ============================================================
echo  New repository created successfully
echo ============================================================
echo.
echo GitHub:
echo   %app.git_create_repo.web%
echo.
echo Source:
echo   %app.git_create_repo.old.slug%
echo.
echo Branch:
echo   %app.git_create_repo.branch%
echo.
echo Git identity:
echo   Name: %app.git_create_repo.git.name%
echo   Email: %app.git_create_repo.git.email%
echo.
echo Remotes:
git remote -v
echo.
echo Latest commit:
git log -1 --oneline
echo.
echo Reference report:
echo   %app.git_create_repo.report%
echo.
if defined app.git_create_repo.folder.rename.required (echo Project folder will now be renamed to: & echo   %app.git_create_repo.folder.target%) else (echo Project folder: & echo   %app.git_create_repo.root%)
exit /b 0

:: ============================================================
:: Function ResolveProjectRoot
:: Purpose
::   Resolves the project root from the current directory or script.
:: Usage
::   call ResolveProjectRoot
:: Returns
::   0 project root found
::   1 prepare.bat unavailable
:: ============================================================
:ResolveProjectRoot
if exist "%CD%\prepare.bat" for %%A in ("%CD%") do set "app.git_create_repo.root=%%~fA"
if not defined app.git_create_repo.root if exist "%~dp0..\prepare.bat" for %%A in ("%~dp0..") do set "app.git_create_repo.root=%%~fA"
if not defined app.git_create_repo.root (echo ERROR: Run this helper from a project root containing prepare.bat. & exit /b 1)
exit /b 0

:: ============================================================
:: Function CreateTimestamp
:: Purpose
::   Creates a filesystem-safe timestamp for reports and backups.
:: Usage
::   call CreateTimestamp
:: Returns
::   0 timestamp available
::   1 timestamp unavailable
:: ============================================================
:CreateTimestamp
set "app.git_create_repo.timestamp="
for /f "delims=" %%A in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyy-MM-dd.HHmmss" 2^>nul') do set "app.git_create_repo.timestamp=%%A"
if not defined app.git_create_repo.timestamp (echo ERROR: Could not create a timestamp. & exit /b 1)
exit /b 0

:: ============================================================
:: Function ParseArgs
:: Purpose
::   Parses provider, target, source, rewrite, identity, confirmation,
::   dry-run, and help arguments.
:: Usage
::   call ParseArgs with command-line arguments
:: Returns
::   0 parsed
::   2 invalid arguments
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="provider" goto :ParseArgsProvider
if /I "%~1"=="owner" goto :ParseArgsOwner
if /I "%~1"=="name" goto :ParseArgsName
if /I "%~1"=="repo" goto :ParseArgsName
if /I "%~1"=="visibility" goto :ParseArgsVisibility
if /I "%~1"=="branch" goto :ParseArgsBranch
if /I "%~1"=="source" goto :ParseArgsSource
if /I "%~1"=="references" goto :ParseArgsReferences
if /I "%~1"=="rename" goto :ParseArgsRename
if /I "%~1"=="identity" goto :ParseArgsIdentity
if /I "%~1"=="gitname" goto :ParseArgsGitName
if /I "%~1"=="gitemail" goto :ParseArgsGitEmail
if /I "%~1"=="login" goto :ParseArgsLogin
if /I "%~1"=="browser" goto :ParseArgsBrowser
if /I "%~1"=="message" goto :ParseArgsMessage
if /I "%~1"=="description" goto :ParseArgsDescription
if /I "%~1"=="confirm" goto :ParseArgsConfirm
if /I "%~1"=="prepared" goto :ParseArgsPrepared
if /I "%~1"=="folderrename" goto :ParseArgsFolderRename
if /I "%~1"=="dryrun" goto :ParseArgsDryRun
if /I "%~1"=="help" goto :ParseArgsHelp
if /I "%~1"=="/help" goto :ParseArgsHelp
if /I "%~1"=="-help" goto :ParseArgsHelp
if /I "%~1"=="--help" goto :ParseArgsHelp
if /I "%~1"=="/h" goto :ParseArgsHelp
if /I "%~1"=="-h" goto :ParseArgsHelp
if /I "%~1"=="--h" goto :ParseArgsHelp
if /I "%~1"=="/?" goto :ParseArgsHelp
if /I "%~1"=="-?" goto :ParseArgsHelp
if /I "%~1"=="--?" goto :ParseArgsHelp
if /I "%~1"=="?" goto :ParseArgsHelp
echo ERROR: Unrecognized argument: %~1
exit /b 2
:ParseArgsProvider
if "%~2"=="" (echo ERROR: provider requires github. & exit /b 2)
if /I not "%~2"=="github" (echo ERROR: Only provider github is currently implemented. & exit /b 2)
set "app.git_create_repo.provider=github"
shift
shift
goto :ParseArgs
:ParseArgsOwner
if "%~2"=="" (echo ERROR: owner requires a value. & exit /b 2)
set "app.git_create_repo.owner=%~2"
shift
shift
goto :ParseArgs
:ParseArgsName
if "%~2"=="" (echo ERROR: name requires a value. & exit /b 2)
set "app.git_create_repo.name=%~2"
shift
shift
goto :ParseArgs
:ParseArgsVisibility
if "%~2"=="" (echo ERROR: visibility requires private, public, or internal. & exit /b 2)
set "app.git_create_repo.visibility=%~2"
shift
shift
goto :ParseArgs
:ParseArgsBranch
if "%~2"=="" (echo ERROR: branch requires a value. & exit /b 2)
set "app.git_create_repo.branch=%~2"
shift
shift
goto :ParseArgs
:ParseArgsSource
if "%~2"=="" (echo ERROR: source requires keep, none, or a repository. & exit /b 2)
if /I "%~2"=="keep" (set "app.git_create_repo.source.mode=keep" & set "app.git_create_repo.source.input=keep")
if /I "%~2"=="none" (set "app.git_create_repo.source.mode=none" & set "app.git_create_repo.source.input=none")
if /I not "%~2"=="keep" if /I not "%~2"=="none" (set "app.git_create_repo.source.mode=keep" & set "app.git_create_repo.source.input=%~2")
shift
shift
goto :ParseArgs
:ParseArgsReferences
if "%~2"=="" (echo ERROR: references requires all, urls, or none. & exit /b 2)
set "app.git_create_repo.references=%~2"
shift
shift
goto :ParseArgs
:ParseArgsRename
if "%~2"=="" (echo ERROR: rename requires yes or no. & exit /b 2)
set "app.git_create_repo.rename.name=%~2"
shift
shift
goto :ParseArgs
:ParseArgsIdentity
if "%~2"=="" (echo ERROR: identity requires ask or defaults. & exit /b 2)
set "app.git_create_repo.identity.mode=%~2"
shift
shift
goto :ParseArgs
:ParseArgsGitName
if "%~2"=="" (echo ERROR: gitname requires a value. & exit /b 2)
set "app.git_create_repo.git.name=%~2"
shift
shift
goto :ParseArgs
:ParseArgsGitEmail
if "%~2"=="" (echo ERROR: gitemail requires a value. & exit /b 2)
set "app.git_create_repo.git.email=%~2"
shift
shift
goto :ParseArgs
:ParseArgsLogin
if "%~2"=="" (echo ERROR: login requires ask, yes, or no. & exit /b 2)
set "app.git_create_repo.login.mode=%~2"
shift
shift
goto :ParseArgs
:ParseArgsBrowser
if "%~2"=="" (echo ERROR: browser requires ask, 1, 2, 3, or 4. & exit /b 2)
if /I "%~2"=="ask" goto :ParseArgsBrowserStore
if "%~2"=="1" goto :ParseArgsBrowserStore
if "%~2"=="2" goto :ParseArgsBrowserStore
if "%~2"=="3" goto :ParseArgsBrowserStore
if "%~2"=="4" goto :ParseArgsBrowserStore
echo ERROR: browser requires ask, 1, 2, 3, or 4.
exit /b 2
:ParseArgsBrowserStore
set "app.git_create_repo.browser.request=%~2"
if /I not "%~2"=="ask" set "app.git_create_repo.login.mode=yes"
shift
shift
goto :ParseArgs
:ParseArgsMessage
if "%~2"=="" (echo ERROR: message requires quoted text. & exit /b 2)
set "app.git_create_repo.message=%~2"
shift
shift
goto :ParseArgs
:ParseArgsDescription
if "%~2"=="" (echo ERROR: description requires quoted text. & exit /b 2)
set "app.git_create_repo.description=%~2"
shift
shift
goto :ParseArgs
:ParseArgsConfirm
if "%~2"=="" (echo ERROR: confirm requires CREATE. & exit /b 2)
set "app.git_create_repo.confirm=%~2"
shift
shift
goto :ParseArgs
:ParseArgsPrepared
if "%~2"=="" (echo ERROR: prepared requires yes or no. & exit /b 2)
set "app.git_create_repo.prepared=%~2"
shift
shift
goto :ParseArgs
:ParseArgsFolderRename
if "%~2"=="" (echo ERROR: folderrename requires yes or no. & exit /b 2)
set "app.git_create_repo.folder.rename=%~2"
shift
shift
goto :ParseArgs
:ParseArgsDryRun
set "app.git_create_repo.dryrun=1"
shift
goto :ParseArgs
:ParseArgsHelp
set "app.git_create_repo.help=1"
shift
goto :ParseArgs

:: ============================================================
:: Function ShowHelp
:: Purpose
::   Displays current command syntax and automation options.
:: Usage
::   call ShowHelp
:: Returns
::   0
:: ============================================================
:ShowHelp
echo.
echo git_create_repository.bat
echo.
echo Creates a normal GitHub repository from the current project,
echo rewrites old repository references, preserves Git history,
echo configures remotes, and performs the first push.
echo.
echo Usage:
echo   git_create_repository.bat [options]
echo.
echo Target:
echo   provider github
echo   owner OWNER
echo   name REPOSITORY
echo   visibility private^|public^|internal  ^(default: private^)
echo   branch NAME
echo   description "TEXT"
echo.
echo Source and references:
echo   source keep^|none^|OWNER/REPOSITORY^|URL  ^(default: none^)
echo                        keep preserves the old repository as local upstream
echo   references all^|urls^|none
echo   rename yes^|no
echo.
echo Authentication and identity:
echo   login ask^|yes^|no
echo   browser ask^|1^|2^|3^|4
echo                        Authentication is provided by git_login.bat
echo   identity defaults^|ask
echo   gitname "NAME"
echo   gitemail "EMAIL"
echo.
echo Commit and execution:
echo   message "TEXT"
echo   confirm CREATE
echo   prepared yes^|no
echo   folderrename yes^|no
echo   dryrun
echo.
echo Help:
echo   help  /help  -help  --help  /h  -h  --h  /?  -?  --?  ?
echo.
echo Test plan:
echo   git_create_repository.bat name testrepo_pleaseignore dryrun
echo.
echo Test creation:
echo   git_create_repository.bat name testrepo_pleaseignore
echo   git_create_repository.bat name testrepo_pleaseignore browser 4
echo.
echo Safety requirements:
echo   tracked files must be clean
echo   untracked non-ignored files are included
echo   generated root folders build_*, source_*, and oldbuilds are excluded
echo   binary files containing old repository references stop the run
echo   the remote repository is created only after local validation
echo   the new GitHub repository is verified as a non-fork
echo   the successful checkout folder is renamed to the repository name
exit /b 0

:: ============================================================
:: Function PauseIfNeeded
:: Purpose
::   Pauses only when this file is the outermost cmd.exe C target.
:: Usage
::   call PauseIfNeeded
:: Returns
::   0
:: ============================================================
:PauseIfNeeded
call :IsConsole
if not errorlevel 1 exit /b 0
echo.
pause
exit /b 0

:: ============================================================
:: Function IsConsole
:: Purpose
::   Detects whether execution is inside an existing console.
:: Usage
::   call IsConsole
:: Returns
::   0 existing console
::   1 outermost cmd.exe C target
:: ============================================================
:IsConsole
setlocal EnableDelayedExpansion
set "ic_cmdline=!CMDCMDLINE!"
echo(!ic_cmdline!| "%SystemRoot%\System32\find.exe" /I " /c " >nul
if errorlevel 1 (endlocal & exit /b 0)
echo(!ic_cmdline!| "%SystemRoot%\System32\find.exe" /I "!app.launch.name!" >nul
if errorlevel 1 (endlocal & exit /b 0)
endlocal & exit /b 1
