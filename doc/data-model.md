# MVS Explorer Toolkit Scalar Data Model

## Product identity

For the current scalar tools, `ID` is the primary key within a dump snapshot.

Archive review established the working structure:

```text
mvs_ids.txt:
TITLE [ID: N]

mvs_dates.txt:
DATE - TITLE [ID: N]
```

Within the reviewed snapshots, an ID occurs once in `mvs_ids.txt` and has one corresponding release-date entry in `mvs_dates.txt`.

Titles are not unique keys. Different IDs can have the same title.

## Current scalar product record

```text
Product
  id      catalog ID
  title   title from mvs_ids.txt
  date    release date from mvs_dates.txt, joined by ID
  note    normalized note text, joined by normalized title
```

## Notes

`mvs_notes.html` does not expose `[ID: N]` in its note headings. Notes are therefore not directly ID-keyed.

Current policy:

1. normalize the product title;
2. normalize each note `<h1>` heading;
3. match exact normalized titles;
4. normalize note HTML to one-line text;
5. de-duplicate identical note blocks for that title;
6. join multiple distinct blocks with ` || `;
7. expose the resulting title-level note to each matching product ID.

This is a convenience join, not evidence that the source itself assigns the note uniquely to an ID.

## Variants

`mvs_names.txt` is the expected basis of the next data-model layer:

```text
Product ID
  -> zero or more variants
       -> variant/display name
       -> filename
       -> hash record
```

The exact SHA-1/SHA-256 and possible `.cat`/`.txt` relationships will be established and documented before those tools are implemented.
