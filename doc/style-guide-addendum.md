# MVS Explorer Toolkit — Batch Style Guide Addendum

**Addendum version:** 0.4.0  
**Applies with:** Batch File Style Guide v1.8.0

This addendum supplements the supplied guide with project-specific conventions.

## 1. Standalone public tools

Each public root `.bat` must perform its core function if copied by itself, assuming Windows `cmd.exe`, `powershell.exe`, and the selected MVS dump are available.

## 2. Shared development source is allowed

The standalone rule does not prohibit common source during development.

Preferred model:

```text
common source -> generation/injection -> standalone public .bat
```

The generator and includes live under `dev\` and are not runtime dependencies.

## 3. Generated files contain implementation

A generated public `.bat` must contain the batch functions and embedded PowerShell it actually uses. Do not generate a wrapper that calls the development library.

## 4. Source-order and sorted interfaces remain distinct

Unsuffixed scalar tools preserve `mvs_ids.txt` source order.

Sorted companions are explicit:

```text
_sorted_by_id
_sorted_by_title
_sorted_by_date
```

Do not silently sort the unsuffixed tools.

## 5. Sort semantics

ID: numeric ascending.

TITLE: case-insensitive natural/alphanumeric ascending; numeric ID tie-break.

DATE: chronological ascending where parseable; source date text then numeric ID tie-break.

No note sort is currently generated.

## 6. Lookup naming and arguments

```text
lookup_mvs_<target>_from_<source>.bat dump-folder search-value
```

## 7. Lookup wildcard

Only `*` is special. It matches zero or more characters anywhere.

Matching is case-insensitive. Every other search character is literal.

This intentionally avoids exposing PowerShell's larger wildcard language by accident.

## 8. Lookup output

Lookup tools emit distinct non-empty associated target values, one per line, with no label/header.

No associated value returns `1` with no stdout.

## 9. Generated-code synchronization

A common source change must be regenerated into every affected public file and validated before release.

Material regenerated implementation changes increment affected tool versions according to the main guide.

## 10. Console-filter behavior

These tools do not auto-pause. Piping/redirection are primary use cases.

## 11. Development records

Milestones update the project history, affected tool histories, prompt/directive records, developer diary, observation journal, and applicable style guides.


## 12. Test scripts

Automated test `.bat` files follow the same standalone-delivery rule as public tools.

A test may share maintained development source, but its generated `.bat` contains its complete test harness.

`test_all.bat` is deliberately self-contained rather than merely calling the subset test files. This ensures the documented root command remains usable even if copied with only the public tools and itself.

## 13. Behavioral test expectations

Tests should verify actual stdout, stderr, and return codes rather than only file existence.

When practical, expected results are reconstructed directly from the selected dump in a test-specific parser instead of being obtained by calling another toolkit public tool.

The suite should fail closed: any assertion failure yields a nonzero final return code.


## 14. Test result bundles

Every generated test script owns one result directory per invocation.

Use the locale-independent sortable name:

```text
test-results-YYYYMMDD-HHMMSS
```

with a numeric collision suffix if needed.

All result files from that invocation stay beneath the same directory. Machine-readable TSV result files contain no ANSI.

Behavioral failure artifacts preserve complete streams; console text may be abbreviated only for readability.

## 15. Embedded PowerShell nonzero contract exits

The current `:RunPowerShellFromLabel` bridge can normalize a script-block-local nonzero `exit` after control returns to the wrapper.

When a documented nonzero code must reach `cmd.exe` without adding unwanted stderr, terminate the embedded PowerShell process explicitly:

```powershell
[Environment]::Exit(code)
```

This is a focused exception used for public contract exits such as lookup no-match (`1`) and documented fatal validation codes.
