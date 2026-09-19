# Filename and Hash Relationship Query Tools

## Purpose

Version 0.8.0 adds relationship queries that traverse:

```text
filename -> mvs.txt product owner -> ID / title / date / note

hash -> filename -> mvs.txt product owner -> ID / title / date / note
```

Hash-to-filename lookup indexes three sources:

```text
mvs.txt
mvs.sha1
mvs.sha256
```

`mvs.txt` is the canonical product-to-filename ownership source in this
relationship family. `mvs_names.txt` is not used as a product-title ownership
source because its headings are variant/display titles.

## Invocation

```text
print_mvs_dump_<projection>_from_filename.bat dump-folder "filename"
read_mvs_dump_<projection>_from_filename.bat dump-folder "filename"

print_mvs_dump_<projection>_from_hash.bat dump-folder hash
read_mvs_dump_<projection>_from_hash.bat dump-folder hash
```

Filename and hash searches are exact and case-insensitive.


## Hash as search key versus output field

The 0.8.0 request enumerates filename/hash **search-source** tools but does not
enumerate a `hash`/`hashes` output projection. Therefore this release indexes
hashes for reverse traversal but does not invent additional public
`*_hashes_from_filename` tool names.

## Result-row model

A result row represents one matched filename/product association.

A filename may belong to more than one `mvs.txt` product section. In that
case, product-bearing projections emit each associated product row.

A hash may map to more than one filename. Each matched filename is traversed
to all of its `mvs.txt` product owners.

If the same projected row is reached more than once, exact duplicate projected
rows are emitted only once.

The script names use plural `filenames`, but each emitted relationship row
contains one `Filename` value. The plural reflects that a query can return
multiple rows/filenames.

## Product metadata

ID and title come from the owning `mvs.txt` section header.

Date is joined by ID from `mvs_dates.txt` when available.

Note uses the established title-level `mvs_notes.html` policy: normalized title,
distinct non-empty note blocks joined with ` || `.

## Hash-source behavior

The hash index accepts 40-hex SHA-1 and 64-hex SHA-256 values from `mvs.txt`.

It also reads the flat `mvs.sha1` and `mvs.sha256` manifests when those files
exist. Missing SHA-256 manifests in older snapshots are therefore not fatal.

Hash/filename pairs duplicated across sources are deduplicated before product
traversal.

A filename discovered only in a flat hash manifest can still be returned by a
filename-bearing projection. If it has no `mvs.txt` owner, product scalar
fields are empty (`(none)` in `print_`, empty TSV fields in `read_`).

A projection containing only scalar product fields emits no row for a
manifest-only filename because there is no associated product scalar value.

## Output contracts

`print_` tools emit one human-readable line per distinct projected row:

```text
ID: 20 | Title: Beta Product | Filename: shared.iso
```

`read_` tools emit headerless TSV:

```text
20<TAB>Beta Product<TAB>shared.iso
```

Return codes:

```text
0  one or more projected rows emitted, or help
1  no associated projected result
2  invalid/missing argument or embedded configuration
3  dump folder not found
4  required mvs.txt missing
5  parse/runtime failure
```

## Projections

- `id` → ID
- `title` → TITLE
- `date` → DATE
- `note` → NOTE
- `filenames` → FILENAME
- `id_title` → ID, TITLE
- `id_date` → ID, DATE
- `id_title_date` → ID, TITLE, DATE
- `id_title_note` → ID, TITLE, NOTE
- `id_title_date_note` → ID, TITLE, DATE, NOTE
- `title_date` → TITLE, DATE
- `title_note` → TITLE, NOTE
- `title_date_note` → TITLE, DATE, NOTE
- `date_note` → DATE, NOTE
- `id_title_filenames` → ID, TITLE, FILENAME
- `id_date_filenames` → ID, DATE, FILENAME
- `id_title_date_filenames` → ID, TITLE, DATE, FILENAME
- `id_title_note_filenames` → ID, TITLE, NOTE, FILENAME
- `id_title_date_note_filenames` → ID, TITLE, DATE, NOTE, FILENAME
- `title_filenames` → TITLE, FILENAME
- `title_date_filenames` → TITLE, DATE, FILENAME
- `title_note_filenames` → TITLE, NOTE, FILENAME
- `title_date_note_filenames` → TITLE, DATE, NOTE, FILENAME
- `date_note_filenames` → DATE, NOTE, FILENAME


The user request included `title_from_filename` and `title_from_hash` twice in
the enumerated lists. Each duplicate name is generated once.

For every projection above, the toolkit generates all four forms:

```text
print ... from_filename
read  ... from_filename
print ... from_hash
read  ... from_hash
```

This yields 96 standalone public relationship tools.
