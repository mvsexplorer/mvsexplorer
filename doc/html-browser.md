# Self-contained MVS HTML browser

> **0.19.0 layout:** Public utility BATs referenced in this document are delivered under `tools\`. Run them as `tools\<tool>.bat` from the project root, or change into `tools\` first. Their established arguments/output semantics are unchanged.


## Purpose

`tools\build_mvs_html_browser.bat` turns an existing compact product-family database
into one portable HTML file. The output can be opened directly from disk in a
modern browser and does not load anything from the network.

```bat
tools\build_mvs_html_browser.bat compact-family-index [output.html]
```

When the output argument is omitted the builder writes a date/time-stamped `mvs-browser-YYYYMMDD-HHmmss.html` in the project root.

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

Every hierarchy list provides **Select all**, **Clear**, **Copy selected**,
**Copy all**, and ordering by Name, Count, Reverse name, or Reverse count.
Select all applies to every currently available value, independent of the text
filter. Clear is a cascading reset: clearing one level also clears dependent
selections to its right before downstream availability is recomputed.

For Basic families, Products, and Releases, the item count is the number of
applicable exact product titles. For **Variants / exact titles**, the count is
instead the number of product-backed **Files & hashes** result rows for that
exact title, because a variant does not contain other variants.

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

The Products and Files & hashes tables sort by any column when its header is
clicked. A second click on the active column reverses the order. Copy-table and
copy-column actions operate on the complete current filtered result set across
all pages, not only visible DOM rows. Page size can be 50, 100, 200, 500, 1000,
or All.

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

## Windows PowerShell compatibility

The delivered builder is required to run under Windows PowerShell 5.1. Project
0.17.1 replaces the 0.17.0 generic static-method sort call with the PS5.1-safe
non-generic `Array.Sort` overload. This changes only builder compatibility; the
HTML data model and browser UI contract are unchanged.

0.17.0 introduced the builder as an independent public tool. Project 0.19.0
integrated browser generation into the modular create/update workflow. Project
0.21.2 advances the generated browser UI to 0.2.0 with hierarchy copy/sort
controls, cascading clear, meaningful variant file/hash-row counts, sortable
result columns, all-pages clipboard export, and selectable page sizes including
All.


## Desktop companion

Project 0.18.0 adds `mvs_explorer_gui.bat`, which exposes the same hierarchy and conservative evidence model as a Windows PowerShell 5.1 / WinForms application reading the compact database directly. See `powershell-gui.md`.
