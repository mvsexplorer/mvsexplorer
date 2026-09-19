# MVS Explorer Toolkit — Batch Style Guide Addendum

**Addendum version:** 0.2.0  
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
