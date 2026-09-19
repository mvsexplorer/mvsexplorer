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

0.16.5 retains the recovery path introduced in 0.16.1 for a late-stage validator/packaging failure after
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
