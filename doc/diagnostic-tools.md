# Duplicate and Orphan Diagnostic Tools

> **0.19.0 layout:** Public utility BATs referenced in this document are delivered under `tools\`. Run them as `tools\<tool>.bat` from the project root, or change into `tools\` first. Their established arguments/output semantics are unchanged.


## Purpose

These tools inspect relationships inside one extracted MVS dump folder.

They are reporting tools. A reported duplicate/orphan is not automatically
proof of corrupt data; interpretation depends on the source file's model.

Usage:

```text
<tool>.bat dump-folder
```

Help aliases:

```text
--help  -h  -?  /h  /?
```

Return codes:

```text
0  successful scan, whether findings exist or not
2  invalid embedded tool configuration
3  dump folder not found
4  required source/target file missing
5  parse/runtime diagnostic failure
```

No finding produces no stdout.

## Duplicate semantics

A duplicate finder groups occurrences of one property inside one source.

Normalization:

```text
ID        numeric identity
TITLE     HTML-decoded/collapsed whitespace, case-insensitive key
DATE      trimmed source date string
FILENAME  trimmed, case-insensitive key
```

For `mvs.txt` and `mvs_names.txt`, ID/title duplicate occurrences print the
entire section from its `--- title [ID: N] ---` header through associated
nonblank lines.

Filename duplicate occurrences print the owning ID/title and exact matched
checksum/filename line.

For notes, title findings print normalized title and note text. Notes normally
carry no ID; the requested notes-ID finder only recognizes literal `[ID: N]`
markers when present.

### Duplicate tools

- `find_mvs_duplicate_id_in_mvs.txt.bat`
- `find_mvs_duplicate_id_in_mvs_dates.txt.bat`
- `find_mvs_duplicate_id_in_mvs_ids.txt.bat`
- `find_mvs_duplicate_id_in_mvs_names.txt.bat`
- `find_mvs_duplicate_id_in_mvs_notes.html.bat`
- `find_mvs_duplicate_title_in_mvs.txt.bat`
- `find_mvs_duplicate_title_in_mvs_dates.txt.bat`
- `find_mvs_duplicate_title_in_mvs_ids.txt.bat`
- `find_mvs_duplicate_title_in_mvs_names.txt.bat`
- `find_mvs_duplicate_title_in_mvs_notes.html.bat`
- `find_mvs_duplicate_date_in_mvs_date.txt.bat`
- `find_mvs_duplicate_date_in_mvs_dates.txt.bat`
- `find_mvs_duplicate_filename_in_mvs_names.txt.bat`
- `find_mvs_duplicate_filename_in_mvs.txt.bat`

`find_mvs_duplicate_date_in_mvs_date.txt.bat` is the exact requested spelling
but reads `mvs_dates.txt`. `find_mvs_duplicate_date_in_mvs_dates.txt.bat` is
the canonical alias.

## Orphan semantics

An orphan finder asks:

```text
For each PROPERTY occurrence in SOURCE:
    does TARGET contain the same normalized PROPERTY value?
    if not, report that SOURCE occurrence.
```

The comparison is directional. `A -> B` and `B -> A` answer different
questions.

For ID/title section sources, the source context is the complete section.
For filename section sources, context contains owner ID/title and the exact
filename line.

### Orphan tools

- `find_mvs_orphan_id_from_mvs_ids.txt_in_mvs.txt.bat`
- `find_mvs_orphan_id_from_mvs_ids.txt_in_mvs_dates.txt.bat`
- `find_mvs_orphan_id_from_mvs_ids.txt_in_mvs_names.txt.bat`
- `find_mvs_orphan_title_from_mvs_ids.txt_in_mvs.txt.bat`
- `find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_dates.txt.bat`
- `find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_names.txt.bat`
- `find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_notes.html.bat`
- `find_mvs_orphan_id_from_mvs_dates.txt_in_mvs.txt.bat`
- `find_mvs_orphan_id_from_mvs_dates.txt_in_mvs_ids.txt.bat`
- `find_mvs_orphan_id_from_mvs_dates.txt_in_mvs_names.txt.bat`
- `find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs.txt.bat`
- `find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs_ids.txt.bat`
- `find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs_names.txt.bat`
- `find_mvs_orphan_id_from_mvs.txt_in_mvs_ids.txt.bat`
- `find_mvs_orphan_id_from_mvs.txt_in_mvs_dates.txt.bat`
- `find_mvs_orphan_id_from_mvs.txt_in_mvs_names.txt.bat`
- `find_mvs_orphan_titles_from_mvs.txt_in_mvs_ids.txt.bat`
- `find_mvs_orphan_titles_from_mvs.txt_in_mvs_dates.txt.bat`
- `find_mvs_orphan_titles_from_mvs.txt_in_mvs_names.txt.bat`
- `find_mvs_orphan_id_from_mvs_names.txt_in_mvs.txt.bat`
- `find_mvs_orphan_id_from_mvs_names.txt_in_mvs_ids.txt.bat`
- `find_mvs_orphan_id_from_mvs_names.txt_in_mvs_dates.txt.bat`
- `find_mvs_orphan_titles_from_mvs_names.txt_in_mvs.txt.bat`
- `find_mvs_orphan_titles_from_mvs_names.txt_in_mvs_ids.txt.bat`
- `find_mvs_orphan_titles_from_mvs_names.txt_in_mvs_dates.txt.bat`
- `find_mvs_orphan_filenames_from_mvs.txt_in_mvs_names.txt.bat`
- `find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.txt.bat`
- `find_mvs_orphan_filenames_from_mvs.txt_in_mvs.sha1.bat`
- `find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.sha1.bat`
- `find_mvs_orphan_filenames_from_mvs.txt_in_mvs.sha256.bat`
- `find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.sha256.bat`

## Source-model cautions

### `mvs_names.txt` repeated IDs

`mvs_names.txt` is a variant/download-name layer. Multiple variant sections
normally reference the same product ID. Therefore repeated ID in this file is
expected one-to-many data, not necessarily an anomaly.

The duplicate finder is still useful for answering the literal question and
for comparing repetition patterns across snapshots.

### `mvs_names.txt` title domain

A `mvs_names.txt` heading is a variant/display title. It is not generally the
same string as the product title in `mvs_ids.txt`.

Therefore title-orphan comparisons between `mvs_names.txt` and product-level
sources are literal string-set diagnostics, not proof that a product
relationship is missing.

### `mvs_notes.html`

Known archive note headings identify titles, not product IDs. The notes-ID
duplicate tool exists because it was explicitly requested and because future
or synthetic input may contain literal ID markers.

### Flat SHA manifests

`mvs.sha1` and `mvs.sha256` are used here only as filename sets. An orphan
filename means the source filename was not found in that flat manifest. It does
not by itself prove the referenced media is invalid.

## Output examples

Duplicate section:

```text
Duplicate ID: 401
Occurrence 1:
  --- TXT Duplicate ID A [ID: 401] ---
  4444444444444444444444444444444444444444 *txt-dup-id-a.iso
  4444444444444444444444444444444444444445 *txt-dup-id-a-extra.iso
Occurrence 2:
  --- TXT Duplicate ID B [ID: 401] ---
  5555555555555555555555555555555555555555 *txt-dup-id-b.iso
```

Filename duplicate:

```text
Duplicate Filename: txt-duplicate-filename.iso
Occurrence 1:
  ID: 404
  Title: TXT Filename Owner A
  8888888888888888888888888888888888888888 *txt-duplicate-filename.iso
```

Orphan:

```text
Orphan ID: 101
Source: mvs_ids.txt
Target: mvs_dates.txt
  IDs Only [ID: 101]
```
