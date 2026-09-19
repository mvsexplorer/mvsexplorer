# MVS Explorer Toolkit — Batch Style Guide Addendum

**Addendum version:** 0.8.1  
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


## 16. Direct external-process return propagation

For MVS Explorer Toolkit's embedded PowerShell runner, the direct return path is now preferred:

```bat
powershell.exe ...
set "rps_rc=%errorlevel%"
exit /b %rps_rc%
```

The `set` and `exit /b` remain on separate physical lines so `%rps_rc%` is expanded after capture.

This is a project-specific clarification based on Windows test evidence. It replaces routing nonzero child-process exit codes through the function's `_fn_rc` re-entry carrier when no cleanup is required.

## 17. Top-level nonzero return

The ordinary scaffold still ends through `GoTo :EOF` for success.

When `app.rc` is nonzero, the top-level `:end` path explicitly returns it before that normal success exit:

```bat
:end
endlocal & call :SetErrorLevel %app.rc%
if not "%errorlevel%"=="0" exit /b %errorlevel%
GoTo :EOF
```

This makes the externally observed process/batch contract explicit.


## 18. Diagnostic finder contract

`find_mvs_*` tools are reporting filters.

A successful scan returns `0` whether it finds zero, one, or many findings.
Findings are stdout data, not error conditions. Missing/invalid input remains
a nonzero error written to stderr.

For section-oriented sources (`mvs.txt`, `mvs_names.txt`), preserve source
context instead of flattening a duplicate/orphan ID/title into only its key.

## 19. Diagnostic comparison normalization

Use the minimum normalization necessary for stable comparison:

```text
ID        numeric identity
TITLE     HTML decode where relevant, collapse whitespace, case-insensitive key
DATE      trim only
FILENAME  trim, case-insensitive key
```

Preserve original/display values in emitted findings.

## 20. Generated diagnostic matrix

The public diagnostic matrix is maintained in
`dev\diagnostic-tool-spec.json` and generated through
`dev\generate_diagnostic_tools.py`.

As with scalar/lookup generation, the specification/library/template may be
shared during development but every resulting root `.bat` contains its full
runtime implementation.


## 21. Relationship-query naming

Relationship-query public files use:

```text
print_mvs_dump_<projection>_from_filename.bat
read_mvs_dump_<projection>_from_filename.bat
print_mvs_dump_<projection>_from_hash.bat
read_mvs_dump_<projection>_from_hash.bat
```

Arguments:

```text
tool.bat dump-folder search-value
```

The second argument is data and is transported through an environment
variable to embedded PowerShell. It is not concatenated into executable
PowerShell source.

## 22. Relationship search semantics

Filename and hash relationship searches are exact and case-insensitive.

This family intentionally does not inherit the `lookup_` family's `*`
wildcard language unless a later requirement explicitly adds it.

## 23. Relationship output

`print_` is human-readable one-line-per-projected-row output.

`read_` is headerless TSV, with no banner, labels, ANSI, or status text.

A no-result relationship returns `1` with no stdout, matching the established
query no-result convention.

## 24. Relationship development injection

The relationship matrix is maintained in
`dev\relationship-tool-spec.json`.

Shared development source lives under `dev\library`/`dev\templates`, but each
generated relationship `.bat` contains its complete batch and PowerShell
runtime implementation.


## 25. Single-dump entity families

Use first-class public families for semantically distinct source entities:

```text
product scalar
product file edge
variant occurrence
hash provenance record
note occurrence
unparsed source line
summary/statistic
```

Do not flatten occurrence/provenance identity merely to reuse a scalar
projection contract.

## 26. Forward detail traversal

For product ID/title forward queries:

```text
mvs.txt product owner
-> filename
-> all observed hash records for that filename
```

Observed hash records may come from `mvs.txt`, `mvs_names.txt`, `mvs.sha1`, or
`mvs.sha256`.

## 27. Raw section presentation

Human product-section output preserves the original section lines.

Machine product-section output emits:

```text
section_occurrence<TAB>id<TAB>title<TAB>line_offset<TAB>physical_line<TAB>raw_line
```

## 28. Unparsed-line reporting

Human finder:

```text
Line N: raw source text
```

Machine reader:

```text
N<TAB>raw source text
```

Successful scans return `0` even when findings are present.

## 29. Summary/statistics output

Human:

```text
key: value
```

Machine:

```text
key<TAB>value
```

Keys are stable machine-facing identifiers; presentation labels are not
localized.


## 30. Windows PowerShell parser compatibility

Embedded PowerShell must target the Windows PowerShell 5.1 parser used by the
supported `powershell.exe` path.

When building multi-field machine-output rows, prefer the established
ArrayList-plus-join emitter over parser-sensitive comma-separated cast/function
array literals.

Static generation checks should encode any concrete parser regression exposed
by an external Windows test run.

## 31. PowerShell collection factory returns

When an embedded PowerShell helper constructs an empty mutable collection and
the caller will invoke methods on it, the helper must return the collection as
one object rather than allow pipeline enumeration to collapse it to no output.

For the shared single-dump runtime, `New-ArrayList` uses unary comma on return.
Release validation must reject generated single-dump tools that omit this
behavior.

