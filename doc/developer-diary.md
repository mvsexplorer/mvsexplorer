## 2026-09-12 - 0.20.2 caller-root preservation hotfix

The first native 0.20.1 run proved that arbitrary argument capture itself worked,
but exposed a cmd.exe positional-frame side effect. `test_all_dumps.bat` saved
`mvsa_script_root=%~dp0` only after repeatedly executing `shift`. By then `%0`
no longer reliably denoted the batch file. The fast synthetic test consequently
looked for `D:\dev\MVS-Explorer\tools`, while modular maintenance looked for
`D:\dev\MVS-Explorer\mvs_databases\tools`.

The maintained archive-sweep template now snapshots caller identity and script
root before the first shift. The existing argument-transport structure test also
verifies this ordering, so preserving more than nine arguments cannot again
corrupt project-root discovery.

## 2026-09-12 - 0.20.1 native argument transport hotfix

The first native 0.20.0 run exposed two release-integration defects before any
archive rebuild began. The structure harness correctly rejected
`test_product_family_tools.bat` because that maintained regression artifact
still identified project 0.19.3. The later modular create/update invocation
showed a separate command-transport bug: adaptive worker options pushed the
`--cache-folder` value into positional argument 10, while `test_all_dumps.bat`
only copied `%1` through `%9` into its embedded PowerShell environment.

0.20.1 advances the maintained family-regression project metadata and replaces
the fixed archive-sweep argument bridge with an indexed capture/shift loop that
accepts arbitrary option counts. A new structure/static guard rejects restoring
the `%9` truncation pattern. Archive processing semantics and the 34,822-row
known plan remain unchanged.

## 2026-09-08 — 0.19.1 native maintenance validation hotfix

The first native 0.19.0 create/update run successfully completed and committed
the expensive archive analysis (34,822/34,822 rows, FAIL=0), the full family
index, and the compact family index. It then failed immediately at stage 06
because the maintenance component created `database-validation` before invoking
`test_generated_databases.bat`; that validator intentionally rejects an
existing output directory.

The fix removes the premature `Ensure-Directory`. This is an orchestration-only
repair. Archive-sweep, family-builder and compact-builder bytes are deliberately
kept unchanged so the successful 0.19.0 committed work remains reusable by the
0.19.1 retry.

## 0.17.1 - native browser-builder parser correction

## 2026-09-07 — Native HTML acceptance and first PowerShell GUI

The corrected 0.17.1 HTML builder ran successfully on Windows PowerShell 5.1
against the production compact index: 8,201 products, 93 basic families,
150 product families, 61,768 distinct filenames, 80,506 distinct hashes and
820 distinct note texts were written to one offline HTML file.

0.18.0 uses that accepted browser as the desktop interaction contract rather
than inventing a second navigation model. `mvs_explorer_gui.bat` keeps all
PowerShell in the delivered BAT and reads the compact database directly.
Hierarchy metadata is loaded once; large product-file/hash/note tables are
deduplicated into per-title string arrays so hierarchy changes do not repeatedly
scan the database and large evidence views can remain paged.


The first native execution of the 0.17.0 browser builder failed before reading
the compact database because Windows PowerShell 5.1 could not parse
`[Array]::Sort[string](...)`. This was a development-environment gap: the
generated JavaScript and static builder guards were valid, but they did not
exercise the embedded PowerShell parser used by the delivered BAT.

The maintained builder now uses the non-generic `Array.Sort` overload with
`StringComparer.OrdinalIgnoreCase`. A structure assertion and the generated
validator explicitly reject the old generic syntax. The browser model itself is
unchanged; 0.17.1 is a compatibility repair, not a taxonomy or UI redesign.

## 0.17.0 - first self-contained browser surface

The next product step is deliberately browser-first rather than pipeline-first.
The compact family database already contains the conservative taxonomy and the
product-backed file/hash/note evidence needed for useful exploration, so the
first browser can be generated without changing database formats or rebuilding
the archive.

The browser hierarchy uses broad family, product family, release, and exact
historical product title. This maps the requested left-to-right exploration
model onto existing classified relationships. Titles which are source-backed
but not classified are placed in an explicit unclassified/historical bucket;
the browser does not manufacture a family merely to fill a UI column.

The lower pane derives files and hashes only from compact
`product-files-all-ever.tsv` and `product-file-hashes-all-ever.tsv`, preserving
the `mvs.txt` product-section ownership rule. Notes use normalized text while
retaining raw-HTML content hashes as provenance. Search text filters what is
visible in a hierarchy list but does not silently act as selection.

A direct JSON embedding of the compact evidence needed for browsing is already
small enough to be practical when repeated strings are dictionary-encoded.
The current real database produces an approximately 13.8 MiB one-file browser
prototype covering 8,201 exact titles, 61,768 distinct filenames, 80,506
distinct hashes, and normalized notes. The browser paginates large detail
tables rather than pushing every matched file/hash row into the DOM.

The builder is kept outside the production pipeline for this first UX cycle.
That avoids turning layout/interaction changes into fail-gated pipeline
changes before the browser contract has been exercised on native Windows.

## 0.16.5 - stream large family queries and normalize ZIP dates

The native 0.16.4 resume run closes the production-pipeline acceptance loop:
phase 7 passes, the log ZIP is created only after writer disposal, all 57
database checks pass, all 32 public family-query smoke executions pass, and the
final status is PASS.

The same run makes the next performance bottleneck unusually clear. The full
family database contains roughly 513 MiB of `product-files.tsv` and 679 MiB of
`product-hashes.tsv`. The old query helper called `Import-Csv` on the complete
fact table before applying an exact filename/hash predicate. Each reverse query
therefore spent roughly nine minutes manufacturing millions of PowerShell
objects to keep only a small match set. Print/read filename/hash reverse
directions together accounted for about 35.3 minutes of the 46-minute
generated-database phase.

The maintained query library now separates candidate scanning from object
materialization. Common exact patterns are scanned by `Select-String
-SimpleMatch`; candidate lines are then split, the requested field is verified
with the existing matcher, and only verified rows become objects. Wildcard or
escaped patterns use a buffered `StreamReader` fallback so semantics are not
narrowed. Family-to-fact queries use exact member-title candidate scanning for
narrow families and a one-pass title-map scan when a family is broad. The
emitter and deduplication paths are unchanged, and candidate line numbers are
sorted to preserve source-table order.

The 0.16.4 archive ZIP checksum also changed across resume runs even though the
archive database passed all integrity checks. The reason is not evidence hash
instability: archive quality validation removes and recreates its deterministic
`quality-check` output. `CreateEntryFromFile` copied the newly assigned
filesystem last-write dates into ZIP entries, so those metadata bytes changed
the package checksum. Comparing the two supplied archive ZIPs confirms the
diagnosis exactly: all 2,341 entry CRC/size pairs match and only six
`quality-check/*` entry timestamps differ; compressed sizes also match. The
pipeline now creates entries explicitly, sorts entry
names as before, fixes each entry timestamp at the earliest legal ZIP date
(1980-01-01 UTC), and streams the original file bytes into the entry.
Content-addressed raw-HTML hashes remain strict.

## 0.16.4 - defer log ZIP until writers are closed

The native 0.16.3 resume run passed all 487 structure checks, archive quality,
and the full 57-check generated-database gate including all 32 real family
queries. The only failure remained the phase-7 attempt to ZIP the pipeline's
own `console.log`.

The uploaded SEND-ME bundle exposed the decisive ordering detail. The normal
phase-7 ZIP attempt failed while `MasterWriter` and `PhaseWriter` were active,
even though their underlying streams used `FileShare.ReadWrite`. The failure
recovery path then successfully produced the SEND-ME ZIP because the outer
`finally` block had already disposed those writers. The correct invariant is
therefore stronger than share-mode permissiveness: the pipeline must not ZIP
its live log directory at all.

0.16.4 makes the success path follow the proven recovery ordering. The final
collection phase copies logs and creates database hardlinks but does not call
`New-ZipFromDirectory` or `Finish-LogZip`. It records PASS while normal logging
is still available, then the outer `finally` block flushes/disposes both
writers. Final log ZIP creation and the log hardlink occur afterward. A static
structure guard now checks this ordering directly and replaces the ineffective
read-sharing guard. Database contents and console token coloring are unchanged.

## 0.16.3 - active-log ZIP sharing and semantic-token color

The native 0.16.2 resume run proved that the three 0.16.1 database-validator
false negatives were fully corrected: structure passed 486/486, archive quality
reported zero errors, and the generated-database gate passed all 57 checks,
including all 32 real family query tools.

The run then failed only during the final log-bundle phase. The pipeline was
trying to ZIP `console.log` while its master `StreamWriter` remained active.
Windows denied the read with a sharing violation before the normal post-run ZIP
refresh could occur. The maintained pipeline now creates the master console and
phase-performance streams with explicit `FileShare.ReadWrite`. This preserves
live logging while allowing the preliminary ZIP pass; after the phase completes
the writers are disposed and the ZIP is rebuilt once more from settled files.

The same native output showed that coloring an entire line whenever it contained
a status word was visually too strong. 0.16.3 writes normal line fragments in
the console's existing color and changes only semantic status/attention tokens:
PASS green, active failure/error tokens red, and warning/SKIP/quality-flag
tokens yellow. Counters stating zero failures or zero warnings are deliberately
left neutral. Log files continue to contain plain text only.

## 0.16.2 - real-data validator ordering/singleton fixes and console UX


A clean 0.16.1 run from only the original 79-snapshot dump archive passed the
1,094-assertion pre-build suite, completed all 34,822 archive logical checks,
passed archive quality, and built both family indexes. Phase 6 then reported
three false negatives: archive plan/run alignment plus the compact snapshot-set
dictionary and its dependent reference check.

Inspection of the produced archive database showed that `plan.tsv` and
`runs.tsv` contain the same 34,822 unique plan indexes with exact
index/scope/snapshot/tool identity. The physical order differs because parallel
snapshot workers append batches when they finish; in the observed run,
`runs.tsv` began at plan index 845 because the third snapshot completed first.
The validator now joins by plan index, matching the executor contract.

The compact database contains 967 valid snapshot sets, 35 of them singletons,
and every reference across the eight compact fact/detail tables resolves with
exact count/first/last metadata. Windows PowerShell 5.1 had unwrapped a
one-element split result to a scalar string, making `$names[0]` the character
`m`. The validator now uses a typed `string[]` so singleton and multi-snapshot
sets follow the same logic.

The same release improves long-run console ergonomics: paired/timed
Starting/Completed snapshot and compare lines, a quiet phase-1 plan preflight,
and status-aware console colors at the top-level pipeline. Plain-text logs are
kept free of terminal escape sequences.

## 0.16.1 - native pipeline validator hotfix

The first native 0.16.0 end-to-end production run passed the 1,092-assertion
test matrix (1,089 pass, three known note skips), completed all 34,822 archive
logical checks with zero failures, passed archive quality validation, and built
both family databases. The new phase-6 validator then failed because several
hand-compacted PowerShell `return` statements had been written without a token
boundary, producing commands such as `return$true` under Windows PowerShell
5.1. The same defect prevented failure-log packaging through `return$map`.

0.16.1 restores explicit whitespace in both maintained libraries, adds a static
regression guard, and introduces a resume mode that revalidates and packages
already-built databases rather than forcing expensive regeneration after a
late-stage pipeline/tooling defect.

The same native log showed that the DAG test itself compared topological visits
against raw `family-nodes.tsv` rows. Because one family may legitimately have
multiple node roles, the accepted real index has 1,229 rows but only 787 unique
case-insensitive family names. The test now compares against its unique
indegree-key set. An independent replay of real family/compact tests 6-24 then
passes all 19 checks, including the corrected DAG test.

## 0.16.0 - one-command production pipeline

Added a fail-gated root pipeline that runs tests, builds archive/full-family/
compact-family databases to the parent output root, validates real databases,
executes all 32 family query tools, captures end-to-end performance, ZIPs every
database/log bundle, and creates SEND-ME hardlinks in the toolkit root.

Progress reporting now exposes project version plus current/remaining assertion
counts. A new 57-check generated-database gate tests compact reconstructability,
family DAG/reference integrity, raw-note content addressing, archive plan/run
alignment and real query-tool execution.

During release hardening, regeneration exposed that the checked-in
`fast-archive.inc.ps1` and generator version lagged the accepted generated
0.14.4+ worker. The maintained source and generator were synchronized to the
accepted byte behavior before 0.16.0 packaging.

# Developer Diary

## 2026-08-27 — Archive reconnaissance

The source archive was treated as a series of catalog snapshots rather than payload storage. The first toolkit layer was defined around scalar product fields: ID, title, release date, and note.

## 2026-08-27 — Scalar projection set

The four scalar fields produce 15 non-empty projections. Each projection received human `print_` and machine `read_` interfaces. `read_` was established as headerless TSV.

## 2026-08-27 — Standalone rewrite

The first implementation used a shared runtime parser. After the standalone requirement was clarified, every public `.bat` was rewritten to contain its own batch and embedded-PowerShell code.

## 2026-08-27 — Shared source without shared runtime dependency

The standalone rule was clarified again: common functions may be maintained centrally and injected during development.

Version 0.3.0 adopts that model. `dev\library`, `dev\templates`, and `dev\tool-spec.json` are development sources. `dev\generate_tools.py` injects them into public `.bat` files.

This keeps source maintenance centralized while preserving independent public tools.

## 2026-08-27 — Sorted companions

The source-order scalar outputs were functional but inconvenient for browsing. The original order is still useful as source provenance, so it was not removed.

Instead, every scalar tool gained explicit `_sorted_by_id`, `_sorted_by_title`, and `_sorted_by_date` companions.

ID uses numeric ordering. Title uses natural/alphanumeric ordering. Date uses chronological ordering where parseable.

## 2026-08-27 — Lookup family

Seven requested lookup relationships were implemented.

The wildcard contract was deliberately restricted to `*`, matching zero or more characters. The implementation escapes all other characters before translating `*`, which prevents accidental extra PowerShell wildcard syntax.

Multiple matching product rows are ordered by the searched field. Lookup output projects distinct non-empty associated values, one per line.


## 2026-08-27 — Automated Windows test harness

A standalone automated test suite was added under `test\`.

The main entry point is exactly:

```text
test\test_all.bat path_to_mvs_dump_folder
```

Rather than testing one tool by comparing it with another public tool, the test harness parses the dump independently and constructs expected scalar/lookup output.

The scalar test matrix executes all 120 scalar tools. The lookup tests exercise every lookup tool with exact, wildcard-all, and no-match cases, plus explicit prefix/suffix/contains wildcard cases for ID lookup.

Each test batch is generated from shared development-time test source but contains the complete injected harness in the delivered file.


## 2026-08-27 — First external Windows test run

The user ran the 0.4.0 full suite against `mvs_2021-01-12-1901`, which the test expectation parser counted as 2003 products.

The run reported 265 passes and 7 failures. All standalone checks and all scalar behavioral checks passed. Successful lookup and wildcard lookup cases passed.

Every failure was the same no-result lookup return-code issue: empty output was correct, but the command returned `0` rather than `1`.

Version 0.5.0 changes these nonzero contract paths to explicit process-level exits.

The same run demonstrated that a full-suite console transcript is too large to rely on scrollback. Test scripts now create timestamped result bundles containing persistent console, summary, environment, TSV assertion, and failure-artifact files.


## 2026-08-27 — 0.5.0 external Windows result bundle

The user supplied the actual timestamped 0.5.0 result archive from Windows PowerShell 5.1 / Windows 10 build 19045.

The bundle contains 272 assertions:

```text
128 structure PASS
120 scalar PASS
17 lookup PASS
7 lookup FAIL
```

The seven failures are still exclusively the deliberate no-match return-code tests. Their expected/actual/stderr files are all empty; only expected `1` versus actual `0` differs.

The 0.5.0 result retention design is therefore validated, while its return-code fix is not.

Version 0.6.0 removes the indirect nonzero return carrier from `:RunPowerShellFromLabel` and returns the captured PowerShell process code directly. It also adds an explicit top-level nonzero `exit /b` before the normal `GoTo :EOF`.


## 2026-08-27 — Clean 0.6.0 Windows baseline

The user supplied a second timestamped Windows result bundle, this time for
0.6.0 against `mvs_2020-09-15_2` (1984 parsed products).

The return-code repair was validated end-to-end:

```text
272 passed
0 failed
0 skipped
```

This establishes the scalar/lookup layer as a clean regression baseline.

## 2026-08-27 — Duplicate/orphan diagnostic layer

The next milestone expands the toolkit from projection/lookup tools into
integrity diagnostics.

Forty-five standalone diagnostic tools were generated: fourteen duplicate
finders (including the requested singular-date filename plus a canonical
plural alias) and thirty-one directional orphan finders.

The implementation preserves full section context for `mvs.txt` and
`mvs_names.txt`, rather than reporting only keys.

While defining the tools, a crucial semantic distinction was retained:
repeated IDs in `mvs_names.txt` are normally expected one-to-many variant
relationships, and its titles are variant/display titles. The tools report
literal repetition/set differences without declaring them corrupt.

A deliberately inconsistent synthetic dump and an independent Python
expected-output generator were added so every diagnostic tool has a positive
known regression case.


## 2026-08-27 — Clean 0.7.0 Windows baseline

The attached 0.7.0 result archive confirms the expanded diagnostic release is
clean on Windows PowerShell 5.1:

```text
363 passed
0 failed
0 skipped
```

The diagnostic fixture contributed all 46 expected passing assertions. This
becomes the regression baseline for the next layer.

## 2026-08-27 — Filename/hash relationship queries

The user requested reverse traversal from filename or SHA-1/SHA-256 hash into
product metadata, with `print_` and `read_` projection families.

The enumerated projection lists contain 24 unique projection names; `title`
appeared twice in each source list, so the duplicate public filename is
generated once.

For every projection, four tools are generated:

```text
print from filename
read from filename
print from hash
read from hash
```

This adds 96 public standalone tools.

The implementation treats `mvs.txt` as product-to-filename ownership truth.
Hash lookup aggregates observed edges from `mvs.txt`, `mvs.sha1`, and
`mvs.sha256`.

The row model preserves ambiguity rather than forcing a one-to-one join:
hashes can resolve to multiple filenames and filenames can resolve to multiple
product sections.

A dedicated relationship fixture was built so the chosen SHA-1 exists only in
`mvs.sha1`, the chosen SHA-256 only in `mvs.sha256`, and another tested hash
only in `mvs.txt`. This prevents the test suite from accidentally validating
only one hash source.


## 2026-08-27 — Clean 0.8.0 Windows baseline

The attached 0.8.0 result archive contains 610 assertions:

```text
607 passed
0 failed
3 skipped
```

The three skips are only data-dependent exact note lookup cases on the chosen
real dump. All 151 relationship assertions passed. This is the baseline for
0.9.0.

## 2026-08-27 — Single-dump completeness milestone

The remaining single-dump information/presentation suggestions were converted
into 154 standalone tools rather than creating meaningless Cartesian-product
wrapper names.

The new layer covers forward product/file/hash traversal, variant occurrences,
hash provenance, product files/sections, note occurrences, malformed lines,
hash integrity, and whole-dump statistics.

A synthetic fixture intentionally contains duplicate/conflicting hashes,
multiple hash sources, an empty variant section, repeated note headings, and
one malformed line in each supported line-oriented source. All 154 public
tools have fixed positive expected stdout generated independently.


## 2026-08-27 — 0.9.0 Windows parser failure and 0.9.1 repair

Two external Windows runs made the defect deterministic. The complete run
recorded 765 passes and 166 failures. Every failure had the same
`ScriptBlock.Create` parser exception at the raw product-section array
expression.

The failure was introduced once in the shared single-dump PowerShell library
and injected into all 154 new tools. The repair was therefore made once in the
library and regenerated, not hand-edited in public scripts.

The corrected emitter deliberately copies the ArrayList construction style
already exercised successfully by the relationship runtime on the same Windows
PowerShell 5.1 host.

The real 2019 dump also forced a model correction: `mvs_names.txt` IDs occupy a
different numeric domain from product IDs. Documentation and summary metrics
were corrected before treating 0.9.x single-dump output as comparison-ready.


## 2026-08-27 — Numeric-only variant parser corrected

Once the common PowerShell syntax failure was isolated, the independent
reference parser was run against `mvs_2019-10-16`. It initially reported 1,084
unparsed `mvs_names.txt` lines. Inspection showed they were 542 valid
alphanumeric-ID section headers plus 542 associated hash/file rows.

An archive-wide header audit found 492,904 nonnumeric `mvs_names.txt` IDs across
29 snapshots. Product sources remain numeric across the archive, so the parser
was split by source: product IDs remain numeric; `mvs_names.txt` IDs are
preserved as trimmed text.

The synthetic fixture now deliberately uses a separate alphanumeric/hyphenated
variant-source ID domain.


## 2026-08-27 — 0.9.1 compiled, then failed on empty collection return

The external 0.9.1 run moved the failure boundary forward exactly one stage:
the embedded block now compiled, but every one of the 166 single-dump
behavioral assertions failed with rc 5 and `You cannot call a method on a
null-valued expression.`

The shared `New-ArrayList` helper returned a newly constructed but empty
ArrayList directly. PowerShell function output enumeration turned that empty
collection into zero pipeline objects, so assignments received `$null`.

The 0.9.2 repair uses unary comma to emit the collection object itself. The
repair is again made only in maintained shared source and regenerated into all
154 standalone single-dump tools. Existing output expectations do not change.


## 2026-08-27 — 0.9.2 clean Windows baseline and 0.10.0 comparison layer

The attached 0.9.2 Windows run completed all 931 assertions with 928 passes,
zero failures, and three expected data-dependent note skips. All 167
single-dump completeness assertions passed, so cross-dump work can start from a
validated single-snapshot model rather than mixing new comparison behavior with
unresolved parser/runtime defects.

The first comparison layer is deliberately source-local and set-based. It
does not attempt semantic product matching across snapshots. Each public tool
extracts one property from one named source in both dump folders, reports
first-only values as removals, then second-only values as additions.

Console color is presentation only. The `-`/`+` prefixes are the durable
machine-visible markers; redirected output is plain text so tests and pipes do
not inherit console escape sequences.


## 2026-08-27 — 0.11.0 archive history and monotonic all-ever record

The first cross-snapshot comparison layer answered one pair at a time. The next
step turns that primitive into an archive chronology without weakening its
source-local semantics.

Two builders were chosen instead of multiplying the public surface by another
38+ wrappers. One builder records additions/removals for all 19 domains across
every adjacent snapshot; the other produces the monotonic all-ever union.

The important design decision is coverage handling. Older archive snapshots do
not uniformly contain `mvs_names.txt` or SHA-256 manifests. Treating a missing
file as an empty set would make file introduction look like a giant addition
and disappearance look like a giant removal. History therefore skips
incomparable domain transitions and records the gap explicitly.

The all-ever union processes every source wherever it exists. It is seeded from
the first available observation, not only from pairwise `+` events, so baseline
values remain represented. First/last seen and observation counts are retained
for later timeline and Explorer UI work.


## 2026-08-27 — 0.12.0 archive-wide real-snapshot sweep

The deterministic regression suite had reached a clean 0.11.0 Windows baseline,
but most newer families were intentionally exercised against synthetic
fixtures. That left a different unanswered question: can every delivered batch
tool traverse every historical real snapshot without parser/runtime failures?

A brute-force loop over root `.bat` files is not sufficient because the public
surface has three argument scopes. Ordinary tools consume one dump folder,
comparison tools consume two dump folders, and archive builders consume the
archive plus an output folder. Query families also require ID/title/date/
filename/hash search values, and variant IDs are a separate source domain.

The archive sweep therefore profiles each snapshot once, derives representative
query values by source domain, then builds a deterministic execution plan before
launching anything. This keeps the run exhaustive while avoiding meaningless
argument errors.

The supplied archive has 79 snapshots. With 422 single-snapshot tools, 19
comparison tools, and two archive builders, the current sweep contains 34,822
invocations. Successful stdout is intentionally temporary; retaining every
successful scalar/variant dump would create a large duplicate corpus with
little diagnostic value. Actual failures preserve complete stdout/stderr/meta.

Long sweeps also need restartability. `runs.tsv` is appended after every
completed invocation and resume is allowed only when a regenerated plan hashes
identically to the original `plan.tsv`.

## 2026-08-28 — 0.13.0 performance architecture

The first literal 0.12.0 archive sweep proved correctness of the planning layer but exposed a process/algorithm cost that would make 34,822 standalone calls impractical. The first two completed snapshots each consumed roughly 1.8 hours, and summary/statistics alone represented nearly half of observed tool time.

0.13.0 therefore separates compatibility from throughput. Public tools stay authoritative and retain their interfaces, while generated runtimes remove unused parsing and replace expensive membership scans. A second combined executor parses a snapshot once and evaluates the same logical checks in bulk.

The archive sweep now records the executor explicitly. `fast-combined` is the default for the large archive task; `external-public` remains available whenever literal wrapper execution is required. Resume is executor-sensitive so result sets cannot silently mix semantics.

Before Windows release testing, the combined classifier was replayed against all 1,171 rows available from the partial 0.12.0 external run and reproduced every status exactly.
## 2026-08-28 — 0.13.1 fast-worker parser maintenance

The optimized public tools passed the complete Windows regression suite, but the new combined
snapshot worker failed at `[ScriptBlock]::Create()` on Windows PowerShell 5.1. The failure was
isolated to the `Test-HashResult` nested boolean expression. The fast runtime was corrected by
using explicit branch-based matching and the validator now rejects the old expression form.

## 2026-08-28 — 0.13.2 fast acceptance metadata check

The 0.13.1 fast worker cleared the earlier PowerShell parser defect, but the
small acceptance harness stopped at its first metadata assertion. The harness
used `findstr /x` against UTF-8-generated summary metadata. The actual archive
sweep had already returned success, so the brittle assertion layer—not a
missing prerequisite—was the next defect.

The acceptance test now reads metadata using PowerShell `Get-Content -Encoding
UTF8`, and any assertion failure automatically prints and preserves its temp
evidence. The test remains self-contained.


## 2026-08-29 — 0.13.3 archive-tail performance fix

A real 79-snapshot fast sweep reached 34,820/34,822 checks with zero logical
failures, then appeared to stall at `=== Archive builders [literal] ===`.
Inspection of the partial result bundle showed the architecture gap: fast mode
still invoked the two original archive builders separately. Each builder
reparsed the full archive and buffered most output until parsing finished.

The fast executor now uses one streaming archive worker for both logical
builders. History additions/removals are emitted incrementally, all-ever state
is updated during the same source pass, and one progress line is produced per
snapshot. Literal public builders remain unchanged for compatibility mode.

## 2026-08-30 — 0.14.0 indexed archive validation and evidence model

The completed real archive sweep proved that process combining alone was
insufficient: about 30 hours of active computation remained. Timing identified
detail and relationship checks as the dominant cost because they repeatedly
searched already-parsed arrays. The fast worker was rebuilt around
snapshot-local ID/title/filename/hash/variant/note indexes and independent
snapshots gained bounded parallel execution.

The interrupted 0.13.x run also exposed a correctness problem: a source
directory moved after a snapshot model had loaded, allowing later logical rows
in that batch to be classified as `SOURCE_MISSING`. 0.14.0 freezes source
metadata at batch start and rejects the entire batch if availability/length/
last-write metadata changes before commit. Resume then reruns a coherent unit.

Archive analysis now explicitly separates ingestion from canonical
interpretation. Suspicious dumps may be excluded from a selected canonical
scope without deleting their source evidence. Per-dump retention quantifies how
much information introduced by an anomalous dump was or was not seen later.

Notes became a first-class versioned evidence stream. Both legacy h3 headings
with source IDs and newer h1 headings are parsed. Snapshot-level observation
counts prevent duplicate-heavy dumps from inflating note longevity, while raw
HTML is retained by SHA-256 so normalized text does not erase markup history.

A comprehensive tester now joins functional regression, synthetic fast
acceptance, archive integrity/quality analysis, and public/logical/batch timing.
The intended development loop is measured optimize -> regenerate -> rerun ->
verify no functional regression.

## 2026-08-30 — 0.14.1 native acceptance exposed two harness defects

A native Windows 10 / Windows PowerShell 5.1 run of
`test\test_fast_archive_sweep.bat` proved the 0.14.1 metadata serialization
repair. The fast executor completed 1,306/1,306 logical checks with `FAIL=0`
and both metadata files contained the intended executor line.

The next assertion failed because the test queried the `runs.tsv` `tool`
column using `read_mvs_dump_note_records.bat`, while the established plan/run
schema stores the extensionless key `read_mvs_dump_note_records`. The failure
message therefore blamed legacy h3 parsing even though the assertion itself
could not locate the row.

The same native session exposed an independent `test_everything.bat` defect:
its `Run` helper used `$Args` as a formal parameter name. On Windows PowerShell
5.1 this collided with the automatic `$args` variable and the representative
snapshot argument was lost before `test_all.bat` was invoked.

0.14.2 fixes both acceptance-harness defects and also brings the archive
representative-note profiler in line with the existing historical-note model
by recognizing h3+ID headings as well as h1 headings.

## 2026-08-30 — 0.14.2 full archive acceptance isolated the archive builder

The first complete native 0.14.2 full-archive run was clean end to end:
34,822/34,822 logical checks, `PASS=33903`, `NO_RESULT=574`,
`SOURCE_MISSING=345`, and `FAIL=0`. The quality checker independently
confirmed that all 345 missing-source rows were historically expected.

The parallel snapshot executor is no longer the dominant wall-time problem.
Across 79 snapshot batches the median was 116.13 seconds and the maximum was
176.742 seconds; all 78 comparison batches together consumed only about
25.6 seconds. The combined archive-history/evolution worker took
15,224.942 seconds (4 h 13 m 44.942 s), making it the clear next optimization
target.

The worker had already emitted per-snapshot timing lines, but
`Invoke-FastArchiveWorker` redirected stdout to `$null`. That made the
four-hour phase look hung even while files were being created. 0.14.3 routes
those lines through the sweep logger so they are visible and retained.

Inspection of the worker also found PowerShell-heavy inner-loop operations that
are safe to remove without changing evidence semantics: section-state
construction used a pipeline and sort even for the overwhelmingly common
zero/one-file cases; SHA-256 formatting used a PowerShell per-byte pipeline and
created a hasher per call; and every TSV field passed through an extra helper
and ArrayList. 0.14.3 replaces those paths with equivalent .NET operations.

The quality checker itself had a blind spot: it reported the 15,224.94-second
maximum but only classified `single`-scope fast batches as batch outliers.
0.14.3 adds an explicit archive-scope outlier report and separate per-scope
batch summaries.

The completed evidence outputs provide the regression baseline for the next
performance run: 572,143 added records, 474,501 removed records, 648,293
all-ever source-local records, 12,103 product states, 100,139 variant states,
3,974 note versions, 820 note bodies, and 6,210 title/body/raw note variants.

## 2026-08-30 - 0.14.4 archive-builder allocation pass

The direct 0.14.3 native benchmark finished at 13,975,326 ms, 8.20% below the
0.14.2 internal baseline, while producing byte-identical archive evidence
except for the elapsed-time summary. The per-snapshot curve still climbed from
tens of seconds in early dumps to roughly 4-5 minutes in the later dumps.

Inspection showed several high-frequency PowerShell allocation paths:
`PSCustomObject` creation for every unique source-local value, a fresh file
`ArrayList` for every product/variant section, a fresh ID `HashSet` for every
state/title, duplicate title normalization during section finalization, and a
filesystem `Test-Path` for every note raw-HTML observation. 0.14.4 removes
those costs without changing value/state keys or ordering and adds a detailed
phase timing ledger so the next optimization is based on measured parse/union/
diff/note/transition/finalization cost.

## 2026-09-01 — 0.15.0 product-family DAG

Added a separate analytical family layer rather than changing concrete product
identity. The key design choice is a DAG: specific release families can have a
product-family parent and a broad release-rollup parent simultaneously.
Source-backed facts remain normalized against concrete titles; queries join
through membership instead of multiplying file/hash/note rows into every
ancestor family.

The public surface grows by 33 tools, but the original 443 tools are unchanged.
Archive-sweep discovery explicitly removes the new family class before deriving
the 422/19/2 legacy plan.

## 2026-09-01 — 0.15.0 real-title taxonomy coverage pass

Before packaging the family feature, the classifier was measured against the
accepted 0.14.4 `title_from_mvs.txt` all-ever ledger. The first conservative
rules covered only a small part of the real archive because many source titles
begin with `Windows`, `SQL Server`, `Visual Studio`, `Office`, `Dynamics`, and
other product names without the word `Microsoft`.

The classifier now has an auditable curated leading-alias table. Alias matching
is start-anchored and token-boundary constrained; it does not turn embedded
references into ownership. On the 8,123-title baseline, 7,295 titles classify at
high confidence, 314 enter the review tier, and 514 remain unclassified. The
synthetic family regression was expanded from 88 to 92 assertions with explicit
SQL Server, Windows Server, Visual Studio Agents, and Office Online alias cases.

## 2026-09-01 — 0.15.1 real-index release-token audit

Native 0.15.0 acceptance passed the 92-case family suite and the complete public
regression. The generated 79-snapshot family index then exposed a semantic
release-layer problem that the synthetic fixture had not covered: `Get-ReleaseToken`
searched any calendar year before dotted versions and did not distinguish
update metadata. That could turn `.NET Framework 4.6 ... Visual Studio 2013`
into `.NET 2013`, or create `Microsoft Windows 2020` from a Windows 10 title
whose trailing metadata said `Updated Jan 2020`.

The maintenance fix leaves ownership and source-backed observations untouched.
Release inference now considers source order, curated leading versions,
explicit `version` tokens, and an update-metadata boundary. Office Online Server
calendar labels are explicitly treated as update stamps. The synthetic family
suite grows from 92 to 96 assertions so those real-index failure shapes are
permanent regression cases.

The native 0.15.0 run also exposed a documentation-only matrix error: the
history scope contains 65 assertions, not 62. The actual full matrix is 1,090
assertions, matching the observed 1,087 PASS plus 3 data-dependent SKIPs.


## 2026-09-01 — Compact product-family evidence index

The first real family index was intentionally forensic and therefore large:
file/hash facts repeated once per observing dump. The accepted 0.15.1 index
showed that this repetition can be collapsed safely without discarding exact
dump provenance.

0.15.2 adds a second-stage compact builder. Facts are grouped by their complete
source-backed identity and point to reusable snapshot sets. Filename/hash
ambiguity is separated into three meanings: cross-product filename reuse,
same-product hash disagreement, and same-hash/multiple-filename aliases. This
avoids treating ordinary filename reuse as evidence corruption.
## 2026-09-03 — Compact regression fixture correction

Native 0.15.2 evidence showed the real compact index was internally consistent
but the synthetic assertion for row collapse failed. The assertion compared raw
product-hash row count with compact row count, while the compact identity key
also preserves source-local product ID. Every synthetic hash observation was
unique under that complete key, so no collapse was possible in the fixture.

The fixture now repeats one exact product-safe file/hash fact across two
snapshots. This is deliberately a test-only correction: all public tools remain
unchanged, and the real compact index audit confirms exact snapshot-set
reconciliation, conflict/alias derivation, and raw-note hash integrity.

## 2026-09-07 — 0.19.0 application layout and incremental database maintenance

The next requested direction is operational rather than another analytical
relationship layer. The root should behave like an application directory:
utility BATs belong under `tools\`, while GUI/database-maintenance/status
entry points remain easy to find.

The incremental updater therefore uses source bytes as the only safe
"already done" identity. For every snapshot, the seven recognized MVS source
files are SHA-256 fingerprinted; a missing file is part of the fingerprint
rather than silently ignored. Reuse additionally requires the same
archive-processing toolset and a complete prior plan/run ledger containing only
valid terminal statuses. Any changed, incomplete, or failed snapshot is rerun
as a whole snapshot batch.

The updater creates a fresh staging archive-analysis directory, seeds only
proven reusable logical rows, and resumes the existing combined fast sweep for
the remaining plan. Archive-quality validation runs before staging is swapped
into the committed slot. An interrupted staging directory is therefore never a
future source of "already done" evidence and is deleted by the next preparation
stage.

Multiple `mvs_dumps_archive*` roots found in the invocation directory and its
parent receive isolated slots under one `mvs_databases\` root. The launcher
continues to later archives after an archive-specific failure and records a
per-archive status. Full-family/compact indexes are rebuilt only when upstream
data/tool state requires it, but the final database validator still runs before
PASS is recorded.

The workflow is deliberately decomposed into eight BAT components. This makes
each phase directly inspectable/loggable without turning the root into another
large tool list. All run logs are grouped under `logs\` and ZIPped after the
master writer closes, preserving the packaging ordering learned from the
0.16.2–0.16.4 log-sharing failures.

HTML outputs are timestamped in the project root. The desktop GUI now performs
the same current/parent discovery expected of the operational tools: exactly
one compact database is automatic, several require a chooser with Browse, and
zero candidates fall back to the folder picker.

During the release pass, three missing closing parentheses in newly maintained
PowerShell were caught by a static delimiter audit before packaging. After
correction, regeneration changed exactly the three affected generated BATs; a
complete subsequent generator pass is required to remain byte-idempotent.

## 2026-09-10 — 0.19.2 native follow-up

The successful 0.19.1 create/update retry proved the managed incremental path:
all 79 snapshots, all 78 adjacent compare groups and both archive-wide builders
were reusable; family/compact rebuilds were skipped; database validation passed
57/57; timestamped HTML generation completed; and the run ended PASS.

Two presentation/orchestration defects remained. GUI discovery returned a
nested array, so Windows PowerShell treated five candidate objects as one array
object and property enumeration turned `.Path` into a space-separated string.
The summary parser also encountered two `Warnings:` headings and overwrote the
numeric `19` with the first warning-detail line.

0.19.2 flattens GUI candidates, parses only numeric quality counters, separates
tool/project versions, and makes persisted database state authoritative for
summary recency. The unchanged archive stage now exits before the sweep/quality
runner when preparation proves the whole archive reusable.

The supplied full-pipeline log exposed an independent stale regression path:
the synthetic product-family test still invoked query wrappers from the old
root surface after 0.19.0 moved those tools to `tools\`. That regression now
uses the delivered layout.

A managed validation cache is added only after a successful deep validation.
It is invalidated by rebuild markers, validator/query-tool changes, or managed
database metadata changes, and can always be bypassed with `--force-validate`.
Source dump reuse continues to require the existing SHA-256 content
fingerprints; timestamps remain non-evidence.

## 2026-09-11 - 0.19.3 pipeline-gate false-negative correction

Native 0.19.2 use proved the managed updater no-op path and summary corrections,
but the full production pipeline stopped in the test gate with two structure
failures. Both were harness defects: double-quoted expected source fragments
interpolated `$slot`/`$stamp` and `$Root`/`$ToolName` before `.Contains()`.
The delivered HTML stage still created the expected timestamped root browser,
and the final product-family regression passed all 106 semantic assertions from
`tools\`.

0.19.3 changes those assertions to literal-safe comparisons. It also captures
the test-results directory in a `finally` block around the ALL TESTS child
phase, copies it into the pipeline log package, and reports downstream archive
work as explicitly NOT RUN when the test gate fails. No archive/database
processing semantics are changed.

## 2026-09-12 - 0.20.0 adaptive worker controller

The first complete native 0.19.3 production run closed the 0.19.2 test-gate
false negatives: the representative suite completed 1,112 PASS / 0 FAIL /
3 SKIP, the production archive sweep completed all 34,822 logical rows with
zero FAIL, the 57 database checks and all 32 family-query smoke tools passed,
and the overall pipeline completed in 03:18:32.

The run also made fixed concurrency look increasingly artificial. With eight
snapshot workers, early snapshot batches completed around 67-70 seconds while
later batches commonly exceeded 300 seconds. That does not by itself prove
eight workers caused the increase because later dumps are larger, but it is
enough evidence not to encode one machine-wide fixed default.

0.20.0 therefore moves worker choice into a conservative feedback controller.
It begins at one quarter of logical CPUs, samples CPU, free physical memory and
physical-disk idle headroom, and raises the target only one worker at a time
after a 30-second window with at least 15% headroom on all resources and
non-regressing completed-check throughput. If telemetry is missing, scaling
stops safely rather than guessing.

Because this is scheduling rather than result semantics, maintenance reuse also
moves from hashing the sweep orchestrator to hashing the actual result-producing
tool/worker set. A narrowly recognized migration from the accepted 0.19.2/
0.19.3 aggregate avoids making the user's freshly accepted 34,822 rows stale
for no analytical reason.

