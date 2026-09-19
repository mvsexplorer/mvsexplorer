# Self-contained MVS HTML browser

## Purpose

`build_mvs_html_browser.bat` turns an existing compact product-family database
into one portable HTML file. The output can be opened directly from disk in a
modern browser and does not load anything from the network.

```bat
build_mvs_html_browser.bat compact-family-index [output.html]
```

When the output argument is omitted the builder writes `mvs-browser.html` in
the current directory.

## Hierarchy

The first browser version uses the existing conservative taxonomy rather than
introducing a second classifier:

1. **Basic families** — `broad_family`.
2. **Products** — `product_family`, normally the product name without release
   specificity.
3. **Releases** — the classified `release`; empty values are shown as
   `(Other / unversioned)`.
4. **Variants / exact titles** — concrete historical `product_title` values.

Each list is searchable as you type and supports multiple selections. A list
search only changes what is visible; it does not silently select evidence.
No selection in a column means all values that remain available from the
columns to its left.

## Evidence pane

The lower area contains four views:

- **Products**: exact title, product family, release, observed range, IDs,
  dates, and classification confidence/status.
- **Files & hashes**: product-backed filenames and hashes, searchable by
  product title, filename, or hash and paged to avoid huge DOM updates.
- **Notes**: normalized historical note text, applicable titles, observed
  range, and retained raw-HTML content hashes.
- **Selection**: a readable summary of the active hierarchy and the evidence
  semantics used by the browser.

## Semantic limits

The browser does not strengthen the database model. Family/release membership
is analytical classification. Filenames and hashes are included only from
`mvs.txt` product-section evidence represented by
`product-files-all-ever.tsv` / `product-file-hashes-all-ever.tsv`. It does not
join standalone manifest hashes to products merely because filenames match.
Notes remain title-level historical evidence.

Source-backed titles which have no conservative classification are retained in
`(Unclassified / historical)` so the browser does not omit evidence merely to
make the hierarchy cleaner.

## Self-contained payload

The HTML contains its CSS, JavaScript, and compact data payload inline. Shared
filenames, hashes, and note text are dictionary-encoded and product records use
integer references. The output requires no local web server, external library,
CDN, font, analytics endpoint, or API.

The browser is deliberately generated from the compact family database rather
than the full observation table set. Exact snapshot provenance remains in the
database; the first browser focuses on exploration and shows product-level
first/last observation plus the evidence values requested for browsing.

## Development status

0.17.0 introduces the builder as an independent public tool. It is not yet
inserted into the production pipeline, so browser UX can be refined before a
future release decides whether browser generation belongs in the fail-gated
pipeline/package set.
