# testprofile_pleaseignore

This repository is a reusable Windows command-line development kit and starter project for creating, preparing, building, installing, and maintaining software repositories.
The first command bootstraps this template, the second previews creation of your new repository, and the third creates it after you have reviewed the dry run.

```bat
set "bootstrap=https://raw.githubusercontent.com/helpersforopenwrt/testprofile_pleaseignore/main/tools/bootstrap.bat" & call curl.exe -sSfL "%bootstrap%" -o "%TEMP%\bootstrap.bat" && call "%TEMP%\bootstrap.bat" auto
```

```bat
tools\git_create_repository.bat name your_repo_name_here dryrun
```

```bat
tools\git_create_repository.bat name your_repo_name_here
```

## What this package is

This repository is both a working demonstration project and a reusable Windows batch-file development framework. It is designed to let a new project start with the same repository setup, Git/GitHub helpers, tool preparation, build orchestration, source snapshots, installation/deployment hooks, and maintenance commands instead of recreating that infrastructure each time.

The bootstrap script can be downloaded directly from the repository and run before the repository exists locally. For GitHub raw URLs, it derives the repository owner, repository name, and branch from the bootstrap URL, then clones or updates the project and prepares the tools needed by the repository.

In `auto` mode, the bootstrap workflow can:

- find or prepare Git;
- clone or update the repository;
- prepare repository tools such as GitHub CLI;
- optionally authenticate with GitHub;
- detect direct-push permission and optionally configure a fork;
- optionally create a new normal GitHub repository from the template;
- run project preparation;
- run the project build;
- optionally install or deploy the result; and
- leave the command prompt in the resulting project directory.

The framework is intentionally project-type independent. Generic launchers live at the project root, while project-specific implementations use suffixes such as `noop`, `web`, `androidjava`, or `windowstcc`.

## Creating a new repository from this template

After bootstrap has cloned the template, run the repository creator with the name you want.

Always review a dry run first:

```bat
tools\git_create_repository.bat name your_repo_name_here dryrun
```

Then create the repository:

```bat
tools\git_create_repository.bat name your_repo_name_here
```

By default, the repository creator:

- uses the authenticated GitHub account as the owner;
- creates a normal GitHub repository rather than a GitHub fork;
- creates the new repository as **private** unless another visibility is requested;
- preserves the existing local Git history;
- rewrites references from the template repository to the new repository;
- renames standalone occurrences of the old repository name where appropriate;
- includes tracked files and untracked files that are not ignored;
- excludes disposable root build-output directories named `build_*`, `source_*`, and `oldbuilds`;
- creates the GitHub repository only after local validation succeeds;
- sets the new repository as the local `origin`;
- leaves the template repository out of the remote list by default;
- performs the first push; and
- renames the local checkout directory to the new repository name after success.

For example:

```bat
tools\git_create_repository.bat name my_new_project dryrun
tools\git_create_repository.bat name my_new_project
```

Use:

```bat
tools\git_create_repository.bat --help
```

for repository owner, visibility, branch, source/upstream, authentication, identity, reference-rewrite, confirmation, and folder-rename options.

### Git remotes after repository creation

The normal result is:

```text
origin -> https://github.com/YOUR_ACCOUNT/your_repo_name_here.git
```

A Git remote named `upstream` is only a local nickname; GitHub gives that name no special behavior. This framework therefore does not add an `upstream` remote by default when creating a new independent repository.

If you explicitly request that the original template be retained as a source, it can be kept locally as:

```text
origin   -> your new repository
upstream -> the original template repository
```

This is useful only when you deliberately want to pull later template changes into the new project.

## Most useful parts

### Bootstrap

`tools\bootstrap.bat` is the remote entry point. It can identify a GitHub repository from the raw bootstrap URL, obtain or update the checkout, prepare repository tooling, and run the project lifecycle.

The common entry point is:

```bat
set "bootstrap=https://raw.githubusercontent.com/helpersforopenwrt/testprofile_pleaseignore/main/tools/bootstrap.bat" & call curl.exe -sSfL "%bootstrap%" -o "%TEMP%\bootstrap.bat" && call "%TEMP%\bootstrap.bat" auto
```

### Repository creation

`tools\git_create_repository.bat` turns the current template checkout into a new independent GitHub repository while preserving history and migrating repository references safely.

The companion `tools\git_create_repository_rewrite.ps1` performs the text-reference scan and rewrite. Binary files containing old repository references stop the migration rather than being modified blindly.

Generated root directories are not project source and are excluded from new-repository migration:

```text
build_*
source_*
oldbuilds
```

They are also ignored by `.gitignore` because the build system recreates them as needed.

### Git and GitHub helpers

The repository contains friendly wrappers for common source-control operations. Frequently useful commands include:

```bat
just_status.bat
just_diff.bat
just_commit.bat
just_push.bat
just_getlatest.bat
just_login.bat
just_logout.bat
```

Additional helpers under `tools` cover branches, history, stashes, tags, releases, pull requests, backups, remotes, ignored files, line endings, undo/restore operations, and repository diagnostics.

The `just_*` scripts are convenience entry points. The larger `git_*.bat` scripts under `tools` contain most of the implementation.

### Portable tool preparation

The framework can use development tools already available on the machine or prepare project-local copies when needed. Tool acquisition helpers include:

```text
tools\GetGit.bat
tools\GetGithubCLI.bat
tools\GetTCC.bat
tools\GetAndroidSDK.bat
tools\GetADB.bat
```

This lets a project prepare much of its own development environment instead of depending entirely on machine-wide installations.

### Project templates

Reusable implementation templates are stored under:

```text
tools\templates\build
tools\templates\prepare
tools\templates\install
tools\templates\build_config
```

Current template families include:

```text
noop
web
androidjava
windowstcc
```

`noop` is the safe demonstrator and starting point. The other templates show how the same launcher architecture can be adapted to web deployment, Android/Java projects, and Windows native C projects.

## Project-root rule

`build_config.bat` is the authoritative project-root marker.

Helpers search in this order:

1. current folder: `build_config.bat`;
2. parent folder: `build_config.bat`;
3. current folder: `build.bat`;
4. parent folder: `build.bat`.

After locating the project root, a helper changes to that directory. This supports both:

```bat
just_status.bat
tools\just_status.bat
```

and also allows a helper to be launched while the current directory is `tools`.

`build_config.bat` contains shared project identity and configuration. A suffix-specific configuration file such as:

```text
build_config_noop.bat
build_config_web.bat
build_config_androidjava.bat
build_config_windowstcc.bat
```

can add settings for one implementation without placing every project type in the shared file.

## Build system

The build system is a small plug-in architecture made from three layers:

```text
prepare.bat  -> prepare_*.bat
build.bat    -> build_*.bat
install.bat  -> install_*.bat
```

The unsuffixed files are generic launchers. Suffixed files contain the implementation for a project type or build target.

For example, a project can contain:

```text
prepare_noop.bat
build_noop.bat
install_noop.bat
```

or replace/add those with another family such as:

```text
prepare_web.bat
build_web.bat
install_web.bat
```

Eligible implementations are discovered from the project root and run alphabetically. Configuration and launcher files are deliberately excluded from implementation discovery.

### 1. Preparation

`prepare.bat` separates repository preparation from project preparation.

Repository preparation handles source-control infrastructure that is independent of the project type:

- detect the source-control system and repository provider;
- resolve or prepare Git;
- resolve or prepare GitHub CLI for GitHub repositories;
- expose selected tools through `PATH`.

Repository preparation does **not** authenticate automatically. Authentication remains an explicit operation through the login helpers or through a bootstrap flow that asks for it.

Project preparation then runs eligible `prepare_*.bat` implementations. A project-specific preparation script can:

1. check whether its environment is already ready;
2. install or prepare missing SDKs, compilers, runtimes, or other tools;
3. validate the prepared environment;
4. apply environment variables and `PATH` changes; and
5. optionally write a reusable environment file.

The generic `prepare_noop.bat` exposes these primary customization functions:

```text
:CheckProjectPreparationReady
:PrepareProjectOperations
:ValidateProjectPreparation
:ApplyProjectEnvironment
:WriteProjectEnvironmentFile
```

Project preparation implementations are called in the current command shell so intentional environment changes can remain available to later lifecycle steps.

### 2. Build

`build.bat` discovers eligible root-level `build_*.bat` implementations and runs them. Each build implementation receives the project root and its suffix through launcher variables.

Build implementations are executed in a child `cmd.exe`, which helps isolate one build implementation's temporary environment from the launcher and from other implementations.

The generic `build_noop.bat` demonstrates the complete build lifecycle even though it intentionally has no compiler configured:

1. load `build_config.bat`;
2. load suffix-specific configuration such as `build_config_noop.bat`;
3. parse the requested build mode;
4. check generic and project-specific prerequisites;
5. create temporary build work directories;
6. run the project-specific build operations;
7. validate the build output;
8. create a source snapshot;
9. promote temporary work into timestamped final directories; and
10. archive older build/source directories under `oldbuilds`.

Its main customization points are:

```text
:CheckBuildPrerequisites
:BuildOperations
:ValidateBuildOutputs
```

A real project normally replaces or adapts those functions with compiler, linker, packager, bundler, test, or other build commands.

### Build outputs and source snapshots

The generic snapshot-oriented build layout is:

```text
build_YYYY-MM-DD.HHhmm.ss\
source_YYYY-MM-DD.HHhmm.ss\
oldbuilds\
```

The temporary build is created first. Final folders are promoted only after the build and validation succeed.

When the project is a Git worktree, the source snapshot is Git-aware: it includes tracked files plus untracked files that are not ignored. The snapshot excludes repository metadata and disposable build output, including:

```text
.git
build_*
source_*
oldbuilds
```

If Git-aware snapshotting is unavailable, the generic implementation can fall back to a filesystem copy.

Older timestamped build and source folders are moved into `oldbuilds`. These directories are outputs, not canonical project source, and can be recreated by future builds.

### Multiple build implementations

A project may contain more than one eligible implementation. For example:

```text
build_client.bat
build_server.bat
build_package.bat
```

`build.bat` runs eligible implementations alphabetically and reports a summary containing succeeded, failed, and ignored candidates.

This makes the launcher useful both for a single application and for projects with multiple independent build targets.

### 3. Installation and deployment

`install.bat` uses the same suffix-based dispatcher pattern for `install_*.bat`.

The generic `install_noop.bat` models a full install/uninstall lifecycle without modifying the machine until project-specific operations are supplied. Its lifecycle can:

1. apply a prepared project environment;
2. check installation prerequisites;
3. resolve and validate an install source;
4. optionally invoke the build when an artifact is missing;
5. resolve the install destination;
6. display the installation plan;
7. request confirmation when configured;
8. perform project-specific installation/deployment operations;
9. validate the result;
10. provide uninstall/rollback guidance; and
11. optionally launch the installed program.

The same file also provides an uninstall path with prerequisite checks, planning, confirmation, removal operations, and result validation.

Build and install implementations run independently, so a project can support building without installation, or use `bootstrap.bat auto` to chain preparation and build with optional installation.

## Root shortcuts

The root shortcut files are intentionally small. A root helper uses its own filename to call the matching implementation under `tools`.

To expose another helper at the project root:

1. copy `tools\_root_helper_stub_TEMPLATE.bat` to the project root;
2. rename the copy to the exact helper filename, for example `just_history.bat`;
3. confirm that `tools\just_history.bat` exists.

## Safety and generated files

`git_create_repository.bat` validates the local workspace before creating a remote repository. The remote repository is created only after the local migration plan and reference changes have passed validation.

The repository creator treats these root directories as disposable generated output:

```text
/build_*/
/source_*/
/oldbuilds/
```

They are intentionally excluded from migration and ignored by Git.

`git_backup_bundle.bat` backs up committed Git history. Git bundles do not contain uncommitted, untracked, or ignored files.

`git_discard_local_changes_DANGEROUS.bat` previews untracked files with `git clean -nd` and requires the exact confirmation word `DISCARD` before destructive cleanup.
