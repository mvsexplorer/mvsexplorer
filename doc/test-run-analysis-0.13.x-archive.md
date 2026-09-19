# Archive sweep analysis — 0.13.x real 79-snapshot run

## Result examined

The completed result set originated under:

```text
test\archive-sweep-results-20260828-063139
```

It ultimately contained all 34,822 logical plan rows.

The authoritative `runs.tsv` status totals were:

```text
PASS             33,414
NO_RESULT            792
SOURCE_MISSING        616
FAIL                    0
TOTAL              34,822
```

The console/summary displayed PASS=33,412 because the two successful archive
logical rows were not added to the in-memory display counters. 0.14.0 corrects
that reporting defect.

## Interrupted snapshot contamination

Exactly 271 of the 616 `SOURCE_MISSING` rows were inconsistent with the final
snapshot inventory. Every unexpected row belonged to:

```text
mvs_2021-01-12-1901
```

The source directory had been moved while the long sweep was running. The
snapshot model was initially loaded, then later logical checks observed missing
paths and committed false historical source absence. The immediately following
snapshot batch failed quickly because its data directory was gone.

The legitimate historical baseline from final source coverage is:

```text
single snapshot SOURCE_MISSING      294
adjacent comparison SOURCE_MISSING   51
total expected                       345
```

0.14.0 freezes source inventory at worker start and rechecks it before any
logical rows from that batch are committed. A move/edit now invalidates the
whole batch for safe resume.

## Performance evidence

Recorded active computation in the completed result set was approximately:

```text
snapshot batches       27.67 hours
comparison batches      0.0066 hours
archive builder          2.34 hours
total                    30.01 hours
```

The earlier combined executor already eliminated tens of thousands of process
launches, but most active time remained inside repeated logical array scans.

Two operation groups accounted for approximately 92.6% of measured
single-snapshot work:

```text
single-complete detail_query    ~12.98 h
relationship queries            ~12.18 h
```

0.14.0 replaces those repeated scans with snapshot-local indexes and adds
bounded parallel independent snapshot workers.

## Archive-builder evidence

The final archive builder completed successfully after the archive was restored.
Its output contained all 19 added ledgers, 19 removed ledgers, 19 all-ever
ledgers, and matching coverage metadata.

Observed totals were:

```text
added records                       572,143
removed records                     474,501
all-ever source-local records       648,293
```

Coverage matched the archive:

```text
mvs_names.txt       76 / 79 snapshots
mvs.sha256          61 / 79 snapshots
```

The all-ever state was reconstructible from transition ledgers without
inconsistency.

## Acceptance implication

The run was valuable performance/integrity evidence but is not a clean
start-to-finish acceptance result because of the 271 interruption-generated
rows. The user chose to run the full archive again after the 0.14.0 integrity
and performance changes rather than treat a targeted repair as the final
acceptance record.
