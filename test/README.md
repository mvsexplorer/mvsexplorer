# MVS Explorer Toolkit Tests

From the project root:

```text
test\test_all.bat path_to_real_mvs_dump_folder
```

The full suite uses the supplied real dump for the established scalar/lookup
regression tests, `test\test-mvs-dump-diagnostics\` for duplicate/orphan
diagnostics, and `test\test-mvs-dump-relationships\` for filename/hash
relationship queries.

Standalone subset entry points:

```text
test\test_structure.bat
test\test_scalar_tools.bat path_to_real_mvs_dump_folder
test\test_lookup_tools.bat path_to_real_mvs_dump_folder
test\test_diagnostic_tools.bat
test\test_relationship_tools.bat
test\test_single_dump_tools.bat
test\test_compare_tools.bat
```

Every test invocation creates a timestamped result directory below `test\`.

Diagnostic expected stdout is stored under `test\expected-diagnostics\`.
Those files are fixed regression expectations generated independently from
the diagnostic public tools.

Expected full-suite assertion matrix for 0.8.0:

```text
Structure:     269
Scalar:        120
Lookup:         24
Diagnostic:     46
Relationship:  151
Total:         610 assertions
```

The diagnostic count is 45 public-tool behavior checks plus one fixture
assertion.

The relationship count is 150 behavior cases plus one relationship-fixture
assertion. Every hash-query tool is tested separately with SHA-1 and SHA-256.


Relationship expected stdout is stored under:

```text
test\expected-relationships\
```

Those expectations are generated independently from the public relationship
batch files.


Single-dump completeness fixture:

```text
test\test-mvs-dump-single-complete\
test\expected-single-dump\
```

The 0.9.2 full-suite assertion matrix is:

```text
Structure:      423
Scalar:         120
Lookup:          24
Diagnostic:      46
Relationship:   151
Single-dump:    167
-------------------
Total:          931 assertions
```

The single-dump scope is 154 exact positive tool comparisons, 12 no-result
return-code checks covering each query operation family, and one fixture
presence assertion.

0.9.2 regenerates all standalone test entry points at test version 0.6.2; the assertion matrix remains 931. Structure checks also require the non-enumerating single-dump `New-ArrayList` return.


Two-dump comparison fixture:

```text
test\test-mvs-dump-compare\before\
test\test-mvs-dump-compare\after\
test\expected-compare\
```

The 0.10.0 full-suite assertion matrix is:

```text
Structure:      442
Scalar:         120
Lookup:          24
Diagnostic:      46
Relationship:   151
Single-dump:    167
Compare:         39
-------------------
Total:          989 assertions
```

The compare scope is 19 exact before-to-after comparisons, 19 identical
before-to-before no-change comparisons, and one fixture-presence assertion.

All eight standalone test entry points are generated at test version 0.7.0.


## Archive history

```bat
test\test_history_tools.bat
```

This subset needs no real dump argument. It executes both archive builders
against `test\test-mvs-dump-history\` and validates every generated added,
removed, and all-ever domain file against independent fixed expectations.
