# Windows Test Run Analysis — MVS Explorer Toolkit 0.6.0

## Attached result

```text
test-results-20260827-122202.zip
```

## Environment

```text
MVS Explorer Toolkit test run
Started: 2026-08-27T12:22:02.2887794-04:00
Test script: test_all.bat
Test version: 0.3.0
Mode: all
Project root: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.6.0
Original dump argument: ..\mvs_dumps_archive\mvs_2020-09-15_2
Resolved dump: C:\Users\user\Downloads\mvs_dumps_archive\mvs_2020-09-15_2
Current directory: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.6.0
Computer: SHODAN
User: user
OS: Microsoft Windows NT 10.0.19045.0
PowerShell: 5.1.19041.6456
CLR: 4.0.30319.42000
Result folder: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.6.0\test\test-results-20260827-122202
```

## Summary

```text
MVS Explorer Toolkit Test Summary
Started: 2026-08-27T12:22:02.2887794-04:00
Finished: 2026-08-27T12:25:49.8139609-04:00
Duration: 00:03:47.5251815
Mode: all
Passed: 272
Failed: 0
Skipped: 0
Total assertions: 272
Result folder: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.6.0\test\test-results-20260827-122202
```

Breakdown:

```text
structure PASS: 128
scalar    PASS: 120
lookup    PASS: 24
failures:       0
```

This establishes 0.6.0 as the clean scalar/lookup regression baseline before
the 0.7.0 duplicate/orphan layer was added.
