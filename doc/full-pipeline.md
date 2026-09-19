## 0.20.2 caller-root hotfix

0.20.2 fixes archive-sweep toolkit-root discovery after the 0.20.1 argument-transport change. Pipeline gating, worker policy, and database semantics are unchanged.

## 0.20.1 native hotfix

0.20.1 corrects the maintained product-family regression project label and the
archive-sweep batch argument bridge exposed by the first 0.20.0 Windows run.
Pipeline gating and adaptive worker policy are otherwise unchanged.

# Full validation and database production pipeline

## Command

From the toolkit root, with `mvs_dumps_archive` as a sibling directory:

```bat
all_test_then_all_database_then_test_database_and_all_tools.bat
```

This is the recommended clean-room rebuild command.

Explicit form:

```bat
all_test_then_all_database_then_test_database_and_all_tools.bat ..\mvs_dumps_archive --workers 8
```

Optional `--output-root DIR` changes where databases/logs/ZIPs are written.
`--strict-performance` promotes the existing performance advisory thresholds to
failures.

## Resume already-built databases

0.19.0 retains the recovery path introduced in 0.16.1 for a late-stage validator/packaging failure after
the three reusable databases were already generated:

```bat
all_test_then_all_database_then_test_database_and_all_tools.bat --resume-built ^
  path_to_archive_database ^
  path_to_full_family_database ^
  path_to_compact_family_database
```

Resume mode does not rebuild the supplied databases. It first runs the
structure-only suite so the new validator/pipeline preflight guards execute,
then re-runs archive quality validation, the full 57-check generated-database
gate, and all 32 family query smoke executions before ZIP/log/hardlink
packaging. Use
`--resume-test-results path_to_test-results-folder` to copy an earlier
successful `test-results-*` folder into the new log bundle.


## Fail gate

The pipeline first runs `test\test_everything.bat`. No reusable database is
built if that test phase returns nonzero. Failure runs still attempt to package
the available logs into a `SEND-ME-LOGS-*.zip` hardlink.

## Successful phase order

1. All normal regression, performance, fast synthetic and real plan tests.
2. Full archive-analysis database via `test\test_all_dumps.bat`.
3. Archive quality validation.
4. Full product-family evidence database.
5. Compact all-ever family database.
6. Real database integrity validation and all 32 family query tools.
7. ZIP archive database.
8. ZIP full family database.
9. ZIP compact family database.
10. Collect logs and create database hardlinks, then close the active pipeline
    log writers; final log ZIP creation, the `SEND-ME-LOGS-*` hardlink and the
    final summary follow immediately after writer disposal.

Every phase prints project version, phase number, phase total and remaining
phases. Child test harnesses provide their own test-number/remaining counters.

The phase-1 real-archive plan preflight runs with `--quiet-plan`, so it validates
the deterministic 34,822-entry plan without printing all snapshot names. The
phase-2 production plan remains visible once. Archive execution prints paired
`Starting snapshot` / `Completed snapshot` and `Starting compare` /
`Completed compare` lines with elapsed time. The top-level pipeline keeps ordinary text at the console's normal color and
colors only semantic status/attention tokens: PASS green, active FAIL/error
tokens red, and warning/SKIP/quality-flag tokens yellow. Zero-failure and
zero-warning counters stay neutral, and logs stay plain text. The final log ZIP
is deliberately deferred until `console.log` and `phase-performance.tsv` have
been flushed and closed; the pipeline never attempts to ZIP its live log
directory.

## Outputs

All generated databases are timestamped and go to the output root (default:
the parent of the toolkit directory).

The archive database keeps the logical run plan/results plus
`archive-output\`, quality outputs and the interactive report.

The full family database is the evidence-preserving source-observation index.

The compact family database is the normal reusable all-ever representation. It
preserves exact snapshot membership through `snapshot-sets.tsv`.

Each database is ZIPped. The toolkit root receives hardlinks named
`SEND-ME-ARCHIVE-DATABASE-...zip`, `SEND-ME-FAMILY-DATABASE-...zip`,
`SEND-ME-COMPACT-DATABASE-...zip` and `SEND-ME-LOGS-...zip`.

## Logs and performance

The pipeline log folder contains:

```text
console.log
phase-performance.tsv
pipeline-summary.txt
database-paths.tsv
run-metadata.txt
test-results\
archive-database-logs\
database-validation\
    console.log
    database-tests.tsv
    all-family-tools-performance.tsv
    summary.txt
```

`phase-performance.tsv` measures the ten end-to-end phases.
`all-family-tools-performance.tsv` records return code, elapsed milliseconds
and output-line count for every real-data family query smoke test.
The pipeline does not ZIP the live log directory. `console.log` and
`phase-performance.tsv` are flushed and disposed first; final log packaging
runs only after both writers are closed.

Database/log ZIP entries are written with a normalized
`1980-01-01T00:00:00Z` entry timestamp. Files such as archive
`quality-check/*` may be deterministically regenerated during resume
validation, and their filesystem last-write times are not database evidence.
Normalizing ZIP metadata prevents those wall-clock dates from changing a ZIP
SHA-256 when names and bytes are otherwise unchanged. The reported ZIP SHA-256
remains a transport/package checksum, not a durable cross-build database
identity: a separately named output directory changes entry paths and therefore
can legitimately produce a different package hash.
The copied ordinary test-results folder retains per-assertion/per-tool
performance data, and the archive database retains `fast-batches.tsv`.

## Database integrity gate

The generated-database validator performs 57 checks: 25 database integrity
checks and 32 real family-query executions. It verifies the archive plan/run
ledger; the family hierarchy and content-addressed note store; the compact
snapshot-set dictionary and reconstructability; the filename/hash conflict,
same-product disagreement and hash-alias ledgers; and exact copied taxonomy
metadata.

It deliberately treats source-local product IDs as provenance rather than
cross-snapshot identities and never infers SHA-1/SHA-256 pairing solely by
filename.


## HTML browser

0.17.0 added `build_mvs_html_browser.bat` as an independent public tool; 0.17.1 fixes its Windows PowerShell 5.1 parser compatibility. Browser generation remains intentionally outside this fail-gated pipeline during the first browser UX cycle.


## PowerShell GUI

0.18.0 adds `mvs_explorer_gui.bat` as an independent consumer of an already
built compact product-family database. Like the HTML browser builder, it is not
automatically invoked by the fail-gated production pipeline. This keeps desktop
UI iteration separate from archive/database production while the GUI has its
native acceptance cycle.

## 0.19.0 incremental maintenance entry point

The original all-test/full-rebuild pipeline above remains available at the
project root for clean-room acceptance and packaging. 0.19.0 adds a separate
normal maintenance entry point:

```bat
create_or_update_mvs_database.bat
```

It searches the invocation directory and its parent for every
`mvs_dumps_archive*` folder, updates isolated slots under `mvs_databases\`,
reuses only content-identical complete snapshots, rebuilds dependent family
indexes when needed, validates the resulting databases, and creates timestamped
HTML browsers in the project root.

Utility tools used by either pipeline now live under `tools\`. This is a
delivery-layout change and does not expand the legacy archive plan.

One create/update invocation retains its master and per-component logs under
`logs\create-or-update-YYYYMMDD-HHmmss\` and creates a sibling ZIP only after
the active log writer is closed. See `database-maintenance.md`.

## 0.19.1 maintenance hotfix note

The 0.19.1 project patch changes modular database-maintenance validation output ownership only; the accepted full-pipeline data semantics are unchanged.

## 0.19.2 tools-layout regression correction

The supplied 0.19.1 full-pipeline log reached the final product-family aggregate
inside `test_all.bat` and failed because `test_product_family_tools.bat` still
resolved the 32 family query wrappers from the project root. The delivered
utilities moved to `tools\` in 0.19.0. 0.19.2 corrects that test caller and
updates its project metadata; archive/database semantics are unchanged.

## 0.19.3 early-gate failure reporting

If `test_everything.bat` returns nonzero, the pipeline now captures the newly
created `test-results-*` directory before rethrowing the phase failure. The
failure log package therefore retains assertion evidence, and the final console
summary reports the test totals plus:

```text
Archive logical checks: NOT RUN - gated by failed test phase
```

This changes failure reporting only; the fail gate remains strict.

## 0.20.0 adaptive worker policy

Fresh pipeline runs use adaptive archive-snapshot concurrency by default:

```bat
all_test_then_all_database_then_test_database_and_all_tools.bat
```

The start is one quarter of detected logical CPUs (rounded up, minimum one) and
the ceiling is the logical CPU count. Override either bound with
`--start-workers N` / `--max-workers N`. The historical `--workers N` form
remains fixed-concurrency mode.

The pipeline passes the same policy through `test_everything.bat` and the fresh
archive-analysis build. Family-index and compact-index builders remain
single-process and are not mislabeled as adaptive-worker phases.

Phase/suite/test/database-test progress now prints only current/total. The
native 0.19.3 baseline for comparison was 03:18:32 overall, with Phase 2 at
01:10:47, full-family Phase 4 at 01:16:11, and compact Phase 5 at 00:32:52.

