# MVS Explorer Toolkit Tests

From the project root:

```text
test\test_all.bat path_to_real_mvs_dump_folder
```

The full suite uses the supplied real dump for the established scalar/lookup
regression tests and uses `test\test-mvs-dump-diagnostics\` for the duplicate/
orphan diagnostic tests.

Standalone subset entry points:

```text
test\test_structure.bat
test\test_scalar_tools.bat path_to_real_mvs_dump_folder
test\test_lookup_tools.bat path_to_real_mvs_dump_folder
test\test_diagnostic_tools.bat
```

Every test invocation creates a timestamped result directory below `test\`.

Diagnostic expected stdout is stored under `test\expected-diagnostics\`.
Those files are fixed regression expectations generated independently from
the diagnostic public tools.

Expected full-suite assertion matrix for 0.7.0:

```text
Structure:   173
Scalar:      120
Lookup:       24
Diagnostic:   46
Total:       363 assertions
```

The diagnostic count is 45 public-tool behavior checks plus one synthetic
fixture-presence assertion.
