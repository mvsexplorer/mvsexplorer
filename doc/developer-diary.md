# Developer Diary

## 2026-08-27 — Archive reconnaissance

The source archive was reviewed as a time series of MVS catalog snapshots rather than a payload archive. The important source files for the first toolkit phase were identified as `mvs_ids.txt`, `mvs_dates.txt`, and `mvs_notes.html`, with `mvs_names.txt`, `mvs.sha1`, and `mvs.sha256` reserved for the later variant/file/hash layer.

The first structural model was deliberately kept simple: a dump contains products; a product is keyed by ID; scalar product data consists of ID, title, release date, and note; variants/files/hashes are child records.

## 2026-08-27 — Scalar projection design

The requested `print all` commands were normalized into projections of four scalar fields:

```text
ID
TITLE
DATE
NOTE
```

Four scalar fields have 15 non-empty combinations. The toolkit therefore implements the complete scalar set, not just the individually enumerated combinations. Each projection is exposed twice: `print_` for human output and `read_` for machine output.

The machine format was fixed as headerless TSV because it is simple to pipe, parse, redirect, compare, and later consume from a GUI or another helper.

## 2026-08-27 — Identity and note joining

Review of the archive showed that IDs are appropriate scalar keys inside a snapshot, while titles are not unique across IDs.

A more significant source limitation was found in `mvs_notes.html`: note headings identify titles, not product IDs. The implementation therefore cannot honestly claim an ID-native note relationship.

The adopted behavior is an explicit title-based convenience join. Distinct note blocks sharing the same normalized title are combined with ` || `. The limitation is recorded in the data model so later code does not silently harden an inference into a false source fact.

## 2026-08-27 — Initial shared-engine implementation

The first delivery used 30 thin batch front ends and one shared parser helper. This minimized duplication and made maintenance attractive, but it conflicted with the project's desired deployment model once the standalone requirement was stated.

## 2026-08-27 — Standalone rewrite

The user established a stronger project rule: every file must be fully standalone and contain the code necessary for its inner function.

Version 0.2.0 therefore duplicates the complete parser/PowerShell bridge inside each of the 30 tools. This is intentional duplication. In this project, single-file portability and independent copying/deployment take precedence over deduplicating runtime code.

Documentation was expanded at the same milestone so future changes preserve both implementation history and the reasoning behind it.
