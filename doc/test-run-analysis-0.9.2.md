# Windows test-run analysis: 0.9.2

Attached result bundle: `test-results-20260827-180704.zip`

Run:

```text
test\test_all.bat ..\mvs_dumps_archive\mvs_2020-04-21
```

Environment recorded by the bundle:

```text
Windows NT 10.0.19045.0
Windows PowerShell 5.1.19041.6456
CLR 4.0.30319.42000
Test version 0.6.2
Products parsed 1899
```

Result:

```text
Passed: 928
Failed: 0
Skipped: 3
Total assertions: 931
```

Scope totals:

```text
Structure:       423 PASS
Scalar:          120 PASS
Lookup:           21 PASS, 3 SKIP
Diagnostic:       46 PASS
Relationship:    151 PASS
Single-dump:     167 PASS
```

The three skips are data-dependent exact note lookup cases; the selected real
dump has no non-empty note association for the required exact ID/title/date
candidates. Wildcard and no-match note lookup cases passed.

The attached `failures\` directory is empty.

This establishes 0.9.2 as the clean Windows single-dump baseline from which
0.10.0 cross-dump comparison development begins.
