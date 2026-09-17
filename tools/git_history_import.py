#!/usr/bin/env python3
"""
git_history_import - stateful front end for archived-version Git history reconstruction.

The lower-level byte-exact inspector/replay engine lives in history_import.py.
This front end manages setup, version selection, status, dry run, rehearsal,
publication, and GitHub reauthentication.
"""
from __future__ import annotations

import argparse
import ctypes
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# This tool is commonly run from a Git worktree. Imported-module bytecode must
# never dirty that worktree or block the publish cleanliness gate.
sys.dont_write_bytecode = True

import history_import as engine

TOOL_VERSION = "0.2.3"
STATE_SCHEMA = "git-history-import-state/v1"
POINTER_NAME = "git_history_import_work_folder.txt"

CSI = "\x1b["
RESET = CSI + "0m"
BOLD = CSI + "1m"
RED = CSI + "31m"
GREEN = CSI + "32m"
YELLOW = CSI + "33m"
BLUE = CSI + "34m"
MAGENTA = CSI + "35m"
CYAN = CSI + "36m"
WHITE = CSI + "37m"
DIM = CSI + "2m"


def enable_ansi() -> None:
    if os.name != "nt":
        return
    try:
        kernel32 = ctypes.windll.kernel32
        handle = kernel32.GetStdHandle(-11)
        mode = ctypes.c_uint()
        if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
            kernel32.SetConsoleMode(handle, mode.value | 0x0004)
    except Exception:
        pass


def c(text: str, color: str) -> str:
    return f"{color}{text}{RESET}" if sys.stdout.isatty() else text


def heading(text: str) -> None:
    print()
    print(c("=" * 60, CYAN))
    print(c(f" {text}", BOLD))
    print(c("=" * 60, CYAN))
    print()


def run(cmd: List[str], cwd: Optional[Path] = None, check: bool = False,
        capture: bool = True) -> subprocess.CompletedProcess:
    kwargs = {
        "cwd": str(cwd) if cwd else None,
        "text": True,
        "errors": "replace",
    }
    if capture:
        kwargs["stdout"] = subprocess.PIPE
        kwargs["stderr"] = subprocess.STDOUT
    p = subprocess.run(cmd, **kwargs)
    if check and p.returncode != 0:
        raise RuntimeError((p.stdout or "").strip() or f"Command failed ({p.returncode}): {' '.join(cmd)}")
    return p


def repo_root(start: Optional[Path] = None) -> Path:
    here = (start or Path.cwd()).resolve()
    p = run(["git", "rev-parse", "--show-toplevel"], cwd=here)
    if p.returncode == 0 and p.stdout.strip():
        return Path(p.stdout.strip()).resolve()
    return here


def git_dir(root: Path) -> Optional[Path]:
    p = run(["git", "rev-parse", "--git-dir"], cwd=root)
    if p.returncode != 0:
        return None
    d = Path(p.stdout.strip())
    if not d.is_absolute():
        d = (root / d).resolve()
    return d


def pointer_path(root: Path) -> Optional[Path]:
    gd = git_dir(root)
    return (gd / "info" / POINTER_NAME) if gd else None


def write_pointer(root: Path, work_folder: Path) -> None:
    pp = pointer_path(root)
    if pp:
        pp.parent.mkdir(parents=True, exist_ok=True)
        pp.write_text(str(work_folder.resolve()) + "\n", encoding="utf-8")


def clear_pointer(root: Path) -> None:
    pp = pointer_path(root)
    if pp and pp.exists():
        pp.unlink()


def default_work_folder(root: Path) -> Path:
    # Sibling by default so publish logs/message files cannot be staged.
    return (root.parent / "local_history_import").resolve()


def resolve_work_folder(root: Path, explicit: Optional[str] = None) -> Path:
    if explicit:
        return Path(explicit).expanduser().resolve()
    pp = pointer_path(root)
    if pp and pp.exists():
        val = pp.read_text(encoding="utf-8", errors="replace").strip()
        if val:
            return Path(val).expanduser().resolve()
    return default_work_folder(root)


def state_path(work_folder: Path) -> Path:
    return work_folder / "git_history_import.state.json"


def load_state(root: Path, explicit: Optional[str] = None, required: bool = True) -> Tuple[Path, Optional[dict]]:
    wf = resolve_work_folder(root, explicit)
    sp = state_path(wf)
    if not sp.exists():
        if required:
            raise engine.HistoryError(
                f"No history-import setup was found at {sp}\nRun: git_history_import setup"
            )
        return wf, None
    data = json.loads(sp.read_text(encoding="utf-8"))
    if data.get("schema") != STATE_SCHEMA:
        raise engine.HistoryError(f"Unsupported state schema in {sp}: {data.get('schema')!r}")
    return wf, data


def save_state(work_folder: Path, state: dict) -> None:
    work_folder.mkdir(parents=True, exist_ok=True)
    state["updatedUtc"] = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    state_path(work_folder).write_text(
        json.dumps(state, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def ask(prompt: str, default: Optional[str] = None) -> str:
    suffix = ""
    if default is not None:
        suffix = f" [{default}]"
    try:
        value = input(f"{prompt}{suffix}: ").strip()
    except EOFError:
        value = ""
    return value if value else (default or "")


def yes_no(prompt: str, default_yes: bool) -> bool:
    suffix = "Y/n" if default_yes else "y/N"
    while True:
        ans = ask(f"{prompt} [{suffix}]").lower()
        if not ans:
            return default_yes
        if ans in {"y", "yes"}:
            return True
        if ans in {"n", "no"}:
            return False
        print(c("Please answer y or n.", YELLOW))


def run_stop_skip(prompt: str) -> str:
    """Return run, stop, or skip for guided dryrun/rehearsal prompts."""
    while True:
        ans = ask(f"{prompt} [Y/n/s]").lower()
        if not ans or ans in {"y", "yes"}:
            return "run"
        if ans in {"n", "no"}:
            return "stop"
        if ans in {"s", "skip"}:
            return "skip"
        print(c("Please answer y, n, or s.", YELLOW))


def phase_passed(state: dict, name: str) -> bool:
    rec = (state.get("phases") or {}).get(name)
    return bool(rec and rec.get("ok"))


def read_list_file(path: Path) -> List[str]:
    out = []
    for raw in path.read_text(encoding="utf-8-sig", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        out.append(line)
    return out


def normalize_path_input(value: str, base: Path) -> str:
    p = Path(value).expanduser()
    if not p.is_absolute():
        p = (base / p).resolve()
    return str(p)


def phase_record(ok: bool, report: Optional[Path] = None, detail: str = "") -> dict:
    return {
        "ok": bool(ok),
        "utc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "report": str(report) if report else None,
        "detail": detail,
    }


def ensure_local_ignore(root: Path, work_folder: Path) -> None:
    try:
        rel = work_folder.relative_to(root)
    except ValueError:
        return
    gd = git_dir(root)
    if not gd:
        return
    exclude = gd / "info" / "exclude"
    exclude.parent.mkdir(parents=True, exist_ok=True)
    old = exclude.read_text(encoding="utf-8", errors="replace") if exclude.exists() else ""
    marker = "# git_history_import local work folder"
    line = "/" + rel.as_posix().rstrip("/") + "/"
    if marker not in old or line not in old:
        if old and not old.endswith("\n"):
            old += "\n"
        old += f"{marker}\n{line}\n"
        exclude.write_text(old, encoding="utf-8", newline="\n")



def _zip_directory_snapshot(src_dir: Path, dst_zip: Path) -> None:
    """Snapshot a version directory to an internal ZIP without altering file bytes."""
    with zipfile.ZipFile(dst_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for fp in sorted(src_dir.rglob("*")):
            if fp.is_file():
                z.write(fp, fp.relative_to(src_dir).as_posix())


def _hardlink_or_copy(src: Path, dst: Path) -> None:
    try:
        os.link(src, dst)
    except OSError:
        shutil.copy2(src, dst)


def prepare_engine_source(original: Path, work_folder: Path) -> Tuple[Path, Dict[str, str], List[str]]:
    """
    Normalize mixed version folders/ZIPs only when the lower-level engine needs it.

    Fast path:
      * directory containing only ZIP revisions -> use directly
      * outer ZIP containing only nested ZIP revisions -> use directly

    Mixed/folder path:
      * immediate version directories are snapshotted into an internal ZIP cache
      * ZIP revision files are hardlinked when possible, otherwise copied
      * outer ZIP top-level version folders are repacked in memory into ZIP revisions
    """
    original = original.resolve()
    aliases: Dict[str, str] = {}
    notes: List[str] = []

    if original.is_dir():
        dirs = [p for p in sorted(original.iterdir()) if p.is_dir()]
        zips = [p for p in sorted(original.iterdir()) if p.is_file() and zipfile.is_zipfile(p)]
        unsupported = [
            p for p in sorted(original.iterdir())
            if p.is_file() and not zipfile.is_zipfile(p)
        ]
        if unsupported and not zips and not dirs:
            raise engine.HistoryError(
                "Source directory contains no version folders or ZIP archives."
            )
        if not dirs:
            # Existing engine directly reads ZIP revisions from a folder.
            return original, aliases, notes

        cache = work_folder / "source-cache"
        if cache.exists():
            shutil.rmtree(cache)
        cache.mkdir(parents=True)
        used = set()
        for zp in zips:
            name = zp.name
            if name.casefold() in used:
                raise engine.HistoryError(f"Duplicate normalized source name: {name}")
            _hardlink_or_copy(zp, cache / name)
            used.add(name.casefold())
        for dp in dirs:
            name = dp.name + ".zip"
            if name.casefold() in used:
                raise engine.HistoryError(
                    f"Version folder {dp.name!r} collides with ZIP revision {name!r}."
                )
            _zip_directory_snapshot(dp, cache / name)
            aliases[dp.name] = name
            used.add(name.casefold())
        notes.append(f"Normalized {len(dirs)} version folder(s) into {cache}")
        if unsupported:
            notes.append(
                f"Ignored {len(unsupported)} loose source-root file(s); version entries are folders/ZIPs."
            )
        return cache, aliases, notes

    if original.is_file() and zipfile.is_zipfile(original):
        with zipfile.ZipFile(original, "r") as outer:
            files = [zi for zi in outer.infolist() if not zi.is_dir()]
            nested = [zi for zi in files if zi.filename.lower().endswith(".zip")]
            nonzip = [zi for zi in files if not zi.filename.lower().endswith(".zip")]
            if nested and not nonzip:
                return original, aliases, notes

            # If this ZIP itself is a single version snapshot, wrap it as one
            # revision in a directory source.
            top_groups: Dict[str, List[zipfile.ZipInfo]] = {}
            root_files = []
            for zi in nonzip:
                parts = zi.filename.replace("\\", "/").split("/")
                if len(parts) < 2:
                    root_files.append(zi)
                else:
                    top_groups.setdefault(parts[0], []).append(zi)

            if not nested and root_files:
                cache = work_folder / "source-cache"
                if cache.exists():
                    shutil.rmtree(cache)
                cache.mkdir(parents=True)
                _hardlink_or_copy(original, cache / original.name)
                notes.append("Treated the supplied ZIP as one version snapshot.")
                return cache, aliases, notes

            if top_groups:
                cache = work_folder / "source-cache"
                if cache.exists():
                    shutil.rmtree(cache)
                cache.mkdir(parents=True)
                used = set()
                for zi in nested:
                    name = Path(zi.filename).name
                    if name.casefold() in used:
                        raise engine.HistoryError(f"Duplicate nested revision name: {name}")
                    (cache / name).write_bytes(outer.read(zi))
                    used.add(name.casefold())
                for group, members in sorted(top_groups.items()):
                    name = group + ".zip"
                    if name.casefold() in used:
                        raise engine.HistoryError(
                            f"Version folder {group!r} collides with nested archive {name!r}."
                        )
                    with zipfile.ZipFile(cache / name, "w", compression=zipfile.ZIP_DEFLATED) as z:
                        prefix = group.rstrip("/") + "/"
                        for zi in members:
                            rel = zi.filename.replace("\\", "/")[len(prefix):]
                            if rel:
                                z.writestr(rel, outer.read(zi))
                    aliases[group] = name
                    used.add(name.casefold())
                if root_files:
                    notes.append(
                        f"Ignored {len(root_files)} loose outer-archive file(s) not belonging to a version folder."
                    )
                notes.append(f"Normalized {len(top_groups)} version folder(s) from the outer ZIP into {cache}")
                return cache, aliases, notes

        raise engine.HistoryError("Compressed source contains no detectable version ZIPs/folders.")

    raise engine.HistoryError("Source must be a folder or ZIP archive.")


def engine_inspect(source: str, output: Path, layout: Optional[str],
                   identity: bool, excludes: List[str], includes: List[str]) -> int:
    ns = argparse.Namespace(
        source=source,
        output=str(output),
        final=None,
        layout=layout,
        identity_layout=identity,
        exclude=excludes,
        include=includes,
        replace_unmanaged=["README.md"],
    )
    return engine.inspect_command(ns)


def source_inventory(source: str) -> List[str]:
    with engine.VersionSource(Path(source)) as src:
        return [e.name for e in src.list_entries()]


def parse_versions_text(text: str) -> List[Tuple[str, str, str]]:
    """Return (token, message, full_subject) per non-comment line."""
    rows = []
    for raw in text.replace("\r\n", "\n").replace("\r", "\n").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 1)
        token = parts[0]
        message = parts[1].strip() if len(parts) > 1 else ""
        rows.append((token, message, line))
    return rows


def read_multiline_ctrl_g() -> str:
    print()
    print("Paste one version per line:")
    print(c("  <version> <commit message>", DIM))
    print()
    print("Press CTRL+G twice when finished.")
    print()
    if os.name != "nt":
        print(c("Non-Windows console: finish with a line containing only END.", YELLOW))
        lines = []
        while True:
            try:
                line = input()
            except EOFError:
                break
            if line == "END":
                break
            lines.append(line)
        return "\n".join(lines)

    import msvcrt
    chars: List[str] = []
    bells = 0
    while True:
        ch = msvcrt.getwch()
        if ch == "\x03":
            raise KeyboardInterrupt
        if ch == "\x07":
            bells += 1
            if bells >= 2:
                print()
                break
            continue
        bells = 0
        if ch in ("\x00", "\xe0"):
            msvcrt.getwch()
            continue
        if ch == "\r":
            chars.append("\n")
            sys.stdout.write("\n")
            sys.stdout.flush()
            continue
        if ch == "\b":
            if chars:
                chars.pop()
                sys.stdout.write("\b \b")
                sys.stdout.flush()
            continue
        chars.append(ch)
        sys.stdout.write(ch)
        sys.stdout.flush()
    return "".join(chars)


def version_aliases(revisions: List[dict]) -> Dict[str, List[dict]]:
    by_numeric: Dict[str, List[dict]] = {}
    for rev in revisions:
        by_numeric.setdefault(rev["version"].casefold(), []).append(rev)

    aliases: Dict[str, List[dict]] = {}
    for rev in revisions:
        ver = rev["version"]
        variant = (rev.get("variant") or "").strip()
        keys = []
        if variant:
            keys += [f"{ver}-{variant}", f"v{ver}-{variant}"]
        if not variant or len(by_numeric.get(ver.casefold(), [])) == 1:
            keys += [ver, f"v{ver}"]
        for key in keys:
            aliases.setdefault(key.casefold(), []).append(rev)
    return aliases


def show_match(status: str, token: str, archive: str = "", note: str = "") -> None:
    if status == "FOUND":
        st = c("[FOUND]", GREEN)
        vt = c(token, GREEN)
    elif status == "MISS":
        st = c("[MISS] ", RED)
        vt = c(token, RED)
    else:
        st = c("[ERROR]", RED)
        vt = c(token, RED)
    tail = f"  {c(archive, CYAN)}" if archive else ""
    if note:
        tail += f"  {c(note, YELLOW if status != 'FOUND' else DIM)}"
    print(f"{st} {vt}{tail}")


def rewrite_selected_plan(plan_path: Path, ordered: List[Tuple[dict, str]], source: str) -> None:
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    by_archive = {r["archive"]: r for r in plan["revisions"]}
    revisions = []
    for idx, (match, subject) in enumerate(ordered, 1):
        rev = by_archive[match["archive"]]
        rev["order"] = idx
        rev["subject"] = subject
        revisions.append(rev)
    plan["revisions"] = revisions
    plan["summary"]["includedRevisions"] = len(revisions)

    moves = {x["from"]: x["to"] for x in plan["layout"]["moves"]}
    prev = None
    with engine.VersionSource(Path(source)) as src:
        for rev in revisions:
            cur = engine.archive_snapshot_for_revision(src, rev, moves, include_data=False)
            rev["deltaFromPrevious"] = engine.delta_counts(prev, cur)
            prev = cur

    plan_path.write_text(json.dumps(plan, indent=2, ensure_ascii=False) + "\n",
                         encoding="utf-8", newline="\n")


def write_review_files(work_folder: Path, plan: dict) -> None:
    excluded = plan.get("source", {}).get("excluded", [])
    (work_folder / "EXCLUDED-ARCHIVES.txt").write_text(
        "\n".join(x.get("archive", "") for x in excluded if x.get("archive")) + ("\n" if excluded else ""),
        encoding="utf-8", newline="\n",
    )

    msgdir = work_folder / "messages"
    if msgdir.exists():
        shutil.rmtree(msgdir)
    msgdir.mkdir(parents=True, exist_ok=True)

    combined: List[str] = []
    for idx, r in enumerate(plan.get("revisions", []), 1):
        subject = r.get("subject", "").strip()
        body = [str(x).strip() for x in (r.get("description") or []) if str(x).strip()]
        text = subject + "\n"
        if body:
            text += "\n" + "\n".join("- " + x for x in body) + "\n"
        safe = re.sub(
            r"[^A-Za-z0-9._-]+", "_",
            f"{idx:03d}-{r.get('version','')}-{r.get('variant','')}"
        ).strip("_")
        (msgdir / f"{safe}.txt").write_text(text, encoding="utf-8", newline="\n")
        combined.append(
            f"{'=' * 72}\n"
            f"{idx:03d}  {r.get('archive','')}\n"
            f"{'=' * 72}\n"
            f"{text.rstrip()}\n"
        )

    (work_folder / "COMMIT-MESSAGES.txt").write_text(
        "\n".join(combined) + ("\n" if combined else ""),
        encoding="utf-8", newline="\n",
    )

def setup_command(args: argparse.Namespace) -> int:
    root = repo_root()
    # A fresh setup must never inherit a stale work-folder pointer from a copied
    # repository/bootstrap. Reuse is explicit via --work-folder; subsequent
    # actions use the pointer written by this setup.
    wf = (Path(args.work_folder).expanduser().resolve()
          if args.work_folder else default_work_folder(root))
    heading(f"git_history_import {TOOL_VERSION} - setup")

    source = args.source
    if not source:
        source = ask("Folder or compressed ZIP containing the history revisions")
    if not source:
        raise engine.HistoryError("A source folder or ZIP is required.")
    source = normalize_path_input(source, Path.cwd())
    if not Path(source).exists():
        raise engine.HistoryError(f"Source does not exist: {source}")

    layout = args.layout
    identity = False
    if layout is None:
        if yes_no("Use a final reference layout", False):
            layout = ask("Reference layout folder/ZIP, or source archive name")
            if not layout:
                raise engine.HistoryError("A layout reference was requested but not supplied.")
        else:
            identity = True
    if layout:
        lp = Path(layout).expanduser()
        if lp.exists() or any(sep in layout for sep in ("/", "\\")):
            if lp.exists():
                layout = str(lp.resolve())
            elif not Path(source).is_file():
                layout = normalize_path_input(layout, Path.cwd())

    exclude_file = args.exclude_list
    if not exclude_file and sys.stdin.isatty():
        val = ask("Exclude-list file (optional; blank for none)")
        exclude_file = val or None
    excludes: List[str] = []
    if exclude_file:
        ep = Path(exclude_file).expanduser()
        if not ep.is_absolute():
            ep = (Path.cwd() / ep).resolve()
        if not ep.is_file():
            raise engine.HistoryError(f"Exclude-list file not found: {ep}")
        exclude_file = str(ep)
        excludes = read_list_file(ep)

    versions_file = args.versions
    if versions_file:
        vp = Path(versions_file).expanduser()
        if not vp.is_absolute():
            vp = (Path.cwd() / vp).resolve()
        if not vp.is_file():
            raise engine.HistoryError(f"Versions file not found: {vp}")
        versions_file = str(vp)

    if args.import_all and versions_file:
        raise engine.HistoryError("--import-all and --versions are mutually exclusive.")

    wf.mkdir(parents=True, exist_ok=True)
    ensure_local_ignore(root, wf)

    original_source = source
    engine_source_path, source_aliases, source_notes = prepare_engine_source(Path(source), wf)
    source = str(engine_source_path)
    if layout in source_aliases:
        layout = source_aliases[layout]
    excludes = [source_aliases.get(x, x) for x in excludes]

    candidate = wf / "candidate-plan.json"

    print(f"Repository:   {root}")
    print(f"Work folder:  {wf}")
    print(f"Source:       {original_source}")
    if source != original_source:
        print(f"Engine source:{source}")
    for note in source_notes:
        print(f"  {note}")
    print(f"Layout:       {layout if layout else 'none (identity layout)'}")
    print(f"Exclude list: {exclude_file or 'none'}")
    print(f"Import all:   {'yes' if args.import_all else 'no'}")
    print()
    print("Inspecting source...")
    rc = engine_inspect(source, candidate, layout, identity, excludes, [])
    if rc not in (0, 3):
        return rc

    candidate_plan = json.loads(candidate.read_text(encoding="utf-8"))
    state = {
        "schema": STATE_SCHEMA,
        "toolVersion": TOOL_VERSION,
        "createdUtc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "repoRoot": str(root),
        "workFolder": str(wf),
        "source": source,
        "sourceOriginal": original_source,
        "sourceAliases": source_aliases,
        "layout": {"mode": "identity" if identity else "reference", "value": layout},
        "excludeList": exclude_file,
        "excludePatterns": excludes,
        "versionsFile": versions_file,
        "importAll": bool(args.import_all),
        "candidatePlan": str(candidate),
        "plan": None,
        "selectedVersions": 0,
        "phases": {
            "setup": phase_record(True, candidate, "candidate source/layout inspection complete"),
            "versions": None,
            "dryrun": None,
            "rehearse": None,
            "publish": None,
        },
    }
    save_state(wf, state)
    write_pointer(root, wf)
    write_review_files(wf, candidate_plan)

    print()
    print(c("SETUP PASS", GREEN + BOLD))
    print(f"{c('Discovered:', CYAN)} {c(str(candidate_plan['summary']['discoveredArchives']), BOLD)}")
    print(f"{c('Available after exclusions:', CYAN)} {c(str(candidate_plan['summary']['includedRevisions']), GREEN + BOLD)}")
    print(f"{c('Excluded source entries:', CYAN)} {c(str(candidate_plan['summary']['excludedArchives']), YELLOW + BOLD)}")
    if excludes:
        inventory = source_inventory(source)
        matched_rules = [pat for pat in excludes if any(engine.matches_any(name, [pat]) for name in inventory)]
        absent_rules = [pat for pat in excludes if pat not in matched_rules]
        print(f"Exclude rules: {len(excludes)} configured, {len(matched_rules)} matched, {len(absent_rules)} absent")
        for pat in absent_rules:
            print(c(f"  [ABSENT] {pat}", YELLOW))
    if candidate_plan["layout"].get("ambiguous"):
        print(c(f"Candidate layout currently has {len(candidate_plan['layout']['ambiguous'])} ambiguity/ambiguities.", YELLOW))
        print("Version selection will re-inspect only the chosen revisions.")

    if yes_no("Run git_history_import versions now", True):
        ns = argparse.Namespace(work_folder=str(wf), versions=versions_file)
        return versions_command(ns)
    print()
    print(f"When ready: git_history_import versions"
          + (f' --versions "{versions_file}"' if versions_file else ""))
    return 0


def select_rows_from_import_all(candidate: dict) -> List[Tuple[str, str, str]]:
    rows = []
    for rev in candidate["revisions"]:
        variant = (rev.get("variant") or "").strip()
        token = f"v{rev['version']}" + (f"-{variant}" if variant else "")
        subject = rev.get("subject") or token
        # Preserve generated subject; if it already contains version, use as-is.
        full = subject if subject.casefold().startswith(("v" + rev["version"]).casefold()) else f"{token} {subject}"
        rows.append((token, full[len(token):].strip(), full))
    return rows


def versions_command(args: argparse.Namespace) -> int:
    root = repo_root()
    wf, state = load_state(root, args.work_folder, required=True)
    assert state is not None
    heading("git_history_import - versions")

    candidate = json.loads(Path(state["candidatePlan"]).read_text(encoding="utf-8"))
    versions_path = args.versions or state.get("versionsFile")

    if state.get("importAll"):
        rows = select_rows_from_import_all(candidate)
        print(f"--import-all: selecting all {len(rows)} available revisions.")
    else:
        if versions_path:
            vp = Path(versions_path)
            if not vp.is_file():
                raise engine.HistoryError(f"Versions file not found: {vp}")
            text = vp.read_text(encoding="utf-8-sig", errors="replace")
            print(f"Reading versions from: {vp}")
        else:
            text = read_multiline_ctrl_g()
        rows = parse_versions_text(text)

    if not rows:
        raise engine.HistoryError("No version/message lines were supplied.")

    aliases = version_aliases(candidate["revisions"])
    selected: List[Tuple[dict, str]] = []
    seen_archives = set()
    errors = 0

    print()
    for token, message, full in rows:
        if not message and not state.get("importAll"):
            show_match("ERROR", token, note="missing commit message")
            errors += 1
            continue
        matches = aliases.get(token.casefold(), [])
        if not matches:
            show_match("MISS", token, note="no matching source revision")
            errors += 1
            continue
        if len(matches) > 1:
            show_match("ERROR", token, note="ambiguous: " + ", ".join(r["archive"] for r in matches))
            errors += 1
            continue
        rev = matches[0]
        if rev["archive"] in seen_archives:
            show_match("ERROR", token, rev["archive"], "duplicate version selection")
            errors += 1
            continue
        seen_archives.add(rev["archive"])
        subject = full
        show_match("FOUND", token, rev["archive"])
        selected.append((rev, subject))

    if errors:
        print()
        print(c(f"VERSIONS FAIL: {errors} problem(s). No import plan was activated.", RED))
        state["phases"]["versions"] = phase_record(False, detail=f"{errors} version-selection errors")
        save_state(wf, state)
        return 2

    selected_plan = wf / "plan.json"
    include_names = [rev["archive"] for rev, _ in selected]
    print()
    print("Re-inspecting only the selected revisions...")
    rc = engine_inspect(
        state["source"], selected_plan,
        state["layout"].get("value"),
        state["layout"].get("mode") == "identity",
        state.get("excludePatterns", []),
        include_names,
    )
    if rc != 0:
        state["phases"]["versions"] = phase_record(False, selected_plan, "selected plan has layout ambiguity/collision")
        save_state(wf, state)
        print(c("VERSIONS FAIL: selected revisions have unresolved layout problems.", RED))
        return rc

    rewrite_selected_plan(selected_plan, selected, state["source"])
    plan = json.loads(selected_plan.read_text(encoding="utf-8"))
    write_review_files(wf, plan)

    state["plan"] = str(selected_plan)
    state["selectedVersions"] = len(selected)
    state["phases"]["versions"] = phase_record(True, selected_plan, f"{len(selected)} revisions selected")
    state["phases"]["dryrun"] = None
    state["phases"]["rehearse"] = None
    state["phases"]["publish"] = None
    save_state(wf, state)

    print()
    print(c(f"VERSIONS PASS: {len(selected)} revisions matched with commit messages.", GREEN + BOLD))
    print(f"Commit messages: {wf / 'COMMIT-MESSAGES.txt'}")
    print(f"Excluded entries: {wf / 'EXCLUDED-ARCHIVES.txt'}")

    dry_choice = run_stop_skip("Run dryrun now")
    if dry_choice == "run":
        rc = replay_action("dryrun", root, wf, state)
        if rc:
            return rc
    elif dry_choice == "stop":
        print()
        print(c("Stopped before dryrun.", YELLOW))
        print("When ready: git_history_import dryrun")
        return 0
    else:
        prior = "previous PASS retained" if phase_passed(state, "dryrun") else "not run; publish remains blocked"
        print(c(f"[SKIP] dryrun - {prior}", YELLOW))

    rehearse_choice = run_stop_skip("Run rehearsal now")
    if rehearse_choice == "run":
        rc = replay_action("rehearse", root, wf, state)
        if rc:
            return rc
    elif rehearse_choice == "stop":
        print()
        print(c("Stopped before rehearsal.", YELLOW))
        print("When ready: git_history_import rehearse")
        return 0
    else:
        prior = "previous PASS retained" if phase_passed(state, "rehearse") else "not run; publish remains blocked"
        print(c(f"[SKIP] rehearse - {prior}", YELLOW))

    if not phase_passed(state, "dryrun") or not phase_passed(state, "rehearse"):
        print()
        print(c("Publish is not offered because dryrun and rehearsal have not both passed.", YELLOW))
        if not phase_passed(state, "dryrun"):
            print("Required: git_history_import dryrun")
        if not phase_passed(state, "rehearse"):
            print("Required: git_history_import rehearse")
        return 0

    if yes_no("Publish now", False):
        return replay_action("publish", root, wf, state)
    print()
    print("When ready: git_history_import publish")
    return 0


def cleanup_importer_bytecode(root: Path) -> List[str]:
    """Remove only bytecode generated by this importer from tools/__pycache__."""
    cache = root / "tools" / "__pycache__"
    removed: List[str] = []
    if not cache.is_dir():
        return removed
    for p in list(cache.iterdir()):
        if not p.is_file():
            continue
        name = p.name.casefold()
        if (name.startswith("git_history_import.") or name.startswith("history_import.")) and name.endswith((".pyc", ".pyo")):
            try:
                p.unlink()
                removed.append(str(p))
            except OSError:
                pass
    try:
        if cache.is_dir() and not any(cache.iterdir()):
            cache.rmdir()
    except OSError:
        pass
    return removed


def require_plan(state: dict) -> Path:
    val = state.get("plan")
    if not val or not Path(val).is_file():
        raise engine.HistoryError("No active version plan. Run: git_history_import versions")
    return Path(val)


def replay_action(mode: str, root: Path, wf: Path, state: dict) -> int:
    plan = require_plan(state)
    logs = wf / "logs" / mode
    target = None
    baseline = None
    reset_target = False

    if mode == "rehearse":
        target = wf / "rehearsal-repository"
        baseline = Path(state["repoRoot"])
        reset_target = True
    elif mode == "publish":
        dry = state["phases"].get("dryrun")
        reh = state["phases"].get("rehearse")
        if not dry or not dry.get("ok"):
            raise engine.HistoryError("Publish is blocked until dryrun has passed.")
        if not reh or not reh.get("ok"):
            raise engine.HistoryError("Publish is blocked until rehearsal has passed.")
        target = Path(state["repoRoot"])
        removed = cleanup_importer_bytecode(target)
        if removed:
            print(c(f"Cleaned {len(removed)} importer bytecode cache file(s).", DIM))
        st = run(["git", "status", "--porcelain"], cwd=target)
        if st.returncode != 0 or st.stdout.strip():
            raise engine.HistoryError(
                "Live repository must be clean before publish.\n" +
                (st.stdout.strip() if st.stdout else "")
            )
        origin = run(["git", "remote", "get-url", "origin"], cwd=target)
        origin_url = origin.stdout.strip() if origin.returncode == 0 else ""
        if not origin_url:
            raise engine.HistoryError("Publish target has no origin remote.")
        login, account = github_status(target)
        push_allowed, push_detail = github_push_permission(target, origin_url)
        if login != "logged in":
            raise engine.HistoryError("GitHub login is required before publish.")
        if push_allowed is False:
            raise engine.HistoryError(
                f"Authenticated GitHub account {account!r} does not have push permission to {push_detail}.\n"
                f"origin: {origin_url}\n"
                "Run `git_history_import relogin`, change origin, or publish from the intended repository."
            )
        if push_allowed is None:
            raise engine.HistoryError(
                "Could not verify GitHub push permission before publish.\n"
                f"origin: {origin_url}\n"
                f"detail: {push_detail}"
            )
        print()
        print(c("LIVE PUBLICATION", RED + BOLD))
        print(f"{c('Repository:', CYAN)} {target}")
        print(f"{c('origin:', CYAN)}     {c(origin_url, YELLOW)}")
        print(f"{c('GitHub:', CYAN)}     {c(login, GREEN if login == 'logged in' else RED)}"
              + (f" ({c(account, BOLD)})" if account else ""))
        print(f"{c('Revisions:', CYAN)}  {c(str(state.get('selectedVersions', 0)), BOLD)}")
        print(c("Review the origin above carefully. This operation creates and pushes commits.", YELLOW))
        if not yes_no("Publish now", False):
            print(c("Publication cancelled.", YELLOW))
            return 0

    ns = argparse.Namespace(
        plan=str(plan),
        source=state["source"],
        mode=mode,
        target=str(target) if target else None,
        baseline=str(baseline) if baseline else None,
        reset_target=reset_target,
        logdir=str(logs),
        start_at=None,
        stop_after=None,
    )
    rc = engine.replay_command(ns)
    report = logs / "report.json"
    state["phases"][mode] = phase_record(rc == 0, report if report.exists() else None)
    save_state(wf, state)
    return rc


def action_command(action: str, args: argparse.Namespace) -> int:
    root = repo_root()
    wf, state = load_state(root, getattr(args, "work_folder", None), required=True)
    assert state is not None
    heading(f"git_history_import - {action}")
    return replay_action(action, root, wf, state)


def inspect_command(args: argparse.Namespace) -> int:
    root = repo_root()
    wf, state = load_state(root, args.work_folder, required=True)
    assert state is not None
    heading("git_history_import - inspect")
    out = wf / "candidate-plan.json"
    rc = engine_inspect(
        state["source"], out,
        state["layout"].get("value"),
        state["layout"].get("mode") == "identity",
        state.get("excludePatterns", []),
        [],
    )
    state["candidatePlan"] = str(out)
    state["phases"]["setup"] = phase_record(rc in (0, 3), out, "candidate source/layout reinspection")
    save_state(wf, state)
    return rc


def find_gh(root: Path) -> Optional[str]:
    local = root / "tools" / "gh" / "bin" / "gh.exe"
    if local.is_file():
        return str(local)
    return shutil.which("gh") or shutil.which("gh.exe")


def github_status(root: Path) -> Tuple[str, str]:
    gh = find_gh(root)
    if not gh:
        return "unavailable", "GitHub CLI not found"
    p = run([gh, "auth", "status", "-h", "github.com"], cwd=root)
    if p.returncode != 0:
        return "logged out", (p.stdout or "").strip().splitlines()[-1] if p.stdout else ""
    u = run([gh, "api", "user", "--jq", ".login"], cwd=root)
    account = u.stdout.strip() if u.returncode == 0 else "authenticated"
    return "logged in", account



def github_repo_from_origin(url: str) -> Optional[str]:
    """Return owner/repo for common GitHub HTTPS/SSH origin forms."""
    value = (url or "").strip()
    patterns = (
        r"^https?://github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$",
        r"^ssh://git@github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$",
        r"^git@github\.com:([^/]+)/([^/]+?)(?:\.git)?$",
    )
    for pattern in patterns:
        m = re.match(pattern, value, re.IGNORECASE)
        if m:
            return f"{m.group(1)}/{m.group(2)}"
    return None


def github_push_permission(root: Path, origin_url: str) -> Tuple[Optional[bool], str]:
    """Check GitHub's reported push permission for the authenticated account."""
    repo = github_repo_from_origin(origin_url)
    if not repo:
        return None, "origin is not a recognized GitHub URL"
    gh = find_gh(root)
    if not gh:
        return None, "GitHub CLI not found"
    p = run([gh, "api", f"repos/{repo}", "--jq", ".permissions.push"], cwd=root)
    if p.returncode != 0:
        detail = (p.stdout or "").strip()
        return None, detail or "GitHub API permission check failed"
    value = p.stdout.strip().lower()
    if value == "true":
        return True, repo
    if value == "false":
        return False, repo
    return None, f"unexpected permission response for {repo}: {p.stdout.strip()}"

def status_command(args: argparse.Namespace) -> int:
    root = repo_root()
    wf, state = load_state(root, args.work_folder, required=False)
    heading(f"git_history_import {TOOL_VERSION} - status")
    print(f"Repository:  {root}")
    print(f"Work folder: {wf}")
    login, account = github_status(root)
    login_color = GREEN if login == "logged in" else (YELLOW if login == "unavailable" else RED)
    print(f"GitHub:      {c(login, login_color)}" + (f" ({c(account, BOLD)})" if account else ""))
    origin = run(["git", "remote", "get-url", "origin"], cwd=root)
    if origin.returncode == 0:
        print(f"origin:      {c(origin.stdout.strip(), CYAN)}")
    print()
    if not state:
        print(c("Setup: NOT CONFIGURED", YELLOW))
        print("Run: git_history_import setup")
        return 0

    print(f"Source:      {state.get('sourceOriginal') or state['source']}")
    if state.get("sourceOriginal") and state.get("sourceOriginal") != state.get("source"):
        print(f"Engine src:  {state['source']}")
    layout = state.get("layout", {})
    print(f"Layout:      {layout.get('value') or 'none (identity layout)'}")
    print(f"Exclude:     {state.get('excludeList') or 'none'}")
    patterns = state.get("excludePatterns", []) or []
    if patterns:
        try:
            inventory = source_inventory(state["source"])
            matched_rules = [pat for pat in patterns if any(engine.matches_any(name, [pat]) for name in inventory)]
            absent_rules = [pat for pat in patterns if pat not in matched_rules]
            print(f"Exclude rules:{len(patterns):>4} configured / {len(matched_rules)} matched / {len(absent_rules)} absent")
            for pat in absent_rules:
                print(c(f"              [ABSENT] {pat}", YELLOW))
        except Exception as exc:
            print(c(f"Exclude check: unavailable ({exc})", YELLOW))
    print(f"Import all:  {'yes' if state.get('importAll') else 'no'}")
    print(f"Selected:    {state.get('selectedVersions', 0)} revision(s)")
    print()
    print("Phases:")
    for key in ("setup", "versions", "dryrun", "rehearse", "publish"):
        rec = state.get("phases", {}).get(key)
        if not rec:
            mark = c("NOT RUN", YELLOW)
        elif rec.get("ok"):
            mark = c("PASS", GREEN)
        else:
            mark = c("FAIL", RED)
        print(f"  {key:<10} {mark}")
        if rec and rec.get("report"):
            print(f"             {rec['report']}")
    excl = wf / "EXCLUDED-ARCHIVES.txt"
    msgs = wf / "COMMIT-MESSAGES.txt"
    if excl.exists():
        count = len([x for x in excl.read_text(encoding="utf-8", errors="replace").splitlines() if x.strip()])
        print()
        print(f"Excluded source entries: {count}  ({excl})")
    if msgs.exists():
        count = int(state.get("selectedVersions") or 0)
        if count == 0:
            try:
                cp = json.loads(Path(state["candidatePlan"]).read_text(encoding="utf-8"))
                count = len(cp.get("revisions", []))
            except Exception:
                pass
        print(f"Commit messages:         {count}  ({msgs})")
        print(f"Individual messages:          {wf / 'messages'}")
    return 0


def reset_command(args: argparse.Namespace) -> int:
    root = repo_root()
    wf, state = load_state(root, args.work_folder, required=False)
    heading("git_history_import - reset")
    if not state:
        print("Nothing to reset.")
        clear_pointer(root)
        return 0
    print(f"This will delete history-import working state:\n  {wf}")
    if not yes_no("Reset and start over", False):
        print("Reset cancelled.")
        return 0
    shutil.rmtree(wf)
    clear_pointer(root)
    print(c("RESET COMPLETE", GREEN))
    print("Run: git_history_import setup")
    return 0


def relogin_command(args: argparse.Namespace) -> int:
    root = repo_root()
    heading("git_history_import - GitHub relogin")
    gh = find_gh(root)
    if not gh:
        raise engine.HistoryError("GitHub CLI was not found.")
    login, account = github_status(root)
    if login == "logged in":
        cmd = [gh, "auth", "logout", "-h", "github.com"]
        if account and account not in {"authenticated", ""}:
            cmd += ["-u", account]
        p = run(cmd, cwd=root, capture=False)
        if p.returncode != 0:
            raise engine.HistoryError("GitHub logout failed.")
    login_bat = root / "just_login.bat"
    if login_bat.is_file() and os.name == "nt":
        p = subprocess.run(["cmd.exe", "/d", "/c", "call", str(login_bat), "authenticate"], cwd=str(root))
    else:
        p = subprocess.run([gh, "auth", "login", "-h", "github.com", "-p", "https", "-w"], cwd=str(root))
    if p.returncode != 0:
        raise engine.HistoryError("GitHub login failed.")
    login, account = github_status(root)
    print()
    print(f"GitHub: {login}" + (f" ({account})" if account else ""))
    return 0


def print_help() -> None:
    print(c(f"git_history_import {TOOL_VERSION}", BOLD))
    print()
    print("Reconstruct and publish Git history from complete archived project revisions.")
    print()
    print(c("USAGE", CYAN))
    print("  git_history_import setup [options]")
    print("  git_history_import versions [--versions FILE]")
    print("  git_history_import inspect")
    print("  git_history_import dryrun")
    print("  git_history_import rehearse [--work-folder FOLDER]")
    print("  git_history_import publish")
    print("  git_history_import status")
    print("  git_history_import reset")
    print("  git_history_import relogin")
    print()
    print(c("SETUP OPTIONS", CYAN))
    print("  --source PATH         Folder of version ZIPs or outer ZIP containing them.")
    print("  --layout PATH|NAME   Optional canonical layout folder/ZIP or source archive name.")
    print("                        Omit it and answer No to use each revision's own layout.")
    print("  --versions FILE      Version/message list to use when versions is run.")
    print("  --exclude-list FILE  Source-entry names/globs to exclude, one per line.")
    print("  --work-folder PATH   Local state/log/rehearsal folder.")
    print("  --import-all         Select all non-excluded source revisions.")
    print()
    print(c("VERSIONS FILE FORMAT", CYAN))
    print("  v0.1.0 feat: initial implementation")
    print("  v0.2.0 fix: correct parser behavior")
    print()
    print("Interactive versions input accepts a multi-line paste; press CTRL+G twice to finish.")
    print()
    print(c("WORKFLOW", CYAN))
    print("  setup -> versions -> dryrun -> rehearse -> publish")
    print("  Guided dryrun/rehearse prompts accept Y=run, n=stop, s=skip.")
    print("  dryrun changes no repository.")
    print("  rehearse creates real commits in a disposable local repository.")
    print(c("  publish modifies the live repository and pushes.", YELLOW))
    print()
    print(c("EXAMPLES", CYAN))
    print('  git_history_import setup --source "..\\Project-History.zip" --layout "Project-1.2.0.zip"')
    print('  git_history_import setup --source "D:\\revisions" --exclude-list "exclude.txt" --import-all')
    print('  git_history_import versions --versions "versions.txt"')
    print()
    print("Example input files supplied with the tool:")
    print("  tools\\git_history_import.exclude.list.example.txt")
    print("  tools\\git_history_import.versions.list.example.txt")
    print()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(add_help=False)
    sub = parser.add_subparsers(dest="command")

    s = sub.add_parser("setup", add_help=True)
    s.add_argument("--source")
    s.add_argument("--layout")
    s.add_argument("--versions")
    s.add_argument("--exclude-list")
    s.add_argument("--work-folder")
    s.add_argument("--import-all", action="store_true")
    s.set_defaults(func=setup_command)

    v = sub.add_parser("versions", add_help=True)
    v.add_argument("--versions")
    v.add_argument("--work-folder")
    v.set_defaults(func=versions_command)

    i = sub.add_parser("inspect", add_help=True)
    i.add_argument("--work-folder")
    i.set_defaults(func=inspect_command)

    for action in ("dryrun", "publish"):
        q = sub.add_parser(action, add_help=True)
        q.add_argument("--work-folder")
        q.set_defaults(func=lambda a, action=action: action_command(action, a))

    r = sub.add_parser("rehearse", add_help=True)
    r.add_argument("--work-folder")
    r.set_defaults(func=lambda a: action_command("rehearse", a))

    st = sub.add_parser("status", add_help=True)
    st.add_argument("--work-folder")
    st.set_defaults(func=status_command)

    rs = sub.add_parser("reset", add_help=True)
    rs.add_argument("--work-folder")
    rs.set_defaults(func=reset_command)

    rl = sub.add_parser("relogin", add_help=True)
    rl.set_defaults(func=relogin_command)
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    enable_ansi()
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv or argv[0].lower() in {"/?", "/h", "-?", "-h", "--help", "help"}:
        print_help()
        return 0
    parser = build_parser()
    try:
        args = parser.parse_args(argv)
        if not hasattr(args, "func"):
            print_help()
            return 0
        return int(args.func(args))
    except engine.HistoryError as e:
        print()
        print(c(f"ERROR: {e}", RED), file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print()
        print(c("Interrupted.", YELLOW), file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
