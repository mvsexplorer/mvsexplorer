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


## Archive-worker completion (0.13.3)

The final two logical archive checks previously escaped the combined executor
and reparsed the complete archive in two literal PowerShell processes. The
0.13.3 archive worker streams each source once per snapshot, compares adjacent
source-local sets while the previous snapshot is still in memory, and updates
the all-ever union during the same pass. This removes the duplicate full-archive
parse and makes progress visible.

The literal public builders remain the authoritative compatibility path under
`--external-tools`.

## 0.14.0 second-stage optimization

The completed 0.13.x real-archive run showed that combining processes was not
enough by itself. Approximately 30 hours of recorded active computation
remained, with detail and relationship logical checks dominating because they
repeatedly searched large PowerShell arrays after the snapshot had already been
parsed.

0.14.0 builds case-insensitive indexes once per snapshot for product IDs/titles,
product filenames, hash values, variant IDs/titles/filenames/hashes, and note
titles. Detail/relationship checks use those indexes rather than full-array
`Where-Object` scans.

Independent snapshot batches can also execute concurrently with `--workers N`.
The automatic default is deliberately conservative; a machine with ample RAM
and cores can explicitly request more workers. Parallelism is applied after the
algorithmic indexing change so it multiplies useful work rather than merely
running several inefficient scans simultaneously.

Repeated runs use a content-addressed snapshot-result cache. Cache keys include
the fast-worker version, the exact per-snapshot plan slice, and SHA-256 of every
present source file. `--no-cache` bypasses this mechanism and is used by the
comprehensive full-archive performance cycle.

Performance is measured at two levels:

- logical check `elapsed_ms` in `runs.tsv`, useful for finding tool-operation
  regressions after a model has been built;
- full worker `elapsed_ms` in `fast-batches.tsv`, which includes parsing/index
  construction and therefore identifies pathologically slow snapshots.

`check_archive_sweep_quality.bat` writes `performance-by-tool.tsv`,
`performance-outliers.tsv`, `performance-by-batch.tsv`, and
`performance-batch-outliers.tsv`. `--strict-performance` converts outlier
warnings to a nonzero quality-check result.

The one-pass archive worker was also changed from per-line scriptblock callbacks
to direct buffered `StreamReader` loops. Its runtime should be measured on
Windows before setting tighter release thresholds.

## 0.14.3 measured archive-builder follow-up

The first clean native 0.14.2 full-archive run supplied the missing measurement.
With eight snapshot workers, the 79 snapshot batches had a 116.13-second
median, 173.18-second p95, and 176.742-second maximum. The 78 comparison
batches together consumed about 25.6 seconds. In contrast,
`run_archive_tools_fast.bat` consumed 15,224.942 seconds (4 h 13 m 44.942 s).

The archive worker is therefore the dominant remaining wall-time target.
0.14.3 applies equivalent hot-path substitutions rather than changing the
evidence model:

- zero- and one-file section states no longer create a PowerShell pipeline and
  sort solely to construct their state fingerprint;
- SHA-256 operations reuse one hasher and convert digest bytes with
  `BitConverter` rather than a per-byte PowerShell pipeline;
- TSV emission builds a fixed string array directly rather than calling a
  field-conversion function through an `ArrayList` for every row.

The archive worker's existing per-snapshot timing lines are now routed through
the parent sweep's `Write-Line`, making them both live console progress and
persistent `console.log` evidence.

Performance reporting is now scope-aware. `performance-batch-outliers.tsv`
continues to identify anomalous snapshot batches.
`performance-archive-outliers.tsv` separately records archive-scope batches
over the advisory one-hour threshold. The quality summary also reports
snapshot, comparison, and archive batch distributions separately. Under
`--strict-performance`, either snapshot or archive batch outliers are errors.

The next fresh 79-snapshot run must compare the archive row in
`fast-batches.tsv` against 15,224.942 seconds while reproducing the 0.14.2
logical/evolution baselines exactly.

## 0.14.4 archive-builder allocation profile

The direct native 0.14.3 archive benchmark completed in 13,975,326 ms versus
15,223,912 ms for 0.14.2, an 8.20% improvement with byte-equivalent archive
outputs except for the elapsed-time summary.

Per-snapshot times still rose with later/larger dumps, so 0.14.4 targets
per-section and per-value allocation rather than changing chronology semantics.
Source-local value rows are stored as parallel typed key/value lists, section
titles/IDs are normalized once, multi-file state lists are lazy, and state/title
ID sets are allocated only when multiple distinct IDs actually occur. Raw note
HTML uses an in-memory content-hash seen set.

`evolution\fast-archive-timings.tsv` records source parse and archive-maintenance
phase timings per snapshot. Total builder time minus the sum of snapshot totals
also exposes final all-ever/retention serialization cost.

## 0.20.0 resource-aware snapshot concurrency

The snapshot phase now treats worker count as a feedback-control problem rather
than a fixed machine constant. Adaptive mode starts at one quarter of logical
processors (rounded up), samples system headroom every 30 seconds, and adds at
most one worker when CPU, free physical memory, and physical-disk idle
percentages are each at least 15% and recent completed-check throughput has not
regressed.

This is intentionally conservative. It does not infer spare I/O capacity when
disk telemetry is unavailable, and it does not extrapolate worker suitability
from logical-core count alone. `worker-scaling.tsv` makes each scale/hold
decision auditable.

The controller currently governs only independently executable snapshot
batches. Compare work remains serial because each batch is already short, while
the archive-wide, full-family, and compact-family builders remain
single-process. Their native 0.19.3 elapsed times make them separate future
parallelization/streaming targets rather than reasons to overstate what the
snapshot worker controller can improve.

