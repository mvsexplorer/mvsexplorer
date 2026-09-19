@echo off
setlocal EnableExtensions DisableDelayedExpansion
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
  type "%log%"
  exit /b 1
)
findstr /x /c:"Executor: fast-combined" "%fastout%\summary.txt" >nul || (
  echo [FAIL] fast-combined executor metadata
  exit /b 1
)
findstr /x /c:"Planned invocations: 1306" "%fastout%\summary.txt" >nul || (
  echo [FAIL] fast-combined planned count
  exit /b 1
)
findstr /x /c:"Completed invocations: 1306" "%fastout%\summary.txt" >nul || (
  echo [FAIL] fast-combined completion count
  exit /b 1
)
findstr /x /c:"FAIL: 0" "%fastout%\summary.txt" >nul || (
  echo [FAIL] fast-combined logical failures
  exit /b 1
)
echo [PASS] fast-combined 1306 logical checks

call "%root%test_all_dumps.bat" "%fixture%" "%extout%" --plan-only --external-tools >"%log%" 2>&1
if errorlevel 1 (
  echo [FAIL] external-public plan-only
  type "%log%"
  exit /b 1
)
findstr /x /c:"Executor: external-public" "%extout%\summary.txt" >nul || (
  echo [FAIL] external-public executor metadata
  exit /b 1
)
findstr /x /c:"Planned invocations: 1306" "%extout%\summary.txt" >nul || (
  echo [FAIL] external-public planned count
  exit /b 1
)
findstr /x /c:"Completed invocations: 0" "%extout%\summary.txt" >nul || (
  echo [FAIL] external-public plan-only completion count
  exit /b 1
)
echo [PASS] external-public plan-only 1306 logical checks

rmdir /s /q "%fastout%" 2>nul
rmdir /s /q "%extout%" 2>nul
del /q "%log%" 2>nul
echo SUMMARY: passed=2 failed=0
exit /b 0
