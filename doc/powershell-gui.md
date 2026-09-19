# MVS Explorer PowerShell GUI

## Purpose

`mvs_explorer_gui.bat` is the desktop companion to the self-contained HTML
browser. The delivered application is one standalone BAT containing all of its
Windows PowerShell source inline.

```bat
mvs_explorer_gui.bat [compact-family-index]
```

When the compact database argument is omitted, a WinForms folder picker asks
for the database directory.

## Runtime requirements

- Windows PowerShell 5.1
- .NET Framework WinForms/System.Drawing
- an existing compact MVS product-family database

No companion `.ps1`, development library, web server, browser engine, external
API, package manager, or network connection is required.

## Hierarchy

The four horizontal lists intentionally mirror the HTML browser:

1. **Basic families** — `broad_family`
2. **Products** — `product_family`
3. **Releases** — classified release, with empty release displayed as
   `(Other / unversioned)`
4. **Variants / exact titles** — concrete historical `product_title`

Each list is a checked multi-selection list. Its textbox filters only the
visible entries; typing never creates evidence selection. Empty checked
selection means all values still available from the columns to the left.
Selections that become impossible because an upstream selection changed are
pruned automatically.

Unclassified source-backed products remain under
`(Unclassified / historical)`.

## Lower evidence area

The lower area has four tabs:

- **Products** — exact title, product family, release, observed range, IDs,
  dates, classification status/confidence.
- **Files & hashes** — paged product-backed filename/hash rows, with a debounced
  filter matching product title, filename, algorithm, or hash. Files with no
  product-section hash remain visible explicitly.
- **Notes** — distinct normalized notes across the current selection, observed
  range, applicable product-title count, and retained raw-HTML SHA-256
  evidence. Selecting a note shows its complete text, titles, and hashes.
- **Selection** — current hierarchy state and the evidence semantics.

## Runtime indexing and performance

The compact database is read once at startup. The GUI deliberately avoids
creating a PowerShell object per large fact-table row. Product-backed filenames,
hash tuples, and note tuples are deduplicated and retained as compact per-title
string arrays. Product and file grids are paged; large file and note text
filters are debounced before rebuilding their result views.

This design trades a bounded startup indexing pass for fast hierarchy changes
after loading while avoiding the multi-million-row full family observation
tables.

## Evidence limits

The GUI does not strengthen the database model. Family/release membership comes
from the existing analytical product-family classification. File/hash rows come
only from `product-files-all-ever.tsv` and
`product-file-hashes-all-ever.tsv`, which represent actual `mvs.txt`
product-section evidence. Standalone manifest hashes are not attached to
products merely because filenames match. Notes remain historical title-level
evidence.

## Development contract

Maintained source lives in:

- `dev\library\powershell-gui.inc.ps1`
- `dev\templates\powershell-gui.bat.tpl`
- `dev\generate_powershell_gui.py`

The public BAT is generated and must remain standalone. New GUI code must parse
under Windows PowerShell 5.1. The GUI remains excluded from the legacy
snapshot/compare archive sweep because it is a consumer of the already-built
archive-level compact database.
