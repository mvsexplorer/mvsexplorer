# Windows Test Run Analysis — MVS Explorer Toolkit 0.4.0

## Supplied command

```text
test\test_all.bat ..\mvs_dumps_archive\mvs_2021-01-12-1901
```

Resolved dump:

```text
mvs_2021-01-12-1901
```

Products parsed by the expectation parser:

```text
2003
```

Supplied summary:

```text
passed=265 failed=7 skipped=0
```

## Passing areas

The supplied console results show:

- all 127 standalone structure checks passed;
- all 120 scalar behavioral tests passed;
- all exact lookup tests passed;
- all wildcard-all lookup tests passed;
- the explicit prefix/suffix/contains ID wildcard tests passed.

## Seven failures

Every failure was the deliberate no-match case for one lookup tool:

```text
lookup_mvs_title_from_id
lookup_mvs_title_from_date
lookup_mvs_note_from_id
lookup_mvs_note_from_title
lookup_mvs_note_from_date
lookup_mvs_date_from_id
lookup_mvs_date_from_title
```

Each had the same signature:

```text
expected return code: 1
actual return code:   0
expected stdout:      empty
actual stdout:        empty
```

This isolates the problem to return-code propagation rather than matching or output generation.

## Root cause and 0.5.0 change

The embedded lookup block used a nonzero `exit` inside the dynamically executed PowerShell script block. The outer `:RunPowerShellFromLabel` bridge returned success afterward.

Version 0.5.0 uses an explicit process-level exit for documented nonzero embedded PowerShell contracts:

```powershell
[Environment]::Exit(1)
```

for lookup no-match, with no stdout/stderr beforehand.

Fatal scalar/lookup validation exits were changed to the same process-level mechanism so their documented nonzero return codes are also reliable.

## Result retention improvement

Beginning with 0.5.0, each test invocation creates one timestamped `test\test-results-*` directory containing the full console log, summary, run metadata, machine-readable assertion tables, and detailed behavioral failure artifacts.
