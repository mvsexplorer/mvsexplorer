# Archive-wide public-tool sweep

Version 0.12.0 adds `test\test_all_dumps.bat`, a standalone Windows integration
harness for executing the complete public-tool surface against an MVS dump
archive.

## Purpose

The ordinary `test\test_all.bat dump-folder` is a deterministic regression
suite. Several newer tool families intentionally run against synthetic fixtures.
`test_all_dumps.bat` serves a different purpose: it exercises the public batch
files against every real historical snapshot so parser/runtime compatibility
can be measured across the entire archive.

## Invocation

From the project root:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive
```

Build the complete deterministic plan without launching public tools:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive --plan-only
```

Choose a results folder:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive C:\temp\mvs-archive-sweep
```

Resume an interrupted run only when the regenerated plan SHA-256 exactly
matches the existing plan:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive C:\temp\mvs-archive-sweep --resume
```

## Scope

The harness discovers root public `.bat` files instead of maintaining a second
hard-coded copy of the public tool list.

For the 0.12.0 public surface:

- 422 ordinary single-snapshot tools run once on every snapshot;
- 19 `compare_mvs_dump_*` tools run on every adjacent snapshot pair;
- `build_mvs_dump_change_history.bat` runs once on the archive;
- `build_mvs_dump_all_ever.bat` runs once on the same archive/output folder.

For the supplied 79-snapshot archive this produces:

```text
422 * 79 + 19 * 78 + 2 = 34,822 invocations
```

The archive-builder order is change-history first and all-ever second so their
outputs coexist under `archive-output\`.

## Search arguments

Query tools cannot be meaningfully invoked with only a dump folder. The sweep
therefore derives representative exact values from each real snapshot.

Examples:

- product ID/title/filename/hash values come from `mvs.txt`;
- date values come from `mvs_dates.txt`;
- note-title values come from `mvs_notes.html`;
- variant ID/title/filename/hash values come from `mvs_names.txt`;
- hash-record filename/hash fall back to `mvs.sha1`/`mvs.sha256` when needed.

The first suitable source value is used. When a source/value is unavailable,
the tool is still invoked with a syntactically valid no-match fallback. Lookup
note searches use `*` as a fallback because lookup tools support wildcard
matching.

This is a runtime sweep, not another exact-output oracle. A derived query can
legitimately have no projected result even though its search value exists.

## Historical source coverage

The harness resolves both known snapshot layouts:

```text
snapshot\mvs.txt
snapshot\mvs_dmp\mvs.txt
```

This specifically covers `mvs_2020-08-20` and `mvs_2020-08-27`.

Older snapshots do not contain all later source files. In particular:

- the first three snapshots do not contain `mvs_names.txt`;
- SHA-256 manifests begin later in the archive.

The runner still invokes the affected tools. Return code 4 in single/compare
scope is recorded as `SOURCE_MISSING`, not as a runtime defect.

## Status policy

`runs.tsv` records every completed invocation.

```text
PASS            rc 0
NO_RESULT       rc 1 in single/compare scope
SOURCE_MISSING  rc 4 in single/compare scope
FAIL            rc 2, 3, 5+, unexpected codes, or any nonzero archive-builder rc
```

`NO_RESULT` and `SOURCE_MISSING` remain visible separately; they are not folded
into PASS.

The overall harness returns code 0 when there are no `FAIL` rows and 1 when at
least one real failure is recorded.

## Results folder

Each normal invocation creates:

```text
test\archive-sweep-results-YYYYMMDD-HHMMSS\
```

For the supplied archive, 76 of 79 snapshots contain `mvs_names.txt`, 61 contain `mvs.sha256`, and exactly two resolve through nested `mvs_dmp\`. `snapshots.tsv` records this source coverage explicitly.

The folder contains:

```text
README.txt
run-info.txt
snapshots.tsv
plan.tsv
plan-sha256.txt
runs.tsv
summary.txt
console.log
failures\
archive-output\
```

`plan.tsv` is written before execution and provides the exact deterministic
work list. `runs.tsv` is appended after every completed invocation, making
interrupted runs resumable.

Successful/no-result/source-missing stdout and stderr are temporary and deleted
after byte counts are recorded. This avoids producing tens of thousands of
large duplicate output files. `FAIL` rows retain full `.stdout.txt`,
`.stderr.txt`, and `.meta.txt` artifacts.

`archive-output\` is retained because the history/all-ever builders create
durable archive-derived datasets rather than transient smoke-test output.

## Resume safety

A resume attempt regenerates the current plan and compares its SHA-256 to
`plan-sha256.txt`. Resume is rejected if snapshot discovery, public-tool set,
tool ordering, or derived search values change. Completed invocation indices
are read from `runs.tsv`, and only unfinished plan rows are executed.

## Relationship to the normal test suite

Use both layers:

```text
test_all.bat        deterministic behavioral regression
test_all_dumps.bat  real-archive runtime/coverage sweep
```

A clean archive sweep does not replace the fixed expected-output tests, and a
clean fixed test suite does not prove that every historical snapshot parses
without runtime errors.

`test_all.bat` deliberately does **not** invoke the archive sweep; otherwise the normal regression suite would expand from 1,056 assertions into tens of thousands of real-data process launches.

## 0.13.0 execution modes

The default executor is `fast-combined`:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive
```

It evaluates the same deterministic logical plan in snapshot/pair batches and records the executor in `plan.tsv`, `runs.tsv`, `run-info.txt`, and the plan hash.

Force literal standalone public-tool execution with:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive --external-tools
```

That executor is recorded as `external-public`.

`--plan-only` and `--resume` remain supported in both modes. Resume rejects a results folder created by the other executor.

In `external-public` mode, successful stdout is discarded rather than persisted to a temporary file. If a logical invocation fails, the tool is rerun with full stdout/stderr capture for the failure artifacts.

For performance measurements from an existing result directory:

```bat
test\analyze_archive_sweep_performance.bat test\archive-sweep-results-YYYYMMDD-HHMMSS
```

See `doc\performance-architecture.md`.


## Fast archive completion (0.13.3)

The default `fast-combined` executor no longer falls back to the two literal
archive builders at the end of a sweep. It invokes:

```bat
test\fast\run_archive_tools_fast.bat archive-root archive-output-folder
```

once, generating both the change-history and all-ever products in one
streaming pass. Progress is printed once per snapshot. As of 0.14.3 those
worker lines are routed through the parent sweep logger, so they are visible
during the long archive phase and retained in `console.log` rather than being
discarded. The two logical archive rows are appended to `runs.tsv` only after
the worker returns success.

`--external-tools` intentionally retains the literal public builders.

Because executor identity and the logical 34,822-row plan are unchanged,
a 0.13.2 fast-combined results folder with 34,820 completed rows can be resumed
by 0.13.3 after stopping any still-running 0.13.2 archive-builder process.

## 0.14.0 indexed, parallel, source-stable execution

`fast-combined` remains a logical-status archive executor, not a replacement for
literal public-wrapper regression tests. Its plan still represents exactly the
same public scope: 422 single-snapshot checks per dump, 19 adjacent comparisons,
and two archive checks.

Snapshot batches now build filename/hash/product/variant/note indexes once and
serve logical checks from those indexes. Independent snapshots can run in
bounded parallel jobs:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive --workers 8
```

The automatic worker count is conservative (up to four); `--workers N` accepts
1 through 32. `--external-tools` intentionally forces literal wrapper
execution instead.

Fast mode has a content-addressed snapshot-result cache under
`test\archive-sweep-cache` by default. Use `--cache-folder DIR` to relocate it
or `--no-cache` for a fresh benchmark.

Every worker freezes presence, length, and UTC last-write metadata for all seven
known sources before parsing and verifies the inventory again before its 422
rows are committed. A source appearing, disappearing, or changing mid-batch
fails that complete batch. Resume therefore reruns it rather than retaining
partial or false historical classifications.

Fast archive output also contains `archive-output\evolution\` and the
self-contained `archive-summary.html`. See
`doc\archive-evolution-and-quality.md`.

Canonical exclusion configuration is accepted with `--exclusions FILE`.
Exclusions affect analysis/report interpretation only; the snapshot is still
tested and its evidence remains ingested.

For a truly fresh performance run:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive --workers 8 --no-cache
```

### 0.14.4 archive-engine phase timings

Fast archive builder output now includes
`archive-output\evolution\fast-archive-timings.tsv`. The file is diagnostic
performance evidence only; it does not participate in the logical 34,822-row
plan or alter historical evidence keys. It records per-snapshot parse time for
each source plus domain-union, adjacent-diff, state-union, notes, variant-ID
transition, flush, and total elapsed milliseconds.

## 0.15.0 family-tool scope

The root public surface is 476 tools in 0.15.0, but the historical sweep plan
intentionally continues to cover only the original 443 sweep-eligible tools:
422 single-snapshot tools, 19 adjacent-comparison tools and two history
builders. The 33 product-family tools are archive-level index/query operations
and are tested separately by `test\test_product_family_tools.bat`; invoking
them once per snapshot would be semantically wrong and would change the
established 34,822-row logical plan for the known 79-snapshot archive.

