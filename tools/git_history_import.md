# git_history_import

**Version:** 0.3.6

`git_history_import` reconstructs and publishes Git history from complete archived project revisions.

The command intentionally lives only under `tools\` because it is an infrequently used repository-maintenance tool:

```bat
tools\git_history_import <action> [options]
```

There is no root-level launcher.

## Dependencies

`git_history_import` has **no Python dependency** and contains no Python source.

The single `tools\git_history_import.bat` file uses:

- ordinary `cmd.exe` batch for the launcher/scaffold;
- embedded Windows PowerShell/.NET for ZIP, JSON, SHA-256, filesystem, and replay operations that are disproportionately awkward in pure batch;
- Git for repository operations;
- GitHub CLI only for `relogin`, GitHub status, permission checks, and live publication preflight.

No temporary `.ps1` files are created.

## Workflow

The normal workflow remains:

```text
setup -> versions -> dryrun -> rehearse -> publish
```

`status` may be run at any time. `reset` removes the local importer state. `relogin` performs a GitHub logout/login cycle.

### setup

All three source forms are equivalent:

```bat
tools\git_history_import "D:\history\Project.zip"
tools\git_history_import setup "D:\history\Project.zip"
tools\git_history_import setup --source "D:\history\Project.zip"
```

`setup` without a source still prompts for one:

```bat
tools\git_history_import setup
```

Options:

```text
--source PATH
--layout PATH|NAME
--versions FILE
--exclude-list FILE
--work-folder PATH
--import-all
```

The source may be a directory of revision ZIPs, a directory of revision folders/ZIPs, or an outer ZIP containing nested revision ZIPs/top-level revision folders.

The optional layout may be an external folder, external ZIP, or the filename of any revision ZIP in the history source. A layout revision is a placement reference only and does not need to be selected in the versions list or published as a Git commit. If no final layout is selected, each revision keeps its own paths and each new snapshot becomes the complete managed project state for that revision.

Example — deliberately a real one-line `cmd.exe` command:

```bat
tools\git_history_import setup --source "D:\mvsworkfolder\MVS-Explorer.zip" --layout "MVS-Explorer-Toolkit-0.21.2.zip" --exclude-list "D:\mvsworkfolder\MVS-Explorer.zip.exclude.txt" --versions "D:\mvsworkfolder\MVS-Explorer.zip.versions.txt"
```

### versions

```bat
tools\git_history_import versions
tools\git_history_import versions --versions "D:\history\Project.zip.versions.txt"
```

Interactive input accepts:

```text
v0.1.0 feat: initial implementation
v0.2.0 fix: correct parser behavior
```

Press `CTRL+G` twice to finish interactive paste input.

Each requested revision is reported as `[FOUND]`, `[MISS]`, or `[ERROR]` before a plan is activated.

### dryrun

```bat
tools\git_history_import dryrun
```

Dry run reads each selected revision, applies the reviewed layout mapping in memory, verifies archive/tree hashes and collisions, and changes no repository.

Progress is one line per revision. In the guided workflow, `Y` runs, `n` stops, and `s` skips the phase.

### rehearse

```bat
tools\git_history_import rehearse
```

Rehearsal creates a disposable sibling repository under the work folder and performs the real materialize/delete/stage/commit/blob-verification sequence. The live repository and GitHub are not modified.

Before each revision, the exact commit subject is printed. The full subject/body is saved under the rehearsal log `messages\` directory.

### publish

```bat
tools\git_history_import publish
```

Publish is blocked until both dry run and rehearsal have passed. It requires a clean live worktree, a GitHub login, a recognized GitHub `origin`, and verified push permission for the authenticated account.

The target repository, origin, account, and revision count are displayed before the default-No confirmation.

The framework `just_publish.bat historyexact` path is used so archived line endings and whitespace are preserved byte-for-byte.

### status

```bat
tools\git_history_import status
```

Status reports the active work folder, source, layout, selected revision count, GitHub login/origin, and PASS/FAIL/NOT RUN state for setup, versions, dryrun, rehearse, and publish.

### reset

```bat
tools\git_history_import reset
```

Reset removes only the recognized importer work folder and clears the local `.git\info` pointer.

### relogin

```bat
tools\git_history_import relogin
```

Relogin logs out the current GitHub account and invokes the framework authentication-only login flow.


## Diagnostics

`tools\git_history_import logs` creates a diagnostic ZIP under the project-local ignored log folder:

```text
tools\logs\git_history_import.YYYY-MM-DD.HHMMSS.zip
```

The bundle includes importer state, candidate/final plans, phase reports, review/message files, the most recent `last-error.txt`, companion configuration files when available, and the current importer BAT. It does **not** include the source history archive, source cache, or rehearsal repository.

Fatal importer errors write `last-error.txt` into the active work folder and print the `logs` command to use for packaging diagnostics.


## Work folder

The default work folder is the sibling:

```text
local_history_import
```

A different location can be selected with `--work-folder`.

Generated review/audit files include:

```text
git_history_import.state.json
candidate-plan.json
plan.json
EXCLUDED-ARCHIVES.txt
COMMIT-MESSAGES.txt
messages\
logs\dryrun\report.txt
logs\dryrun\report.json
logs\rehearse\report.txt
logs\rehearse\report.json
rehearsal-repository\
```

## Input examples

Generic examples are supplied as:

```text
tools\git_history_import.exclude.list.example.txt
tools\git_history_import.versions.list.example.txt
```

The exclude file contains one source name/path glob per line. Blank lines and `#` comments are ignored.

The versions file contains one version token and commit message per line. Blank lines and `#` comments are ignored.

## Batch implementation notes

The BAT follows the project Batch File Style Guide:

- `EnableExtensions` is assumed and is never enabled.
- The script does not use `setlocal` or delayed expansion.
- Commands are not physically continued with a trailing caret.
- The top-level batch scaffold is `:setup`, `:main`, `:end`, then `GoTo :EOF`.
- Reusable batch functions have documentation/version blocks.
- The PowerShell fallback is embedded between labels inside the BAT and executed through `:RunPowerShellFromLabel`; no `.ps1` file is generated.
- The BAT is UTF-8 without BOM with CRLF line endings.

## 0.3.1

- Added positional source setup: `tools\git_history_import SOURCE`.
- Added automatic `.layout.txt`, `.exclude.txt`, and `.versions.txt` companion discovery.
- Added `.layout.txt` support as a one-line canonical layout reference.
- Added deterministic companion precedence and ambiguity detection.

## 0.3.0

0.3.0 is an architectural revision:

- removed `git_history_import.py`;
- removed `history_import.py`;
- removed the Python-based low-level history launchers;
- removed the root-level `git_history_import.bat` launcher;
- consolidated the importer into `tools\git_history_import.bat`;
- eliminated the Python runtime dependency and `__pycache__` side effects;
- adopted the project batch style guide for the command surface and scaffold;
- preserved the 0.2.x setup/versions/dryrun/rehearse/publish/status/reset/relogin workflow.

## Positional source and companion discovery

A source archive or folder may be passed as the first positional argument:

    tools\git_history_import "D:\history\Project.zip"
    tools\git_history_import "D:\history\Project"

This is equivalent to `setup --source PATH`.

For a file source such as `Project.zip`, the preferred companion files beside it are `Project.zip.layout.txt`, `Project.zip.exclude.txt`, and `Project.zip.versions.txt`. For a folder source such as `Project`, the preferred files inside the source folder are `Project\Project.layout.txt`, `Project\Project.exclude.txt`, and `Project\Project.versions.txt`; sibling `Project.TYPE.txt` files are also accepted. If no exact companion is present, a unique `*.TYPE.txt` in the applicable search folder may be used. Multiple wildcard candidates are an error rather than a guess.

Explicit `--layout`, `--exclude-list`, and `--versions` values override automatic discovery.

A `.layout.txt` file contains exactly one active line after blank lines and `#` comments are ignored. That line may be the name of a source revision archive, a ZIP path, or a folder path.


## Version history

### 0.3.5

- Fixed command dispatch on Windows PowerShell 5.1 by removing collisions with the automatic `$args` variable.
- Renamed option-parser and GitHub-login argument variables to non-reserved names.
- Added `setup SOURCE` as an explicit positional-source form alongside `SOURCE` and `setup --source SOURCE`.
- Added a source-not-found error instead of falling through to generic help for a nonexistent positional source.

### 0.3.2

- Fixed Windows PowerShell 5.1 parsing of a state-schema error message by delimiting the interpolated path variable before `:`.
