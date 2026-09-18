# git_get_old_repo_version_zip

**Version:** 0.7.0

Exports the complete repository tree for a historical version as a ZIP.

```bat
tools\git_get_old_repo_version_zip 0.19.3
```

By default the output is written to the current directory as `<repository>-v<VERSION>.zip`. Use `--output FILE` to choose another path.

The version resolver first looks for exactly one Git commit whose subject begins with `vVERSION`. If that version is not present in the local object database, the tool looks for the active `git_history_import` state and, when it contains a configured publication target, fetches that target's `main` history into the non-working-tree ref `refs/remotes/git-history-tools/main` and retries. This allows the utility to work from a fresh framework/bootstrap worktree after a successful publish. If no version-subject match exists, a Git commit/ref may be supplied directly. `current` exports `HEAD`.

The ZIP is produced with `git archive`, so it represents committed repository content only. If the output path is inside the repository, the generated ZIP is added to the repository-local `.git\info\exclude`; project `.gitignore` is not changed.

The tool has no Python dependency and uses batch plus embedded Windows PowerShell for orchestration.
