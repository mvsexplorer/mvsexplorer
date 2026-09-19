# Development Observation Journal

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
