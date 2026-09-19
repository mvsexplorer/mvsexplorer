# MVS Explorer Toolkit — Embedded PowerShell Style Guide

**Guide version:** 0.8.1  
**Context:** Companion to Batch File Style Guide v1.8.0 and the MVS Explorer Toolkit addendum.

## 1. Role

Batch remains the public executable format. Embedded PowerShell is appropriate for Unicode/text parsing, HTML normalization, dictionaries/joins, sorting, wildcard matching, and parser-sensitive content that would be fragile through repeated `cmd.exe` parsing.

## 2. Development injection

PowerShell can be maintained centrally under `dev\library` and injected into every generated public `.bat`.

The generated `.bat` must contain the embedded block and must not read the include at runtime.

## 3. Invocation

Use:

```text
powershell.exe -NoLogo -NoProfile -NonInteractive -Command ...
```

Avoid temporary `.ps1` files for ordinary work and do not add `-ExecutionPolicy Bypass` to normal embedded `-Command` calls.

## 4. Source/data separation

Never construct executable PowerShell source from arbitrary dump data or lookup search text.

Transport controlled settings through environment variables and treat MVS/search content purely as data.

## 5. Streams

Set `$ErrorActionPreference = 'Stop'`.

Normal records go to stdout. Errors and diagnostics go to stderr.

Do not contaminate `read_` or `lookup_` stdout with presentation text.

## 6. Text

Set console output encoding explicitly for Unicode output.

Where one physical line is the protocol, normalize embedded TAB/CR/LF appropriately.

Preserve source date strings for output; sorting does not justify silently reformatting them.

## 7. Sorting

Centralize product sorting.

ID:
: integer/numeric ascending.

TITLE:
: case-insensitive natural key. Numeric runs are normalized in the internal key so version-like numbers sort naturally. ID breaks ties.

DATE:
: parse using invariant culture and an explicit assumption for zone-less values; sort by UTC ticks when parseable. Preserve original source date text for output. Use source date text and ID as deterministic tie-breaks.

Apply sorting before output projection so hidden fields may be sort keys.

## 8. Lookup wildcard

Public wildcard semantics consist only of `*`.

Implementation should regex-escape the complete user pattern, replace escaped `*` with `.*`, anchor the expression to the entire field, and use case-insensitive matching.

This prevents characters such as `[` from acquiring undocumented PowerShell wildcard semantics.

## 9. Lookup multiplicity

Filter complete product records by the source field, sort matching records by that source field, project the target field, omit empty targets, and emit exact distinct target values in first-sorted occurrence order.

## 10. Source truth

Use ID joins when IDs exist in both sources.

Treat notes as title-level convenience data unless a source providing an ID-native note relation is identified.

## 11. Compatibility

Write for Windows PowerShell launched by `powershell.exe`, not just PowerShell 7/`pwsh`.

## 12. Performance

One PowerShell startup per tool invocation is acceptable.

Do not spawn PowerShell once per product/field.

Read source files once per invocation where practical.

## 13. Testing focus

Sort tests:

- `2`, `10`, `28`, `200`;
- titles with embedded numbers;
- equal titles/dates;
- timezone-bearing dates;
- unparseable dates.

Lookup tests:

- exact;
- `2*`;
- `*28`;
- `*2*`;
- quoted values containing spaces;
- characters meaningful to regex/PowerShell wildcards but literal in this interface;
- multiple matches;
- duplicate target values;
- no match;
- matching product with missing note.


## 14. Automated test harness PowerShell

The Windows test harness may use `System.Diagnostics.Process` to execute public batch tools and capture stdout/stderr concurrently.

To avoid `cmd.exe` quoting problems with dump/search values, pass dynamic values through child-process environment variables and keep the child command line structurally fixed.

Read redirected stdout/stderr asynchronously before/while waiting for process completion to avoid pipe-buffer deadlocks on large outputs.

Normalize captured line endings only for comparison; do not otherwise alter expected protocol text.

Test expected-value logic uses test-specific helper names and derives expectations from dump source files, reducing accidental dependence on another public toolkit command.


## 15. Nonzero return codes through the embedded bridge

A local `exit N` in a dynamically executed embedded script block can be normalized by the outer bridge.

For a documented nonzero public contract that must reach the calling batch:

```powershell
[Environment]::Exit(N)
```

Emit any intended stderr before that call.

A normal lookup no-result exit code `1` emits no stdout/stderr.

## 16. Test result files

The test harness writes result files as UTF-8 without BOM.

Maintain separate files for:

- run metadata;
- complete console transcript;
- final summary;
- all assertion rows;
- scope-specific assertion rows;
- complete behavioral failure artifacts.

Failure artifact streams are lossless; only the console comparison preview is abbreviated.


## 17. End-to-end return-code testing

A PowerShell block setting a local/nonzero exit is not sufficient evidence that the calling batch receives that code.

For every documented nonzero PowerShell-backed contract, test all boundaries:

```text
embedded block
-> powershell.exe process
-> batch bridge function
-> top-level batch
-> caller cmd.exe
```

The lookup no-match test is the current canonical regression test.


## 18. Diagnostic record parsing

Diagnostic parsing should preserve both normalized comparison fields and raw
source context.

For `mvs.txt`/`mvs_names.txt`, parse a section as:

```text
header
associated nonblank lines
```

ending on a blank line or the next section header.

Filename occurrences inside those sections remain attached to their owning
record so output can include product/variant ID/title context.

## 19. Diagnostic set operations

Duplicate detection groups source occurrences by a normalized property key
while retaining source order for deterministic output.

Orphan detection builds a target-key set and walks source occurrences in
source order. It is directional and should not silently symmetrize the check.

Do not infer semantic equivalence between product titles and variant/display
titles merely because both are represented by a `title` property in a
diagnostic tool name.

## 20. Regression oracle independence

The synthetic diagnostic test expected outputs are generated by a separate
Python reference parser. Do not produce expected output by calling the public
diagnostic tool under test.


## 21. Relationship edge indexes

Represent observed relationships independently:

```text
filename -> owning mvs.txt section(s)
hash -> filename(s)
```

Do not create an inferred SHA-1/SHA-256 pair from a shared filename.

A hash index may combine observations from:

```text
mvs.txt
mvs.sha1
mvs.sha256
```

while deduplicating the same observed hash/filename pair.

## 22. Optional hash manifests

`mvs.txt` is required for product ownership.

`mvs.sha1` and `mvs.sha256` are supplementary hash indexes and may be absent.
In particular, older dumps may lack `mvs.sha256`; absence is not itself a
relationship-query runtime failure.

## 23. Relationship row projection

Traverse first, project second.

This order is important because a filename may own multiple product sections
and a hash may map to multiple filenames.

After projection, exact duplicate projected rows can be suppressed while
genuinely distinct rows remain.

## 24. Exact filename/hash matching

Relationship filename/hash inputs are exact case-insensitive values.

Do not use PowerShell wildcard operators for this family. This prevents
characters such as `[` and `]` in filenames from acquiring unintended query
semantics.

## 25. Windows PowerShell compatibility

Keep relationship code compatible with Windows PowerShell 5.1 and .NET
Framework-era APIs, matching the externally tested project baseline.


## 26. Preserve source occurrence identity

Variant sections and raw note records require occurrence counters. Hash records
require source and physical line.

These identities should remain available even when a simpler projected query
deduplicates identical display values.

## 27. Parse-loss visibility

For line-oriented sources, retain every nonblank line that is neither a valid
record nor a valid structural header in an unparsed-line collection.

Do not silently discard parse failures.

## 28. Forward product/hash traversal

When a product ID/title selects filenames through `mvs.txt`, keep the selected
product owner fixed while gathering all observed hash records by filename.
Do not accidentally replace the selected owner with every other product that
may reuse the same filename.

## 29. Summary implementation

Summary metrics should be derived from the same parsed model used by the
first-class entity tools, not from re-parsing ad hoc with conflicting rules.

Optional files such as `mvs.sha256` contribute zero/presence metrics when
missing rather than making a whole-dump summary fail.


## 30. Parser-safe array construction

For embedded Windows PowerShell 5.1 code, avoid comma-separated array
expressions that mix unparenthesized casts, property access, and command-style
function invocation, for example:

```text
@(
    [string]$object.id,
    Normalize-Scalar ([string]$object.title),
    ...
)
```

The 0.9.0 Windows test run proved that this form can fail during
`[ScriptBlock]::Create()` before any tool logic runs.

Prefer the already proven pattern:

```text
$values = New-ArrayList
[void]$values.Add([string]$object.id)
[void]$values.Add((Normalize-Scalar ([string]$object.title)))
Write-Line (($values | ForEach-Object { [string]$_ }) -join [char]9)
```

A static release validator must reject the known unsafe single-dump section
emitter form.


## 31. Source-specific ID parsing

Do not share the numeric product-ID header regex with `mvs_names.txt`.

Use numeric ID parsing for:

```text
mvs_ids.txt
mvs_dates.txt
mvs.txt
```

Preserve the trimmed text between `[ID:` and `]` for:

```text
mvs_names.txt
```

Variant-source ID matching is case-insensitive textual equality.

## 32. Returning mutable collections from helper functions

PowerShell enumerates normal function output. A newly constructed empty
collection therefore must not be returned bare when callers expect the
collection object itself.

Unsafe for an empty `ArrayList`:

```text
function New-ArrayList {
    return (New-Object System.Collections.ArrayList)
}
```

Required pattern:

```text
function New-ArrayList {
    return ,(New-Object System.Collections.ArrayList)
}
```

The unary comma suppresses enumeration of the returned collection. Generated
single-dump tools must be statically checked for this requirement.



## 33. Console-aware comparison color

For comparison tools, color the complete removal/addition line only when
`[Console]::IsOutputRedirected` is false.

Use `System.Console.ForegroundColor` and restore the previous color in a
`finally` block. When output is redirected, write the exact same `- value` or
`+ value` text without escape/control bytes.

This keeps interactive readability separate from the machine-visible output
contract.
