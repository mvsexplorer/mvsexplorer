# Development Observation Journal

This journal records observations that may affect later MVS Explorer Toolkit design. It is intentionally distinct from the developer diary: the diary records what was done; this file records facts, risks, patterns, and questions discovered while doing it.

## 2026-08-27

### The dump archive is metadata, not payload storage

The archive contains catalog text/checksum/HTML metadata. Filenames for ISO/EXE/ZIP/etc. payloads appear as references; the payloads themselves are not the content being explored here.

### Snapshot layout changes over time

Not every snapshot has every later file. Early snapshots predate `mvs_names.txt`; SHA-256 manifests also appear later. Some snapshots contain an extra directory level. Future dump-resolution and validation code must not assume one historical layout without checking.

### ID is a better scalar key than title

Inside a snapshot, IDs behave as unique product identifiers for the product/date records reviewed. Titles can be duplicated across IDs.

Implication: joins should use ID whenever the source provides ID.

### Notes are structurally weaker than dates

Dates contain IDs and can be joined directly.

Notes are headed by title and do not carry IDs. A title join can be useful but cannot remove ambiguity when titles repeat.

Implication: the GUI should eventually be able to expose raw source provenance and ambiguity rather than only a flattened convenience value.

### Variant is useful terminology but still a toolkit term

The headings in `mvs_names.txt` look like named download variants. Calling them `variant` is useful for the toolkit, but the term should remain documented as an MVS Explorer model term rather than falsely attributed as a formal source field name.

### Hash algorithm cannot be assumed globally

Examples in older dumps are SHA-1-shaped, but the archive evolves to include SHA-256 material. Future variant/hash parsers should recognize the algorithm from the actual record/source rather than assume all `mvs_names.txt` entries are SHA-1.

### Standalone files are a deliberate maintenance tradeoff

Embedding the parser in every tool increases duplication and future update work.

For this project the duplication is intentional because a copied individual tool must remain usable by itself. To manage the tradeoff, future releases should use generation/testing during development while delivering standalone artifacts.

### Machine output should remain boring

The `read_` family should avoid ANSI, labels, banners, progress, pause prompts, and decorative text on stdout. Stable boring output is valuable because it becomes a protocol used by later scripts and the graphical MVS Explorer.

### Parser-sensitive values justify PowerShell

Titles/notes can contain characters that are unpleasant to transport and transform safely through multiple `cmd.exe` parse passes. Embedded PowerShell confines that complexity without adding an external `.ps1` dependency.

### Runtime testing still needs Windows

Static checks can verify labels, CRLF, BOM, scaffolds, and obvious dependency mistakes in this environment. Actual `cmd.exe` and Windows PowerShell execution should be part of milestone validation on Windows.
