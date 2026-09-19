# Current project status

Date: 2026-08-30  
Development version: 0.14.1 maintenance work

## Validated

- 443 public root tools unchanged from 0.13.3 baseline.
- Windows public regression on 0.14.0: 1053 pass / 0 fail / 3 skip.
- 0.14.0 fast-combined executor itself completed the 3-snapshot 1306-check
  synthetic sweep with FAIL=0 and generated `archive-summary.html`.

## Open native validation

The 0.14.0 acceptance harness rejected metadata serialization after the sweep
completed. 0.14.1 fixes the metadata producer by parenthesizing PowerShell
string concatenations used in summary/run-info arrays.

Next command:

```bat
test\test_fast_archive_sweep.bat
```

After that passes:

```bat
test\test_everything.bat ..\mvs_dumps_archive
```

Then perform one fresh uninterrupted full archive acceptance run and verify it
with the strict quality/performance gate.

See `HANDOFF.md` for the full continuation state and
`development-directives.md` for design requirements.
