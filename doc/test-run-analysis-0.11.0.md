# Windows test-run analysis — MVS Explorer Toolkit 0.11.0

Date analyzed: 2026-08-27

## Supplied result bundles

Main full-suite run:

```text
test-results-20260827-204413
```

Environment:

```text
Windows NT 10.0.19045.0
PowerShell 5.1.19041.6456
CLR 4.0.30319.42000
Dump: mvs_2019-03-19
```

Summary:

```text
Started:  2026-08-27T20:44:13.2764713-04:00
Finished: 2026-08-27T20:50:31.5597084-04:00
Duration: 00:06:18.2832371
Passed:   1053
Failed:   0
Skipped:  3
Total:    1056
```

The three skips are the established data-dependent exact note lookup cases.
No failure artifacts were produced.

Scope totals:

```text
Structure:      444 pass
Scalar:         120 pass
Lookup:          21 pass / 3 skip
Diagnostic:      46 pass
Relationship:   151 pass
Single-dump:    167 pass
Compare:         39 pass
History:         65 pass
--------------------------------
Total:         1053 pass / 0 fail / 3 skip
```

The 65 new archive-history assertions validate both public builders, snapshot
and source-coverage records, every added/removed domain ledger, every all-ever
domain union, and preservation of history ledgers when all-ever output is
generated into the same destination.

Dedicated compare run:

```text
test-results-20260827-205031
```

Summary:

```text
Duration: 00:00:11.3839916
Passed:   39
Failed:   0
Skipped:  0
```

The dedicated compare harness still executes its synthetic before/after fixture;
the supplied real-dump arguments are not used as a real-pair behavioral oracle.

## Baseline conclusion

MVS Explorer Toolkit 0.11.0 is a clean native Windows PowerShell 5.1 baseline.
The next validation layer can therefore focus on archive-wide real-snapshot
execution rather than unresolved deterministic regression failures.
