# 0.14.0 Windows test-run analysis

Date: 2026-08-30

## Public regression

`test\\test_all.bat ..\\mvs_dumps_archive\\mvs_2018-10-04`

- Windows 10.0.19045.0
- Windows PowerShell 5.1.19041.6456
- CLR 4.0.30319.42000
- 1,589 products parsed for scalar/lookup expectations
- PASS: 1,053
- FAIL: 0
- SKIP: 3
- Total assertions: 1,056
- Duration: 00:06:29.1229534

The three skips are the existing data-dependent exact note lookup cases.

## Fast synthetic archive acceptance

The 0.14.0 `fast-combined` executor completed all 1,306 logical checks:

- PASS: 1,282
- NO_RESULT: 24
- SOURCE_MISSING: 0
- FAIL: 0
- interactive `archive-summary.html` generated

The acceptance script then failed its first metadata assertion. The generated
`summary.txt` contained `Executor:` and `fast-combined` on separate physical
lines. The root cause was unparenthesized string concatenation in PowerShell
array literals used by `Write-Summary` and the run-info writer.

0.14.1 fixes the producer rather than weakening the test.
