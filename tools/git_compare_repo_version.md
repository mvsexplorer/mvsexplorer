# git_compare_repo_version

**Version:** 0.7.0

Compares repository versions, the current working tree, ZIP/files, and folders.

## Usage

```bat
tools\git_compare_repo_version 0.19.3
tools\git_compare_repo_version 0.19.3 current
tools\git_compare_repo_version 0.19.3 0.20.0 0.21.2
tools\git_compare_repo_version 0.19.3 "D:\history\Project-0.19.3.zip"
tools\git_compare_repo_version current "D:\checks\project-folder"
```

A single target is compared with `current`. Two or more targets are compared pairwise in the order supplied.

Targets:

- `VERSION` resolves the unique Git commit whose subject begins with `vVERSION`. If the version is not local, the tool may fetch the configured `git_history_import` publication target's `main` history into `refs/remotes/git-history-tools/main` and retry.
- `current` means the current tracked plus non-ignored working-tree files.
- an existing ZIP path is read as a snapshot; one common top directory is stripped;
- an existing folder path is read recursively relative to that folder;
- an existing non-ZIP file is treated as a one-file snapshot.

## Layout handling

The tool automatically reads the active `git_history_import` plan through the repository-local work-folder pointer. External ZIP/file/folder targets are normalized through that plan's reviewed path-move mapping.

If the active import used identity/no layout, comparison also uses identity layout. `--no-layout` explicitly disables layout normalization for the comparison regardless of the active plan.

Repository versions and `current` are already repository-layout snapshots, so they are not remapped.

When exactly one side is external and the other is a repository/current snapshot, the external side defines the managed project set. Managed files must match by path and SHA-256; repository-only framework/tooling files are counted separately. This is the intended way to compare a historical Git version against its original archive after layout normalization.

When both sides are repository snapshots or both are external snapshots, the tool performs a full tree comparison and reports unchanged, modified, only-left, and only-right paths.

Differences are comparison results, not command failures; a successfully completed comparison exits 0 even when the trees differ.

The tool has no Python dependency and uses batch plus embedded Windows PowerShell/.NET.
