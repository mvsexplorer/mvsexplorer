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
