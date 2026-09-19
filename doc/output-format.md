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


## `find_mvs_duplicate_*` output

Findings are human-readable blocks.

For simple one-line sources, the original line is retained:

```text
Duplicate ID: 201
Occurrence 1:
  Duplicate ID First [ID: 201]
Occurrence 2:
  Duplicate ID Second [ID: 201]
```

For section sources (`mvs.txt`, `mvs_names.txt`), ID/title findings retain the
whole source section.

Filename duplicates report the owning ID/title and exact matching filename
line.

No duplicates produce no stdout. A duplicate finding does not change the
successful return code from `0`.

## `find_mvs_orphan_*` output

Each unmatched source occurrence is a block:

```text
Orphan ID: 101
Source: mvs_ids.txt
Target: mvs_dates.txt
  IDs Only [ID: 101]
```

The comparison is directional and output remains in source occurrence order.

No orphan findings produce no stdout. Orphan findings themselves return `0`.
