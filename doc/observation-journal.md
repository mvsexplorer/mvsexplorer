## 2026-09-13 - Native 0.20.2 acceptance exposed presentation and taxonomy costs rather than correctness failures

The 0.20.2 native fresh pipeline passed end-to-end, including all 34,822 archive
checks and 57 generated-database validations. Its 03:18:28 duration was
dominated by the full family index (~83 minutes), archive build (~59 minutes),
and compact family index (~34 minutes), making those builders the appropriate
optimization targets rather than weakening validation or reuse rules.

Assertion-level and scheduler-sample evidence is valuable in files but does not
need to occupy permanent interactive console history. A useful distinction is:
persistent console messages describe completed sections, actionable warnings,
errors, and milestones; transient messages describe in-flight scheduling state;
structured files retain the full telemetry.

A title prefix such as `Windows` is an ecosystem/branding signal, not sufficient
product identity. `Windows Services for UNIX 1.0` and `Windows Rights Management
Services 1.0` demonstrate why generic alias rules must yield to explicit curated
subproduct rules before release grouping.

Language is similarly evidence-sensitive. A title ending in `(English)` can
support an English analytical/UI layer, while a title without an explicit
language marker must remain `Language not specified`; filenames or adjacent
records must not fill the gap.

## 2026-09-12 - Native adaptive invocation crossed cmd.exe's ninth-argument boundary

Composable CLI options can turn a previously safe `%1`..`%9` batch bridge into
silent truncation without changing any individual option. The 0.20.0 adaptive
maintenance preflight placed `--cache-folder` at argument 9 and its directory at
argument 10. Batch wrappers that forward extensible option sets must therefore
capture/shift arbitrary arguments instead of enumerating a fixed positional
ceiling.

## 2026-09-10 — native 0.19.1 follow-up

### PowerShell array shape is part of GUI correctness

Returning `,@($items)` from candidate discovery preserves the array as one
pipeline object. When a `[object[]]` parameter receives that object, `Count`
can be one even though the nested array contains several candidates. Accessing
`.Path` on the nested array enumerates all member paths, and casting the result
to string produces one space-separated invalid path. The database chooser needs
a flat sequence instead.

### Human summaries may repeat labels

The archive quality text contains a numeric `Warnings:` counter and later a
second `Warnings:` heading introducing detail lines. A parser that blindly
assigns the next line for every matching heading will replace `19` with the
first warning message. Machine-facing extraction must accept only the numeric
counter.

### Directory timestamps are not reliable database recency

Updating a child file does not necessarily make a parent database-root
directory timestamp a useful semantic update marker. The persisted
`database-summary.json.updated` field is the appropriate source for choosing
and displaying the latest maintained database root.

### A no-op maintenance run should stop at proof of no work

Once all source-content fingerprints, plan rows, compare groups and archive-wide
builders are proven reusable, executing the sweep again just to copy/revalidate
identical archive output adds latency without new evidence. The proof produced
during preparation is sufficient to retain the committed archive analysis.

### Relocation regressions must test callers, not only files

The 0.19.0 move to `tools\` left the utility BATs valid, but a dedicated
product-family regression still looked in the root. Layout migrations require
tests that exercise representative callers after generation, not only presence
checks.

## 2026-09-08 — first native 0.19.0 managed-database run

The first `create_or_update_mvs_database.bat --workers 8` run discovered the
79-snapshot `mvs_dumps_archive`, generated and completed the established 34,822
logical archive plan, and committed archive analysis with 33,903 PASS,
574 NO_RESULT, 345 expected SOURCE_MISSING, and 0 FAIL. Archive quality passed
with the established 19 advisory flags and 0 errors.

The same run then built and committed the full family database
(products=7,609; memberships=18,805) and compact database
(files=178,456; product-file-hashes=197,600; global-file-hashes=80,941;
conflicts=26). Stage 06 did not execute database validation because the caller
pre-created the validator's collision-guarded output directory. That is an
orchestration defect, not evidence of database corruption; 0.19.1 corrects the
directory-ownership contract while preserving the processing toolset bytes for
reuse.

# Development Observation Journal

## 2026-09-07 — native browser-builder compatibility

### Static generation checks do not replace the target PowerShell parser

The first 0.17.0 native browser build failed before database ingestion because
Windows PowerShell 5.1 does not parse generic static-method invocation syntax
used by `[Array]::Sort[string](...)`. The same ordering can be expressed with
the non-generic `Array.Sort(Array, IComparer)` overload and
`StringComparer.OrdinalIgnoreCase`.

Browser-builder structure validation now guards both sides of that lesson: the
PS5.1-safe marker must be present and the incompatible generic marker must be
absent.

## 2026-09-07 — browser exploration layer

### The compact family database is already a sufficient browser source

A useful first browser does not need a new database format. The compact family
index already provides taxonomy, exact titles, IDs/dates, product-backed
files/hashes, historical notes, and observed ranges.

### UI hierarchy must not strengthen data semantics

Broad family -> product family -> release -> exact title is a presentation of
existing classification. Unclassified historical titles must remain explicit
rather than being heuristically forced into the hierarchy.

### Search text and selection are different concepts

Filter-as-you-type should reduce visible list rows. It should not silently
change the evidence set until the user selects a value; otherwise typing becomes
an invisible query predicate with surprising downstream effects.

### One-file HTML is practical with dictionary encoding

The large tables contain heavy repetition. Integer references to shared
filename/hash/note dictionaries keep the browser payload far smaller than
embedding raw TSV observations while preserving the values needed by the UI.

### Large result sets should be paged at rendering time

Holding the compact data in memory is acceptable, but creating tens of
thousands of DOM rows on each selection change is not. Pagination keeps the
browser responsive without discarding applicable evidence.

## 2026-08-27

### Source order and sorted order serve different purposes

Source order preserves provenance from `mvs_ids.txt`. Sorted order improves exploration. Explicit companion tools preserve both.

### Sort key should be independent of projection

A tool can print NOTE while sorting by TITLE. Sorting therefore belongs before projection in the data pipeline.

### Natural title sorting is preferable to plain lexical sorting

Product titles often contain version numbers. Plain lexical ordering can put `10` before `7`; natural/alphanumeric ordering better matches user expectation.

### Date ordering should parse rather than merely compare strings

ISO-like source values often sort lexically, but zone and representation differences make chronological parsing more robust. The emitted source string should remain unchanged.

### Wildcard syntax should be intentionally small

The requested wildcard behavior is `*`. Reusing PowerShell `-like` directly would silently expose bracket expressions and other wildcard semantics.

Escaping first and translating only `*` provides the requested language and nothing more.

### Duplicate lookup target values are not useful row identity

A lookup that returns only a target field cannot explain why the same target appears twice. Current lookup tools therefore emit exact distinct non-empty target values. A future row-level lookup/report should include ID if multiplicity matters.

### Missing target and missing source match are collapsed at lookup output level

A matched product can have no note under the title-based note join. Lookup tools omit empty targets and return `1` when no non-empty associated value is emitted.

### Generated standalone files solve the maintenance/deployment tension

There are now 127 public tools. Manually synchronizing common functions would be error-prone. Development-time generation keeps one maintained common source while producing independent deliverables.

### Tool discovery is becoming a project concern

The scalar matrix alone produces 120 tools: 15 projections × 2 output modes × 4 orderings. A machine-readable tool catalog is now useful and will be even more important for MVS Explorer GUI integration.

### Windows runtime testing remains required

Static validation can verify generation, labels, CRLF/BOM, injection, naming, and obvious dependency leakage here. Actual `cmd.exe` and Windows PowerShell execution should be part of Windows milestone testing.


### Testing public scripts requires invoking `cmd.exe`, not only testing parser functions

A parser-only unit test can pass while a generated batch wrapper, environment handoff, return code, or output stream is broken. The automated suite therefore launches each actual public `.bat`.

### Capturing both stdout and stderr can deadlock if done sequentially

Some scalar outputs can be large. The test harness reads redirected stdout and stderr asynchronously before waiting for completion.

### Dynamic command data should not be concatenated directly into test command source

Dump paths and lookup patterns may contain spaces or parser-sensitive characters. The harness transports these through child-process environment variables and uses a fixed `cmd.exe` command form.

### Exact output tests intentionally include empty machine fields/lines

For projections such as NOTE-only machine output, missing notes legitimately create empty records. Whole-stream comparison preserves those cases instead of using `for /f`, which would silently discard empty lines.


### The first Windows run isolated a bridge return-code defect

The 0.4.0 run passed structure, scalar output, exact lookup, and wildcard lookup behavior. Only lookup no-result return codes failed.

This demonstrates why behavioral tests must assert return code as well as stdout.

### Full-suite console scrollback is not a durable test record

A long run should leave a self-contained timestamped bundle. This makes failures reproducible, comparable, and shareable without copying terminal output manually.

### Failure artifacts should remain lossless

The console may abbreviate a large expected/actual mismatch, but stored expected/actual/stderr files should preserve the complete streams.


### A correct inner exit does not prove the external batch exit contract

The 0.5.0 lookup block explicitly requested process exit `1`, yet the calling test process still observed `0`.

The practical lesson is to simplify and verify every return boundary, not merely the innermost one.

### The timestamped result bundle is now validated by real use

The attached 0.5.0 archive was sufficient to isolate the problem without relying on console scrollback: environment, assertion table, full failure metadata, expected output, actual output, and stderr were all preserved.

### The return path should be simpler than the cleanup path when no cleanup exists

`RunPowerShellFromLabel` needs no cleanup after `powershell.exe` returns. Directly returning the captured code is clearer and removes one re-entry/parse transition.


### Repetition is not the same thing as invalid duplication

`mvs_names.txt` has its own numeric ID domain. Those IDs must not be
interpreted as product IDs merely because some numeric values overlap. A
duplicate-ID finder over that file is therefore a literal source-ID repetition
check, not a product one-to-many check.

Diagnostic naming should describe the mechanical question without overclaiming
that every result is an integrity defect.

### Title domains differ across source files

Product-level sources (`mvs_ids.txt`, `mvs_dates.txt`, `mvs.txt`) and
`mvs_names.txt` do not generally use titles at the same semantic level.
Variant/display headings can differ legitimately from product titles.

A title-orphan result across those domains is a literal string-set difference,
not automatically a broken product link.

### Section context is necessary for actionable diagnostics

An ID or title by itself is insufficient in `mvs.txt`/`mvs_names.txt`.
Preserving all associated lines makes duplicate/orphan reports useful for
hash/filename investigation.

### Positive synthetic inconsistency is valuable

Real dumps may contain no example of a particular defect. A purpose-built test
dump can force every finder down its reporting path while fixed expected output
turns those paths into exact regression contracts.

### Flat SHA manifests are filename reference sets in this phase

The current orphan comparisons against `mvs.sha1`/`mvs.sha256` answer whether a
filename is present in the flat manifest. They do not yet assert variant-level
hash equivalence.


### Filename is a relationship edge, not a unique product key

The archive already demonstrates filename reuse across product IDs. A
filename-driven query must therefore preserve multiple owning products.

### Hash-to-filename can also be one-to-many

Flat manifests and section data can theoretically associate one digest with
more than one filename. The reverse query should emit every observed filename,
not arbitrarily select one.

### Matching filenames do not prove matching hash algorithms

A SHA-1 and SHA-256 that share a filename may describe the same media, but the
source files do not provide an explicit digest-pair identity. The relationship
layer therefore indexes observed hash->filename edges independently.

### mvs.txt is the right product-title ownership source for this family

`mvs_names.txt` IDs can identify owning products, but its headings are
variant/display titles. Using those headings as product titles would mix title
domains and make `title_from_filename` ambiguous.

### Exact relationship search avoids accidental wildcard syntax

Filenames commonly contain punctuation. Exact case-insensitive matching keeps
the query contract predictable and distinct from the explicit `lookup_`
wildcard family.

### Hash-source tests must isolate provenance

If the same test digest appears in both `mvs.txt` and `mvs.sha1`, a broken
manifest parser could go unnoticed. The synthetic fixture assigns the primary
SHA-1, SHA-256, and mvs.txt-only test hashes to distinct source paths.


### A complete single-dump model needs occurrence and provenance identities

Product IDs identify products. Variant records require their own source ID
plus section occurrence, and hash records require source/physical-line
provenance. Flattening these identities—or treating the variant-source ID as a
product foreign key—would lose or invent relationships before comparison.

### Forward traversal must gather all observed hashes for a product filename

A product-selected filename can have hash observations in section data and
flat manifests. Forward product queries therefore use the product ownership
edge from `mvs.txt` and then collect observed hash records by filename.

### Raw occurrence views and convenience views should coexist

Combined product notes are useful, but raw note occurrences are necessary for
source-faithful inspection. The same principle applies to normalized product
file rows versus raw product sections.

### Malformed records must be visible before comparison

Cross-dump comparison should not silently compare only successfully parsed
records. Per-source unparsed-line reports and summary counts make parse loss
observable first.

### Real-dump execution exposed a source-ID domain error before comparison

On `mvs_2019-10-16`, the independent parser sees 1,791 product IDs with a
maximum of 6,658, while `mvs_names.txt` has 37,594 distinct source IDs extending
to 86,083. Only 203 numeric values overlap. This disproves the earlier
assumption that the `mvs_names.txt` ID is an owning product ID.

Exact filename+hash pairs from that dump can be matched back to `mvs.txt`, but
some pairs are reused by multiple products. Product-to-variant ownership must
therefore be represented as a derived, potentially ambiguous relationship.


### Source-specific ID syntax matters

The same textual marker `[ID: ...]` does not imply the same value type in every
source. Across the archive, product sources use numeric IDs, while
`mvs_names.txt` has hundreds of thousands of alphanumeric source IDs.

A generic numeric header parser can therefore convert valid source records into
false "unparsed" diagnostics. Parser rules should follow the source schema, not
the visual label alone.


### The mvs_names ID domain changes across generations

`mvs_2019-10-16` has 38,136 distinct `mvs_names.txt` IDs for 38,136 sections,
including 542 nonnumeric IDs; only 203 numeric values overlap its 1,791 product
IDs.

By contrast, `mvs_2020-09-23` has 46,868 sections but only 1,965 distinct
`mvs_names.txt` IDs, and all 1,965 are present in the product-ID set.

Therefore neither universal claim is safe: the field is not always a product
ID, but it can become product-like in later dump generations. Preserve the
source value and measure/derive relationships per dump.


### Empty collections are not neutral PowerShell function return values

A function that directly returns an empty collection can emit zero pipeline
objects. The caller can therefore receive `$null` rather than an empty
collection, and a later method call such as `.Add()` fails.

For helper factories that must return a mutable collection object, suppress
enumeration explicitly (for example with unary comma) or construct the
collection directly at the assignment site. Static validation should encode
this requirement when the helper is injected into hundreds of standalone
tools.


### First cross-dump comparison should remain source-local

A source-local set difference answers a precise question without inventing
cross-snapshot identity: what values disappeared from this source, and what
values appeared in the same source? More complex product/variant matching can
be layered later without changing these basic facts.

### Color must not contaminate redirected comparison output

Red/green console presentation is useful interactively, but terminal control
sequences would make exact tests, files, and pipelines harder to consume.
Console-aware coloring keeps the durable output contract as plain `- value` /
`+ value` lines.

### mvs_names ID comparison must preserve the corrected source domain

The 0.9.x real-dump work proved that `mvs_names.txt` IDs are not universally
product IDs. Cross-dump comparison therefore treats them as case-insensitive
text, while product-source IDs continue to use numeric normalization.


### Missing source is not equivalent to empty source in archive history

Across a long-lived dump archive, source-file availability changes. Pairwise
set difference is meaningful only when the source exists on both sides.
Converting "file unavailable" into "set has zero members" creates artificial
mass removals/additions that describe collection coverage rather than catalog
change.

History therefore needs an explicit coverage dimension.

### An all-ever union must include the baseline, not only observed plus events

The oldest available snapshot has no preceding dump, so its values can never
appear as `+` events. A "complete record of everything ever seen" must seed from
the first available source snapshot and then monotonically absorb later values.

### Source-local accumulation remains necessary after many snapshots

Accumulating more data does not make incompatible source domains compatible.
In particular, textual `mvs_names.txt` IDs and variant titles must remain
separate from product ID/title domains even when both have been observed across
the full archive.


### Archive snapshot roots can contain a nested mvs_dmp source root

The known `mvs_2020-08-20` and `mvs_2020-08-27` snapshots place their source
files under `mvs_dmp\`. Archive-wide processing must resolve both the ordinary
snapshot-root layout and this nested layout before declaring a source missing.


### "Run every tool" requires scope-aware dispatch

The public root contains single-snapshot tools, adjacent-pair comparison tools,
and archive-level builders. Treating every `.bat` as if it accepted the same
arguments tests the dispatcher rather than the tools.

### Real-archive sweeps need representative search values

Query tools require source-domain values. Product IDs/titles, variant IDs,
notes, dates, filenames, and hashes cannot be substituted for one another just
because they are all strings at the batch boundary. One profile per snapshot is
enough to derive valid representative inputs for all query families.

### Missing historical source and runtime failure are different outcomes

An old snapshot that predates `mvs_names.txt` or `mvs.sha256` can legitimately
produce the documented source-missing return code. Archive-wide execution should
record that explicitly rather than count it as a parser/runtime defect.

### Exhaustive validation does not require retaining exhaustive stdout

A 34,822-invocation sweep would duplicate large product/variant listings many
times if every successful stdout stream were kept. For compatibility testing,
status, return code, byte counts, and full failure artifacts are sufficient.
Archive-builder datasets are durable outputs and should be retained.

### Long validation plans should be resumable by immutable plan identity

Resuming by row number alone is unsafe if snapshots or tools have changed.
Hashing the complete deterministic plan makes an interrupted run resumable
without silently changing its work definition.

### Literal standalone execution is not the right unit for a 34,822-check archive audit

The 0.12.0 partial run established that wrapper-level process startup, repeated parsing, repeated enrichment, and large temporary stdout writes compound dramatically over tens of thousands of calls. Correct public tools can remain independently executable while a separate bulk executor reuses parsing for the archive-wide task.

### Summary/statistics exposed quadratic-style membership work

Early snapshots showed roughly 13.4–14.1 minute summary/statistics calls. Repeated PowerShell array membership inside large loops is unsuitable for this scale; HashSet-backed membership is the correct primitive for repeated existence checks.

### Fast logical validation and literal wrapper validation are different guarantees

The combined executor is appropriate for status-level archive coverage. Literal wrapper output/return-code behavior remains covered by the normal regression suite and, when desired, the archive sweep's `--external-tools` mode. Result metadata must make that distinction visible.
### Fast combined PowerShell must be parser-tested separately from public-tool regressions

A clean regression run of all public tools does not exercise the embedded PowerShell inside
`test\fast\` workers. Parser-sensitive constructs in combined workers therefore need dedicated
Windows acceptance and static regression guards in addition to the normal public-tool suite.

### Acceptance-test diagnostics must survive assertion failures

A wrapper-level test can fail after the system under test has already
succeeded. Metadata assertions therefore need their own robust encoding-aware
reader, and failure paths must expose the temporary result directory instead
of silently leaving it under `%TEMP%`.

## 2026-08-30

### Snapshot parsing once is not enough if every query still scans the model

The first combined executor eliminated thousands of PowerShell process starts
but still spent most of its time repeatedly filtering large arrays. Reusable
indexes are the correct unit for high-volume logical validation.

### Parallelism should follow algorithmic optimization

Independent snapshots are safe parallel work units, but concurrency should not
be used to hide quadratic or repeated-scan behavior. Index first, then apply a
bounded worker count.

### A missing source during a worker is not historical evidence

Source availability is a property of the snapshot being tested, not of a
momentary filesystem race. Freeze the inventory, validate it before commit, and
discard the complete batch if the underlying files change.

### Exclusion and ingestion are different operations

A dump can be unsuitable as a canonical transition while still containing
unique historically valuable evidence. Canonical exclusions must therefore
never mean physical skipping. Per-dump “never seen later” counts make the cost
of an exclusion visible.

### Notes need version and occurrence provenance

A latest-note-only model loses one-off historical text. A normalized-text-only
model can also lose meaningful markup changes. Keep occurrence provenance,
snapshot-level version counts, normalized text hashes, and raw HTML hashes.

### Source-level variant IDs are regime-dependent evidence

Large adjacent re-ID percentages with stable variant content demonstrate that
`mvs_names.txt` IDs cannot be treated as permanent variant identity. Preserve
them as source provenance and compare variants by independently normalized
content state.

### Performance regression needs both logical and batch timing

Per-check timing finds expensive predicates after a model is built. Batch wall
time captures parsing/index construction and pathological snapshots. Both are
needed to understand where fresh-run time went.

### Acceptance assertions must use the persisted schema, not display filenames

`runs.tsv` intentionally stores extensionless tool keys. An acceptance check
that supplied a `.bat` filename produced a false-negative and a misleading
legacy-note error message. Tests that validate persisted rows should use the
schema's canonical key format.

### PowerShell automatic-variable names are unsafe formal parameter names

Using `$Args` as a helper parameter obscured the intended array on Windows
PowerShell 5.1. Internal helper parameters should avoid automatic variable
names such as `$args` even when case differs.

### Representative query profiling must understand every historical source form

The fast worker and archive evidence parser already understood legacy
`<h3>Title [ID: ...]</h3>` notes, but the archive sweep's representative-value
profiler only recognized `<h1>`. Profiling and execution parsers need the same
historical heading vocabulary or valid checks can be planned as no-result.

## 2026-09-01 — Family classification observations

Product-family ownership cannot safely be derived from arbitrary substring
matches. Titles that merely reference "Microsoft Office" are retained as
unclassified in the synthetic guard cases. Curated structural prefixes receive
high confidence; unmatched Microsoft-leading stems enter a review tier.

A release rollup such as `Microsoft Office 2007` is analytically different from
the product family `Microsoft Office Communications Server`. The same concrete
title may legitimately belong to both via separate DAG edges. Product IDs and
dates retain snapshot/source provenance and are not promoted to cross-snapshot
identities.

### Family aliases should canonicalize source-leading names, not substrings

The real archive frequently omits `Microsoft` from product-leading titles.
Useful family coverage therefore needs curated aliases such as `SQL Server` ->
`Microsoft SQL Server` and `Office` -> `Microsoft Office`. The safe boundary is
structural: the alias must begin the normalized title and end on a token
boundary. Embedded references remain insufficient evidence of ownership.

Coverage itself is a measured archive property, not a hard-coded invariant.
The accepted 0.14.4 title ledger measures 7,295 high-confidence, 314 review, and
514 unclassified titles out of 8,123; future snapshots may change that mix.
## 2026-09-06

### Parallel completion order is not plan identity

A concurrent executor may append successful batch results in completion order.
Validation must join `runs.tsv` to `plan.tsv` by the stable plan index rather
than assuming physical row order. Ordering is presentation; the index is the
identity key.

### PowerShell singleton unwrapping can invalidate list logic

An expression that emits one object may become a scalar under Windows
PowerShell 5.1. Snapshot-set parsing must force a typed array before using
indexing semantics; otherwise `$names[0]` on a string returns its first
character rather than the first snapshot name.

### Preflight should remain complete without duplicating long visual output

The real archive plan is worth validating before expensive builds, but an
automated preflight does not need to print every snapshot name. A quiet-plan
mode preserves the safety gate while reserving detailed planning output for the
production plan that is actually persisted.

### Long-running progress should have paired lifecycle messages

`Starting X ...` and `Completed X in N s ...` makes concurrent work easier to
follow than section banners followed by detached aggregate progress lines.
Completion time belongs on the same line as the item identity.

### Console color should not contaminate retained logs

Status color is a presentation concern. Applying console foreground colors at
the top-level writer keeps PASS/FAIL/WARN visually distinct while writing the
same plain text to log files.

## 2026-09-07

### Full-table object materialization dominated real family-query latency

The accepted 0.16.4 performance ledger shows exact filename/hash reverse queries spending minutes in eager `Import-Csv` over 500-700 MiB TSVs. Candidate-first scanning is a much better fit because the useful result set is tiny compared with the source table.

### Candidate prefilters must be verified at the real field boundary

A literal substring scan is safe only as a prefilter. Every candidate is still checked against the requested TSV field with the public matcher, which prevents matches in another column or inside a longer field from changing behavior.

### ZIP timestamps are not evidence

Archive quality output is deterministic in content but is regenerated during validation. Copying its new filesystem timestamps into ZIP entries made the package checksum look unstable. Normalizing ZIP dates fixes this packaging artifact without weakening content-addressed evidence hashes.

### A desktop browser should reuse archive semantics, not re-interpret them

The accepted HTML hierarchy is an interaction layer over the compact family
database, not a new evidence model. A WinForms version can therefore read that
database directly and reuse broad family, product family, release, exact title,
product-backed files/hashes and title-level notes without creating new joins.

### Compact runtime indexes are preferable to row-object materialization

The compact file/hash tables contain hundreds of thousands of facts but only
need a few fields for browsing. Deduplicated strings grouped by product title
provide a substantially smaller PowerShell object graph than one PSCustomObject
per row, while still retaining every exposed filename, algorithm and hash.

### Fixed worker counts hide machine and workload differences

The native 0.19.3 archive sweep used eight workers throughout. Snapshot wall
times grew from about one minute in early dumps to more than five minutes for
some later dumps, while compare batches remained sub-second and the archive
builder was single-process. Snapshot size growth is a confounder, so these
timings do not justify a simplistic claim that eight workers caused slowdown.
They do justify replacing a universal fixed default with measured resource
headroom and throughput feedback.

### Scheduler bytes are not result semantics

`test_all_dumps.bat` owns orchestration, progress, and concurrency. A change in
those concerns should not invalidate already accepted logical rows when the
public result-producing tools and fast worker implementations are unchanged.
The maintenance fingerprint should therefore follow semantic producers rather
than the scheduler wrapper. Legacy-fingerprint migration must still be exact
and enumerated; compatibility cannot be inferred from version labels alone.

### Missing performance telemetry should reduce ambition

Adaptive scaling is allowed only when CPU, memory, and physical-disk headroom
are all observable. Treating a failed performance counter as spare capacity
would make the controller least safe on the systems where telemetry is least
reliable.

