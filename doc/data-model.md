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
