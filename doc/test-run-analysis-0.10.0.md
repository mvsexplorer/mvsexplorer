# Windows test-run analysis — MVS Explorer Toolkit 0.10.0

Date: 2026-08-27

## Full-suite run

Command supplied by the Windows tester:

```bat
test\test_all.bat ..\mvs_dumps_archive\mvs_2019-03-19
```

Result directory:

```text
test\test-results-20260827-194602
```

The attached result bundle and console report establish:

```text
Passed:  986
Failed:    0
Skipped:   3
Total:   989
```

The three skips are the expected data-dependent exact NOTE lookup cases on a
dump with no suitable non-empty note association. They are not failures.

The run parsed 1,702 products from `mvs_2019-03-19`.

The structure scope confirmed all 441 public 0.10.0 root batch files were
standalone. Scalar, lookup, duplicate/orphan diagnostics, filename/hash
relationship queries, single-dump completeness tools, and the new two-dump
comparison tools all completed without a failure.

## Dedicated comparison regression run

A second invocation produced:

```text
test\test-results-20260827-195229
```

with:

```text
Passed:  39
Failed:   0
Skipped:  0
```

These 39 assertions are the fixed synthetic comparison regression matrix:

```text
1   comparison fixture presence
19  changed before->after comparisons
19  no-change before->before comparisons
```

The 19 comparison tools therefore have a clean Windows PowerShell 5.1
behavioral baseline.

## Harness note

The 0.10.0 `test_compare_tools.bat` entry point accepts only its internally
defined synthetic comparison fixture. Extra dump-folder arguments supplied on
the command line are not used as a real-dump comparison smoke test.

That does not invalidate the 39/0/0 synthetic comparison result; it means the
second invocation should be described accurately as a dedicated synthetic
regression run rather than a test of the two supplied real dump folders.

## Baseline status

0.10.0 is accepted as the clean Windows baseline for the 441-tool surface:

```text
Full suite:          986 pass / 0 fail / 3 skip
Compare-only suite:   39 pass / 0 fail / 0 skip
```

0.11.0 archive-history work is built on this baseline.
