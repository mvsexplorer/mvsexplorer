# MVS Explorer Toolkit — Batch Style Guide Addendum

**Addendum version:** 0.1.0  
**Applies with:** Batch File Style Guide v1.8.0  
**Project:** MVS Explorer Toolkit

This addendum does not replace the supplied style guide. It records project-specific clarifications discovered while implementing MVS Explorer Toolkit.

## 1. Standalone delivery is a project requirement

Every user-facing `.bat` tool delivered in MVS Explorer Toolkit must be independently runnable when copied by itself.

Therefore a delivered tool must not require another toolkit `.bat`, `.cmd`, `.ps1`, `.js`, library file, generated cache, configuration file, or documentation file in order to perform its advertised core function.

Windows components such as `cmd.exe` and `powershell.exe`, and the user's selected MVS dump files, are runtime dependencies rather than toolkit-file dependencies.

This project-specific rule intentionally favors duplication over shared runtime helpers.

Development-time generators and tests may be shared, but generated deliverables must remain standalone.

## 2. Embedded PowerShell is part of the standalone file

When PowerShell is necessary, substantial PowerShell should be embedded between labels and executed through `:RunPowerShellFromLabel`.

No temporary `.ps1` file is created for ordinary parsing.

The embedded block is considered part of the `.bat` tool itself, not an external dependency.

## 3. Console-filter behavior overrides pause-on-double-click defaults

The scalar `print_` and `read_` tools are designed primarily as console filters that can be piped and redirected.

They therefore do **not** pause on exit, even when launched outside an existing console.

A future explicitly interactive tool may use `:IsConsole` and pause where appropriate.

## 4. Human and machine output are separate contracts

`print_` means human-oriented output.

`read_` means machine-oriented output.

Machine output must not contain:

- ANSI color;
- banners;
- labels;
- progress text;
- pause prompts;
- explanatory prose on stdout.

Errors go to stderr.

## 5. TSV is the initial machine scalar protocol

For scalar `read_` tools:

- one product is one physical line;
- fields are separated by TAB;
- no header is emitted;
- missing values are empty fields;
- TAB/CR/LF occurring inside values are normalized to spaces.

If a future format is called CSV/JSON/XML, proper escaping for that format is mandatory.

## 6. Preserve source order unless a tool explicitly promises sorting

Scalar tools emit products in `mvs_ids.txt` order.

Do not silently sort by ID, title, or date in a tool whose name does not state a sorting behavior.

## 7. Source truth versus convenience joins must be documented

An ID join from `mvs_dates.txt` is source-supported.

The current note join is title-based because `mvs_notes.html` lacks IDs. It is a convenience relation and must be described as such.

Future tools should keep similar distinctions explicit.

## 8. Tool names are part of the public interface

Current convention:

```text
print_mvs_dump_<projection>.bat
read_mvs_dump_<projection>.bat
```

Projection fields are ordered left to right in the filename and in output.

Changing a tool's field order is an interface change.

## 9. Complete scalar projection set

For four scalar product fields, the toolkit intentionally exposes all 15 non-empty combinations rather than an arbitrary subset.

This makes naming predictable and prevents special-case growth.

## 10. Duplicate implementation must be synchronized deliberately

Because standalone delivery duplicates common code, a change to shared behavior such as dump resolution, note normalization, help, error handling, or the PowerShell bridge must be propagated to every affected standalone tool and recorded in each tool's version history.

Automated generation is encouraged during development to reduce drift, provided the delivered `.bat` files remain independent.

## 11. Project documentation is a maintained development artifact

At milestone delivery, update as applicable:

- project version history;
- changed tool version histories;
- developer diary;
- observation journal;
- development directives when user requirements change;
- this addendum when project experience clarifies batch conventions;
- the PowerShell style guide when embedded PowerShell conventions change.
