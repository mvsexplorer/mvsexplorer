@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "app.version=0.1.2"
set "root=%~dp0"
set "fixture=%root%test-mvs-dump-history"
set "tag=%RANDOM%%RANDOM%"
set "fastout=%TEMP%\mvs-fast-sweep-test-%tag%"
set "extout=%TEMP%\mvs-external-plan-test-%tag%"
set "log=%TEMP%\mvs-fast-sweep-test-%tag%.log"

if not exist "%fixture%\" (
  echo [FAIL] history fixture missing: %fixture%
  exit /b 1
)

call "%root%test_all_dumps.bat" "%fixture%" "%fastout%" >"%log%" 2>&1
if errorlevel 1 (
  echo [FAIL] fast-combined sweep
  call :ShowFailure "%fastout%"
  exit /b 1
)

call :AssertMetadataLine "%fastout%\summary.txt" "Executor: fast-combined"
if errorlevel 1 (
  echo [FAIL] fast-combined executor metadata
  call :ShowFailure "%fastout%"
  exit /b 1
)
call :AssertMetadataLine "%fastout%\summary.txt" "Planned invocations: 1306"
if errorlevel 1 (
  echo [FAIL] fast-combined planned count
  call :ShowFailure "%fastout%"
  exit /b 1
)
call :AssertMetadataLine "%fastout%\summary.txt" "Completed invocations: 1306"
if errorlevel 1 (
  echo [FAIL] fast-combined completion count
  call :ShowFailure "%fastout%"
  exit /b 1
)
call :AssertMetadataLine "%fastout%\summary.txt" "FAIL: 0"
if errorlevel 1 (
  echo [FAIL] fast-combined logical failures
  call :ShowFailure "%fastout%"
  exit /b 1
)
echo [PASS] fast-combined 1306 logical checks

call "%root%test_all_dumps.bat" "%fixture%" "%extout%" --plan-only --external-tools >"%log%" 2>&1
if errorlevel 1 (
  echo [FAIL] external-public plan-only
  call :ShowFailure "%extout%"
  exit /b 1
)
call :AssertMetadataLine "%extout%\summary.txt" "Executor: external-public"
if errorlevel 1 (
  echo [FAIL] external-public executor metadata
  call :ShowFailure "%extout%"
  exit /b 1
)
call :AssertMetadataLine "%extout%\summary.txt" "Planned invocations: 1306"
if errorlevel 1 (
  echo [FAIL] external-public planned count
  call :ShowFailure "%extout%"
  exit /b 1
)
call :AssertMetadataLine "%extout%\summary.txt" "Completed invocations: 0"
if errorlevel 1 (
  echo [FAIL] external-public plan-only completion count
  call :ShowFailure "%extout%"
  exit /b 1
)
echo [PASS] external-public plan-only 1306 logical checks

rmdir /s /q "%fastout%" 2>nul
rmdir /s /q "%extout%" 2>nul
del /q "%log%" 2>nul
echo SUMMARY: passed=2 failed=0
exit /b 0

:AssertMetadataLine
set "mvs_assert_file=%~1"
set "mvs_assert_line=%~2"
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop'; if(-not(Test-Path -LiteralPath $env:mvs_assert_file -PathType Leaf)){exit 2}; $lines=@(Get-Content -LiteralPath $env:mvs_assert_file -Encoding UTF8); if($lines -contains $env:mvs_assert_line){exit 0}; exit 1"
exit /b %errorlevel%

:ShowFailure
echo Artifacts retained at: %~1
if exist "%~1\summary.txt" (
  echo ----- summary.txt -----
  type "%~1\summary.txt"
) else (
  echo summary.txt is missing.
)
if exist "%~1\run-info.txt" (
  echo ----- run-info.txt -----
  type "%~1\run-info.txt"
)
if exist "%log%" (
  echo ----- captured sweep log -----
  type "%log%"
  echo Captured log: %log%
)
exit /b 0
