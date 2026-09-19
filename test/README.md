# MVS Explorer Toolkit Tests

From the project root:

```text
test\test_all.bat path_to_real_mvs_dump_folder
```

The full suite uses the supplied real dump for the established scalar/lookup
regression tests, `test\test-mvs-dump-diagnostics\` for duplicate/orphan
diagnostics, and `test\test-mvs-dump-relationships\` for filename/hash
relationship queries.

Standalone subset entry points:

```text
test\test_structure.bat
test\test_scalar_tools.bat path_to_real_mvs_dump_folder
test\test_lookup_tools.bat path_to_real_mvs_dump_folder
test\test_diagnostic_tools.bat
test\test_relationship_tools.bat
test\test_single_dump_tools.bat
test\test_compare_tools.bat
```

Every test invocation creates a timestamped result directory below `test\`.

Diagnostic expected stdout is stored under `test\expected-diagnostics\`.
Those files are fixed regression expectations generated independently from
the diagnostic public tools.

Expected full-suite assertion matrix for 0.8.0:

```text
Structure:     269
Scalar:        120
Lookup:         24
Diagnostic:     46
Relationship:  151
Total:         610 assertions
```

The diagnostic count is 45 public-tool behavior checks plus one fixture
assertion.

The relationship count is 150 behavior cases plus one relationship-fixture
assertion. Every hash-query tool is tested separately with SHA-1 and SHA-256.


Relationship expected stdout is stored under:

```text
test\expected-relationships\
```

Those expectations are generated independently from the public relationship
batch files.


Single-dump completeness fixture:

```text
test\test-mvs-dump-single-complete\
test\expected-single-dump\
```

The 0.9.2 full-suite assertion matrix is:

```text
Structure:      423
Scalar:         120
Lookup:          24
Diagnostic:      46
Relationship:   151
Single-dump:    167
-------------------
Total:          931 assertions
```

The single-dump scope is 154 exact positive tool comparisons, 12 no-result
return-code checks covering each query operation family, and one fixture
presence assertion.

0.9.2 regenerates all standalone test entry points at test version 0.6.2; the assertion matrix remains 931. Structure checks also require the non-enumerating single-dump `New-ArrayList` return.


Two-dump comparison fixture:

```text
test\test-mvs-dump-compare\before\
test\test-mvs-dump-compare\after\
test\expected-compare\
```

The 0.10.0 full-suite assertion matrix is:

```text
Structure:      442
Scalar:         120
Lookup:          24
Diagnostic:      46
Relationship:   151
Single-dump:    167
Compare:         39
-------------------
Total:          989 assertions
```

The compare scope is 19 exact before-to-after comparisons, 19 identical
before-to-before no-change comparisons, and one fixture-presence assertion.

All eight standalone test entry points are generated at test version 0.7.0.


## Archive history

```bat
test\test_history_tools.bat
```

This subset needs no real dump argument. It executes both archive builders
against `test\test-mvs-dump-history\` and validates every generated added,
removed, and all-ever domain file against independent fixed expectations.


## Archive-wide real-dump sweep

The ordinary full suite uses fixed/synthetic fixtures where appropriate. To
exercise every public tool against the real archive, use:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive
```

Plan-only mode discovers snapshots, resolves nested `mvs_dmp\` layouts, derives
query values, and writes the full invocation plan without launching public
tools:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive --plan-only
```

For the supplied 79-snapshot archive and current 443 public tools, the plan is
34,822 invocations: 422 single-snapshot tools on 79 snapshots, 19 comparison
tools on 78 adjacent transitions, and two archive builders.

The archive sweep writes `plan.tsv`, `runs.tsv`, `summary.txt`, a resumable
plan SHA-256, failure artifacts, and retained history/all-ever output. See
`doc\archive-sweep.md`.


## Fast archive-sweep acceptance test

```bat
test\test_fast_archive_sweep.bat
```

This test has no prerequisite. It directly uses the packaged three-snapshot
history fixture. Its working folders are created under `%TEMP%`, not under
`test\`. Successful runs clean those temporary folders. Failed runs retain
them and print their exact locations together with summary/run-info/log
contents.


### 0.14.1 metadata serialization maintenance

Windows PowerShell 5.1 requires the archive sweep summary/run-info array
concatenations to be parenthesized so each `Key: value` field remains one
physical line. `test_fast_archive_sweep.bat` verifies the executor metadata in
both files before continuing with evolution, quality, and HTML assertions.


## 0.14.0 comprehensive archive quality/performance cycle

Run the recurring development gate with:

```bat
test\test_everything.bat ..\mvs_dumps_archive
```

Add a fresh real-archive run with:

```bat
test\test_everything.bat ..\mvs_dumps_archive --full-archive --workers 8
```

The public regression harness now records `elapsed_ms` for actual tool
invocations. `test\analyze_test_performance.bat` ranks timed cases and tools.

`test\check_archive_sweep_quality.bat` verifies archive ledger/source integrity,
evolution outputs, note retention, and logical/batch performance outliers.

Fast archive runs create a self-contained `archive-summary.html`. Rebuild it
without rerunning the archive with:

```bat
test\build_archive_html_report.bat result-folder
```

`test\archive-exclusions.tsv` is an optional non-destructive canonical
interpretation file. Excluded snapshots remain tested and fully ingested.
