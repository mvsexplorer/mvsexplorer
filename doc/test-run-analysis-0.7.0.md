# Windows Test Run Analysis — MVS Explorer Toolkit 0.7.0

## Attached result

```text
test-results-20260827-141412.zip
```

## Environment

```text
MVS Explorer Toolkit test run
Started: 2026-08-27T14:14:12.6202408-04:00
Test script: test_all.bat
Test version: 0.4.0
Mode: all
Project root: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.7.0
Original dump argument: ..\mvs_dumps_archive\mvs_2020-10-20
Resolved dump: C:\Users\user\Downloads\mvs_dumps_archive\mvs_2020-10-20
Current directory: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.7.0
Computer: SHODAN
User: user
OS: Microsoft Windows NT 10.0.19045.0
PowerShell: 5.1.19041.6456
CLR: 4.0.30319.42000
Diagnostic fixture: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.7.0\test\test-mvs-dump-diagnostics
Result folder: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.7.0\test\test-results-20260827-141412
```

## Summary

```text
MVS Explorer Toolkit Test Summary
Started: 2026-08-27T14:14:12.6202408-04:00
Finished: 2026-08-27T14:18:03.8493826-04:00
Duration: 00:03:51.2291418
Mode: all
Passed: 363
Failed: 0
Skipped: 0
Total assertions: 363
Diagnostic fixture: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.7.0\test\test-mvs-dump-diagnostics
Result folder: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.7.0\test\test-results-20260827-141412
```

Breakdown:

```text
structure  PASS: 173
scalar     PASS: 120
lookup     PASS: 24
diagnostic PASS: 46
failure artifacts: 0
```

This establishes 0.7.0 as the clean Windows-tested baseline before the
filename/hash relationship layer added in 0.8.0.
