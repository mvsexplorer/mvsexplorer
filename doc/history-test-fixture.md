# Archive-history regression fixture

`test\test-mvs-dump-history\` contains three synthetic snapshots:

```text
mvs_2020-01-01
mvs_2020-01-02
mvs_2020-01-03_2
```

The second snapshot stores all six source files under `mvs_dmp\`, removes Alpha, and adds Beta. The third reintroduces Alpha,
removes Beta, and adds Gamma. Keep records persist through all three snapshots
while deliberately changing harmless presentation details such as filename
case, title whitespace, textual variant-ID case, and numeric product-ID
zero-padding.

The fixture exercises all 19 comparison/history domains.

Fixed expected output lives beneath:

```text
test\expected-history\history\
test\expected-history\all-ever\
```

`dev\generate_expected_history_outputs.py` is the independent reference oracle.
It parses the fixture directly and never invokes the public batch tools.
