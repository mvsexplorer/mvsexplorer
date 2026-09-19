# Single-Dump Completeness Layer

## Scope

The 0.9.2 single-dump layer makes each source-level entity inside one extracted dump
queryable before cross-dump comparison begins.

### Product

```text
ID
Title
Date
Note
```

Existing scalar and lookup families remain unchanged.

### Product file edge (`mvs.txt`)

```text
Product ID
Product title
Date
Note
Filename
Hash
Algorithm
```

Forward queries are available from product ID/title. Filename/hash queries can
also show the owning product context.

### Variant occurrence (`mvs_names.txt`)

A variant is identified by **source section occurrence**, not by
`variant-title + ID`, because those pairs can repeat.

Fields:

```text
Occurrence
mvs_names source ID
Variant/display title
Filename
Hash
Algorithm
```

Empty variant sections remain visible in full variant enumeration.

The `ID` in this variant family means the ID printed by `mvs_names.txt`.
It is **not automatically** treated as a product ID or product foreign key.
Some dump generations show near/complete overlap with product IDs; others do
not. Product ownership must therefore be derived or validated from
source-supported relationships and may be ambiguous when a file/hash pair is
reused.

### Hash provenance record

Observed records are kept independently from:

```text
mvs.txt
mvs_names.txt
mvs.sha1
mvs.sha256
```

Fields:

```text
Source
Physical line
Source ID (when the source supplies one)
Product title (mvs.txt)
Variant title (mvs_names.txt)
Filename
Hash
Algorithm
```

No SHA-1/SHA-256 pair is inferred merely because filenames match.

### Note occurrence

Raw note occurrence presentation preserves:

```text
Occurrence
Title heading
Note body
```

This is separate from the established product convenience policy that combines
distinct note blocks for a normalized title.

### Unparsed lines

The following sources have both human finder and machine-reader forms:

```text
mvs.txt
mvs_names.txt
mvs.sha1
mvs.sha256
mvs_ids.txt
mvs_dates.txt
```

Machine output is:

```text
line_number<TAB>raw_line
```

### Summary/statistics

`print_mvs_dump_summary.bat` and `print_mvs_dump_statistics.bat` emit
`key: value`.

The `read_` counterparts emit:

```text
key<TAB>value
```

Metrics cover source presence, products, product files, variants, notes, flat
hash manifests, combined provenance records, duplicate/reuse indicators,
directional orphan filename counts, and unparsed-line counts.

## Search semantics

ID/title/filename/hash selectors in this new family are exact.

Product IDs from `mvs.txt` are compared numerically. Variant IDs from
`mvs_names.txt` are preserved as source text and compared case-insensitively,
because real dumps contain both numeric and alphanumeric/hyphenated IDs.
Titles, filenames, and hashes compare case-insensitively.

No wildcard syntax is introduced into this family.

## Return codes

```text
0  successful output / successful diagnostic scan / summary / help
1  query produced no associated projected result
2  invalid/missing argument/configuration
3  dump folder not found
4  operation-required source file missing
5  parse/runtime failure
```

Diagnostic/unparsed scans return `0` whether findings exist or not; findings
are data, not process failures.
