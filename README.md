# MVS Explorer Toolkit 0.2.0

MVS Explorer Toolkit is being developed as a collection of simple console tools that will eventually support a graphical application named **MVS Explorer**.

This milestone implements scalar product-list views for extracted MVS dump folders.

## Standalone-tool rule

Every `.bat` in the project root is **fully standalone**.

A tool does not call another toolkit `.bat`, `.ps1`, `.js`, library, or helper file at runtime. Each script contains all code required for its own operation, including:

- argument handling and help;
- dump-folder resolution;
- `mvs_ids.txt` parsing;
- `mvs_dates.txt` parsing;
- `mvs_notes.html` parsing and note normalization;
- human or machine output formatting;
- embedded PowerShell extraction/execution;
- error reporting and return-code handling.

The only runtime dependencies are Windows `cmd.exe`, `powershell.exe`, and the selected extracted MVS dump.

## Tool families

`print_mvs_dump_*.bat`
: Human-readable one-line-per-product output with labels.

`read_mvs_dump_*.bat`
: Machine-readable, headerless TSV with one line per product.

The project currently provides all 15 non-empty scalar projections of:

```text
ID
TITLE
DATE
NOTE
```

in both output modes, for 30 standalone tools total.

## Examples

```text
print_mvs_dump_id.bat mvs_2021-08-17
print_mvs_dump_id_title_date.bat mvs_2021-06-21-1830
read_mvs_dump_id_title.bat "D:\MVS\mvs_2021-08-17"
read_mvs_dump_title_note.bat mvs_2021-08-17 > titles-and-notes.tsv
```

Help:

```text
print_mvs_dump_id.bat --help
```

## Dump lookup

The dump argument may be an absolute/relative folder or a dump folder name.

Named folders are searched in:

1. the current directory;
2. `%MVS_DUMPS_ROOT%`, if defined;
3. the script directory;
4. `mvs_dumps_archive` below/adjacent to the script directory;
5. `mvs_dumps_archive` below the current directory.

## Scalar data model

Within the supplied archive, product ID is the reliable primary key for the scalar catalog records:

```text
ID -> one title in mvs_ids.txt
ID -> one release date in mvs_dates.txt
```

Titles are not unique across IDs.

Notes are not keyed by ID in `mvs_notes.html`; they are headed by title. This toolkit therefore treats notes as title-level information and documents the ambiguity when multiple IDs have the same title.

## Machine output

`read_` tools emit literal TAB-separated fields in the order named by the tool, with no header, color, banner, or status text on stdout.

Missing fields are empty. Embedded tab/CR/LF characters are normalized to spaces.

Errors go to stderr.

## Documentation

See `doc\` for:

- the supplied Batch File Style Guide v1.8.0;
- project-specific style-guide addendum;
- PowerShell style guide;
- development prompts;
- distilled development directives;
- developer diary;
- development observation journal;
- project version history;
- one version-history file per tool;
- scalar data-model and output-format notes.
