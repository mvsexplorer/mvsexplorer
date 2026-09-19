# MVS Explorer Toolkit 0.13.1

## 0.13.1 fast-worker PowerShell 5.1 parser fix

Version 0.13.1 is a narrow maintenance release over the validated 0.13.0 public-tool surface.
The 443 public root tools are unchanged from 0.13.0. It fixes the combined snapshot worker's
`Test-HashResult` predicate, which Windows PowerShell 5.1 rejected at script-block parse time
because of an overly nested boolean expression. The predicate now uses explicit branch-based
logic and the archive-sweep validator rejects the old parser-sensitive form.


MVS Explorer Toolkit is a growing collection of console tools for exploring MVS dump snapshots, intended to culminate in the graphical **MVS Explorer** application.


## 0.12.0 archive-wide real-dump sweep

The validated 0.11.0 Windows baseline completed **1053 passes, 0 failures, and
3 expected data-dependent note skips**. Version 0.12.0 adds a separate
real-archive integration harness without changing the 443 public root tools.

From the project root:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive
```

For the supplied 79-snapshot archive the deterministic plan contains **34,822
public-tool invocations**:

```text
422 single-snapshot tools * 79 snapshots
+ 19 compare tools * 78 adjacent transitions
+ 2 archive builders
= 34,822
```

Use plan-only mode before launching the sweep:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive --plan-only
```

Interrupted runs can be resumed safely when the regenerated plan SHA-256
matches:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive path_to_existing_results --resume
```

The runner resolves both ordinary snapshot roots and the known nested
`mvs_dmp\` layout. It records `PASS`, `NO_RESULT`, `SOURCE_MISSING`, and `FAIL`
separately, retains full artifacts only for failures, and preserves the
archive history/all-ever builder output.

See `doc\archive-sweep.md` for the complete execution and result contract.


## Standalone public tools, shared development source

Every public `.bat` in the project root is fully standalone.

Common code is now maintained under `dev\` and injected by `dev\generate_tools.py`. The generated public tools contain their own batch functions and embedded PowerShell; they do not read or call anything under `dev\` at runtime.

The development model is:

```text
common library + template + tool specification
                  |
                  v
             generation
                  |
                  v
      fully standalone public .bat
```

## Public tool count

Version 0.3.0 contains **127 standalone public batch tools**:

- 30 source-order scalar tools;
- 90 sorted scalar tools;
- 7 lookup tools.

## Sorted scalar tools

Every existing scalar `print_` and `read_` tool now has three companions:

```text
_sorted_by_id
_sorted_by_title
_sorted_by_date
```

For example:

```text
print_mvs_dump_id_title_date_note.bat
print_mvs_dump_id_title_date_note_sorted_by_id.bat
print_mvs_dump_id_title_date_note_sorted_by_title.bat
print_mvs_dump_id_title_date_note_sorted_by_date.bat
```

Sort semantics are ascending:

- **ID:** numeric product ID.
- **TITLE:** case-insensitive natural/alphanumeric title; numeric runs are compared naturally, with numeric ID as tie-break.
- **DATE:** chronological date/time where parseable; source date text and numeric ID provide deterministic tie-breaks.

The original unsorted tools remain source-order interfaces and follow `mvs_ids.txt`.

A sort field does not have to be displayed. For example, `print_mvs_dump_note_sorted_by_title.bat` prints notes while ordering product rows by title.

## Lookup tools

Current lookup relationships:

```text
lookup_mvs_title_from_id.bat
lookup_mvs_title_from_date.bat
lookup_mvs_note_from_id.bat
lookup_mvs_note_from_title.bat
lookup_mvs_note_from_date.bat
lookup_mvs_date_from_id.bat
lookup_mvs_date_from_title.bat
```

Examples:

```text
lookup_mvs_title_from_id.bat mvs_2021-08-17 28
lookup_mvs_title_from_id.bat mvs_2021-08-17 2*
lookup_mvs_title_from_id.bat mvs_2021-08-17 *28
lookup_mvs_title_from_id.bat mvs_2021-08-17 *2*
lookup_mvs_note_from_title.bat mvs_2021-08-17 "Windows 7 *"
```

`*` matches zero or more characters anywhere in the search value. Matching is case-insensitive. Every non-`*` character is treated literally.

Lookup tools emit **distinct, non-empty associated values, one per line**, with no label or header. Multiple matching product rows are ordered by the searched field: ID numerically, title naturally, or date chronologically.

No associated value produces no stdout and return code `1`.

## Scalar output families

`print_`
: Human-readable, labeled, one product per line.

`read_`
: Headerless TSV, one product per line, intended for piping and machine consumption.

## Development files

`dev\library\`
: Common maintained batch/PowerShell source.

`dev\templates\`
: Batch templates.

`dev\tool-spec.json`
: Tool matrix.

`dev\generate_tools.py`
: Injects common source into standalone public tools.

`dev\validate_generated.py`
: Static validator for generated tools.

These are development-time files only.

## Documentation

See `doc\` for the supplied Batch File Style Guide, project addendum, embedded PowerShell style guide, developer diary, observation journal, complete prompt record, distilled directives, project history, output/data-model documents, tool catalog, and one version-history file per public/development tool.


## Automated tests

Run the complete Windows test suite from the project root:

```text
test\test_all.bat path_to_mvs_dump_folder
```

Subset tests are also standalone:

```text
test\test_structure.bat
test\test_scalar_tools.bat path_to_mvs_dump_folder
test\test_lookup_tools.bat path_to_mvs_dump_folder
```

`test_all.bat` invokes every one of the 127 public batch tools and compares its output/return code against expectations independently constructed from the selected dump. It also performs standalone-structure checks.

The test suite covers:

- all 120 scalar source-order/sorted tools;
- exact output for human and machine projections;
- numeric ID, natural title, and chronological date ordering;
- all seven lookup tools;
- exact lookup;
- wildcard-all lookup;
- no-match return behavior;
- prefix, suffix, and contains `*` wildcard cases for ID lookup;
- clean stderr on successful/expected no-match runs;
- standalone injected-code structure.

All four test `.bat` files are themselves fully standalone; `test_all.bat` does not require the other test files to execute.


## Timestamped test result bundles

Every test invocation creates a single result directory beneath `test\`:

```text
test\test-results-YYYYMMDD-HHMMSS\
```

If two runs start in the same second, `-01`, `-02`, etc. is appended.

The normal full-suite command remains:

```text
test\test_all.bat path_to_mvs_dump_folder
```

Each result directory contains:

```text
README.txt
run-info.txt
console.log
summary.txt
all-results.tsv
general-results.tsv
structure-results.tsv
scalar-results.tsv
lookup-results.tsv
failures\
```

`all-results.tsv` records every assertion. The scope-specific TSV files make it easy to inspect just structure, scalar, or lookup testing.

When a behavioral comparison fails, `failures\` contains the complete expected stdout, actual stdout, stderr, and metadata for that case. Console messages may abbreviate long differences, but these failure files do not.

Version 0.5.0 also fixes the lookup no-match return-code defect found by the first external Windows run: a lookup that finds no non-empty associated result now returns code `1` while keeping stdout/stderr empty.


## 0.6.0 return-code propagation hardening

The attached 0.5.0 Windows result bundle confirmed that output and matching were still correct, but all seven no-match lookup cases continued to reach the caller as return code `0`.

Version 0.6.0 hardens both batch return boundaries:

1. `:RunPowerShellFromLabel` now returns the captured `powershell.exe` process exit code directly with `exit /b`.
2. The top-level `:end` path explicitly exits on any nonzero application code before the normal `GoTo :EOF`.

The explicit PowerShell process-level no-match exit remains in place as well. This removes the previous indirect nonzero return-carrier path and makes the intended chain:

```text
lookup no result
    -> powershell.exe exit 1
    -> :RunPowerShellFromLabel exit /b 1
    -> app.rc = 1
    -> top-level exit /b 1
    -> calling cmd.exe sees 1
```

The existing automated lookup no-match cases remain the acceptance test for this behavior.


## 0.7.0 duplicate/orphan diagnostic layer

Version 0.7.0 adds **45 standalone diagnostic finders**:

- 14 duplicate-property tools;
- 31 directional orphan-reference tools.

Together with the established scalar/lookup layer, the project now contains
**172 standalone public root `.bat` tools**.

Diagnostic tools use:

```text
find_mvs_duplicate_<property>_in_<source>.bat dump-folder
find_mvs_orphan_<property>_from_<source>_in_<target>.bat dump-folder
```

Findings are human-readable and preserve source context. No findings means no
stdout and return code `0`. A finding is information, not a process failure.

For `mvs.txt` and `mvs_names.txt`, duplicate/orphan ID or title findings print
the complete source section: header plus all associated nonblank lines through
the next blank line/source section. Filename findings print the owning ID,
title, and exact matching checksum/filename line.

Duplicate title/filename comparisons are case-insensitive after documented
normalization. IDs compare numerically. Dates compare as trimmed source values.

### Important interpretation notes

Repeated IDs in `mvs_names.txt` are normally expected because one product ID
can own many variant sections. The requested duplicate-ID finder reports the
literal repetition; it does not label that relationship corrupt.

Likewise, titles in `mvs_names.txt` are variant/display titles rather than the
same title domain as product titles in `mvs_ids.txt`, `mvs_dates.txt`, and
`mvs.txt`. Cross-file title-orphan tools involving `mvs_names.txt` therefore
report literal title-set differences and can legitimately produce many results.

`mvs_notes.html` normally has no ID field. The requested
`find_mvs_duplicate_id_in_mvs_notes.html.bat` scans literal `[ID: N]` markers
if present; ordinary archive note files are expected to yield no ID findings.

The requested filename:

```text
find_mvs_duplicate_date_in_mvs_date.txt.bat
```

is supplied exactly and reads the actual source file `mvs_dates.txt`. A
canonical alias is also supplied:

```text
find_mvs_duplicate_date_in_mvs_dates.txt.bat
```

See `doc\diagnostic-tools.md` for the complete matrix and output contract.

## Diagnostic regression fixture

The test suite now includes the intentionally inconsistent synthetic dump:

```text
test\test-mvs-dump-diagnostics\
```

and 45 independently generated fixed expected-output files under:

```text
test\expected-diagnostics\
```

Run only the diagnostic regression suite with:

```text
test\test_diagnostic_tools.bat
```

The full suite remains:

```text
test\test_all.bat path_to_real_mvs_dump_folder
```

The real dump is used for scalar/lookup regression tests; the fixed synthetic
dump is used for duplicate/orphan tests.


## 0.8.0 filename/hash relationship queries

Version 0.8.0 adds **96 standalone relationship-query tools**: 24 requested
projections, each available as `print_` and `read_`, from both filename and
hash.

The project now contains **268 standalone public root `.bat` tools**.

Examples:

```text
print_mvs_dump_id_title_filenames_from_filename.bat dump-folder "shared.iso"
read_mvs_dump_title_date_note_from_filename.bat dump-folder "shared.iso"

print_mvs_dump_id_title_date_note_filenames_from_hash.bat dump-folder SHA1_OR_SHA256
read_mvs_dump_filenames_from_hash.bat dump-folder SHA1_OR_SHA256
```

Filename/hash searches are exact and case-insensitive.

Hash reverse lookup indexes `mvs.txt`, `mvs.sha1`, and `mvs.sha256`.
The resulting filenames are then traversed to product sections in `mvs.txt`
and joined to date/note metadata.

A filename can map to more than one product and a hash can map to more than one
filename, so multiple rows are preserved when associations are genuinely
different.

See `doc\relationship-tools.md` for the exact row/output semantics.

### Relationship regression fixture

```text
test\test-mvs-dump-relationships\
test\expected-relationships\
test\test_relationship_tools.bat
```

The full test suite now expects **610 assertions** on the 0.8.0 matrix:

```text
Structure:     269
Scalar:        120
Lookup:         24
Diagnostic:     46
Relationship:  151
Total:         610
```


## 0.9.x single-dump completeness milestone

Version 0.9.x adds **154 standalone tools** covering the remaining
single-dump information/presentation layer. The project now has **422 public
standalone `.bat` tools**.

New areas:

```text
Product -> filename -> hash forward traversal
mvs_names.txt variant occurrence records
hash/provenance records from mvs.txt, mvs_names.txt, mvs.sha1, mvs.sha256
raw product-file rows and raw product sections
raw note occurrence records
malformed/unparsed-line reporting
hash-integrity diagnostics
whole-dump summary/statistics
```

Every concrete suggestion from the single-dump completeness review is present,
along with the natural `print_`/`read_` counterpart where machine-readable
output is meaningful.

Examples:

```text
print_mvs_dump_filenames_from_id.bat dump-folder 10
read_mvs_dump_hashes_from_title.bat dump-folder "Product title"
print_mvs_dump_id_title_filenames_hashes_from_id.bat dump-folder 10
print_mvs_dump_sha1_from_filename.bat dump-folder "file.iso"
print_mvs_dump_filename_hash_algorithm_source.bat dump-folder

print_mvs_dump_variants.bat dump-folder
read_mvs_dump_variants_from_id.bat dump-folder 10
print_mvs_dump_id_variant_title_filename_hashes_from_hash.bat dump-folder HASH

print_mvs_dump_hash_records.bat dump-folder
print_mvs_dump_product_files_from_id.bat dump-folder 10
print_mvs_dump_product_sections_from_id.bat dump-folder 10
print_mvs_dump_note_records.bat dump-folder

find_mvs_unparsed_lines_in_mvs.txt.bat dump-folder
find_mvs_hash_mismatch_for_filename_between_mvs.txt_and_mvs.sha1.bat dump-folder

print_mvs_dump_summary.bat dump-folder
read_mvs_dump_statistics.bat dump-folder
```

Hash provenance records retain source, physical line, ID/product title where
available, variant title where available, filename, digest, and algorithm.

The summary/statistics layer reports source presence, product/file/variant/note
coverage, ID/date ranges, SHA-1/SHA-256 counts, reused filenames, variant
multiplicity, note duplicate-heading groups, directional filename orphan
counts, and malformed-line totals.

A new exact regression fixture is under:

```text
test\test-mvs-dump-single-complete\
test\expected-single-dump\
```

and the new subset runner is:

```text
test\test_single_dump_tools.bat
```

The 0.9.1 full suite expects **931 assertions** before any data-dependent skips
from the supplied real dump.



## 0.9.2 ArrayList runtime bugfix

The first Windows 0.9.1 full run proved that the 0.9.0 parse-time failure was
fixed: the embedded single-dump script now compiles. It also exposed the next
shared-runtime defect. All 166 single-dump behavioral checks failed with return
code 5 and the same stderr:

```text
ERROR: You cannot call a method on a null-valued expression.
```

The cause was `New-ArrayList`. Returning a bare empty
`System.Collections.ArrayList` from a PowerShell function emits no pipeline
objects, so callers receive `$null`. The first subsequent `.Add()` therefore
fails.

0.9.2 makes the helper return the collection itself as one object:

```text
return ,(New-Object System.Collections.ArrayList)
```

All 154 single-dump tools were regenerated as tool version 0.1.2. The 268
pre-0.9.0 public tools remain unchanged. The test harness structure check and
the static release validator now both reject a single-dump runtime that lacks
this non-enumerating collection return.

The full test matrix remains 931 assertions. For `mvs_2019-10-16`, three exact
note lookups are data-dependent skips, so the expected clean result is:

```text
SUMMARY: passed=928 failed=0 skipped=3
```

Windows 10 / Windows PowerShell 5.1 validation is now clean: the attached 0.9.2 run completed 928 passed, 0 failed, 3 data-dependent note skips.

## 0.9.1 parser bugfix

The first real Windows 0.9.0 executions exposed a Windows PowerShell 5.1 parser
error in the shared single-dump runtime. One raw-section TSV expression used a
comma-separated cast/function form that prevented the entire injected
single-dump script block from compiling.

0.9.1 rewrites that emitter with the established ArrayList pattern already
used successfully by the earlier relationship tools.

The attached result analysis established that the completed 0.9.0 run had:

```text
765 passed
166 failed
0 skipped
931 total
```

All 166 failures contained the same ScriptBlock.Create parser error.

The real `mvs_2019-10-16` dump also disproved an earlier semantic assumption:
IDs in `mvs_names.txt` are not guaranteed product IDs. Variant tools continue to expose
the source ID as `ID`, but documentation and summary metrics now label that
domain correctly and do not imply product ownership.


### Real-dump reference output

The independent reference parser was run against the archived
`mvs_2019-10-16` dump. Its corrected summary is checked into:

```text
doc\reference-output-mvs_2019-10-16-summary.txt
doc\reference-output-mvs_2019-10-16-summary.tsv
```

Important corrected values include:

```text
products.mvs.sections: 1791
variants.sections: 38136
variants.unique_ids: 38136
variants.ids_matching_product_ids: 203
variants.ids_not_in_product_ids: 37933
integrity.unparsed.mvs_names.txt: 0
integrity.unparsed.total: 0
```

These files are reference outputs from the independent Python parser. The
actual standalone Windows batch runtime still requires the external 0.9.2
Windows test run.


## 0.10.0 two-dump comparison layer

Version 0.10.0 begins cross-snapshot comparison while preserving the validated
0.9.2 single-dump baseline. It adds **19 standalone comparison tools**, bringing
the project to **441 public root `.bat` tools**.

Every comparison tool accepts two dump folders:

```text
compare_mvs_dump_<property>_from_<source>.bat first-dump-folder second-dump-folder
```

The first dump is the old/baseline side and the second dump is the new side.

Normal output contains only differences:

```text
- removed-value
+ added-value
```

All removals are printed first, preserving first-dump source order. All
additions follow, preserving second-dump source order. Values present in both
dumps are omitted. Duplicate occurrences inside one source are collapsed to
set membership.

When stdout is an interactive console, removed lines are red and added lines
are green. When stdout is redirected or captured, the same lines are emitted
as plain text with no ANSI/control bytes.

Comparison families in 0.10.0:

```text
ID:
  mvs.txt
  mvs_ids.txt
  mvs_names.txt
  mvs_dates.txt

TITLE:
  mvs.txt
  mvs_ids.txt
  mvs_names.txt
  mvs_dates.txt

DATE:
  mvs_dates.txt

SHA1:
  mvs.txt
  mvs_names.txt
  mvs.sha1

SHA256:
  mvs.txt
  mvs_names.txt
  mvs.sha256

FILENAME:
  mvs.txt
  mvs_names.txt
  mvs.sha1
  mvs.sha256
```

`mvs_names.txt` IDs remain a textual source-ID domain; they are not coerced to
product IDs. Product-source IDs are normalized numerically. Titles compare
case-insensitively after HTML decode/whitespace normalization. Filenames and
hashes compare case-insensitively; hashes are displayed lowercase. Dates
compare as trimmed source text.

No differences is a successful comparison: stdout is empty and return code is
`0`.

Comparison return codes are:

```text
0  successful comparison, whether or not differences exist
2  invalid/missing arguments or unsupported embedded configuration
3  one of the dump folders was not found
4  the required source file is missing from either dump
5  parse/runtime comparison failure
```

The dedicated synthetic comparison regression suite is:

```text
test\test_compare_tools.bat
```

It validates every comparison tool against an intentionally different
before/after pair and also validates every tool against an identical
before/before pair. The full suite remains:

```text
test\test_all.bat path_to_real_mvs_dump_folder
```

The 0.10.0 full test matrix contains **989 assertions** before data-dependent
lookup skips:

```text
Structure:       442
Scalar:          120
Lookup:           24
Diagnostic:       46
Relationship:    151
Single-dump:     167
Compare:          39
Total:           989
```

See `doc\compare-tools.md` and `doc\compare-tool-matrix.tsv` for the exact
tool list and comparison contract.


## 0.11.0 archive history / all-ever accumulation

Two standalone builders now turn an ordered directory of MVS dump snapshots
into durable source-local history:

```text
build_mvs_dump_change_history.bat mvs-dumps-root output-folder
build_mvs_dump_all_ever.bat       mvs-dumps-root output-folder
```

The first writes separate added/removed TSV ledgers for all 19 comparison
domains. The second writes an all-ever union for each domain with first-seen,
last-seen, and observation-count provenance.

Missing source files are recorded as coverage gaps rather than treated as empty
sets. See `doc\history-tools.md`.

Dedicated Windows regression entry point:

```text
test\test_history_tools.bat
```

The history-only suite contributes **65 assertions**. With the two new
standalone structure checks, the 0.11.0 full suite contains **1,056 total
assertions**; NOTE lookup pass/skip distribution remains data-dependent.

## 0.13.0 performance update

The public root remains 443 standalone tools. 377 generated public tools received performance-only internal changes without changing their interfaces or scopes.

The archive-wide sweep now defaults to a combined executor:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive
```

Use the literal public tools instead with:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive --external-tools
```

The combined path records `executor=fast-combined`; the literal path records `executor=external-public`. Executor identity is part of the deterministic plan hash and resume safety.

Additional performance utilities:

```text
test\fast\run_snapshot_tools_fast.bat
test\fast\run_compare_tools_fast.bat
test\analyze_archive_sweep_performance.bat
test\test_fast_archive_sweep.bat
```

See `doc\performance-architecture.md`.

## 0.13.2 fast-sweep acceptance-test maintenance

`test\test_fast_archive_sweep.bat` is self-contained and does **not** require
`test\test_all.bat` to be run first. It uses `test\test-mvs-dump-history\`
directly.

The acceptance test now validates UTF-8 metadata with PowerShell rather than
`findstr /x`. On any failure it retains and prints the temporary result folder,
`summary.txt`, `run-info.txt`, and captured sweep log so the failure can be
diagnosed immediately.

The 443 public root tools are unchanged from 0.13.1.
