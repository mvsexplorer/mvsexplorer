# history_import.py (low-level engine)

`history_import.py` is the byte-exact inspector/replay engine used by
`git_history_import`. Normal users should run `git_history_import`; the two
`just_history_*` launchers are retained for advanced/debugging use.

## Inspector

```bat
call tools\just_history_inspect.bat --source PATH --output plan.json [options]
```

Important options:

```text
--layout PATH|NAME    canonical layout directory/ZIP or included source archive
--identity-layout     keep each revision's own paths; do not reorganize
--final ARCHIVE       legacy alias for selecting an included final archive
--include GLOB        include only matching source revision names; repeatable
--exclude GLOB        exclude matching source revision names; repeatable
--replace-unmanaged PATH
```

The source accepted directly by the low-level engine is a folder of revision ZIPs
or an outer ZIP containing revision ZIPs. `git_history_import` adds its normalization
layer when the user supplies revision folders.

A reference layout is used only to infer canonical destination paths. Identity layout
uses no path mapping: the selected revision snapshot is applied as-is.

The generated plan records archive SHA-256 values, normalized tree SHA-256 values,
deltas, inferred moves, historical-only paths, ambiguities, collisions, exclusions,
and proposed release notes. Replay refuses a plan with unresolved ambiguities or
collisions.

## Replay

```bat
call tools\just_history_replay.bat ^
  --plan plan.json ^
  --source PATH ^
  --mode dryrun|rehearse|publish ^
  [--target PATH] [--baseline PATH] [--reset-target] [--logdir PATH]
```

`dryrun` reads/verifies all revisions without writing project files.

`rehearse` resets/creates a disposable local Git repository, materializes each
revision, stages and commits it, verifies every committed blob, and never contacts a
remote.

`publish` operates on an existing clean Git worktree and invokes the framework's
guarded exact-history publisher for every revision.

All replay modes print `[current/total]` progress. Rehearse/publish also print the
materialize/stage/commit/verify phase plus elapsed time and a rolling remaining-time
estimate.

## Exact-history safety

Historical releases may contain line endings or whitespace that normal new-work
publishing correctly rejects. Exact-history mode does not silently clean them.

For rehearsal/publish the engine temporarily installs a local `* -text` Git
attribute, stages with `core.autocrlf=false`, and verifies committed Git blob bytes
against the source snapshot. The temporary attribute is removed in a `finally` path.

Live publication goes through:

```bat
just_publish.bat historyexact yes messagefile "<generated-message>" PUBLISH COMMIT
```

The framework requires both the exact command tokens and
`HISTORY_IMPORT_EXACT=1`, which is set only by the importer.

Generated log/message files must be outside the target worktree or in a location
that Git confirms is ignored.

## Requirements

Python 3, Git, and (for publish) the normal framework/GitHub dependencies.
Only Python's standard library is used by the importer.
