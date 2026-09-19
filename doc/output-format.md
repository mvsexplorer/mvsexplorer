# Output Format

## Source-order scalar tools

Unsuffixed scalar tools preserve product order from `mvs_ids.txt`.

## Sorted scalar tools

Sorted companions change row order only. Projection and presentation remain the same.

```text
_sorted_by_id     numeric ID ascending
_sorted_by_title  natural/alphanumeric title ascending, case-insensitive
_sorted_by_date   chronological date ascending where parseable
```

Title ties use numeric ID. Date ties/unparseable values use source date text and then numeric ID for deterministic ordering.

## `print_`

Human-readable, labeled rows:

```text
ID: 748 | Title: Windows 7 Ultimate | Date: 2009-08-06T09:59:56
```

Missing scalar values display as `(none)`.

## `read_`

Headerless TSV:

```text
748<TAB>Windows 7 Ultimate<TAB>2009-08-06T09:59:56
```

The real stream contains literal TAB characters.

Rules:

- one product per physical line;
- output field order follows the tool name;
- no banner/header/color/progress on stdout;
- missing fields are empty;
- embedded TAB/CR/LF in values are normalized to spaces;
- errors go to stderr.

## `lookup_`

Lookup output contains only associated values:

```text
Windows 7 Ultimate
Windows 7 Ultimate N
Windows 7 Ultimate K
```

Rules:

- one distinct non-empty target value per line;
- no labels/header;
- case-insensitive search;
- `*` is the only wildcard;
- all non-`*` characters are literal;
- multiple matching rows are sorted by the search/source field;
- duplicate target strings are emitted once;
- no associated value produces no stdout and exit code `1`.
