# Windows Test Run Analysis — MVS Explorer Toolkit 0.5.0

## Source

Attached result archive:

```text
test-results-20260827-111852.zip
```

## Environment

```text
MVS Explorer Toolkit test run
Started: 2026-08-27T11:18:52.1315407-04:00
Test script: test_all.bat
Test version: 0.2.0
Mode: all
Project root: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.5.0
Original dump argument: ..\mvs_dumps_archive\mvs_2020-08-14
Resolved dump: C:\Users\user\Downloads\mvs_dumps_archive\mvs_2020-08-14
Current directory: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.5.0
Computer: SHODAN
User: user
OS: Microsoft Windows NT 10.0.19045.0
PowerShell: 5.1.19041.6456
CLR: 4.0.30319.42000
Result folder: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.5.0\test\test-results-20260827-111852
```

## Summary

```text
MVS Explorer Toolkit Test Summary
Started: 2026-08-27T11:18:52.1315407-04:00
Finished: 2026-08-27T11:22:43.6780835-04:00
Duration: 00:03:51.5465428
Mode: all
Passed: 265
Failed: 7
Skipped: 0
Total assertions: 272
Result folder: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.5.0\test\test-results-20260827-111852
```

Assertion counts by scope/status:

```text
structure PASS: 128
scalar    PASS: 120
lookup    PASS: 17
lookup    FAIL: 7
```

## Failure signature

All seven failures are lookup no-match return-code assertions. For every failure:

```text
expected stdout: empty
actual stdout:   empty
stderr:          empty
expected rc:     1
actual rc:       0
```

The failing cases are:

- `lookup_mvs_title_from_id [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]`
- `lookup_mvs_title_from_date [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]`
- `lookup_mvs_note_from_id [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]`
- `lookup_mvs_note_from_title [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]`
- `lookup_mvs_note_from_date [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]`
- `lookup_mvs_date_from_id [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]`
- `lookup_mvs_date_from_title [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]`


## What this proves

The attached artifacts rule out a lookup matching/output defect:

- exact lookup cases pass;
- wildcard-all cases pass;
- prefix/suffix/contains wildcard cases pass;
- deliberate no-match cases produce exactly the correct empty output;
- only process return-code propagation is wrong.

The result bundle itself also passed its purpose: it captured the complete console transcript, run environment, machine-readable assertion table, summary, and one detailed failure artifact set per failure.

## 0.6.0 change

Version 0.5.0 attempted to force the nonzero code at the embedded PowerShell level. The external Windows result shows that this was insufficient as an end-to-end batch contract.

Version 0.6.0 therefore changes the batch propagation path itself:

```text
powershell.exe
    -> capture ERRORLEVEL
    -> :RunPowerShellFromLabel exit /b captured-code
    -> main captures ERRORLEVEL
    -> :end explicitly exit /b on nonzero
```

The previous `_rps_rc` re-entry carrier is removed from `:RunPowerShellFromLabel`.

This is intentionally a simpler return path with fewer parse/control-flow transitions.
