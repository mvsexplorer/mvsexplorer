# MVS Explorer Toolkit 0.19.0



## 0.19.0 database maintenance workflow and root cleanup

0.19.0 reorganizes the delivered command surface around applications/orchestration
at the project root and utility tools under `tools\`.

The project root now contains the main entry points:

```text
mvs_explorer_gui.bat
create_or_update_mvs_database.bat
display_mvs_database_summary.bat
all_test_then_all_database_then_test_database_and_all_tools.bat
```

All 478 public utility BATs whose names begin with `build_mvs_`, `compare_mvs_`,
`find_mvs_`, `lookup_mvs_`, `print_mvs_`, or `read_mvs_` are generated into
`tools\`. The move is layout-only for their established behavior and does not
add those archive-level/database consumers to the legacy sweep. The known
79-snapshot archive plan remains 34,822 logical checks.

`create_or_update_mvs_database.bat` is the normal incremental maintenance entry
point. It searches the invocation directory and its parent for every
`mvs_dumps_archive*` directory, gives each source archive an isolated slot under
`mvs_databases\`, and processes every discovered archive. Its implementation is
split into eight ordered standalone component BATs under
`create_or_update_mvs_database\`:

```text
01_discover_archives.bat
02_prepare_archive_update.bat
03_run_archive_update.bat
04_rebuild_family_index.bat
05_rebuild_compact_index.bat
06_validate_database.bat
07_create_html_browser.bat
08_write_database_summary.bat
```

Incremental reuse is content based. Each recognized dump is fingerprinted from
the SHA-256 bytes of the seven known MVS source files (`mvs.txt`,
`mvs_ids.txt`, `mvs_dates.txt`, `mvs_names.txt`, `mvs_notes.html`, `mvs.sha1`,
and `mvs.sha256`), with missing sources represented explicitly. A dump is
reported as `Already done` only when the source fingerprint is unchanged, the
archive-processing toolset is compatible, and every expected prior logical row
has a valid terminal status. New, changed, incomplete, or faulty snapshots are
processed from scratch as complete snapshot batches. Incomplete staging
directories are discarded on the next run; successful archive analysis is
promoted only after archive quality validation succeeds.

Full-family and compact-family databases are rebuilt only when their upstream
data/tool state requires it. Every resulting database set is passed through the
generated-database validator and all 32 family query smoke tests.

All maintenance logs go under `logs\create-or-update-YYYYMMDD-HHmmss\`, with
a master console transcript and per-component logs. After active log writers
are closed, the complete run directory is ZIPped alongside it.

Maintenance HTML browsers are generated into the project root with
date/time-stamped names such as
`mvs-browser-<archive-slot>-YYYYMMDD-HHmmss.html`. The standalone HTML builder
under `tools\` also uses a timestamped project-root filename when no explicit
output is supplied.

`display_mvs_database_summary.bat` searches the current and parent directories
for `mvs_databases*`, selects the most recently modified database root, and
prints a colored PASS/WARN/FAIL health summary. It checks database component
presence, validation state, archive plan/run completeness, quality counts, and
completeness against the current source archive, including changed source
fingerprints.

With no explicit database argument, `mvs_explorer_gui.bat` now searches the
current and parent directories for usable compact databases. One match is
opened automatically; multiple matches are presented in a chooser with a
Browse option; no match falls back to the folder picker.

0.19.0 is a structural/incremental-maintenance candidate pending its first
native Windows maintenance run. The generated structure suite expects 495
assertions and all mode expects 1,108.

## 0.18.0 standalone PowerShell/WinForms MVS Explorer

0.18.0 adds `mvs_explorer_gui.bat`, a desktop GUI companion to the accepted
self-contained HTML browser. The delivered application is one standalone BAT
file with its Windows PowerShell code injected at generation time; it has no
`dev\` runtime dependency and does not require a companion `.ps1`.

The GUI reads an existing compact product-family database at runtime. With no
argument it opens a folder picker; with an argument it opens that database
directly. Its hierarchy mirrors the HTML browser: **basic family -> product
family -> release -> exact product title/variant**. Every column supports
filter-as-you-type and multi-selection, with typed text affecting visibility
only. Empty selection continues to mean all values available from the columns
to the left.

The lower WinForms area provides Products, Files & hashes, Notes, and Selection
tabs. Large file/hash tables are indexed into compact per-title string arrays
during startup rather than materialized as hundreds of thousands of
`PSCustomObject` rows. Result grids are paged and file/note detail filters are
debounced. The same conservative evidence rules remain in force: family/release
membership is analytical classification; files/hashes come only from
product-backed `mvs.txt` section evidence; notes remain title-level historical
evidence; unclassified source titles stay visible explicitly.

0.17.1 is now native-accepted for HTML generation. 0.18.0 is a new GUI feature
candidate pending native Windows UI acceptance. The public root becomes **480**
standalone BATs: 422 single-snapshot, 19 compare, 2 archive, 34 product-family,
1 HTML builder, 1 PowerShell GUI, and 1 production pipeline. Both browser tools
are excluded from the legacy archive sweep, so the established plan remains
34,822 logical checks. Structure becomes 494 assertions and all mode 1,107.

## 0.17.1 Windows PowerShell 5.1 browser-builder compatibility fix

0.17.1 fixes the native Windows failure in `build_mvs_html_browser.bat` discovered
during the first 0.17.0 acceptance run. The browser builder used generic static
method invocation syntax (`[Array]::Sort[string](...)`) that is not accepted by
Windows PowerShell 5.1. It now calls the PS5.1-compatible non-generic array-sort
overload while retaining ordinal, case-insensitive ordering.

A dedicated structure regression rejects the unsupported generic syntax and
requires the compatible sort marker. Browser behavior, hierarchy, evidence
semantics and payload format are otherwise unchanged from 0.17.0.

## 0.17.0 self-contained MVS HTML browser

0.17.0 adds the first browser-oriented delivery tool:
`build_mvs_html_browser.bat`. It consumes an existing compact product-family
index and emits one offline `.html` file with no external scripts, stylesheets,
fonts, services, or network dependency.

The browser presents a horizontal cascading hierarchy of **basic family ->
product family -> release -> exact product title/variant**. Every column has a
filter-as-you-type box, supports multi-selection, and constrains the columns to
its right without silently treating typed text as evidence selection. Empty
selection means all currently available values.

The lower evidence area summarizes the active match set and provides paged
product details, product-backed filenames and SHA-1/SHA-256 values, normalized
historical notes with retained raw-HTML evidence hashes, IDs, dates, and
first/last observed snapshots. Source-backed titles which are not conservatively
classified remain visible under an explicit `(Unclassified / historical)`
bucket instead of being hidden or force-classified.

The HTML payload is compacted specifically for browser use with integer indexes
for shared filenames/hashes/note text while preserving the existing semantic
boundaries: family membership is analytical classification; file/hash rows come
only from actual `mvs.txt` product-section evidence; notes remain title-level
historical evidence; no standalone-manifest filename join is invented.

The public root now contains **479** standalone tools: the prior 478-tool
surface plus the HTML browser builder. The accepted production pipeline is not
yet changed to build the browser automatically; browser UX can therefore evolve
without destabilizing the native-accepted 0.16.5 pipeline. The known legacy
archive plan remains 34,822 logical checks because the browser builder is not a
snapshot/compare/archive-sweep subject.


## 0.16.5 large-family-query performance and deterministic ZIP metadata

The native 0.16.4 resume run is the first complete production-pipeline
acceptance: 487/487 structure checks passed, archive quality reported zero
errors, all 57 generated-database checks and all 32 real family-query tools
passed, phase 7 packaged successfully, and the final status was PASS.

Its retained `all-family-tools-performance.tsv` also exposed the next dominant
cost. Exact filename->family and hash->family lookups were each spending roughly
8.6-9.1 minutes importing 513-679 MiB TSVs into millions of PowerShell objects;
the four print/read reverse lookups alone consumed about 35.3 minutes. 0.16.5
keeps the public query contracts unchanged but streams large fact tables.
Common exact searches use `Select-String -SimpleMatch` as a native candidate
prefilter and materialize rows only after the requested field is verified.
Wildcard/escaped patterns use a one-pass `StreamReader` fallback, preserving
the existing PowerShell wildcard semantics without an all-row `Import-Csv`.
Family->fact directions use the same strategy, with a native multi-title
prefilter for narrow families and a single streaming scan for broad families.

0.16.4 also showed that the reused archive database could produce a different
ZIP SHA-256 after quality revalidation while the full and compact family ZIP
hashes remained stable. The cause is ZIP metadata, not database evidence:
`check_archive_sweep_quality.bat` recreates deterministic files under
`quality-check`, changing their filesystem last-write times, and
`CreateEntryFromFile` copied those times into each ZIP entry. Direct comparison
of the uploaded pre/post-validation archive ZIPs confirms all 2,341 entries
have identical CRC and uncompressed size; exactly six `quality-check/*` entries
have different ZIP timestamps, with identical compressed sizes. 0.16.5 writes ZIP
entries explicitly with a fixed legal ZIP timestamp (`1980-01-01T00:00:00Z`).
Entry names remain sorted and file bytes are unchanged, so repeated packaging of
the same directory/name no longer changes solely because validation ran at a
different wall-clock time. Content-addressed SHA-256 checks for retained raw
HTML remain strict; those hashes protect evidence bytes and are not weakened.

No archive/full-family/compact database table format changes are made. The
public root remains 478 tools and the current known legacy archive plan remains
34,822 logical checks. Two new structure guards cover the large-table query
streaming path and deterministic ZIP timestamping, so structure becomes 489
assertions and all-mode becomes 1,102 assertions.

## 0.16.4 deferred log-ZIP finalization

The native 0.16.3 resume run confirms the data and validator path is healthy:
the structure precheck passed 487/487, archive quality passed, and all 57
generated-database checks passed, including all 32 real family-query tools.
The run then reproduced the final packaging failure when the pipeline attempted
to ZIP its own active `console.log`.

`FileShare.ReadWrite` was not sufficient for the `CreateEntryFromFile` path on
the tested Windows/PowerShell 5.1 environment. 0.16.4 therefore removes the
live-log ZIP attempt entirely. The final collection phase copies logs and
creates the three database hardlinks, records its result, and then the outer
`finally` block flushes and disposes both active pipeline log writers. Only
after those handles are closed does the success path create the log ZIP and
`SEND-ME-LOGS-*` hardlink.

The structure guard now checks this ordering directly: no log-directory ZIP
operation may occur between the final collection phase starting and disposal of
the active master writer, while final log packaging must occur afterward.
Token-level semantic console coloring from 0.16.3 is retained unchanged.

No archive, full-family, compact-family, or query-tool data format changes are
made in 0.16.4. The public root remains 478 tools, the known archive plan remains
34,822 logical checks, structure remains 487 assertions, and all-mode remains
1,100 assertions. Existing validated databases can be resumed without
rebuilding.

## 0.16.3 log-packaging hotfix and token-level console color

A native 0.16.2 resume run against the already-built 0.16.1 production
databases confirms that the validator fixes are correct: the structure precheck
passed 486/486 assertions, archive quality passed with zero errors, and all 57
generated-database checks passed, including all 32 real family-query tool smoke
executions.

The only remaining failure was phase-7 packaging. The pipeline attempted to
create the log ZIP while its own `console.log` was still open for writing, and
Windows rejected `CreateEntryFromFile` with a sharing violation. 0.16.3
attempted to address this by opening both active pipeline log streams with
explicit `FileShare.ReadWrite`. A subsequent native 0.16.3 run proved that
`CreateEntryFromFile` still could not read the live `console.log`; 0.16.4
supersedes that approach by deferring log ZIP creation until after writer
disposal.

Console coloring is also narrowed from whole-line coloring to semantic-token
coloring. Normal text stays at the console's existing color while `PASS` is
green, active `FAIL`/`FAILED`/`ERROR` tokens are red, and
`WARN`/`WARNING`/nonzero `Warnings`/`SKIP`/`quality flags` attention tokens are
yellow. Zero-failure and zero-warning counters such as `FAIL=0`,
`failed=0`, `Warnings: 0`, and `Errors: 0` remain neutral. Retained logs remain
plain text with no terminal color control sequences.

One new structure assertion guards readable active log streams, while the
existing color assertion now requires token-level rather than whole-line
styling. The 0.16.3 structure scope is 487 assertions and all-mode is 1,100;
on the established representative dump the expected result is 1,097 PASS /
0 FAIL / 3 data-dependent note SKIP.

No archive, full-family, compact-family, or query-tool data format changes are
made in 0.16.3. Databases already validated by 0.16.2 can be resumed and
packaged without rebuilding.

## 0.16.2 real-database validator and console-progress fixes

A clean native 0.16.1 production run completed the test gate, all 34,822
archive logical checks, archive quality validation, and both family database
builds. The final 57-check database gate then exposed three validator-only
false negatives. The generated databases themselves are valid.

0.16.2 fixes archive plan/run reconciliation to join by the stable plan
`index` rather than by row position. Parallel snapshot workers intentionally
append completed batches in completion order, so `runs.tsv` is not required to
have the same physical row order as `plan.tsv`.

It also fixes Windows PowerShell 5.1 singleton unwrapping in
`snapshot-sets.tsv` validation by preserving the parsed snapshot list as a
typed string array. This corrects both the snapshot-set dictionary check and
the dependent compact-reference check without changing the compact database
format.

The archive sweep console output is now paired and timed:

```text
Starting snapshot mvs_2020-04-21 [fast-combined 422 checks; worker 8/8] ...
Completed snapshot mvs_2020-04-21 in 112.963 s. Progress: ...

Starting compare mvs_2022-03-15-1649 -> mvs_2022-04-20-1713 [fast-combined 19 checks] ...
Completed compare mvs_2022-03-15-1649 -> mvs_2022-04-20-1713 in 0.312 s. Progress: ...
```

The one-command pipeline colorizes PASS lines green, FAIL/error lines red, and
warning/SKIP lines yellow on an interactive console. Retained log files remain
plain text.

The real archive plan is still validated during phase 1, but that preflight now
uses `--quiet-plan`; the repeated list of all snapshot names is suppressed.
Phase 2 still prints the production planning pass because that is the plan
actually persisted into the archive database.

The pre-build `test_all` structure gate now contains five additional assertions
covering these fixes and UX invariants. The 0.16.2 all-mode matrix is 1,099
assertions; on the established representative dump the expected result is
1,096 PASS / 0 FAIL / 3 data-dependent note SKIP.

## 0.16.1 Windows PowerShell 5.1 database-validator hotfix and resume mode

Native 0.16.0 production testing completed the full test gate, the 34,822-check
archive database, archive quality validation, the full family database, and the
compact family database. Phase 6 then exposed a Windows PowerShell 5.1 lexical
bug in the newly added generated-database validator: several compacted
PowerShell `return` statements had lost the required token boundary before a
variable or type literal (for example `return$true`, `return$map`, and
`return[pscustomobject]...`). The same source-formatting defect affected the
pipeline's failure-summary/log-packaging helper.

0.16.1 fixes those maintained PowerShell sources, regenerates the standalone
validator/pipeline, and adds a static release guard that rejects any future
missing whitespace immediately after `return` in those new components.

The native failure log also exposed a second validator-only assumption in the
DAG test. `family-nodes.tsv` legitimately contains multiple rows for one family
name when that name has multiple node roles. The real index has 1,229 node rows
but 787 case-insensitive unique family names. The corrected DAG test compares
its topological visit count with the unique family-key count, while still
requiring every parent/child reference to resolve and still detecting cycles.

Fresh production runs still use the same one-command entry point:

```bat
all_test_then_all_database_then_test_database_and_all_tools.bat
```

A failed 0.16.0 run that already built the three databases can now resume
without repeating the expensive build phases:

```bat
all_test_then_all_database_then_test_database_and_all_tools.bat --resume-built ^
  ..\mvs-archive-database-0.16.0-YYYYMMDD-HHMMSS ^
  ..\mvs-family-index-0.16.0-YYYYMMDD-HHMMSS ^
  ..\mvs-family-index-compact-0.16.0-YYYYMMDD-HHMMSS
```

Optionally preserve a prior successful `test_all` result folder in the new log
bundle with:

```text
--resume-test-results DIR
```

Resume mode first runs the lightweight structure suite (including the two new
validator/pipeline preflight guards), then re-runs archive quality validation,
all 57 generated-database checks, and all 32 real family-query smoke executions
before ZIP/hardlink packaging. It does not rebuild the three supplied databases.

The database formats, the archive/family/compact builders, the 32 family query
tools, and the 443 legacy public tools are unchanged from 0.16.0. The only
public-root behavior change is the orchestration tool itself.

The pre-build `test_all` structure gate now contains two additional assertions
covering these exact late-stage failures. The 0.16.1 all-mode matrix is 1,094
assertions; on the established representative dump the expected result is
1,091 PASS / 0 FAIL / 3 data-dependent note SKIP.



## 0.16.0 one-command validation and database production pipeline

Version 0.16.0 adds
`all_test_then_all_database_then_test_database_and_all_tools.bat`, a
fail-gated one-command workflow for rebuilding the reusable databases from the
original dump archive.

With the normal layout where the toolkit and `mvs_dumps_archive` are sibling
directories, run this from the toolkit root:

```bat
all_test_then_all_database_then_test_database_and_all_tools.bat
```

The default archive is `..\mvs_dumps_archive`; the default output root is
`..`. Optional arguments are:

```text
[mvs-dumps-root] [--workers N] [--output-root DIR] [--strict-performance]
```

The pipeline runs all normal tests first. Database generation does not begin
unless that test gate passes. It then builds and validates three reusable
outputs under the output root:

```text
mvs-archive-database-0.16.0-YYYYMMDD-HHMMSS\
mvs-family-index-0.16.0-YYYYMMDD-HHMMSS\
mvs-family-index-compact-0.16.0-YYYYMMDD-HHMMSS\
```

The archive database is a complete fast-combined archive sweep with plan,
logical runs, chronology/evolution outputs, quality results and the interactive
HTML report. The full family index preserves one row per source observation.
The compact family index collapses repeated facts across dumps while retaining
exact snapshot provenance through `snapshot_set_id`.

After generation, `test\test_generated_databases.bat` performs 25 structural
and semantic database checks plus one real-data smoke execution of each of the
32 public family query tools (57 database tests total). It validates archive
plan/run alignment and status counters; full-index summary counts, hierarchy
referential integrity, DAG acyclicity and content-addressed note blobs; compact
snapshot-set reconstruction, source/compact observation accounting, conflict
and alias ledgers, taxonomy byte identity and provenance safety flags.

Successful runs ZIP all three databases and the collected log folder. The ZIPs
are stored beside the generated databases under the output root. Four
`SEND-ME-*.zip` hardlinks are created in the toolkit root, so the artifacts can
be grabbed or attached without searching through the output directories.

Progress output now includes project version, current test number, total tests
and remaining tests. `test_all.bat` has 1,092 assertions in `all` mode for the
0.16.0 public surface; on the representative historical dump the expected
baseline remains three data-dependent note skips and no failures. The dedicated
family suite remains 106 assertions. `test_everything.bat` also numbers its
top-level child suites, and the one-command pipeline numbers its ten phases.

The pipeline log folder includes `console.log`, `phase-performance.tsv`,
`pipeline-summary.txt`, `database-paths.tsv`, the complete `test-results`
folder, archive-database top-level sweep/quality logs and the database
validation folder containing `database-tests.tsv` and
`all-family-tools-performance.tsv`.

The public root now contains 479 tools: the established 443 legacy tools, 34
product-family tools, and one orchestration tool. The orchestration tool is
excluded from snapshot/compare planning, so the known 79-snapshot archive plan
remains exactly 34,822 logical checks.

This release also repairs a development-source reproducibility issue discovered
during hardening: the checked-in fast-archive PowerShell source/generator is
synchronized to the already accepted optimized 0.15.x generated worker, so
regenerating performance tools no longer risks reverting the 0.14.4 archive
speedup.



## 0.15.3 compact synthetic-regression maintenance

Version 0.15.3 is a test-fixture-only maintenance release. Native 0.15.2
testing exposed that the compact-index assertion `compact hash rows collapse
repeated observations` expected at least one repeated product-safe hash fact,
but the synthetic fixture contained none once source-local product ID was
retained as part of the compact key.

The synthetic archive now repeats one identical
`source_file + product_title + product_id + filename + algorithm + hash`
observation in two snapshots. This makes the existing compaction assertion
exercise the intended behavior. The compact builder, full family builder,
all query tools, and all 443 legacy tools are unchanged from 0.15.2.

Audit of the real 0.15.2 compact index confirms that this was a fixture defect,
not a builder defect: compact `snapshot_count` totals exactly reconstruct the
raw ID/date/file/hash/note/presence observation totals; all 967 snapshot-set
references resolve; the 26 filename/hash conflicts, zero same-product hash
disagreements, and 356 hash/filename aliases recompute exactly; and all 6,330
content-addressed raw-note blobs verify by SHA-256.

## 0.15.2 compact family index

Version 0.15.2 adds `build_mvs_product_family_compact_index.bat`, a second-stage
builder for the product-family index. The original family index remains the
forensic/evidence form with one row per snapshot observation. The compact index
collapses identical facts across snapshots while preserving exact dump
provenance through reusable `snapshot_set_id` records.

The compact builder is intentionally lossless with respect to the source-backed
family facts it summarizes. Product IDs remain source/snapshot observations,
product file/hash relationships remain those actually observed in `mvs.txt`,
note raw HTML remains content-addressed, and SHA-1/SHA-256 values are never
paired merely because a filename matches.

Build it from an existing full family index:

```bat
build_mvs_product_family_compact_index.bat family-index compact-family-index
```

Key compact outputs include:

```text
snapshot-catalog.tsv
snapshot-sets.tsv
product-files-all-ever.tsv
product-file-hashes-all-ever.tsv
file-hashes-all-ever.tsv
product-ids-all-ever.tsv
product-dates-all-ever.tsv
product-notes-all-ever.tsv
product-presence-all-ever.tsv
filename-hash-conflicts.tsv
filename-hash-conflict-details.tsv
product-file-hash-conflicts.tsv
hash-filename-aliases.tsv
compact-index-summary.txt
```

`filename-hash-conflicts.tsv` distinguishes ordinary cross-product filename
reuse from a true same-product filename/hash disagreement.
`product-file-hash-conflicts.tsv` is the stricter ledger for cases where the
same normalized product title and filename/algorithm are observed with
different hashes. `hash-filename-aliases.tsv` records the inverse condition:
the same payload hash appears under multiple filenames.

Against the accepted 0.15.1 real index, this representation collapses
3,729,072 product-hash observations to 197,600 source/product/file/hash facts
and 80,941 global filename/algorithm/hash tuples. There are 26 global
filename/hash collision keys, zero same-product hash disagreements, and 356
hashes that appear under multiple filenames. Those are observed archive
statistics, not hard-coded expectations.

The public root now contains 477 tools: the original 443 legacy tools, the
existing 33 family tools, and the new compact builder. The legacy archive sweep
remains 34,822 logical checks because both family builders are separate
archive-level features. The dedicated family regression now performs 106
assertions.

## 0.15.1 release-token inference maintenance

Version 0.15.1 is a correctness maintenance release for the analytical
product-family release layer. Native 0.15.0 acceptance proved the family
ownership graph and all 33 family tools, but audit of the generated real index
showed that the release parser could mistake a later update/reference year for
the product's own release. Examples included `Office Online Server (Updated
November 2018)`, `.NET Framework 4.6 ... Visual Studio 2013`, and Windows titles
whose `Updated ... 2020` metadata followed an earlier Windows/version token.

The builder now derives releases from structural evidence in source order:
leading curated versions such as Windows 10/11 and Office 95/365 are preferred;
otherwise the left-most year or dotted semantic version is used; explicit
Windows-style `version 1809` tokens are recognized; and `Updated`/`Last updated`
tails cannot contribute release evidence. Office Online Server's dated archive
labels are treated as update stamps and do not create artificial Office
2016/2017/2018 release families.

This changes only analytical release-token derivation in
`build_mvs_product_family_index.bat`. Family ownership, confidence, source
product facts, raw-note preservation, and all legacy archive semantics remain
unchanged. The 32 family query wrappers are unchanged.

The dedicated family regression now performs 96 assertions, including guards
for update timestamps, referenced years, dotted semantic versions and explicit
non-calendar version tokens. Native 0.15.0 testing also established the correct
full regression matrix as 1,090 assertions: on the representative dump the
expected baseline is 1,087 PASS, 0 FAIL and the same 3 data-dependent note
SKIPs.

## 0.15.0 product-family hierarchy and bidirectional queries

Version 0.15.0 adds an analytical product-family hierarchy on top of the
historical concrete product titles. The original 443 public root tools are
unchanged; 33 new standalone family tools expand the public surface to 476.

The family model is a DAG rather than a simple prefix tree. A product such as:

```text
Microsoft Office Communications Server 2007 Standard Edition (English)
```

can simultaneously belong to:

```text
Microsoft Office
Microsoft Office Communications Server
Microsoft Office 2007
Microsoft Office Communications Server 2007
```

This keeps a broad family, a specific product family, a broad release rollup
and a specific release family distinct. Consequently `Microsoft Office 2007`
can be queried independently from `Microsoft Office Communications Server`,
`Microsoft Office Proofing Tools`, or `Microsoft Office System Developer Kit`.

Build the index once:

```bat
build_mvs_product_family_index.bat ..\mvs_dumps_archive family-index
```

For safety the output folder must not already exist. An optional third
`overrides.tsv` argument applies exact-title taxonomy decisions without
modifying source evidence.

Then query it in either direction, for example:

```bat
read_mvs_product_ids_from_family.bat family-index "Microsoft Office"
read_mvs_product_families_from_id.bat family-index 469
read_mvs_product_dates_from_family.bat family-index "Microsoft Office 2007"
read_mvs_product_families_from_date.bat family-index "2007-*"

read_mvs_product_filenames_from_family.bat family-index "Microsoft Office"
read_mvs_product_filenames_from_family.bat family-index "Microsoft Office 2007"
read_mvs_product_families_from_filename.bat family-index "some-file.iso"

read_mvs_product_hashes_from_family.bat family-index "Microsoft Office Communications Server"
read_mvs_product_families_from_hash.bat family-index "012345..."

read_mvs_product_family_parents_from_family.bat family-index "Microsoft Office Communications Server 2007"
read_mvs_product_family_children_from_family.bat family-index "Microsoft Office"
```

The index stores family membership separately from concrete title facts.
Product IDs and dates retain the snapshot and source file that observed them and
are not promoted to immutable identities. Product files/hashes are inherited only from
source-observed `mvs.txt` product sections; hash pairings are never inferred from filenames. Notes retain their
historical title evidence, raw HTML and source IDs only where the source
actually supplied an ID. No `mvs_names.txt` variant ID is reinterpreted as a
stable product identity.

Automatic classification uses curated high-confidence structural prefixes plus
curated leading aliases for source titles that omit the word `Microsoft`
(`Windows ...`, `SQL Server ...`, `Visual Studio ...`, `Office ...`, and other
known product-leading forms). Matching is anchored at the beginning of the
normalized title and requires a token boundary; arbitrary substring references
never establish family ownership.

Against the accepted 0.14.4 archive's 8,123 all-ever `mvs.txt` product titles,
the shipped rules classify 7,295 (89.8%) at high confidence, place 314 (3.9%)
generic Microsoft-leading titles in the explicit `review` tier, and leave 514
(6.3%) unclassified rather than guessing. These are a baseline for that archive,
not hard-coded discovery counts. Unsupported titles are written to
`unclassified-products.tsv`. Exact-title `set`/`exclude` overrides are supported
for reviewed taxonomy corrections.

Testing is integrated into the normal harness:

```bat
test\test_product_family_tools.bat
test\test_all.bat dump-folder
test\test_everything.bat archive-root
```

The family regression builds a three-snapshot synthetic index from scratch,
validates every normalized index table plus content-addressed raw-note blobs,
runs all 32 query wrappers in positive and no-result modes, tests a nested
`mvs_dmp\` snapshot, and guards against false family ownership from embedded
product-name references. It performs 92 dedicated assertions and is invoked
once from the normal `test_all.bat` suite.

The legacy archive sweep remains intentionally unchanged at 34,822 logical
checks (422 snapshot tools x discovered snapshots, 19 adjacent-comparison
tools, and 2 history builders). The 33 family tools form a separate archive-level
class and are not incorrectly invoked once per snapshot.

See `doc\product-family-tools.md` and
`doc\product-family-tool-matrix.tsv` for the complete model and tool matrix.

## 0.14.4 archive-builder benchmark result

Native Windows PowerShell 5.1 validation of 0.14.4 completed the full
79-snapshot fast archive builder in 967,234 ms (16 m 7.234 s), down from
13,975,326 ms for 0.14.3. The historical output remained byte-equivalent to the
accepted 0.14.3 result except for elapsed-time metadata and the intentionally
new phase-timing ledger. The accepted historical totals remain 572,143 added,
474,501 removed, 648,293 all-ever source-local records, 12,103 product states,
100,139 variant states, 3,974 note versions, 820 note bodies and 6,210 raw-note
variants.

## 0.14.4 archive-builder allocation reduction and phase profiling

Version 0.14.4 is driven by the native Windows PowerShell 5.1 benchmark of
0.14.3. All 443 public root tools remain byte-for-byte unchanged.

The direct 0.14.3 archive-builder benchmark completed the same 79-snapshot
historical model in 13,975,326 ms (3 h 52 m 55.326 s), compared with
15,223,912 ms for 0.14.2. That is an 8.20% improvement. The generated archive
output was byte-for-byte identical to the 0.14.2 accepted archive output in
2,323 of 2,324 files; the only differing file was `fast-archive-summary.txt`
because its elapsed-time line changed.

The remaining profile is dominated by work repeated once per product/variant
section and once per source-local set value. 0.14.4 therefore keeps the same
archive evidence model and output ordering while reducing PowerShell object and
collection churn:

- source-local value sets use parallel typed key/value lists instead of one
  `PSCustomObject` per unique value;
- product/variant titles and IDs are normalized once at section-header parse
  time instead of being normalized again during section-state finalization;
- zero/one-file sections no longer allocate an `ArrayList`; a file list is
  allocated only when a section actually has multiple files;
- state/title ID tracking stores one primary ID directly and allocates a
  case-insensitive extra-ID set only when a state/title genuinely has multiple
  distinct source IDs;
- raw note HTML uses an in-memory SHA-256 seen set instead of performing a
  filesystem existence test for every note observation;
- large final union/order lists are enumerated directly rather than copied
  through `@(...)`.

0.14.4 also writes:

```text
archive-output\evolution\fast-archive-timings.tsv
```

The timing ledger records, for every snapshot, parse time for each source plus
domain-union, adjacent-diff, state-union, note, re-ID transition, flush, and
total time. This makes the next optimization cycle evidence-driven even if the
total runtime remains substantial.

Validate first with:

```bat
test\test_fast_archive_sweep.bat
test\test_everything.bat ..\mvs_dumps_archive
```

Then benchmark only the archive engine before launching another full sweep:

```bat
test\fast\run_archive_tools_fast.bat ..\mvs_dumps_archive test\archive-builder-benchmark-0144
type test\archive-builder-benchmark-0144\fast-archive-summary.txt
```

The accepted historical counts remain 572,143 added records, 474,501 removed
records, 648,293 all-ever source-local records, 12,103 product states, 100,139
variant states, 3,974 note versions, 820 note bodies, and 6,210 raw note
variants.


## 0.14.3 measured archive-builder performance maintenance

Version 0.14.3 is driven by the first clean native Windows 10 / Windows
PowerShell 5.1 full-archive acceptance of the 0.14.x architecture. All 443
public root tools remain byte-for-byte unchanged.

The 0.14.2 full run completed the complete 34,822-row logical plan with:

- `PASS=33903`
- `NO_RESULT=574`
- `SOURCE_MISSING=345`
- `FAIL=0`

All 345 `SOURCE_MISSING` rows were the historically expected source-coverage
cases; there were zero unexpected missing-source classifications. The public
regression was also clean at 1,053 pass / 0 fail / 3 data-dependent skips, and
the synthetic fast archive acceptance was 3 pass / 0 fail.

That run exposed one dominant remaining performance cost. The 79 parallel
snapshot batches had a 116.13-second median and 176.742-second maximum, while
the combined archive-history/evolution worker alone took 15,224.942 seconds
(4 h 13 m 44.942 s). The old quality checker reported that maximum but only
classified snapshot-scope batch outliers, so the archive bottleneck was not
itself flagged.

0.14.3 therefore makes three focused archive-layer changes without changing
the logical plan or archive evidence model:

- archive-worker progress is streamed through the sweep logger instead of
  being discarded, so `Fast archive snapshot N/79` timing lines are visible
  live and retained in `console.log`;
- the archive worker removes several PowerShell-heavy hot paths while
  preserving the same keys and outputs: zero/one-file section states avoid a
  pipeline/sort, SHA-256 hashing reuses one hasher and uses `BitConverter`
  rather than a per-byte PowerShell pipeline, and TSV rows avoid per-field
  helper/ArrayList construction;
- the quality checker now reports snapshot, comparison, and archive batch
  timing separately and emits `performance-archive-outliers.tsv`; an archive
  batch over one hour is an advisory performance warning (or an error under
  `--strict-performance`).

The 0.14.2 result archive also established the real historical evidence
baseline used to verify future optimized runs: 572,143 added records, 474,501
removed records, 648,293 all-ever source-local records, 12,103 product states,
100,139 variant states, 3,974 note versions, 820 note bodies, and 6,210
title/body/raw-markup note variants.

Validate 0.14.3 first with:

```bat
test\test_fast_archive_sweep.bat
test\test_everything.bat ..\mvs_dumps_archive
```

After both pass, benchmark the fresh real archive with:

```bat
test\test_everything.bat ..\mvs_dumps_archive --full-archive --workers 8
```

The primary performance comparison is the `archive` row in
`fast-batches.tsv`; the logical counts and evolution totals above must remain
unchanged.


## 0.14.2 Windows acceptance-harness maintenance

Version 0.14.2 is a narrow maintenance release over 0.14.1. All 443 public
root tools remain byte-for-byte unchanged.

Native Windows 10 / Windows PowerShell 5.1 validation of 0.14.1 proved the
0.14.1 archive metadata serialization repair: the three-snapshot fast sweep
completed all 1,306 logical checks with `FAIL=0`, and both `summary.txt` and
`run-info.txt` contained `Executor: fast-combined` on one physical line.

That run exposed two later harness defects which 0.14.2 fixes:

- `test_fast_archive_sweep.bat` queried `runs.tsv` with a `.bat` suffix even
  though the `tool` column intentionally stores extensionless tool keys. The
  assertion now uses the real schema and also verifies the legacy-h3
  title-filtered note-record path.
- `test_everything.bat` named its helper argument array `$Args`, colliding with
  PowerShell's automatic `$args` variable and dropping the representative
  snapshot argument before invoking `test_all.bat`. The helper now uses
  `$ToolArgs`.

The archive sweep's representative-note profile now recognizes both historical
`<h3>Title [ID: ...]</h3>` and current `<h1>Title</h1>` headings, stripping the
legacy ID suffix before title matching. This prevents avoidable `NO_RESULT`
statuses for title-filtered note checks on older dumps.

Run the acceptance gates in this order:

```bat
test\test_fast_archive_sweep.bat
test\test_everything.bat ..\mvs_dumps_archive
```

Only after both pass, run the fresh real-archive acceptance:

```bat
test\test_everything.bat ..\mvs_dumps_archive --full-archive --workers 8
```


## 0.14.1 PowerShell 5.1 archive-metadata serialization fix

Version 0.14.1 is a maintenance release over 0.14.0. All 443 public root
tools remain byte-for-byte identical to 0.14.0 and the supplied 0.13.3
baseline.

The 0.14.0 fast executor itself completed the three-snapshot acceptance sweep
successfully (1,306/1,306 logical checks, FAIL=0), but the acceptance harness
then rejected its metadata. Windows PowerShell 5.1 evaluated several
unparenthesized string-concatenation expressions inside the summary/run-info
array literals as separate array elements, producing `Executor:` and
`fast-combined` on separate physical lines instead of the intended
`Executor: fast-combined`.

0.14.1 parenthesizes every concatenated summary/run-info array entry, keeps the
acceptance test strict, and additionally verifies the executor line in both
`summary.txt` and `run-info.txt`. The static validator rejects the
PowerShell-5.1-sensitive form.

The 0.14.0 Windows public regression remains clean: 1,053 pass, 0 fail,
3 data-dependent skips (1,056 assertions) on `mvs_2018-10-04`.



## 0.14.0 indexed archive analysis, quality, and reporting

Version 0.14.0 keeps all 443 public root tools byte-for-byte identical to the
0.13.3 baseline while substantially extending the archive-wide test and
analysis layer.

The default `fast-combined` executor now builds snapshot-local indexes for
product/file/hash/variant/note lookups, checks independent snapshots with
bounded parallel workers, freezes source inventories so a moved or modified
dump invalidates an entire batch instead of creating false `SOURCE_MISSING`
rows, and supports a content-addressed snapshot-result cache.

A fresh parallel archive run can be requested with:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive --workers 8 --no-cache
```

Repeated runs may omit `--no-cache` to reuse unchanged snapshot results. Literal
wrapper execution remains available with `--external-tools`.

The fast archive worker now produces evolution evidence in addition to the
existing 19-domain history/all-ever ledgers. This includes per-dump first-seen
contributions, introduced-here versus seen-later retention, duplicate/quality
metrics, variant source-ID regime transitions, all-ever product/variant states,
and complete versioned note evidence. Notes preserve occurrence provenance,
normalized text, raw HTML by SHA-256, title-based product associations, and
distinct raw-markup variants. Legacy `<h3>... [ID: ...]</h3>` and newer `<h1>`
note headings are both supported.

Canonical exclusions are deliberately non-destructive. Configure
`test\archive-exclusions.tsv` (or `--exclusions FILE`) to remove a suspicious
dump from a selected canonical interpretation while still ingesting all of its
evidence and one-off notes.

The archive sweep creates a self-contained interactive `archive-summary.html`
with tabs for dump contributions, retention, re-ID regimes, duplication/quality,
notes, exclusions, all-ever totals, and performance.

The comprehensive tester is:

```bat
test\test_everything.bat ..\mvs_dumps_archive
```

For a fresh full archive performance/regression cycle:

```bat
test\test_everything.bat ..\mvs_dumps_archive --full-archive --workers 8
```

`analyze_test_performance.bat` and `check_archive_sweep_quality.bat` write ranked
tool/batch timing tables and outlier reports. `--strict-performance` promotes
reported performance outliers to test failures.

See `doc\archive-evolution-and-quality.md`,
`doc\comprehensive-testing.md`, and `doc\performance-architecture.md`.


## 0.13.3 fast archive builder

Version 0.13.3 closes the final performance gap in the archive sweep. In
`fast-combined` mode, the two archive-wide history/all-ever checks are now
executed by `test\fast\run_archive_tools_fast.bat` in one streaming pass over
the archive. The public `build_mvs_dump_change_history.bat` and
`build_mvs_dump_all_ever.bat` interfaces are unchanged and remain available
through `--external-tools`.

The fast archive worker writes history ledgers incrementally, reports one
progress line per snapshot, reuses parsed source data for history and all-ever
accumulation, and is restart-safe because logical archive rows are committed to
`runs.tsv` only after the combined worker succeeds.

## 0.13.1 fast-worker PowerShell 5.1 parser fix

Version 0.13.1 is a narrow maintenance release over the validated 0.13.0 public-tool surface.
The 443 public root tools are unchanged from 0.13.0. It fixes the combined snapshot worker's
`Test-HashResult` predicate, which Windows PowerShell 5.1 rejected at script-block parse time
because of an overly nested boolean expression. The predicate now uses explicit branch-based
logic and the archive-sweep validator rejects the old parser-sensitive form.


MVS Explorer Toolkit is a growing collection of console tools for exploring MVS dump snapshots, intended to culminate in the graphical **MVS Explorer** application.


## 0.12.0 archive-wide real-dump sweep

The validated 0.11.0 Windows baseline completed **1053 passes, 0 failures, and
3 expected data-dependent note skips**. Version 0.12.0 adds a separate
real-archive integration harness without changing the 443 public root tools.

From the project root:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive
```

For the supplied 79-snapshot archive the deterministic plan contains **34,822
public-tool invocations**:

```text
422 single-snapshot tools * 79 snapshots
+ 19 compare tools * 78 adjacent transitions
+ 2 archive builders
= 34,822
```

Use plan-only mode before launching the sweep:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive --plan-only
```

Interrupted runs can be resumed safely when the regenerated plan SHA-256
matches:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive path_to_existing_results --resume
```

The runner resolves both ordinary snapshot roots and the known nested
`mvs_dmp\` layout. It records `PASS`, `NO_RESULT`, `SOURCE_MISSING`, and `FAIL`
separately, retains full artifacts only for failures, and preserves the
archive history/all-ever builder output.

See `doc\archive-sweep.md` for the complete execution and result contract.


## Standalone public tools, shared development source

Every public `.bat` in the project root is fully standalone.

Common code is now maintained under `dev\` and injected by `dev\generate_tools.py`. The generated public tools contain their own batch functions and embedded PowerShell; they do not read or call anything under `dev\` at runtime.

The development model is:

```text
common library + template + tool specification
                  |
                  v
             generation
                  |
                  v
      fully standalone public .bat
```

## Public tool count

Version 0.3.0 contains **127 standalone public batch tools**:

- 30 source-order scalar tools;
- 90 sorted scalar tools;
- 7 lookup tools.

## Sorted scalar tools

Every existing scalar `print_` and `read_` tool now has three companions:

```text
_sorted_by_id
_sorted_by_title
_sorted_by_date
```

For example:

```text
print_mvs_dump_id_title_date_note.bat
print_mvs_dump_id_title_date_note_sorted_by_id.bat
print_mvs_dump_id_title_date_note_sorted_by_title.bat
print_mvs_dump_id_title_date_note_sorted_by_date.bat
```

Sort semantics are ascending:

- **ID:** numeric product ID.
- **TITLE:** case-insensitive natural/alphanumeric title; numeric runs are compared naturally, with numeric ID as tie-break.
- **DATE:** chronological date/time where parseable; source date text and numeric ID provide deterministic tie-breaks.

The original unsorted tools remain source-order interfaces and follow `mvs_ids.txt`.

A sort field does not have to be displayed. For example, `print_mvs_dump_note_sorted_by_title.bat` prints notes while ordering product rows by title.

## Lookup tools

Current lookup relationships:

```text
lookup_mvs_title_from_id.bat
lookup_mvs_title_from_date.bat
lookup_mvs_note_from_id.bat
lookup_mvs_note_from_title.bat
lookup_mvs_note_from_date.bat
lookup_mvs_date_from_id.bat
lookup_mvs_date_from_title.bat
```

Examples:

```text
lookup_mvs_title_from_id.bat mvs_2021-08-17 28
lookup_mvs_title_from_id.bat mvs_2021-08-17 2*
lookup_mvs_title_from_id.bat mvs_2021-08-17 *28
lookup_mvs_title_from_id.bat mvs_2021-08-17 *2*
lookup_mvs_note_from_title.bat mvs_2021-08-17 "Windows 7 *"
```

`*` matches zero or more characters anywhere in the search value. Matching is case-insensitive. Every non-`*` character is treated literally.

Lookup tools emit **distinct, non-empty associated values, one per line**, with no label or header. Multiple matching product rows are ordered by the searched field: ID numerically, title naturally, or date chronologically.

No associated value produces no stdout and return code `1`.

## Scalar output families

`print_`
: Human-readable, labeled, one product per line.

`read_`
: Headerless TSV, one product per line, intended for piping and machine consumption.

## Development files

`dev\library\`
: Common maintained batch/PowerShell source.

`dev\templates\`
: Batch templates.

`dev\tool-spec.json`
: Tool matrix.

`dev\generate_tools.py`
: Injects common source into standalone public tools.

`dev\validate_generated.py`
: Static validator for generated tools.

These are development-time files only.

## Documentation

See `doc\` for the supplied Batch File Style Guide, project addendum, embedded PowerShell style guide, developer diary, observation journal, complete prompt record, distilled directives, project history, output/data-model documents, tool catalog, and one version-history file per public/development tool.


## Automated tests

Run the complete Windows test suite from the project root:

```text
test\test_all.bat path_to_mvs_dump_folder
```

Subset tests are also standalone:

```text
test\test_structure.bat
test\test_scalar_tools.bat path_to_mvs_dump_folder
test\test_lookup_tools.bat path_to_mvs_dump_folder
```

`test_all.bat` invokes every one of the 127 public batch tools and compares its output/return code against expectations independently constructed from the selected dump. It also performs standalone-structure checks.

The test suite covers:

- all 120 scalar source-order/sorted tools;
- exact output for human and machine projections;
- numeric ID, natural title, and chronological date ordering;
- all seven lookup tools;
- exact lookup;
- wildcard-all lookup;
- no-match return behavior;
- prefix, suffix, and contains `*` wildcard cases for ID lookup;
- clean stderr on successful/expected no-match runs;
- standalone injected-code structure.

All four test `.bat` files are themselves fully standalone; `test_all.bat` does not require the other test files to execute.


## Timestamped test result bundles

Every test invocation creates a single result directory beneath `test\`:

```text
test\test-results-YYYYMMDD-HHMMSS\
```

If two runs start in the same second, `-01`, `-02`, etc. is appended.

The normal full-suite command remains:

```text
test\test_all.bat path_to_mvs_dump_folder
```

Each result directory contains:

```text
README.txt
run-info.txt
console.log
summary.txt
all-results.tsv
general-results.tsv
structure-results.tsv
scalar-results.tsv
lookup-results.tsv
failures\
```

`all-results.tsv` records every assertion. The scope-specific TSV files make it easy to inspect just structure, scalar, or lookup testing.

When a behavioral comparison fails, `failures\` contains the complete expected stdout, actual stdout, stderr, and metadata for that case. Console messages may abbreviate long differences, but these failure files do not.

Version 0.5.0 also fixes the lookup no-match return-code defect found by the first external Windows run: a lookup that finds no non-empty associated result now returns code `1` while keeping stdout/stderr empty.


## 0.6.0 return-code propagation hardening

The attached 0.5.0 Windows result bundle confirmed that output and matching were still correct, but all seven no-match lookup cases continued to reach the caller as return code `0`.

Version 0.6.0 hardens both batch return boundaries:

1. `:RunPowerShellFromLabel` now returns the captured `powershell.exe` process exit code directly with `exit /b`.
2. The top-level `:end` path explicitly exits on any nonzero application code before the normal `GoTo :EOF`.

The explicit PowerShell process-level no-match exit remains in place as well. This removes the previous indirect nonzero return-carrier path and makes the intended chain:

```text
lookup no result
    -> powershell.exe exit 1
    -> :RunPowerShellFromLabel exit /b 1
    -> app.rc = 1
    -> top-level exit /b 1
    -> calling cmd.exe sees 1
```

The existing automated lookup no-match cases remain the acceptance test for this behavior.


## 0.7.0 duplicate/orphan diagnostic layer

Version 0.7.0 adds **45 standalone diagnostic finders**:

- 14 duplicate-property tools;
- 31 directional orphan-reference tools.

Together with the established scalar/lookup layer, the project now contains
**172 standalone public root `.bat` tools**.

Diagnostic tools use:

```text
find_mvs_duplicate_<property>_in_<source>.bat dump-folder
find_mvs_orphan_<property>_from_<source>_in_<target>.bat dump-folder
```

Findings are human-readable and preserve source context. No findings means no
stdout and return code `0`. A finding is information, not a process failure.

For `mvs.txt` and `mvs_names.txt`, duplicate/orphan ID or title findings print
the complete source section: header plus all associated nonblank lines through
the next blank line/source section. Filename findings print the owning ID,
title, and exact matching checksum/filename line.

Duplicate title/filename comparisons are case-insensitive after documented
normalization. IDs compare numerically. Dates compare as trimmed source values.

### Important interpretation notes

Repeated IDs in `mvs_names.txt` are normally expected because one product ID
can own many variant sections. The requested duplicate-ID finder reports the
literal repetition; it does not label that relationship corrupt.

Likewise, titles in `mvs_names.txt` are variant/display titles rather than the
same title domain as product titles in `mvs_ids.txt`, `mvs_dates.txt`, and
`mvs.txt`. Cross-file title-orphan tools involving `mvs_names.txt` therefore
report literal title-set differences and can legitimately produce many results.

`mvs_notes.html` normally has no ID field. The requested
`find_mvs_duplicate_id_in_mvs_notes.html.bat` scans literal `[ID: N]` markers
if present; ordinary archive note files are expected to yield no ID findings.

The requested filename:

```text
find_mvs_duplicate_date_in_mvs_date.txt.bat
```

is supplied exactly and reads the actual source file `mvs_dates.txt`. A
canonical alias is also supplied:

```text
find_mvs_duplicate_date_in_mvs_dates.txt.bat
```

See `doc\diagnostic-tools.md` for the complete matrix and output contract.

## Diagnostic regression fixture

The test suite now includes the intentionally inconsistent synthetic dump:

```text
test\test-mvs-dump-diagnostics\
```

and 45 independently generated fixed expected-output files under:

```text
test\expected-diagnostics\
```

Run only the diagnostic regression suite with:

```text
test\test_diagnostic_tools.bat
```

The full suite remains:

```text
test\test_all.bat path_to_real_mvs_dump_folder
```

The real dump is used for scalar/lookup regression tests; the fixed synthetic
dump is used for duplicate/orphan tests.


## 0.8.0 filename/hash relationship queries

Version 0.8.0 adds **96 standalone relationship-query tools**: 24 requested
projections, each available as `print_` and `read_`, from both filename and
hash.

The project now contains **268 standalone public root `.bat` tools**.

Examples:

```text
print_mvs_dump_id_title_filenames_from_filename.bat dump-folder "shared.iso"
read_mvs_dump_title_date_note_from_filename.bat dump-folder "shared.iso"

print_mvs_dump_id_title_date_note_filenames_from_hash.bat dump-folder SHA1_OR_SHA256
read_mvs_dump_filenames_from_hash.bat dump-folder SHA1_OR_SHA256
```

Filename/hash searches are exact and case-insensitive.

Hash reverse lookup indexes `mvs.txt`, `mvs.sha1`, and `mvs.sha256`.
The resulting filenames are then traversed to product sections in `mvs.txt`
and joined to date/note metadata.

A filename can map to more than one product and a hash can map to more than one
filename, so multiple rows are preserved when associations are genuinely
different.

See `doc\relationship-tools.md` for the exact row/output semantics.

### Relationship regression fixture

```text
test\test-mvs-dump-relationships\
test\expected-relationships\
test\test_relationship_tools.bat
```

The full test suite now expects **610 assertions** on the 0.8.0 matrix:

```text
Structure:     269
Scalar:        120
Lookup:         24
Diagnostic:     46
Relationship:  151
Total:         610
```


## 0.9.x single-dump completeness milestone

Version 0.9.x adds **154 standalone tools** covering the remaining
single-dump information/presentation layer. The project now has **422 public
standalone `.bat` tools**.

New areas:

```text
Product -> filename -> hash forward traversal
mvs_names.txt variant occurrence records
hash/provenance records from mvs.txt, mvs_names.txt, mvs.sha1, mvs.sha256
raw product-file rows and raw product sections
raw note occurrence records
malformed/unparsed-line reporting
hash-integrity diagnostics
whole-dump summary/statistics
```

Every concrete suggestion from the single-dump completeness review is present,
along with the natural `print_`/`read_` counterpart where machine-readable
output is meaningful.

Examples:

```text
print_mvs_dump_filenames_from_id.bat dump-folder 10
read_mvs_dump_hashes_from_title.bat dump-folder "Product title"
print_mvs_dump_id_title_filenames_hashes_from_id.bat dump-folder 10
print_mvs_dump_sha1_from_filename.bat dump-folder "file.iso"
print_mvs_dump_filename_hash_algorithm_source.bat dump-folder

print_mvs_dump_variants.bat dump-folder
read_mvs_dump_variants_from_id.bat dump-folder 10
print_mvs_dump_id_variant_title_filename_hashes_from_hash.bat dump-folder HASH

print_mvs_dump_hash_records.bat dump-folder
print_mvs_dump_product_files_from_id.bat dump-folder 10
print_mvs_dump_product_sections_from_id.bat dump-folder 10
print_mvs_dump_note_records.bat dump-folder

find_mvs_unparsed_lines_in_mvs.txt.bat dump-folder
find_mvs_hash_mismatch_for_filename_between_mvs.txt_and_mvs.sha1.bat dump-folder

print_mvs_dump_summary.bat dump-folder
read_mvs_dump_statistics.bat dump-folder
```

Hash provenance records retain source, physical line, ID/product title where
available, variant title where available, filename, digest, and algorithm.

The summary/statistics layer reports source presence, product/file/variant/note
coverage, ID/date ranges, SHA-1/SHA-256 counts, reused filenames, variant
multiplicity, note duplicate-heading groups, directional filename orphan
counts, and malformed-line totals.

A new exact regression fixture is under:

```text
test\test-mvs-dump-single-complete\
test\expected-single-dump\
```

and the new subset runner is:

```text
test\test_single_dump_tools.bat
```

The 0.9.1 full suite expects **931 assertions** before any data-dependent skips
from the supplied real dump.



## 0.9.2 ArrayList runtime bugfix

The first Windows 0.9.1 full run proved that the 0.9.0 parse-time failure was
fixed: the embedded single-dump script now compiles. It also exposed the next
shared-runtime defect. All 166 single-dump behavioral checks failed with return
code 5 and the same stderr:

```text
ERROR: You cannot call a method on a null-valued expression.
```

The cause was `New-ArrayList`. Returning a bare empty
`System.Collections.ArrayList` from a PowerShell function emits no pipeline
objects, so callers receive `$null`. The first subsequent `.Add()` therefore
fails.

0.9.2 makes the helper return the collection itself as one object:

```text
return ,(New-Object System.Collections.ArrayList)
```

All 154 single-dump tools were regenerated as tool version 0.1.2. The 268
pre-0.9.0 public tools remain unchanged. The test harness structure check and
the static release validator now both reject a single-dump runtime that lacks
this non-enumerating collection return.

The full test matrix remains 931 assertions. For `mvs_2019-10-16`, three exact
note lookups are data-dependent skips, so the expected clean result is:

```text
SUMMARY: passed=928 failed=0 skipped=3
```

Windows 10 / Windows PowerShell 5.1 validation is now clean: the attached 0.9.2 run completed 928 passed, 0 failed, 3 data-dependent note skips.

## 0.9.1 parser bugfix

The first real Windows 0.9.0 executions exposed a Windows PowerShell 5.1 parser
error in the shared single-dump runtime. One raw-section TSV expression used a
comma-separated cast/function form that prevented the entire injected
single-dump script block from compiling.

0.9.1 rewrites that emitter with the established ArrayList pattern already
used successfully by the earlier relationship tools.

The attached result analysis established that the completed 0.9.0 run had:

```text
765 passed
166 failed
0 skipped
931 total
```

All 166 failures contained the same ScriptBlock.Create parser error.

The real `mvs_2019-10-16` dump also disproved an earlier semantic assumption:
IDs in `mvs_names.txt` are not guaranteed product IDs. Variant tools continue to expose
the source ID as `ID`, but documentation and summary metrics now label that
domain correctly and do not imply product ownership.


### Real-dump reference output

The independent reference parser was run against the archived
`mvs_2019-10-16` dump. Its corrected summary is checked into:

```text
doc\reference-output-mvs_2019-10-16-summary.txt
doc\reference-output-mvs_2019-10-16-summary.tsv
```

Important corrected values include:

```text
products.mvs.sections: 1791
variants.sections: 38136
variants.unique_ids: 38136
variants.ids_matching_product_ids: 203
variants.ids_not_in_product_ids: 37933
integrity.unparsed.mvs_names.txt: 0
integrity.unparsed.total: 0
```

These files are reference outputs from the independent Python parser. The
actual standalone Windows batch runtime still requires the external 0.9.2
Windows test run.


## 0.10.0 two-dump comparison layer

Version 0.10.0 begins cross-snapshot comparison while preserving the validated
0.9.2 single-dump baseline. It adds **19 standalone comparison tools**, bringing
the project to **441 public root `.bat` tools**.

Every comparison tool accepts two dump folders:

```text
compare_mvs_dump_<property>_from_<source>.bat first-dump-folder second-dump-folder
```

The first dump is the old/baseline side and the second dump is the new side.

Normal output contains only differences:

```text
- removed-value
+ added-value
```

All removals are printed first, preserving first-dump source order. All
additions follow, preserving second-dump source order. Values present in both
dumps are omitted. Duplicate occurrences inside one source are collapsed to
set membership.

When stdout is an interactive console, removed lines are red and added lines
are green. When stdout is redirected or captured, the same lines are emitted
as plain text with no ANSI/control bytes.

Comparison families in 0.10.0:

```text
ID:
  mvs.txt
  mvs_ids.txt
  mvs_names.txt
  mvs_dates.txt

TITLE:
  mvs.txt
  mvs_ids.txt
  mvs_names.txt
  mvs_dates.txt

DATE:
  mvs_dates.txt

SHA1:
  mvs.txt
  mvs_names.txt
  mvs.sha1

SHA256:
  mvs.txt
  mvs_names.txt
  mvs.sha256

FILENAME:
  mvs.txt
  mvs_names.txt
  mvs.sha1
  mvs.sha256
```

`mvs_names.txt` IDs remain a textual source-ID domain; they are not coerced to
product IDs. Product-source IDs are normalized numerically. Titles compare
case-insensitively after HTML decode/whitespace normalization. Filenames and
hashes compare case-insensitively; hashes are displayed lowercase. Dates
compare as trimmed source text.

No differences is a successful comparison: stdout is empty and return code is
`0`.

Comparison return codes are:

```text
0  successful comparison, whether or not differences exist
2  invalid/missing arguments or unsupported embedded configuration
3  one of the dump folders was not found
4  the required source file is missing from either dump
5  parse/runtime comparison failure
```

The dedicated synthetic comparison regression suite is:

```text
test\test_compare_tools.bat
```

It validates every comparison tool against an intentionally different
before/after pair and also validates every tool against an identical
before/before pair. The full suite remains:

```text
test\test_all.bat path_to_real_mvs_dump_folder
```

The 0.10.0 full test matrix contains **989 assertions** before data-dependent
lookup skips:

```text
Structure:       442
Scalar:          120
Lookup:           24
Diagnostic:       46
Relationship:    151
Single-dump:     167
Compare:          39
Total:           989
```

See `doc\compare-tools.md` and `doc\compare-tool-matrix.tsv` for the exact
tool list and comparison contract.


## 0.11.0 archive history / all-ever accumulation

Two standalone builders now turn an ordered directory of MVS dump snapshots
into durable source-local history:

```text
build_mvs_dump_change_history.bat mvs-dumps-root output-folder
build_mvs_dump_all_ever.bat       mvs-dumps-root output-folder
```

The first writes separate added/removed TSV ledgers for all 19 comparison
domains. The second writes an all-ever union for each domain with first-seen,
last-seen, and observation-count provenance.

Missing source files are recorded as coverage gaps rather than treated as empty
sets. See `doc\history-tools.md`.

Dedicated Windows regression entry point:

```text
test\test_history_tools.bat
```

The history-only suite contributes **65 assertions**. With the two new
standalone structure checks, the 0.11.0 full suite contains **1,056 total
assertions**; NOTE lookup pass/skip distribution remains data-dependent.

## 0.13.0 performance update

The public root remains 443 standalone tools. 377 generated public tools received performance-only internal changes without changing their interfaces or scopes.

The archive-wide sweep now defaults to a combined executor:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive
```

Use the literal public tools instead with:

```bat
test\test_all_dumps.bat ..\mvs_dumps_archive --external-tools
```

The combined path records `executor=fast-combined`; the literal path records `executor=external-public`. Executor identity is part of the deterministic plan hash and resume safety.

Additional performance utilities:

```text
test\fast\run_snapshot_tools_fast.bat
test\fast\run_compare_tools_fast.bat
test\analyze_archive_sweep_performance.bat
test\test_fast_archive_sweep.bat
```

See `doc\performance-architecture.md`.

## 0.13.2 fast-sweep acceptance-test maintenance

`test\test_fast_archive_sweep.bat` is self-contained and does **not** require
`test\test_all.bat` to be run first. It uses `test\test-mvs-dump-history\`
directly.

The acceptance test now validates UTF-8 metadata with PowerShell rather than
`findstr /x`. On any failure it retains and prints the temporary result folder,
`summary.txt`, `run-info.txt`, and captured sweep log so the failure can be
diagnosed immediately.

The 443 public root tools are unchanged from 0.13.1.
