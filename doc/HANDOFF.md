# MVS Explorer Toolkit — Development Handoff

**Handoff date:** 2026-08-30  
**Current development tree:** 0.14.1 maintenance work  
**Last packaged public baseline tested on Windows:** 0.14.0 public tools  
**Target runtime:** Windows 10 / Windows PowerShell 5.1 / `cmd.exe`

This document is intended to let another developer or assistant continue the project
without relying on chat history.

---

## 1. Project objective

MVS Explorer Toolkit is a collection of standalone Windows batch tools for inspecting,
querying, comparing, validating, and accumulating information from historical MVS dump
snapshots.

The current delivered public surface is **443 standalone root `.bat` tools**:

- 422 single-snapshot tools
- 19 two-snapshot comparison tools
- 2 archive history/all-ever builders

The project is also evolving toward a higher-level **MVS Explorer** application. The
console toolkit remains the authoritative low-level data/behavior layer.

Public batch files must remain standalone: they may be generated from shared development
source, but a delivered public root `.bat` must not depend on `dev\` at runtime.

---

## 2. Current status

### 2.1 Public-tool baseline

The 0.14.0 public root tools are byte-for-byte identical to the supplied 0.13.3 baseline.

Windows regression run:

```bat
test\test_all.bat ..\mvs_dumps_archive\mvs_2018-10-04
```

Result:

```text
PASS   1053
FAIL      0
SKIP      3
TOTAL  1056
```

The three skips are the existing data-dependent exact note-lookup cases.

Therefore the current public tool behavior is considered regression-clean.

### 2.2 0.14.0 fast synthetic sweep result

`test\test_fast_archive_sweep.bat` ran the actual fast-combined executor to completion:

```text
planned logical checks: 1306
PASS:                  1282
NO_RESULT:               24
SOURCE_MISSING:            0
FAIL:                      0
HTML report:             generated
```

The acceptance script then failed its **metadata assertion**, not the fast executor.

Observed 0.14.0 metadata:

```text
summary.txt:
Executor:
fast-combined

run-info.txt:
all fields serialized on one physical line
```

The root cause is Windows PowerShell 5.1 array-expression behavior around
unparenthesized string concatenation.

### 2.3 0.14.1 maintenance state

The current 0.14.1 development tree fixes the producer rather than weakening the test.

Maintained and generated archive-sweep code now uses parenthesized values such as:

```powershell
('Executor: ' + $Executor)
('Sweep script: ' + $Caller)
```

The strict acceptance test remains in place.

**Native Windows acceptance of 0.14.1 has not yet been observed in this handoff.**
That is the first continuation task.

All 443 public root tools remain unchanged from 0.14.0 / 0.13.3.

---

## 3. Immediate next actions

Run these in this order from the 0.14.1 project root.

### Gate A — fast synthetic archive

```bat
test\test_fast_archive_sweep.bat
```

Expected behavior:

- executor metadata assertion passes;
- all 1,306 logical checks complete;
- FAIL remains 0;
- evolution outputs are validated;
- note-history assertions pass;
- archive quality checker passes;
- `archive-summary.html` is generated.

If this fails, use the printed retained `%TEMP%\mvs-fast-sweep-test-*` directory.
Do not weaken the test to hide a producer-format defect.

### Gate B — comprehensive non-full archive cycle

```bat
test\test_everything.bat ..\mvs_dumps_archive
```

This should run:

1. public functional regression;
2. public performance analysis;
3. fast synthetic archive acceptance;
4. real-archive plan/integrity checks.

### Gate C — fresh complete real archive

Once Gates A and B are clean:

```bat
test\test_everything.bat ..\mvs_dumps_archive --full-archive --workers 8
```

The full acceptance run should be **fresh** (`--no-cache` internally for the full
performance baseline) and should complete start-to-finish without filesystem moves or
manual interruption.

The user explicitly wants at least one full start-to-finish clean run before treating the
archive execution path as stable.

### Gate D — quality/performance verification

For the resulting archive-sweep folder:

```bat
test\check_archive_sweep_quality.bat result-folder --strict-performance
```

Then build/rebuild the report:

```bat
test\build_archive_html_report.bat result-folder
```

Preserve the full result directory/ZIP as acceptance evidence.

---

## 4. Public compatibility contract

Performance work on existing public tools must **not** change:

- public filename;
- argument count/order/meaning;
- scope;
- stdout format;
- stderr behavior;
- return-code contract;
- help aliases.

Public help aliases:

```text
--help
-h
-?
/h
/?
```

The public root count stays at **443** unless a new public feature is separately approved.

High-performance combined utilities may have a different interface, but they belong under
`test\fast\` and are not public root tools.

`test\test_all_dumps.bat` must keep both execution modes:

```bat
test\test_all_dumps.bat archive-root
test\test_all_dumps.bat archive-root --external-tools
```

- default: `fast-combined`
- compatibility/reference path: `external-public`

Executor identity is part of plan/run metadata and resume identity.

---

## 5. Archive/data-model invariants

### 5.1 Snapshot layout

Current archive:

- 79 snapshots
- first: `mvs_2018-10-04`
- last: `mvs_2022-10-07-1939`
- two snapshots use nested `mvs_dmp\` source layout:
  - `mvs_2020-08-20`
  - `mvs_2020-08-27`

Future snapshot discovery must remain dynamic. Do not hard-code 79.

### 5.2 Source coverage

Known historical source coverage:

```text
mvs.txt          79/79
mvs_ids.txt      79/79
mvs_dates.txt    79/79
mvs_notes.html   79/79
mvs.sha1         79/79
mvs_names.txt    76/79
mvs.sha256       61/79
```

Missing historical sources are coverage facts, not errors.

### 5.3 Product IDs

Numeric IDs in `mvs.txt`, `mvs_ids.txt`, and `mvs_dates.txt` are product-level IDs.

Product titles are not unique.

Do not use a product ID by itself as long-term product identity across snapshots.

### 5.4 `mvs_names.txt` IDs

The source ID in `mvs_names.txt` is **not a stable universal variant ID** and must not be
assumed to be a product ID.

The archive contains dramatic source-ID regime changes. Example:

```text
mvs_2019-05-04 -> mvs_2019-05-28
retained variant fingerprints: 35,105
retained fingerprints with changed source ID: 35,046
re-ID rate: 99.83%
```

Other large regime transitions also exist.

For cross-snapshot analysis, treat the literal ID as provenance and compare substantive
variant fingerprints independently of it.

### 5.5 Product/variant state identity

For analysis—not for rewriting source semantics—a useful ID-independent product state is:

```text
normalized product title
+ observed product filename/hash set
```

A useful variant fingerprint is:

```text
normalized variant title
+ observed variant filename/hash set
```

These are analytical fingerprints, not claims of immutable real-world entity identity.

### 5.6 Hashes

Do not infer a canonical SHA-1/SHA-256 pair merely because two hashes share a filename.

Hash-to-filename relationships must remain source-observed.

### 5.7 Notes

Notes are title-level evidence, not guaranteed ID-specific records.

Important rules:

- preserve **every distinct note version**, not only the latest;
- count note longevity by distinct snapshots, not duplicate occurrences;
- preserve raw HTML by content hash;
- parse historical `<h3>Title [ID: ...]</h3>` and newer `<h1>Title</h1>`;
- record source IDs when present as provenance;
- associate notes to product titles only when supported by source/title evidence;
- do not invent product-to-variant ownership.

Across the analyzed archive there are thousands of distinct title+text versions, including
hundreds observed in only one snapshot. Excluding a dump before harvesting notes can lose
real historical evidence.

---

## 6. Bad-dump / exclusion policy

A snapshot may be structurally suspicious while still containing unique evidence.

Therefore **exclusion is non-destructive**.

Separate:

```text
INGEST
  Should evidence from this snapshot enter the all-ever evidence store?

CANONICAL
  Should this snapshot participate in canonical change/churn interpretation?
```

Normal policy:

```text
INGEST = yes
```

even for suspicious snapshots.

`test\archive-exclusions.tsv` may scope canonical interpretation for:

- products
- variants
- notes
- payload/completeness
- comparison baselines

Analyzer-generated exclusions are suggestions only. Never apply them silently.

Every exclusion decision should be supported by `per-dump-retention.tsv`:

```text
introduced_here
seen_later
never_seen_later
```

The purpose is to answer: **What information would be lost if this dump were treated as
non-canonical or removed from a downstream view?**

### Known anomaly candidates

These are quality-review candidates, not hard-coded exclusions.

#### `mvs_2021-04-20`

Large transient `mvs_names.txt` duplication spike.

Earlier analysis found approximately:

```text
variant sections:                     67,233
exact duplicate section occurrences: 16,786
duplicate variant-state occurrences:  17,738
```

It also introduces information not all seen later, including note evidence. Therefore it
must not simply be discarded.

#### `mvs_2022-10-07-1939`

Large completeness/catalog contraction signal.

Earlier analysis found roughly 54% of product sections with no product-file row and a
substantial `mvs_names` contraction versus the preceding dump.

It is the newest current snapshot, so "never seen later" cannot yet be interpreted as
permanent uniqueness.

---

## 7. Fast archive architecture

### 7.1 Why the old sweep was too slow

The literal 0.12-era sweep spawned one public process per logical invocation:

```text
422 * 79 = 33,338 single
19 * 78  =  1,482 compare
2        =      2 archive
----------------------
total    = 34,822
```

The first early snapshots took roughly 1.8 hours each.

The first combined implementation removed process startup but still spent roughly 30 active
hours on the full archive. About 92.6% of the measured single-snapshot time was concentrated
in repeated detail/relationship scans.

### 7.2 0.14 indexed model

The fast snapshot worker should build reusable snapshot-local indexes such as:

```text
productById
productsByTitle
productFilesById
productFilesByTitle
productFilesByFilename
hashRecordsByFilename
hashRecordsByHash
variantsById
variantsByTitle
variantsByFilename
variantsByHash
notesByTitle
```

Logical checks then use dictionary/index lookup rather than repeated array scans.

### 7.3 Parallelism

Fast mode supports bounded workers:

```bat
test\test_all_dumps.bat archive-root --workers N
```

There must always be a single-worker path for determinism/debugging.

Worker count must remain user-configurable; do not assume one hardware topology.

### 7.4 Content cache

Repeated runs may reuse snapshot results when the cache identity proves the inputs and
implementation are unchanged.

Cache identity must include:

- worker version;
- exact plan slice;
- source content hashes;
- executor-relevant configuration.

Fresh performance acceptance must support:

```text
--no-cache
```

### 7.5 Interruption safety

The previous long real-archive run exposed a serious integrity requirement.

At snapshot-worker start:

- freeze source presence;
- size;
- last-write metadata;
- content identity as required.

At worker completion, verify the source inventory again.

If a source disappears or changes during the batch:

```text
discard the complete 422-check batch
mark worker failure
do not commit logical rows
```

Never convert a mid-batch path disappearance into historical `SOURCE_MISSING`.

---

## 8. Comprehensive functional/quality/performance loop

Primary recurring development gate:

```bat
test\test_everything.bat mvs-dumps-root
```

The tester must keep the order:

```text
functional regression
      ->
performance measurement
      ->
archive quality/integrity
      ->
outlier report
      ->
optimization
      ->
rerun
```

Behavior correctness always precedes performance interpretation.

Performance output should identify:

- slow public tools;
- slow logical operations/families;
- slow complete snapshot batches;
- high-output calls where relevant;
- cache hits/misses where relevant.

Performance outliers are development work items, not merely informational noise.

After optimizing an outlier, rerun the same gate to prove both:

1. performance improved;
2. output/return-code behavior did not regress.

The project goal is to make fresh full runs practical enough to execute regularly during
the week, not only as rare multi-day events.

---

## 9. Quality gate

`test\check_archive_sweep_quality.bat` must validate more than `FAIL=0`.

Required checks include:

- plan row count and identity;
- run row count and unique indices;
- plan/run field alignment;
- plan SHA-256;
- executor identity;
- authoritative status totals;
- expected historical `SOURCE_MISSING`;
- unexpected `SOURCE_MISSING`;
- source inventory consistency;
- archive evolution row counts;
- note observation-count bounds;
- raw-note retention;
- per-dump retention completeness;
- performance outliers;
- whole-batch timing outliers.

The earlier contaminated run demonstrates why this is necessary: it completed 34,822
logical rows with zero `FAIL`, yet 271 `SOURCE_MISSING` rows were false because the archive
directory was moved during one worker.

A clean acceptance result must pass the quality checker, not just the sweep summary.

---

## 10. Archive evolution outputs

The fast archive worker should emit enough evidence to answer both cumulative-growth and
bad-dump questions.

Key outputs:

```text
per-dump-contributions.tsv
per-dump-domain-additions.tsv
per-dump-retention.tsv
per-dump-quality.tsv
variant-id-transitions.tsv
suggested-exclusions.tsv

product-states-all-ever.tsv
variant-states-all-ever.tsv

note-observations.tsv
note-versions.tsv
note-bodies.tsv
note-raw-variants.tsv
raw-html\
```

The legacy 19 source-local history/all-ever domains remain authoritative and separate.

---

## 11. Interactive HTML report

The HTML report is a sanity-check/debugging artifact and should remain self-contained.

Builder:

```bat
test\build_archive_html_report.bat result-folder
```

Output:

```text
archive-summary.html
```

Required report areas:

- Overview
- Dumps
- What This Dump Added
- Removals / retention
- Re-ID / ID regimes
- Duplicates / quality
- Notes
- Exclusions
- All-Ever
- Performance

For each dump the report should make it easy to answer:

- What genuinely new IDs/titles/files/hashes appeared?
- What was old content under a new source ID?
- What appeared here and never appeared again?
- What was introduced here and later confirmed?
- Did the dump exhibit unusual duplication or completeness collapse?
- What unique notes would be lost if the dump were ignored?
- How much did it increase each running all-ever total?
- Was this dump a performance outlier?

The report should not require a web server or external JavaScript/CDN.

---

## 12. Future dumps

Nothing in runtime logic may assume the current final date or exactly 79 snapshots.

A future dump should:

1. be discovered from the established `mvs_*` naming convention;
2. resolve root/nested source layout;
3. have source content fingerprints calculated;
4. reuse cached parsed/source results when content-identical;
5. produce the same contribution/retention/quality analysis;
6. receive advisory quality warnings when thresholds trigger;
7. preserve new note versions immediately;
8. extend the all-ever union without rewriting historical evidence semantics.

The final/current dump should not automatically be labeled bad merely because its additions
have not yet been seen later.

---

## 13. Release gates

Do not call an archive-performance release accepted until:

1. static generators/validators pass;
2. public-tool regression is clean;
3. fast synthetic acceptance is clean on Windows PowerShell 5.1;
4. comprehensive non-full test gate is clean;
5. one fresh full real-archive sweep completes start-to-finish;
6. archive quality checker passes;
7. strict performance output is reviewed;
8. interactive HTML report is generated and sanity-checked;
9. package manifest matches ZIP members;
10. ZIP integrity test passes.

If a maintenance release changes only test/archive infrastructure, verify the 443 public
root batch files remain byte-for-byte identical to the already validated public baseline.

---

## 14. Do-not-regress checklist

- Do not reinterpret `mvs_names.txt` IDs as stable product or variant IDs.
- Do not infer SHA-1/SHA-256 pairings by shared filename.
- Do not collapse note history to latest text.
- Do not discard suspicious snapshots before ingesting unique evidence.
- Do not treat missing historical sources as failures.
- Do not treat mid-run filesystem disappearance as historical source absence.
- Do not weaken functional assertions to make a performance optimization pass.
- Do not hide fast/external executor identity.
- Do not hard-code 79 snapshots.
- Do not add runtime `dev\` dependencies to public tools.
- Do not change public interfaces as part of performance work without explicit approval.
- Do not interpret `FAIL=0` alone as archive acceptance.
- Do not silently apply analyzer-suggested exclusions.

---

## 15. Useful files for the next developer

```text
README.md
doc\development-directives.md
doc\comprehensive-testing.md
doc\archive-evolution-and-quality.md
doc\performance-architecture.md
doc\data-model.md
doc\archive-sweep.md
doc\project-version-history.txt
doc\test-run-analysis-0.14.0.md
test\README.md
dev\README.md
```

This handoff document should be updated whenever the acceptance state or major design
directive changes.
