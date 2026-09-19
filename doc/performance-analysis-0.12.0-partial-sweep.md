# Preserved 0.12.0 partial archive-sweep performance baseline

This report is preserved in 0.13.0 as the measured baseline that motivated the performance architecture. It is derived from the user-supplied partial Windows result folder `archive-sweep-results-20260827-214147`.

# MVS Explorer Toolkit archive sweep performance analysis

Source results: archive-sweep-results-20260827-214147
Completed invocations: 1,171 / 34,822
Observed tool elapsed time: 4.84 hours
PASS: 951
NO_RESULT: 50
SOURCE_MISSING: 170
FAIL: 0

## Completed snapshots

mvs_2018-10-04: 1.82 hours for 422 calls.
mvs_2018-10-05: 1.84 hours for 422 calls.

## Dominant bottlenecks

The summary/statistics operation is the largest observed bottleneck. It accounts for
47.1% of all measured tool time in this partial run.
Each summary/statistics call on the early snapshots takes about 13.5 to 14.1 minutes.

The relationship and single-complete detail-query families are the next largest groups.
The single-complete implementation constructs a complete multi-source model for many
operations even when a query needs only one source. This repeated parsing is a major
structural source of overhead.

Successful stdout is currently redirected to a temporary file for every invocation solely
to count bytes, then deleted. Several enumeration tools emit tens of megabytes per run, so
this adds avoidable I/O during an archive-wide validation sweep.

## Slowest tools observed

- print_mvs_dump_statistics: mean 818.4s, max 826.0s, observed total 40.9 min
- print_mvs_dump_summary: mean 818.2s, max 823.9s, observed total 40.9 min
- read_mvs_dump_summary: mean 830.4s, max 845.9s, observed total 27.7 min
- read_mvs_dump_statistics: mean 811.0s, max 815.0s, observed total 27.0 min
- print_mvs_dump_hash_records: mean 71.6s, max 72.3s, observed total 3.6 min
- read_mvs_dump_hash_records: mean 64.5s, max 65.1s, observed total 3.2 min
- find_mvs_filename_with_multiple_hashes_in_mvs.txt: mean 59.3s, max 59.9s, observed total 3.0 min
- find_mvs_hash_with_multiple_filenames_in_mvs.sha1: mean 57.5s, max 57.7s, observed total 2.9 min
- find_mvs_duplicate_sha1_in_mvs.sha1: mean 57.4s, max 57.6s, observed total 2.9 min
- find_mvs_duplicate_hash_in_mvs.txt: mean 57.0s, max 57.5s, observed total 2.9 min
- print_mvs_dump_filename_hash_algorithm_source: mean 47.7s, max 48.2s, observed total 2.4 min
- read_mvs_dump_filename_hash_algorithm_source: mean 45.4s, max 45.9s, observed total 2.3 min
- print_mvs_dump_product_files: mean 37.9s, max 38.0s, observed total 1.9 min
- read_mvs_dump_filename_sha1: mean 33.2s, max 33.3s, observed total 1.7 min
- print_mvs_dump_sha1_filename: mean 33.1s, max 33.2s, observed total 1.7 min

## Recommended optimization order

1. Replace quadratic array membership in summary/statistics with HashSet-backed membership.
2. Make the single-complete model source-lazy by operation so note, variant, raw-section,
   unparsed, and source-specific diagnostics do not parse unrelated files.
3. In archive-sweep validation mode, discard successful stdout instead of writing a
   temporary file; rerun only failures with stdout capture if failure artifacts are needed.
4. Checkpoint summary.txt periodically rather than rewriting it after every invocation.
5. After the algorithmic fixes, add optional bounded parallel workers for independent
   public-tool calls.

The existing runs.tsv already contains elapsed_ms, so no separate timing pass is needed
to identify the current bottlenecks.
