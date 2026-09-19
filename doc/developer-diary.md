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
