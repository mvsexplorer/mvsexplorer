@echo off
:setup
REM One-command full test -> database build -> database validation -> all family query tools -> ZIP/hardlink pipeline.
setlocal DisableDelayedExpansion
set "app.version=1.0.4"
set "app.name=all_test_then_all_database_then_test_database_and_all_tools"
set "app.rc=0"
set "app.self=%~f0"
set "mvspipe_project_version=@@PROJECT_VERSION@@"
set "mvspipe_project_root=%~dp0"
set "mvspipe_caller=%~nx0"
set "mvspipe_arg1=%~1"
set "mvspipe_arg2=%~2"
set "mvspipe_arg3=%~3"
set "mvspipe_arg4=%~4"
set "mvspipe_arg5=%~5"
set "mvspipe_arg6=%~6"
set "mvspipe_arg7=%~7"
set "mvspipe_arg8=%~8"
set "mvspipe_arg9=%~9"
:main
set "RunPowerShellFromLabel.function=MVSAllPipeline"
call :RunPowerShellFromLabel
set "app.rc=%errorlevel%"
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF

@@BATCH_COMMON@@

:_MVSAllPipeline_start
@@PIPELINE_POWERSHELL@@
:_MVSAllPipeline_end
