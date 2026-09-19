# Archive evolution, quality, notes, and canonical exclusions

Version 0.14.0 extends the fast archive worker from change-history/all-ever
generation into an evidence-preserving archive evolution analyzer.

## Principles

The source snapshots are observations, not a guaranteed sequence of perfectly
clean canonical databases. A snapshot can contain useful unique evidence while
also being unsuitable as a canonical comparison baseline.

For that reason ingestion and canonical interpretation are separate:

- **ingestion** always retains source evidence from discovered snapshots;
- **canonicality** can exclude a snapshot for a selected scope without deleting
  anything that snapshot contributed.

The toolkit never silently applies its anomaly suggestions as exclusions.

## Per-dump contributions

`archive-output\evolution\per-dump-contributions.tsv` records high-level
first-seen information for each snapshot, including product/variant states and
note versions/bodies.

`per-dump-domain-additions.tsv` keeps the same concept independently for all 19
source-local domains used by the comparison/history layer. Keeping those
domains separate prevents source-level ID or filename semantics from being
collapsed into an invented cross-source identity.

`per-dump-retention.tsv` answers the complementary question: for evidence first
introduced by a dump, how much was observed in at least one later snapshot and
how much was never seen later. It contains one row per snapshot and evidence
kind:

```text
index  dump  evidence_kind  introduced_here  seen_later  never_seen_later
```

Evidence kinds include product state, variant state, note version, note body,
and each of the 19 source-local domains. This table is the primary safeguard
when considering a canonical exclusion.

## Product and variant state identity

A product state is based on normalized product title plus the section's
observed file/hash state. A variant state is similarly based on normalized
`mvs_names.txt` variant title plus its observed file/hash state.

The source-level ID in `mvs_names.txt` is retained as provenance but is not
treated as a permanent variant identity. Its semantics change substantially
across archive generations.

`variant-id-transitions.tsv` measures adjacent snapshots using content/title
state independently of source ID. It reports retained states, how many retained
the same source ID, how many received a different source ID, and the numeric-ID
representation percentages on each side. High state retention together with a
high changed-ID percentage is evidence of an ID-regime change rather than
wholesale new content.

## Duplication and quality

`per-dump-quality.tsv` records product and variant section counts, zero-file
counts, duplicate-state occurrences, exact duplicate-section occurrences,
source-ID cardinality, numeric-ID proportion, note count, and advisory quality
flags.

`suggested-exclusions.tsv` contains analyzer recommendations such as duplicate
spikes or suspicious catalog contractions. Suggestions are evidence for human
review only.

Quality warnings do not make archive validation fail. Structural/integrity
errors do.

## Notes

Notes require an all-ever/versioned model because source text can change and a
version may occur in only one historical snapshot.

Both historical heading forms are accepted:

```html
<h3>Product Title [ID: 123]</h3>
...
```

and:

```html
<h1>Product Title</h1>
...
```

The source ID, when present, is retained. It is not fabricated when absent.

Files under `archive-output\evolution\notes\`:

- `note-observations.tsv` — every parsed note occurrence with snapshot,
  occurrence number, normalized title, literal source ID when present,
  same-snapshot title-matched product IDs, same-title variant source IDs,
  normalized-text SHA-256, raw-HTML SHA-256, and normalized note text.
- `note-versions.tsv` — all-ever `(normalized title, normalized note text)`
  versions with first/last seen and number of distinct snapshots observed.
- `note-bodies.tsv` — all-ever normalized text bodies independent of title.
- `note-raw-variants.tsv` — distinct raw-markup forms for each normalized
  title/text version, again with snapshot-level observation counts.
- `raw-html\<sha256>.html` — retained raw HTML body text as parsed from the
  source fragment and written as UTF-8, addressed by SHA-256.

Observation counts are per **snapshot**, never per duplicate occurrence inside
one snapshot.

Notes are fundamentally title-level source evidence. Same-snapshot product IDs
are associated only by normalized exact product-title match. Variant source IDs
are recorded only when an exact normalized variant-title match exists. The
toolkit does not invent product-to-variant ownership from filenames or hashes.

## Canonical exclusions

The default file is:

```text
test\archive-exclusions.tsv
```

Schema:

```text
snapshot    scope    canonical    reason
```

A noncanonical row can use `no`, `false`, `0`, or `exclude`.

Supported report scopes include:

- `products`
- `variants`
- `notes`
- `payloads`
- `comparison-baseline`
- `all`

Example:

```text
mvs_2021-04-20    variants    no    reviewed duplicate-section spike
```

This does **not** skip the dump. It remains part of the evidence store and is
still tested. The report shows how much evidence was first introduced there and
how much of it was never seen later.

Pass a different file with:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive --exclusions C:\path\archive-exclusions.tsv
```

## Interactive report

Fast archive runs create:

```text
results-folder\archive-summary.html
```

The report is self-contained and needs no web server. Tabs cover:

- overview;
- dumps;
- high-level and 19-domain additions;
- introduced-here versus seen-later retention;
- re-ID / ID regimes;
- duplication / quality;
- versioned notes;
- configured and suggested exclusions;
- all-ever totals;
- performance.

Tables are searchable and sortable.

The standalone report builder is:

```bat
test\build_archive_html_report.bat results-folder
```

## Future dumps

Snapshot discovery remains name-based and dynamic. No analysis rule assumes the
archive permanently contains 79 snapshots.

A new dump is ingested as another observation. First-seen and retention
statistics, source-ID transition metrics, note versions, and quality flags are
derived from the newly discovered chronological sequence.

Quality rules deliberately flag unusual changes instead of automatically
discarding future source formats. A new source-generation regime can therefore
be reviewed without losing evidence.
