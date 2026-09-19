# Comparison regression fixture

The two-dump comparison tests use a purpose-built synthetic pair under:

```text
test\test-mvs-dump-compare\before\
test\test-mvs-dump-compare\after\
```

Each side contains `mvs_ids.txt`, `mvs_dates.txt`, `mvs.txt`,
`mvs_names.txt`, `mvs.sha1`, and `mvs.sha256`.

For every comparison source/property pair, the fixture contains:

- at least one value present in both dumps;
- at least one value only in `before` (removed);
- at least one value only in `after` (added).

The fixed expected output files under `test\expected-compare\` are generated
by `dev\generate_expected_compare_outputs.py`, an independent Python reference
parser that does not invoke or parse the generated public batch tools.

This fixture is intentionally small so ordering, set membership, and exact
`-`/`+` output are easy to inspect.
