# Performance architecture

MVS Explorer Toolkit 0.13.0 keeps the public command-line surface compatible while adding a separate high-throughput archive-sweep execution path.

## Motivation

The 0.12.0 archive-wide sweep correctly planned 34,822 public-tool invocations for the 79 supplied snapshots, but a partial Windows run showed that literal standalone execution would take several days.

The partial run `archive-sweep-results-20260827-214147` recorded 1,171 completed invocations with no failures. Its timing data showed three structural bottlenecks:

1. `print/read_mvs_dump_summary` and `print/read_mvs_dump_statistics` repeatedly performed large array membership scans and took roughly 13.4–14.1 minutes per call on early snapshots.
2. Many single-dump tools rebuilt a complete multi-source model even when the operation needed only one or two sources.
3. The external sweep wrote successful stdout to temporary files only to measure byte counts, causing unnecessary I/O for enumeration tools that can emit tens of megabytes.

## Layer 1: optimized public standalone tools

The public root remains 443 standalone batch files.

Exactly 377 generated tools receive performance-only internal changes while keeping their existing names, arguments, stdout contracts, scopes, and return-code contracts:

- 120 scalar tools
- 7 lookup tools
- 96 filename/hash relationship tools
- 154 single-dump completeness tools

The remaining 66 public tools are byte-for-byte unchanged from 0.12.0.

Key changes include:

- Date and note enrichment is parsed only when a projection/sort/search actually needs it.
- Relationship tools avoid unused date/note enrichment.
- Single-dump operations load only operation-relevant source files.
- Summary/statistics membership checks use case-insensitive hash sets rather than repeated linear array scans.
- Detail/hash queries use filename/hash indexes rather than repeatedly scanning the full record catalog.

These changes are implementation details only. They do not change the public command line or documented data model.

## Layer 2: combined high-performance sweep executors

Two non-public test utilities live under `test\fast`:

```text
run_snapshot_tools_fast.bat
run_compare_tools_fast.bat
```

They intentionally use a bulk interface. A snapshot is parsed once and reused for the 422 logical single-snapshot checks. An adjacent snapshot pair is parsed once and reused for the 19 logical comparison checks.

For the 79-snapshot archive, the logical plan remains exactly:

```text
79 × 422 single-snapshot checks = 33,338
78 × 19 comparison checks      =  1,482
2 archive builders             =      2
                                     ------
                                     34,822
```

But fast mode reduces process launches from about 34,822 to approximately 159:

```text
79 snapshot batches
78 comparison batches
2 archive builder calls
```

The fast executors classify logical checks as:

```text
PASS
NO_RESULT
SOURCE_MISSING
FAIL
```

They are designed for archive validation/status coverage, not byte-for-byte stdout comparison.

## Layer 3: dual-mode archive sweep

`test\test_all_dumps.bat` defaults to the combined executor:

```bat
test\test_all_dumps.bat mvs-dumps-root
```

The run metadata records:

```text
executor=fast-combined
```

To force literal public-tool execution:

```bat
test\test_all_dumps.bat mvs-dumps-root --external-tools
```

That run records:

```text
executor=external-public
```

Executor identity is serialized into the plan and therefore into the plan SHA-256. Resume refuses to cross executor modes.

External-public mode also avoids materializing successful stdout. Successful payloads go to the null sink. If an invocation fails, it is rerun once with complete stdout/stderr capture for diagnostics.

## Status replay validation

The combined status classifier was replayed against all 1,171 completed invocations from the partial 0.12.0 Windows sweep:

```text
PASS            951 / 951
NO_RESULT        50 / 50
SOURCE_MISSING  170 / 170
FAIL              0 / 0

Total matched  1,171 / 1,171
Mismatches          0
```

This validates logical status equivalence against the available literal-wrapper evidence. It does not replace `test_all.bat` or `--external-tools` when public wrapper behavior itself needs validation.

## Performance analysis utility

Existing sweep results can be analyzed without rerunning tools:

```bat
test\analyze_archive_sweep_performance.bat result-folder
```

The analyzer ranks tool and family elapsed time and reports large-output calls using the timing data already stored in `runs.tsv`.

## Acceptance strategy

Use three levels:

1. `test\test_all.bat dump-folder` — validates public-tool output/return-code regressions.
2. `test\test_fast_archive_sweep.bat` — validates combined executor behavior on the synthetic three-snapshot archive.
3. `test\test_all_dumps.bat archive-root` — performs the high-throughput full archive sweep.

Use `--external-tools` when literal wrapper execution over the full archive is specifically desired.
## PowerShell 5.1 parser compatibility maintenance (0.13.1)

The 0.13.0 combined snapshot worker used an overly nested `Where-Object` boolean predicate in
`Test-HashResult`. Windows PowerShell 5.1 rejected the embedded script block before execution.
0.13.1 rewrites that predicate as explicit algorithm/source branches. This is a parser-only
maintenance correction; the logical status contract and public-tool interfaces do not change.
