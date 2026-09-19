# MVS Explorer Toolkit Scalar Data Model

## Product record

```text
Product
  id      product ID
  title   title from mvs_ids.txt
  date    release date from mvs_dates.txt, joined by ID
  note    title-level convenience join from mvs_notes.html
```

ID is treated as the reliable scalar key where the source provides it. Titles are not unique across product IDs.

## Notes

`mvs_notes.html` headings do not provide product IDs, so notes cannot be joined as an ID-native source field.

Current policy:

1. normalize title/note heading;
2. exact-match normalized title;
3. normalize note HTML to one-line text;
4. de-duplicate identical note blocks;
5. join distinct note blocks with ` || `;
6. expose that title-level convenience value to matching products.

## Sorting

Sorting is applied to complete product records before output projection.

This permits views such as:

```text
print_mvs_dump_note_sorted_by_title.bat
```

where TITLE controls order without being printed.

## Lookup relationships

Version 0.3.0 exposes:

```text
ID    -> TITLE
DATE  -> TITLE
ID    -> NOTE
TITLE -> NOTE
DATE  -> NOTE
ID    -> DATE
TITLE -> DATE
```

Lookup results are projected target values rather than full product records.

## Variant layer

Variant/file/hash relationships remain a later phase.


## Diagnostic comparison domains

The diagnostic layer deliberately separates **mechanical equality** from
**semantic interpretation**.

### Product-level ID/title sources

```text
mvs_ids.txt
mvs_dates.txt
mvs.txt
```

These sources use product-level IDs/titles.

### Variant-level source

```text
mvs_names.txt
```

Its ID references the owning product, so repeated IDs are normally expected.
Its heading/title is a variant/display title and is not generally equal to the
product title.

### Notes source

```text
mvs_notes.html
```

Known note headings are title-based and normally do not carry IDs.

### Flat filename/hash sources

```text
mvs.sha1
mvs.sha256
```

For 0.7.0 orphan diagnostics, these are treated as filename sets only.

Therefore:

- ID orphan checks across product/variant sources can test reference coverage.
- title orphan checks involving `mvs_names.txt` are literal title-set checks,
  not proof of missing product relationships.
- filename orphan checks answer filename presence only; they do not yet prove
  algorithm/digest equivalence.


## Filename/hash relationship query model

Version 0.8.0 adds an explicit query edge model:

```text
MVS.TXT PRODUCT SECTION
  ID
  TITLE
  +-- filename edge(s)
       +-- hash value stored on mvs.txt line

FLAT HASH MANIFESTS
  mvs.sha1   hash -> filename
  mvs.sha256 hash -> filename

SCALAR JOINS
  ID -> DATE from mvs_dates.txt
  normalized TITLE -> NOTE from mvs_notes.html
```

A query result is based on a matched filename plus zero or more owning
`mvs.txt` product sections.

This preserves real ambiguity:

- one filename can be referenced by multiple product IDs;
- one hash can resolve to multiple filenames;
- one filename can have conflicting/different hash records across sources.

The relationship layer does not manufacture a SHA-1/SHA-256 pair merely
because two digests share a filename. It indexes each observed hash->filename
edge independently.

`mvs_names.txt` is deliberately not used as a product-title ownership source
for this family because its headings are variant/display titles.
