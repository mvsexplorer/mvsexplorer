# MVS Explorer Toolkit 0.1.0

This first toolkit milestone provides scalar product-list views for an extracted MVS dump.

## What is included

Each scalar view has two front ends:

- `print_mvs_dump_*.bat` - human-readable output with field labels.
- `read_mvs_dump_*.bat` - machine-oriented TSV output with no header or decoration.

All front ends call `tools\MVS_Query.bat`, which contains the shared parser and an embedded PowerShell helper. No temporary `.ps1` file is created.

The requested views are included, plus `id_date_note`, which is the one omitted non-empty combination of the four scalar product fields (`id`, `title`, `date`, `note`).

## Usage

```text
print_mvs_dump_id mvs_2021-08-17
print_mvs_dump_id_title mvs_2021-06-21-1830
read_mvs_dump_id_title_date "D:\MVS\mvs_2021-08-17"
```

Help:

```text
print_mvs_dump_id --help
```

A dump argument can be an existing absolute/relative folder path or a folder name. Named folders are searched in:

1. the current directory;
2. `%MVS_DUMPS_ROOT%` if defined;
3. the toolkit directory;
4. common `mvs_dumps_archive` locations in/adjacent to the toolkit and current directory.

A usable dump folder must contain `mvs_ids.txt` and `mvs_dates.txt`. `mvs_notes.html` is optional for parsing but is needed for note values.

## Human-readable output

Example:

```text
ID: 748 | Title: Windows 7 Ultimate | Date: 2009-08-06T09:59:56
```

Missing scalar values are shown as `(none)`. Output remains one physical line per product.

## Machine-readable output

`read_` commands emit one physical line per product, no header, with fields separated by a literal TAB in the order named by the script.

Example:

```text
748<TAB>Windows 7 Ultimate<TAB>2009-08-06T09:59:56
```

`<TAB>` above is illustrative; the real output contains a tab character. Embedded tabs/newlines in values are normalized to spaces. Missing values are empty fields. No ANSI color or banner text is emitted. Errors are written to stderr.

## Data model used by this milestone

Within every one of the 79 supplied snapshots, `mvs_ids.txt` has unique IDs and each ID has exactly one matching `mvs_dates.txt` entry. An ID therefore has one catalog title record and one release-date record in a given snapshot.

Titles are **not** unique keys. Different IDs can have the same title.

`mvs_notes.html` does not contain product IDs. Its `<h1>` note sections are keyed by title, and some titles/sections repeat. This version therefore uses a deterministic title-based note join:

1. HTML-decode and normalize whitespace in the product title and note heading.
2. Collect all non-empty note blocks having that exact normalized title.
3. De-duplicate identical normalized note blocks.
4. Join multiple distinct blocks with ` || `.
5. Use that combined title-level note for every product ID having that title.

This preserves the note information available in the dump without pretending that the HTML provides an ID-specific mapping. For duplicate-title IDs, the original source is intrinsically ambiguous.

## Output order

Products are emitted in the order in `mvs_ids.txt`. Dates are joined by ID. Notes are joined by normalized title as described above.

## Dependencies

- Windows `cmd.exe`
- Windows PowerShell available as `powershell.exe`
- Extracted MVS dump folders; the ZIP archive itself is not read directly in this milestone

The PowerShell is embedded in the shared `.bat` helper and is invoked through `-Command`, avoiding execution-policy issues associated with temporary/external `.ps1` scripts.

## Return codes

- `0` success/help
- `2` invalid arguments or unsupported mode/field
- `3` dump folder not found
- `4` required dump file missing
- `5` no product records parsed
- other nonzero values may come from the PowerShell host/helper

Machine-mode errors use:

```text
MVS_QUERY_ERROR<TAB>code<TAB>message
```

on stderr.

## Scope

This version intentionally implements only the scalar product fields:

```text
ID
TITLE
DATE
NOTE
```

Variants, filenames, SHA-1, SHA-256, `.cat`, and `.txt` relationships are the next data-model layer and are not implemented by these wrappers yet.

## Style

The batch files follow the supplied Batch File Style Guide v1.8.0: ordinary scripts use the `:setup` / `:main` / `:end` scaffold, reusable functions are documented/versioned, no trailing-caret continuations are used, and substantial text parsing is delegated to embedded PowerShell rather than made fragile in pure batch.

The shared helper uses a scoped `setlocal DisableDelayedExpansion` because it is called by many wrappers and must not leak its internal environment into the caller. The scope is unwound in `:end`.

The print/read utilities intentionally do not pause on exit: they are console filters designed for piping and redirection.
