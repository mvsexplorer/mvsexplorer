# Scalar data model

## Product identity

For this toolkit, product `ID` is the primary key within a dump snapshot.

Validation of the supplied archive found:

- 79 dump snapshots.
- No duplicate IDs inside `mvs_ids.txt` in any snapshot.
- Every ID in every `mvs_ids.txt` had exactly one matching `mvs_dates.txt` row.
- Product titles are not unique; multiple IDs can share the same title.

Therefore the scalar record is modeled as:

```text
Product
  id      required, unique within dump
  title   required, taken from mvs_ids.txt
  date    required in the supplied archive, joined from mvs_dates.txt by ID
  note    optional/ambiguous, joined from mvs_notes.html by normalized title
```

## Notes are not ID-keyed

`mvs_notes.html` uses `<h1>Product Title</h1>` sections and does not include `[ID: n]` markers.

That means a title shared by multiple IDs cannot be unambiguously assigned an ID-specific note from this file alone. Some note titles also occur more than once.

Version 0.1.0 deliberately models notes as title-level information. All distinct normalized note blocks for a title are combined with ` || ` and exposed for every ID having that title.

A future parser may expose both `product.note` (joined convenience value) and raw note-section records so callers can inspect ambiguity directly.

## Date representation

Dates are emitted exactly as parsed from the left-hand date field in `mvs_dates.txt`. This preserves variants found in the archive, including forms ending in `Z` or `+00:00`; the toolkit does not silently convert time zones.

## Normalization

Titles and note headings are HTML-decoded where relevant, trimmed, and have runs of whitespace collapsed for matching/output.

Notes are converted from HTML to one-line text, HTML-decoded, and have runs of whitespace collapsed.

Machine output replaces literal TAB/CR/LF inside scalar values with spaces so every product remains exactly one TSV record.
