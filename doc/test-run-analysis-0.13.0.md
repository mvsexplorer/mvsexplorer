# Windows test-run analysis — MVS Explorer Toolkit 0.13.0

Date: 2026-08-28

## Optimized public-tool regression

The attached Windows run `test-results-20260828-055842` completed on:

```text
Windows NT 10.0.19045.0
PowerShell 5.1.19041.6456
CLR 4.0.30319.42000
```

Result:

```text
Passed:  1053
Failed:     0
Skipped:    3
Total:   1056
Duration: 00:06:18.2765622
```

The three skips are the existing data-dependent exact-note lookup cases. This
validates the 0.13.0 optimized public-tool surface and confirms that the
performance changes did not alter the normal regression contract.

## Fast-combined acceptance failure

`test\test_fast_archive_sweep.bat` discovered the expected three synthetic
snapshots and planned 1,306 logical checks, but the first combined snapshot
worker failed before execution.

Windows PowerShell 5.1 reported a `[ScriptBlock]::Create()` parser error in
`Test-HashResult`:

```text
Missing closing ')' in expression.
```

The failing construct was an overly nested filename/hash boolean predicate
inside `Where-Object`. Because the entire embedded script block is compiled
before execution, this parser defect affected the fast worker independently
of the already validated public tools.

## 0.13.1 correction

0.13.1 changes only the fast-worker/test/development layer. The 443 public root
tools remain byte-for-byte unchanged from 0.13.0.

`Test-HashResult` now uses explicit branch-based matching for algorithm,
filename, and hash conditions. The archive-sweep static validator also rejects
the old parser-sensitive predicate.
