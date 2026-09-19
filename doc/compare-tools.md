# Two-dump comparison tools

Version 0.10.0 introduces the first cross-snapshot comparison layer.

## Invocation

Every public comparison tool is standalone:

```text
compare_mvs_dump_<property>_from_<source>.bat first-dump-folder second-dump-folder
```

The first folder is treated as the earlier/baseline dump. The second folder is
treated as the later/new dump.

A value found in the first source but absent from the second is **removed**.
A value absent from the first source but present in the second is **added**.

Normal output contains only differences:

```text
- removed-value
+ added-value
```

All removed values are emitted before any added values. Removed values preserve
first-dump source order; added values preserve second-dump source order.

Interactive console output colors the complete `-` line red and the complete
`+` line green. Redirected/captured stdout is intentionally plain text so the
tools remain pipe- and test-friendly.

No differences produces no stdout and return code `0`.

## Set semantics and normalization

Comparison is based on source-local set membership. Repeated occurrences of the
same normalized value within one source are represented once.

- Product IDs from `mvs.txt`, `mvs_ids.txt`, and `mvs_dates.txt` use numeric
  normalization, so leading zeroes do not make a new ID.
- IDs from `mvs_names.txt` are textual source IDs and compare
  case-insensitively without numeric coercion.
- Titles are HTML-decoded, whitespace-collapsed, trimmed, and compared
  case-insensitively.
- Dates are trimmed and otherwise compared as source text.
- SHA-1/SHA-256 values are compared case-insensitively and displayed lowercase.
- Filenames are trimmed and compared case-insensitively while preserving the
  first encountered display spelling on the side that emits the difference.

Malformed/unparsed rows are not promoted into comparison values. The existing
single-dump unparsed-line tools remain the mechanism for inspecting them.

## Public comparison matrix

### ID

```text
compare_mvs_dump_id_from_mvs.txt.bat
compare_mvs_dump_id_from_mvs_ids.txt.bat
compare_mvs_dump_id_from_mvs_names.txt.bat
compare_mvs_dump_id_from_mvs_dates.txt.bat
```

The `mvs_dates.txt` ID form is included because the request listed
`mvs_names.txt` twice; it completes the natural four-source ID matrix.

### Title

```text
compare_mvs_dump_title_from_mvs.txt.bat
compare_mvs_dump_title_from_mvs_ids.txt.bat
compare_mvs_dump_title_from_mvs_names.txt.bat
compare_mvs_dump_title_from_mvs_dates.txt.bat
```

### Date

```text
compare_mvs_dump_dates_from_mvs_dates.txt.bat
```

The requested plural `dates` filename is preserved exactly.

### SHA-1

```text
compare_mvs_dump_sha1_from_mvs.txt.bat
compare_mvs_dump_sha1_from_mvs_names.txt.bat
compare_mvs_dump_sha1_from_mvs.sha1.bat
```

`mvs.txt` and `mvs_names.txt` contribute only 40-hex checksum rows to SHA-1
comparison. `mvs.sha1` contributes valid SHA-1 manifest rows.

### SHA-256

```text
compare_mvs_dump_sha256_from_mvs.txt.bat
compare_mvs_dump_sha256_from_mvs_names.txt.bat
compare_mvs_dump_sha256_from_mvs.sha256.bat
```

`mvs.txt` and `mvs_names.txt` contribute only 64-hex checksum rows to SHA-256
comparison. `mvs.sha256` contributes valid SHA-256 manifest rows.

### Filename

```text
compare_mvs_dump_filenames_from_mvs.txt.bat
compare_mvs_dump_filenames_from_mvs_names.txt.bat
compare_mvs_dump_filenames_from_mvs.sha1.bat
compare_mvs_dump_filenames_from_mvs.sha256.bat
```

These compare filename membership independently within each source; they do
not imply that a filename in one source is linked to the same product/variant
record in another source.

## Return codes

```text
0  successful comparison, with or without differences
2  invalid/missing arguments or unsupported embedded configuration
3  first or second dump folder not found
4  required source file missing from either dump
5  parse/runtime comparison failure
```

Help aliases `--help`, `-h`, `-?`, `/h`, and `/?` return `0`.

## Regression tests

The dedicated test entry point is:

```text
test\test_compare_tools.bat
```

It uses:

```text
test\test-mvs-dump-compare\before\
test\test-mvs-dump-compare\after\
test\expected-compare\
```

Every one of the 19 comparison tools is checked against exact before-to-after
stdout, and every tool is also run before-to-before to prove that unchanged
sets emit nothing.

The comparison scope therefore contributes 39 assertions:

```text
1   fixture-presence assertion
19  exact difference assertions
19  no-change assertions
```
