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
