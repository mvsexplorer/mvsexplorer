@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "app.version=0.4.2"
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

call "%root%test_all_dumps.bat" "%fixture%" "%fastout%" --no-cache >"%log%" 2>&1
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
call :AssertMetadataLine "%fastout%\run-info.txt" "Executor: fast-combined"
if errorlevel 1 (
  echo [FAIL] fast-combined run-info executor metadata
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

call :AssertExpectedTree "%root%expected-history\history" "%fastout%\archive-output"
if errorlevel 1 (
  echo [FAIL] fast archive history output mismatch
  call :ShowFailure "%fastout%"
  exit /b 1
)
call :AssertExpectedTree "%root%expected-history\all-ever" "%fastout%\archive-output"
if errorlevel 1 (
  echo [FAIL] fast archive all-ever output mismatch
  call :ShowFailure "%fastout%"
  exit /b 1
)
echo [PASS] fast-combined 1306 logical checks and archive outputs

if not exist "%fastout%\archive-output\evolution\per-dump-contributions.tsv" (
  echo [FAIL] evolution per-dump contribution output missing
  call :ShowFailure "%fastout%"
  exit /b 1
)
if not exist "%fastout%\archive-output\evolution\per-dump-quality.tsv" (
  echo [FAIL] evolution quality output missing
  call :ShowFailure "%fastout%"
  exit /b 1
)
if not exist "%fastout%\archive-output\evolution\notes\note-versions.tsv" (
  echo [FAIL] all-ever note-version output missing
  call :ShowFailure "%fastout%"
  exit /b 1
)
if not exist "%fastout%\archive-output\evolution\per-dump-retention.tsv" (
  echo [FAIL] per-dump retention output missing
  call :ShowFailure "%fastout%"
  exit /b 1
)
if not exist "%fastout%\archive-output\evolution\notes\note-raw-variants.tsv" (
  echo [FAIL] all-ever raw-note-variant output missing
  call :ShowFailure "%fastout%"
  exit /b 1
)

call :AssertTsvMetric "%fastout%\archive-output\evolution\summary.tsv" "snapshots" "3"
if errorlevel 1 (
  echo [FAIL] evolution snapshot count
  call :ShowFailure "%fastout%"
  exit /b 1
)
call :AssertTsvMetric "%fastout%\archive-output\evolution\summary.tsv" "product_states_all_ever" "4"
if errorlevel 1 (
  echo [FAIL] all-ever product-state count
  call :ShowFailure "%fastout%"
  exit /b 1
)
call :AssertTsvMetric "%fastout%\archive-output\evolution\summary.tsv" "variant_states_all_ever" "4"
if errorlevel 1 (
  echo [FAIL] all-ever variant-state count
  call :ShowFailure "%fastout%"
  exit /b 1
)

call :AssertTsvMetric "%fastout%\archive-output\evolution\summary.tsv" "note_versions_all_ever" "5"
if errorlevel 1 (
  echo [FAIL] all-ever note-version count
  call :ShowFailure "%fastout%"
  exit /b 1
)
call :AssertTsvMetric "%fastout%\archive-output\evolution\summary.tsv" "note_bodies_all_ever" "5"
if errorlevel 1 (
  echo [FAIL] all-ever note-body count
  call :ShowFailure "%fastout%"
  exit /b 1
)
call :AssertTsvMetric "%fastout%\archive-output\evolution\summary.tsv" "note_raw_variants_all_ever" "5"
if errorlevel 1 (
  echo [FAIL] all-ever raw-note-variant count
  call :ShowFailure "%fastout%"
  exit /b 1
)
call :AssertRunStatus "%fastout%\runs.tsv" "mvs_2020-01-01" "read_mvs_dump_note_records" "PASS"
if errorlevel 1 (
  echo [FAIL] legacy h3 note parsing in fast snapshot worker
  call :ShowFailure "%fastout%"
  exit /b 1
)
call :AssertRunStatus "%fastout%\runs.tsv" "mvs_2020-01-01" "read_mvs_dump_note_records_from_title" "PASS"
if errorlevel 1 (
  echo [FAIL] legacy h3 note title profiling in archive sweep
  call :ShowFailure "%fastout%"
  exit /b 1
)
call :AssertNoteVersion "%fastout%\archive-output\evolution\notes\note-versions.tsv" "Keep Product" "Keep note" "3"
if errorlevel 1 (
  echo [FAIL] note-version snapshot observation count
  call :ShowFailure "%fastout%"
  exit /b 1
)

if not exist "%fastout%\archive-summary.html" (
  echo [FAIL] interactive archive summary missing
  call :ShowFailure "%fastout%"
  exit /b 1
)

call "%root%check_archive_sweep_quality.bat" "%fastout%" >>"%log%" 2>&1
if errorlevel 1 (
  echo [FAIL] archive quality/integrity checker
  call :ShowFailure "%fastout%"
  exit /b 1
)
echo [PASS] evolution, concrete all-ever counts, quality checker, and interactive HTML report

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
call :AssertMetadataLine "%extout%\run-info.txt" "Executor: external-public"
if errorlevel 1 (
  echo [FAIL] external-public run-info executor metadata
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
echo SUMMARY: passed=3 failed=0
exit /b 0

:AssertMetadataLine
set "mvs_assert_file=%~1"
set "mvs_assert_line=%~2"
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop'; if(-not(Test-Path -LiteralPath $env:mvs_assert_file -PathType Leaf)){exit 2}; $lines=@(Get-Content -LiteralPath $env:mvs_assert_file -Encoding UTF8); if($lines -contains $env:mvs_assert_line){exit 0}; exit 1"
exit /b %errorlevel%

:AssertTsvMetric
set "mvs_metric_file=%~1"
set "mvs_metric_name=%~2"
set "mvs_metric_value=%~3"
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop'; if(-not(Test-Path -LiteralPath $env:mvs_metric_file -PathType Leaf)){exit 2}; $rows=@(Import-Csv -LiteralPath $env:mvs_metric_file -Delimiter \"`t\" -Encoding UTF8); $match=@($rows | Where-Object {$_.metric -eq $env:mvs_metric_name}); if($match.Count-ne1){exit 1}; if([string]$match[0].value-ne[string]$env:mvs_metric_value){exit 1}; exit 0"
exit /b %errorlevel%


:AssertRunStatus
set "mvs_run_file=%~1"
set "mvs_run_snapshot=%~2"
set "mvs_run_tool=%~3"
set "mvs_run_status=%~4"
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop'; if(-not(Test-Path -LiteralPath $env:mvs_run_file -PathType Leaf)){exit 2}; $rows=@(Import-Csv -LiteralPath $env:mvs_run_file -Delimiter \"`t\" -Encoding UTF8 | Where-Object {$_.snapshot -eq $env:mvs_run_snapshot -and $_.tool -eq $env:mvs_run_tool}); if($rows.Count-ne1){exit 1}; if([string]$rows[0].status-ne[string]$env:mvs_run_status){exit 1}; exit 0"
exit /b %errorlevel%

:AssertNoteVersion
set "mvs_note_file=%~1"
set "mvs_note_title=%~2"
set "mvs_note_text=%~3"
set "mvs_note_observed=%~4"
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop'; if(-not(Test-Path -LiteralPath $env:mvs_note_file -PathType Leaf)){exit 2}; $rows=@(Import-Csv -LiteralPath $env:mvs_note_file -Delimiter \"`t\" -Encoding UTF8 | Where-Object {$_.title -eq $env:mvs_note_title -and $_.note_text -eq $env:mvs_note_text}); if($rows.Count-ne1){exit 1}; if([string]$rows[0].observed_snapshots-ne[string]$env:mvs_note_observed){exit 1}; exit 0"
exit /b %errorlevel%

:AssertExpectedTree
set "mvs_expected_root=%~1"
set "mvs_actual_root=%~2"
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop'; $e=$env:mvs_expected_root; $a=$env:mvs_actual_root; if(-not(Test-Path -LiteralPath $e -PathType Container)){exit 2}; foreach($f in Get-ChildItem -LiteralPath $e -File -Recurse){$rel=$f.FullName.Substring($e.Length).TrimStart('\'); $g=Join-Path $a $rel; if(-not(Test-Path -LiteralPath $g -PathType Leaf)){exit 1}; $x=(Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8).Replace(\"`r`n\",\"`n\"); $y=(Get-Content -LiteralPath $g -Raw -Encoding UTF8).Replace(\"`r`n\",\"`n\"); if($x-ne$y){exit 1}}; exit 0"
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
