# git_history_import

`git_history_import` reconstructs Git history from complete archived project revisions.

The public command is:

```bat
git_history_import <action> [options]
```

The root `git_history_import.bat` is only a launcher. The implementation lives under
`tools\git_history_import.bat` and `tools\git_history_import.py`.

## Workflow

The normal workflow is:

1. `setup`
2. `versions`
3. `dryrun`
4. `rehearse`
5. `publish`

`status` may be run at any time. `reset` discards local import state and starts over.
`relogin` logs out of GitHub and performs the framework authentication flow again.

### setup

`setup` records the history source, optional canonical layout, exclusions, work folder,
and optional versions file. It inspects the source and writes a candidate plan.

```bat
git_history_import setup
```

Non-interactive options:

```text
--source PATH
--layout PATH|NAME
--versions FILE
--exclude-list FILE
--work-folder PATH
--import-all
```

The source can be:

- a directory containing revision ZIP files;
- a directory containing revision folders and/or revision ZIP files;
- an outer ZIP containing nested revision ZIP files;
- an outer ZIP containing top-level revision folders.

When the lower-level engine needs a uniform representation, revision folders are
snapshotted into the local work-folder cache. Revision ZIPs are read directly when
possible; local ZIPs are hardlinked into the cache when normalization is required and
the filesystem allows it.

The reference layout can be:

- a directory containing the desired canonical final file layout;
- an external ZIP containing that layout;
- the filename of one revision ZIP inside the history source.

If no reference layout is selected, path mapping is disabled. Every selected revision
keeps its own relative paths. When a file disappears from the next revision, the
previous imported copy is deleted; newly appearing files are added. Unmanaged framework
files are preserved unless a planned imported path is explicitly allowed to replace one.

### versions

`versions` selects exactly which source revisions become Git commits and assigns the
commit subject for each one.

Interactive mode accepts a multi-line paste:

```text
v0.1.0 feat: initial implementation
v0.2.0 fix: correct parser behavior
```

Press `CTRL+G` twice to terminate the paste.

File mode:

```bat
git_history_import versions --versions my-versions.txt
```

Each line is checked before a plan is activated:

```text
[FOUND] v0.1.0  Project-0.1.0.zip
[MISS]  v0.1.1  no matching source revision
[ERROR] v0.2.0  ambiguous ...
```

Variant names may be used to disambiguate two archives with the same numeric version,
for example `v0.14.1-development-handoff`. If only one archive exists for a numeric
version, a filename suffix such as `-final` does not have to be repeated in the versions
file.

With `--import-all`, all non-excluded source revisions are selected. Numeric semantic
versions are ordered by version; collisions are ordered deterministically by source
entry name.

### dryrun

`dryrun` rereads every selected source revision, applies the reviewed mapping in memory,
and verifies archive hashes, normalized tree hashes, deltas, and collisions. It changes
no repository and creates no commits.

```bat
git_history_import dryrun
```

Progress is printed as `[current/total]` with elapsed time and an estimated remaining
time.

### rehearse

`rehearse` performs the real materialize/delete/stage/commit/verify sequence in a
disposable local repository.

```bat
git_history_import rehearse
git_history_import rehearse --work-folder D:\temp\history-work
```

Rehearsal starts immediately. It does not ask for a confirmation because the rehearsal
repository is disposable and no remote is contacted. The live repository is not
modified.

### publish

`publish` is blocked until both `dryrun` and `rehearse` have passed. It also requires a
clean live worktree. It asks for a default-No confirmation before creating and pushing
the selected commits.

```bat
git_history_import publish
```

The byte-exact publisher uses the guarded `historyexact` path in the framework's
`just_publish.bat`, preserving historical whitespace and line endings while verifying
the committed Git blobs.

### status

```bat
git_history_import status
```

Status reports:

- repository and work folder;
- original and normalized source when different;
- layout mode/reference;
- exclude list;
- selected revision count;
- setup/versions/dryrun/rehearse/publish PASS/FAIL/NOT RUN;
- paths to the reports;
- count/path of excluded source entries;
- count/path of commit messages;
- current GitHub login status/account;
- current `origin`.

### reset

```bat
git_history_import reset
```

Reset removes only a recognized `git_history_import` work folder after confirmation and
clears the local `.git\info` pointer to it.

### relogin

```bat
git_history_import relogin
```

This logs the current GitHub account out and invokes the framework authentication-only
login path again. `status` reports the resulting login account.

## Work-folder files

The work folder is local state, not project source. By default it is a sibling named
`local_history_import`; a custom path can be supplied with `--work-folder`.

Important generated files include:

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

If a custom work folder is inside the live Git worktree, setup adds it to the local
`.git\info\exclude`; the replay engine refuses to use an in-worktree log folder unless
Git confirms it is ignored.

## Exclusion-list format

See `git_history_import.exclude.list.example.txt`.

One source entry path/name or glob per line. Blank lines and `#` comments are ignored.

## Versions-list format

See `git_history_import.versions.list.example.txt`.

One selected version plus commit subject per line. Blank lines and `#` comments are
ignored.

## Low-level engine

`history_import.py` remains the lower-level inspector/replay engine. Its
`just_history_inspect.bat` and `just_history_replay.bat` launchers are retained for
advanced/debugging use; normal users should use `git_history_import`.
