# Incremental MVS database maintenance

## Entry point

From the toolkit root or a working directory near the source archives:

```bat
create_or_update_mvs_database.bat
```

Optional worker count:

```bat
create_or_update_mvs_database.bat --workers 8
```

The launcher searches the invocation directory and its parent for every
directory matching `mvs_dumps_archive*`. It attempts all discovered archives.

## Database layout

The launcher creates/uses an `mvs_databases\` root in the working area and one
slot per discovered archive:

```text
mvs_databases\
  <archive-slot>\
    archive-analysis\
    family-index\
    compact-index\
    cache\
    database-state.json
    validation-status.txt
    latest-html.txt
```

Duplicate archive names discovered at different paths receive a short
path-derived suffix so they cannot collide.

## Ordered components

Normal usage:

```bat
create_or_update_mvs_database.bat [--workers N] [--force-validate]
```

`--force-validate` bypasses a reusable managed database-validation PASS and
runs the full 57-check validator plus all 32 family-query smoke executions.

`create_or_update_mvs_database.bat` invokes these standalone components in
order for each archive:

```text
create_or_update_mvs_database\
  01_discover_archives.bat
  02_prepare_archive_update.bat
  03_run_archive_update.bat
  04_rebuild_family_index.bat
  05_rebuild_compact_index.bat
  06_validate_database.bat
  07_create_html_browser.bat
  08_write_database_summary.bat
```

The launcher continues to later discovered archives after an archive-specific
failure. Stage 08 records the final state for that slot.

## Already-done and restart rules

Preparation creates a fresh staging archive-analysis plan and fingerprints each
snapshot from the bytes of:

```text
mvs.txt
mvs_ids.txt
mvs_dates.txt
mvs_names.txt
mvs_notes.html
mvs.sha1
mvs.sha256
```

Each present file contributes its SHA-256; missing files contribute an explicit
`MISSING` marker. Filesystem creation/modification dates are not used as source
identity.

A snapshot can be seeded as `Already done` only when:

1. the source-content fingerprint is unchanged;
2. the archive-processing toolset fingerprint is unchanged;
3. every expected prior single-snapshot plan row exists; and
4. every corresponding run row has PASS, NO_RESULT, or SOURCE_MISSING status.

Adjacent comparison rows are reused only when both endpoint snapshots and the
complete comparison group are reusable. Archive-wide builders are reused only
when the complete snapshot/compare plan is reusable.

New, changed, faulty, incomplete, or incompatible snapshots are not partially
seeded. Their complete snapshot batch is run again. Abandoned
`archive-analysis.staging-*` directories are deleted before preparation.

When preparation finds pending work, the combined archive sweep runs against
staging with `--resume`. Archive quality validation must pass before staging
replaces committed `archive-analysis`.

When preparation proves `pending=0` and the archive-wide builders are reusable,
stage 03 is a true no-op: it updates only maintenance metadata needed for the
current run, keeps the committed archive analysis, and does not invoke the
archive sweep or regenerate quality output.

## Dependent databases

The full product-family index is rebuilt when archive work changed or its
builder fingerprint changed. The compact index is rebuilt when the full family
index was rebuilt or its own builder fingerprint changed.

After a successful deep validation, stage 06 stores a validator/query-toolset
fingerprint plus a managed database metadata fingerprint. On a later unchanged
managed run, validation may be reported `Already done` only when the prior
status is PASS, archive work is zero, neither family layer rebuilt, and both
fingerprints still match. `--force-validate` always runs
`test\test_generated_databases.bat`, including the 32 family-query smoke
executions. This cache is a performance mechanism only; source-content
fingerprints and content-addressed evidence hashes remain authoritative.

Stage 06 passes a non-existing `database-validation` output path to the validator; the validator itself owns creation of that directory. This is required by the validator's collision-safety contract.

## HTML output

Stage 07 writes one self-contained browser in the toolkit project root:

```text
mvs-browser-<archive-slot>-YYYYMMDD-HHmmss.html
```

`tools\build_mvs_html_browser.bat compact-index` also defaults to a
date/time-stamped `mvs-browser-YYYYMMDD-HHmmss.html` in the project root when
the output argument is omitted.

## Logs

Every invocation creates:

```text
logs\
  create-or-update-YYYYMMDD-HHmmss\
    console.log
    01_discover_archives.log
    <archive-slot>_02_prepare_archive_update.bat.log
    ...
    run-summary.txt
  create-or-update-YYYYMMDD-HHmmss.zip
```

The ZIP is created after the master log writer is flushed and disposed.

## Health summary

Run:

```bat
display_mvs_database_summary.bat
```

It searches the current directory and parent for `mvs_databases*`, chooses the
candidate with the newest persisted `database-summary.json.updated` value
(falling back to directory time when needed), and prints per-slot colored
health. The
summary checks:

- committed archive/full/compact database presence;
- final database validation state;
- archive plan/run completeness and logical FAIL count;
- archive quality warnings/errors;
- source snapshot count versus database snapshot count;
- source snapshots absent from the database; and
- source snapshots whose current seven-file content fingerprint differs from
  the processed fingerprint.

Quality warnings are displayed as numeric advisory counts and do not by themselves change PASS health; an error/structural condition still promotes the slot to FAIL.
