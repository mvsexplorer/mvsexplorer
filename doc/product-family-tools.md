# Product-family hierarchy and query tools

MVS Explorer Toolkit 0.15.x provides an analytical product-family layer above the
concrete product titles preserved by the source archive.

## Why this is a separate analytical layer

The archive supplies concrete product titles, product-level IDs/dates in
specific source files, product-section file/hash evidence in `mvs.txt`, and
title-level notes. It does not supply an authoritative product-family
taxonomy. Family assignments are therefore classifications with an explicit
basis/confidence, not rewritten source facts.

Product IDs remain snapshot/source-local observations. `mvs_names.txt` IDs are
variant/source provenance and are not used as product identities or family
ownership keys. SHA-1/SHA-256 relationships are retained only when observed
inside the same `mvs.txt` product section; hashes are never paired merely
because a filename matches.

## Hierarchy model

The family model is a directed acyclic graph (DAG), not a single-parent tree.
A title can simultaneously participate in broad-family, product-family,
broad-release and specific-release relationships.

Example:

```text
Microsoft Office Communications Server 2007 Standard Edition (English)
  -> Microsoft Office                         [broad_family]
  -> Microsoft Office Communications Server   [product_family]
  -> Microsoft Office 2007                    [broad_release]
  -> Microsoft Office Communications Server 2007 [specific_release]
```

The specific release family has two meaningful parents:

```text
Microsoft Office Communications Server 2007
  -> Microsoft Office Communications Server   [specific_release_of]
  -> Microsoft Office 2007                    [member_of_release_rollup]
```

That makes these queries distinct:

```text
Microsoft Office
Microsoft Office 2007
Microsoft Office Communications Server
Microsoft Office Communications Server 2007
Microsoft Office Proofing Tools
Microsoft Office System Developer Kit
```

`Office 2007 Proofing Tools ...` is normalized to the Microsoft Office broad
family while retaining its own `Microsoft Office Proofing Tools` product
family. `Microsoft Office System Developer Kit 3.0 ...` retains release 3.0 but
does not fabricate a broad `Microsoft Office 3.0` release rollup.


## Release-token derivation

Release memberships are analytical classifications, not source facts. Starting
with 0.15.1, the builder deliberately separates product-version evidence from
maintenance dates and referenced-product years.

The precedence is conservative:

1. after a curated leading product prefix, a leading small integer can be a
   structural release (`Windows 10`, `Windows 11`, `Office 95`, `Office 365`);
2. otherwise the left-most source-order calendar year or dotted semantic
   version is used (`.NET Framework 4.6 ... Visual Studio 2013` therefore uses
   `4.6`);
3. explicitly labeled Windows-style versions such as `version 1809` are
   recognized even though 1809 is not a calendar release year;
4. text at and after `Updated` or `Last updated` is maintenance metadata and
   cannot supply a release token;
5. Office Online Server's archive labels such as `(Updated November 2018)` or
   `(Last updated March 2017)` are update stamps, so they produce broad/product
   family memberships but no synthetic `Microsoft Office 2018`/`2017` release
   node.

These rules do not alter product-family ownership. A title can still be a
high-confidence member of `Microsoft Office Online Server` while having no
release-family membership when the source title supplies only an update date.

## Build the index

```bat
build_mvs_product_family_index.bat mvs-dumps-root output-folder [overrides.tsv]
```

The builder dynamically discovers snapshot folders, including snapshots whose
source files live under `mvs_dmp\`. It writes through a sibling staging folder
and commits the completed index as a unit. For safety, the requested output
folder must not already exist; remove/rename an old index or choose a new
destination for a rebuild.

Important normalized outputs:

```text
family-nodes.tsv
family-parent-relationships.tsv
classification-rules.tsv
product-classifications.tsv
product-family-memberships.tsv
product-ids.tsv
product-dates.tsv
product-files.tsv
product-hashes.tsv
product-notes.tsv
product-snapshots.tsv
unclassified-products.tsv
overrides-applied.tsv
raw-html\<sha256>.html
family-index-summary.txt
```

`product-files.tsv` and `product-hashes.tsv` come only from source-observed
`mvs.txt` product sections. The standalone manifest hash files are not assigned
to products merely by filename.

`product-notes.tsv` retains title evidence, source ID where the heading
actually supplies one, normalized text, and a content-addressed raw HTML block.

## Classification confidence

The automatic classifier has two tiers:

- `high`: curated structural prefixes and curated leading aliases, including
  Microsoft Office, Communications Server, Proofing Tools, Office System
  Developer Kit, SQL Server, Visual Studio, Exchange Server, Windows/
  Windows Server, System Center, Dynamics and other source-leading forms.
  Aliases such as `SQL Server ...` canonicalize to `Microsoft SQL Server`
  without requiring the source title itself to contain `Microsoft`.
- `review`: a product title begins with `Microsoft` but no curated family rule
  matched. The generic leading stem is exposed for review rather than silently
  treated as a canonical taxonomy decision.

Alias matching is deliberately anchored to the beginning of the normalized
title and requires a token boundary. It is not substring matching. Against the
accepted 0.14.4 all-ever `title_from_mvs.txt` ledger (8,123 titles), the shipped
rules classify 7,295 titles (89.8%) at high confidence, route 314 (3.9%) to
review, and leave 514 (6.3%) unclassified. Future archives are discovered
dynamically and can have different coverage.

A title that merely mentions another family is not ownership evidence. For
example:

```text
Contoso Security for Microsoft Office Communications Server 2007
FabriKam 3.1: The Microsoft Office System Solutions Learning Kit
```

are not classified as Microsoft Office products solely because the string
"Microsoft Office" appears inside the title.

Unsupported titles are retained in `unclassified-products.tsv`.

## Overrides

The optional override file is tab-separated with this header:

```text
product_title	action	broad_family	product_family	release	specific_release_family	broad_release_family	confidence	reason
```

`action` is either:

```text
set
exclude
```

A copyable example is provided as `doc\product-family-overrides.example.tsv`.

Overrides match the normalized concrete title exactly. `set` replaces only the
analytical family classification; it does not modify any source evidence.
`exclude` means "do not classify this title into the family taxonomy", not
"discard this product from the archive".

## Query directions

The delivered `print_*` tools emit labeled human-readable rows. Their matching
`read_*` tools emit tab-separated machine rows. Search patterns use
case-insensitive PowerShell wildcard semantics (`*` and `?`).

Family -> product facts:

```bat
read_mvs_product_titles_from_family.bat index "Microsoft Office"
read_mvs_product_ids_from_family.bat index "Microsoft Office"
read_mvs_product_dates_from_family.bat index "Microsoft Office 2007"
read_mvs_product_filenames_from_family.bat index "Microsoft Office 2007"
read_mvs_product_hashes_from_family.bat index "Microsoft Office Communications Server"
read_mvs_product_snapshots_from_family.bat index "Microsoft Office"
read_mvs_product_notes_from_family.bat index "Microsoft Office Communications Server"
read_mvs_product_releases_from_family.bat index "Microsoft Office"
```

Product facts -> family:

```bat
read_mvs_product_families_from_title.bat index "Microsoft Office Communications Server 2007*"
read_mvs_product_families_from_id.bat index "101"
read_mvs_product_families_from_date.bat index "2007-*"
read_mvs_product_families_from_filename.bat index "ocs2007-standard.iso"
read_mvs_product_families_from_hash.bat index "1111111111111111111111111111111111111111"
read_mvs_product_families_from_snapshot.bat index "mvs_2020-01-*"
```

Hierarchy navigation:

```bat
read_mvs_product_family_parents_from_family.bat index "Microsoft Office Communications Server 2007"
read_mvs_product_family_children_from_family.bat index "Microsoft Office"
```

The ID/date reverse queries always print snapshot/source provenance. They do
not imply that an ID is a permanent cross-snapshot identity.

## Return codes

Query tools use:

```text
0  one or more rows
1  no matching rows
2  invalid arguments or unsupported operation
3  missing/incomplete family index
5  internal processing failure
```

The builder uses 0 for success, 2 for invalid arguments/override schema, 3 for
missing archive/override input, and 5 for processing failure.

All tools recognize `--help`, `-h`, `-?`, `/h`, and `/?`.

## Testing

```bat
test\test_product_family_tools.bat
```

The synthetic regression builds a three-snapshot index (including one nested
`mvs_dmp` snapshot) and performs 96 assertions:

- archive fixture and builder execution;
- all normalized output tables;
- Communications Server, Proofing Tools and Developer Kit distinctions;
- false-positive guards for embedded Office references;
- review-tier behavior and an exact-title override;
- raw-note content-address integrity;
- positive execution of all 32 query wrappers;
- no-result return-code/stdout checks for all 32 query wrappers.

`test_all.bat` invokes this regression once as the family scope. Family tools
are deliberately excluded from the legacy archive-sweep plan, which remains
422 single-snapshot tools + 19 adjacent comparisons + 2 history builders.
