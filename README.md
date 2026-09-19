# MVS Explorer Toolkit 0.7.0

MVS Explorer Toolkit is a growing collection of console tools for exploring MVS dump snapshots, intended to culminate in the graphical **MVS Explorer** application.

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
