# Windows Test Run Analysis — MVS Explorer Toolkit 0.8.0

## Attached result

```text
test-results-20260827-154404.zip
```

## Environment

```text
MVS Explorer Toolkit test run
Started: 2026-08-27T15:44:04.8767982-04:00
Test script: test_all.bat
Test version: 0.5.0
Mode: all
Project root: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.8.0
Original dump argument: ..\mvs_dumps_archive\mvs_2019-08-27
Resolved dump: C:\Users\user\Downloads\mvs_dumps_archive\mvs_2019-08-27
Current directory: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.8.0
Computer: SHODAN
User: user
OS: Microsoft Windows NT 10.0.19045.0
PowerShell: 5.1.19041.6456
CLR: 4.0.30319.42000
Diagnostic fixture: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.8.0\test\test-mvs-dump-diagnostics
Relationship fixture: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.8.0\test\test-mvs-dump-relationships
Result folder: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.8.0\test\test-results-20260827-154404
```

## Summary

```text
MVS Explorer Toolkit Test Summary
Started: 2026-08-27T15:44:04.8767982-04:00
Finished: 2026-08-27T15:48:31.6064254-04:00
Duration: 00:04:26.7296272
Mode: all
Passed: 607
Failed: 0
Skipped: 3
Total assertions: 610
Diagnostic fixture: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.8.0\test\test-mvs-dump-diagnostics
Relationship fixture: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.8.0\test\test-mvs-dump-relationships
Result folder: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.8.0\test\test-results-20260827-154404
```

Breakdown:

```text
structure    PASS: 269
scalar       PASS: 120
lookup       PASS: 21
lookup       SKIP: 3
diagnostic   PASS: 46
relationship PASS: 151
failure artifacts: 0
```

The three skips are the data-dependent exact note lookup cases on the selected
real dump; all wildcard/no-result note lookup cases passed. This establishes
0.8.0 as the clean Windows-tested baseline before the 0.9.0 single-dump
completeness layer.
