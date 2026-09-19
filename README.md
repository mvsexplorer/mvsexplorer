# MVS Explorer Toolkit 0.4.0

MVS Explorer Toolkit is a growing collection of console tools for exploring MVS dump snapshots, intended to culminate in the graphical **MVS Explorer** application.

## Standalone public tools, shared development source

Every public `.bat` in the project root is fully standalone.

Common code is now maintained under `dev\` and injected by `dev\generate_tools.py`. The generated public tools contain their own batch functions and embedded PowerShell; they do not read or call anything under `dev\` at runtime.

The development model is:

```text
common library + template + tool specification
                  |
                  v
             generation
                  |
                  v
      fully standalone public .bat
```

## Public tool count

Version 0.3.0 contains **127 standalone public batch tools**:

- 30 source-order scalar tools;
- 90 sorted scalar tools;
- 7 lookup tools.

## Sorted scalar tools

Every existing scalar `print_` and `read_` tool now has three companions:

```text
_sorted_by_id
_sorted_by_title
_sorted_by_date
```

For example:

```text
print_mvs_dump_id_title_date_note.bat
print_mvs_dump_id_title_date_note_sorted_by_id.bat
print_mvs_dump_id_title_date_note_sorted_by_title.bat
print_mvs_dump_id_title_date_note_sorted_by_date.bat
```

Sort semantics are ascending:

- **ID:** numeric product ID.
- **TITLE:** case-insensitive natural/alphanumeric title; numeric runs are compared naturally, with numeric ID as tie-break.
- **DATE:** chronological date/time where parseable; source date text and numeric ID provide deterministic tie-breaks.

The original unsorted tools remain source-order interfaces and follow `mvs_ids.txt`.

A sort field does not have to be displayed. For example, `print_mvs_dump_note_sorted_by_title.bat` prints notes while ordering product rows by title.

## Lookup tools

Current lookup relationships:

```text
lookup_mvs_title_from_id.bat
lookup_mvs_title_from_date.bat
lookup_mvs_note_from_id.bat
lookup_mvs_note_from_title.bat
lookup_mvs_note_from_date.bat
lookup_mvs_date_from_id.bat
lookup_mvs_date_from_title.bat
```

Examples:

```text
lookup_mvs_title_from_id.bat mvs_2021-08-17 28
lookup_mvs_title_from_id.bat mvs_2021-08-17 2*
lookup_mvs_title_from_id.bat mvs_2021-08-17 *28
lookup_mvs_title_from_id.bat mvs_2021-08-17 *2*
lookup_mvs_note_from_title.bat mvs_2021-08-17 "Windows 7 *"
```

`*` matches zero or more characters anywhere in the search value. Matching is case-insensitive. Every non-`*` character is treated literally.

Lookup tools emit **distinct, non-empty associated values, one per line**, with no label or header. Multiple matching product rows are ordered by the searched field: ID numerically, title naturally, or date chronologically.

No associated value produces no stdout and return code `1`.

## Scalar output families

`print_`
: Human-readable, labeled, one product per line.

`read_`
: Headerless TSV, one product per line, intended for piping and machine consumption.

## Development files

`dev\library\`
: Common maintained batch/PowerShell source.

`dev\templates\`
: Batch templates.

`dev\tool-spec.json`
: Tool matrix.

`dev\generate_tools.py`
: Injects common source into standalone public tools.

`dev\validate_generated.py`
: Static validator for generated tools.

These are development-time files only.

## Documentation

See `doc\` for the supplied Batch File Style Guide, project addendum, embedded PowerShell style guide, developer diary, observation journal, complete prompt record, distilled directives, project history, output/data-model documents, tool catalog, and one version-history file per public/development tool.


## Automated tests

Run the complete Windows test suite from the project root:

```text
test\test_all.bat path_to_mvs_dump_folder
```

Subset tests are also standalone:

```text
test\test_structure.bat
test\test_scalar_tools.bat path_to_mvs_dump_folder
test\test_lookup_tools.bat path_to_mvs_dump_folder
```

`test_all.bat` invokes every one of the 127 public batch tools and compares its output/return code against expectations independently constructed from the selected dump. It also performs standalone-structure checks.

The test suite covers:

- all 120 scalar source-order/sorted tools;
- exact output for human and machine projections;
- numeric ID, natural title, and chronological date ordering;
- all seven lookup tools;
- exact lookup;
- wildcard-all lookup;
- no-match return behavior;
- prefix, suffix, and contains `*` wildcard cases for ID lookup;
- clean stderr on successful/expected no-match runs;
- standalone injected-code structure.

All four test `.bat` files are themselves fully standalone; `test_all.bat` does not require the other test files to execute.
