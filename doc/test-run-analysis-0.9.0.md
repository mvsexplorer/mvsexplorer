# Windows Test Run Analysis — MVS Explorer Toolkit 0.9.0

## Supplied result archive

The uploaded archive contains two Windows test-result directories:

```text
test-results-20260827-164530
test-results-20260827-165132
```

Both were produced on:

```text
OS: Microsoft Windows NT 10.0.19045.0
PowerShell: 5.1.19041.6456
CLR: 4.0.30319.42000
```

## Run 1 — mvs_2019-10-16

Invocation:

```text
test\test_all.bat ..\mvs_dumps_archive\mvs_2019-10-16
```

The harness resolved the dump and independently parsed 1,791 products.

The run was manually interrupted while the new single-dump scope was still
executing. At interruption, `all-results.tsv` contains:

```text
836 assertions recorded
762 PASS
71 FAIL
3 SKIP
```

Scope rows recorded:

```text
structure      423
scalar         120
lookup          24
diagnostic      46
relationship   151
single_dump     72
```

The three lookup skips are the expected data-dependent exact note cases on a
dump with no nonempty associated notes.

## Run 2 — mvs_2020-09-23

Invocation:

```text
test\test_all.bat ..\mvs_dumps_archive\mvs_2020-09-23
```

The harness resolved the dump and independently parsed 1,985 products.

This run completed:

```text
Passed: 765
Failed: 166
Skipped: 0
Total assertions: 931
```

All pre-0.9.0 scopes passed. The single-dump scope contains 167 assertions:

```text
1 fixture-presence PASS
154 positive public-tool FAIL
12 no-result public-tool FAIL
```

## Common failure signature

All 166 complete-run stderr artifacts are identical at the meaningful error
body. Windows PowerShell failed while compiling the injected block through
`[ScriptBlock]::Create()`:

```text
At line:670 char:41
+                     [string]$section.id,
+                                         ~
Missing expression after ','.

At line:671 char:21
+                     Normalize-Scalar ([string]$section.title),
+                     ~~~~~~~~~~~~~~~~
Unexpected token 'Normalize-Scalar' in expression or statement.
```

The failing source is the machine/raw-product-section field-array expression in
the shared single-dump runtime.

Because every 0.9.0 single-dump tool embeds that same complete runtime, the
parser rejects the block before operation dispatch. The 166 failures are
therefore one shared loader defect, not 166 independent query defects.

## 0.9.1 correction

The field-row construction was rewritten to the established ArrayList emitter
pattern already exercised successfully by the relationship tools:

```text
$values = New-ArrayList
[void]$values.Add(...)
...
Write-Line (($values | ForEach-Object { [string]$_ }) -join [char]9)
```

The known unsafe source form is also rejected by the development-time static
validator.

## Additional real-dump model finding

Independent inspection of `mvs_2019-10-16` shows:

```text
product sections / product IDs:       1,791
product ID maximum:                   6,658
mvs_names sections (correct parser):     38,136
distinct mvs_names IDs:                   38,136
numeric mvs_names IDs:                    37,594
nonnumeric mvs_names IDs:                    542
maximum numeric mvs_names ID:             86,083
numeric IDs shared by product/name domains:  203
```

Therefore the ID printed by `mvs_names.txt` is not an owning product ID and
must not be treated as a product foreign key.

0.9.1 corrects the variant documentation and summary metric names accordingly.
The existing variant `..._from_id` tools continue to mean the source ID printed
by `mvs_names.txt`.

An archive-wide audit found 492,904 nonnumeric `mvs_names.txt` IDs across 29
snapshots (492,887 alphanumeric plus 17 simple hyphenated/mixed IDs). The
0.9.0 numeric-only variant header parser would therefore have dropped valid
variant sections on those dumps. 0.9.1 preserves `mvs_names.txt` IDs as text
and the synthetic fixture now tests alphanumeric and hyphenated forms.

Product-to-variant ownership, when needed, must be derived from file/hash
relationships and must preserve ambiguity rather than joining on numeric ID.


For comparison, `mvs_2020-09-23` has 46,868 `mvs_names.txt` sections but only
1,965 distinct `mvs_names.txt` IDs; all 1,965 occur in that dump's product-ID
set. This confirms that the source-ID domain changes across dump generations
and must not be hard-coded to one semantic interpretation.
