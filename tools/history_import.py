#!/usr/bin/env python3
"""
General-purpose version-archive history inspector and replay tool.

The tool turns a bundle/directory of version ZIPs into a reviewable plan, then
reconstructs each version into the final release's canonical path layout.

Subcommands:
  inspect   build a JSON import plan
  replay    dry-run, rehearse locally, or publish through just_publish.bat

Only Python's standard library is used.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime as _dt
import fnmatch
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Dict, Iterable, Iterator, List, Optional, Tuple

SCHEMA = "history-import-plan/v1"
VERSION_RE = re.compile(r"(?P<version>\d+(?:\.\d+){1,3})(?:-(?P<variant>[^.]+))?\.zip$", re.I)
VERSION_LINE_RE = re.compile(r"^\s*(\d+(?:\.\d+){1,3})(?:\s*-\s*.*)?\s*$")
HISTORY_MARKER_BEGIN = "# history-import exact-bytes begin"
HISTORY_MARKER_END = "# history-import exact-bytes end"


class HistoryError(RuntimeError):
    pass


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def git_blob_oid(data: bytes, algorithm: str = "sha1") -> str:
    header = f"blob {len(data)}\0".encode("ascii")
    h = hashlib.new(algorithm)
    h.update(header)
    h.update(data)
    return h.hexdigest()


def stable_tree_sha256(files: Dict[str, dict]) -> str:
    h = hashlib.sha256()
    for path in sorted(files, key=str.casefold):
        h.update(path.encode("utf-8"))
        h.update(b"\0")
        h.update(files[path]["sha256"].encode("ascii"))
        h.update(b"\n")
    return h.hexdigest()


def normalize_zip_path(path: str) -> str:
    path = path.replace("\\", "/")
    p = PurePosixPath(path)
    if p.is_absolute() or ".." in p.parts or any(":" in x for x in p.parts):
        raise HistoryError(f"Unsafe archive path: {path!r}")
    cleaned = "/".join(x for x in p.parts if x not in ("", "."))
    if not cleaned:
        raise HistoryError(f"Empty archive path after normalization: {path!r}")
    return cleaned


def common_root_prefix(names: Iterable[str]) -> str:
    names = [normalize_zip_path(n) for n in names]
    if not names:
        return ""
    split = [n.split("/") for n in names]
    if any(len(parts) < 2 for parts in split):
        return ""
    first = {parts[0] for parts in split}
    return next(iter(first)) + "/" if len(first) == 1 else ""


def strip_root(path: str, prefix: str) -> str:
    if prefix and path.startswith(prefix):
        return path[len(prefix):]
    return path


def parse_version(filename: str) -> Tuple[Tuple[int, ...], str, str]:
    m = VERSION_RE.search(Path(filename).name)
    if not m:
        raise HistoryError(f"Could not parse a numeric version from archive name: {filename}")
    ver = m.group("version")
    nums = tuple(int(x) for x in ver.split("."))
    return nums, ver, (m.group("variant") or "")


def _zip_datetime_key(dt: Tuple[int, int, int, int, int, int]) -> Tuple[int, ...]:
    return tuple(int(x) for x in dt)


@dataclass
class SourceEntry:
    name: str
    datetime_key: Tuple[int, ...]
    size: int


class VersionSource:
    """A directory of ZIPs or an outer ZIP containing version ZIPs."""

    def __init__(self, source: Path):
        self.source = source.resolve()
        self.outer: Optional[zipfile.ZipFile] = None
        self.mode = ""
        if self.source.is_dir():
            self.mode = "directory"
        elif self.source.is_file() and zipfile.is_zipfile(self.source):
            self.mode = "bundle"
            self.outer = zipfile.ZipFile(self.source, "r")
        else:
            raise HistoryError(f"Source is not a directory or ZIP file: {self.source}")

    def close(self) -> None:
        if self.outer is not None:
            self.outer.close()
            self.outer = None

    def __enter__(self) -> "VersionSource":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def list_entries(self) -> List[SourceEntry]:
        if self.mode == "directory":
            out = []
            for p in sorted(self.source.glob("*.zip")):
                st = p.stat()
                dt = _dt.datetime.fromtimestamp(st.st_mtime)
                out.append(SourceEntry(p.name, (dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second), st.st_size))
            return out
        assert self.outer is not None
        out = []
        for zi in self.outer.infolist():
            if zi.is_dir() or not zi.filename.lower().endswith(".zip"):
                continue
            out.append(SourceEntry(Path(zi.filename).name, _zip_datetime_key(zi.date_time), zi.file_size))
        return out

    def read_archive_bytes(self, name: str) -> bytes:
        if self.mode == "directory":
            p = self.source / name
            if not p.is_file():
                raise HistoryError(f"Version archive not found: {p}")
            return p.read_bytes()
        assert self.outer is not None
        candidates = [zi for zi in self.outer.infolist() if not zi.is_dir() and Path(zi.filename).name == name]
        if len(candidates) != 1:
            raise HistoryError(f"Expected exactly one nested archive named {name!r}; found {len(candidates)}")
        return self.outer.read(candidates[0])


def archive_inventory(data: bytes, include_data: bool = False) -> Tuple[Dict[str, dict], str]:
    try:
        z = zipfile.ZipFile(io.BytesIO(data), "r")
    except zipfile.BadZipFile as e:
        raise HistoryError(f"Invalid version ZIP: {e}") from e
    infos = [zi for zi in z.infolist() if not zi.is_dir()]
    raw_names = [normalize_zip_path(zi.filename) for zi in infos]
    prefix = common_root_prefix(raw_names)
    files: Dict[str, dict] = {}
    try:
        for zi, raw_name in zip(infos, raw_names):
            rel = normalize_zip_path(strip_root(raw_name, prefix))
            b = z.read(zi)
            if rel in files:
                raise HistoryError(f"Duplicate path after root stripping: {rel}")
            rec = {
                "sha256": sha256_bytes(b),
                "size": len(b),
            }
            if include_data:
                rec["data"] = b
            files[rel] = rec
    finally:
        z.close()
    return files, prefix


def extract_text(files: Dict[str, dict], path: str, source: VersionSource, archive_name: str) -> str:
    # files may not carry bytes; reopen only when text is needed
    target = next((p for p in files if p.casefold() == path.casefold()), None)
    if target is None:
        return ""
    data = source.read_archive_bytes(archive_name)
    full, _ = archive_inventory(data, include_data=True)
    return full[target]["data"].decode("utf-8", "replace")


def extract_readme_and_history(data: bytes) -> Tuple[str, str]:
    files, _ = archive_inventory(data, include_data=True)
    readme = ""
    hist = ""
    for p, rec in files.items():
        if p.casefold() == "readme.md":
            readme = rec["data"].decode("utf-8", "replace")
        if p.casefold() == "doc/project-version-history.txt":
            hist = rec["data"].decode("utf-8", "replace")
    return readme, hist


def history_section(history: str, version: str) -> List[str]:
    lines = history.replace("\r\n", "\n").replace("\r", "\n").splitlines()
    start = None
    exact = re.compile(r"^\s*" + re.escape(version) + r"(?:\s*-\s*.*)?\s*$")
    for i, line in enumerate(lines):
        if exact.match(line):
            start = i + 1
            break
    if start is None:
        return []
    bullets: List[str] = []
    current = ""
    for line in lines[start:]:
        if VERSION_LINE_RE.match(line):
            break
        m = re.match(r"^\s*[-*]\s+(.*)$", line)
        if m:
            if current:
                bullets.append(re.sub(r"\s+", " ", current).strip())
            current = m.group(1).strip()
        elif current and line.strip():
            current += " " + line.strip()
    if current:
        bullets.append(re.sub(r"\s+", " ", current).strip())
    return bullets


def first_paragraph_after_h1(readme: str) -> str:
    lines = readme.replace("\r\n", "\n").replace("\r", "\n").splitlines()
    seen_h1 = False
    para: List[str] = []
    for line in lines:
        if not seen_h1:
            if line.startswith("# "):
                seen_h1 = True
            continue
        if line.startswith("#"):
            if para:
                break
            continue
        if not line.strip():
            if para:
                break
            continue
        para.append(line.strip())
    return re.sub(r"\s+", " ", " ".join(para)).strip()


def readme_summary_bullets(readme: str) -> List[str]:
    """Returns bullets from an early README summary section when no version history exists."""
    lines = readme.replace("\r\n", "\n").replace("\r", "\n").splitlines()
    preferred = {"what is included", "changes", "highlights", "what changed", "overview"}
    starts: List[int] = []
    for i, line in enumerate(lines):
        if line.startswith("## "):
            heading = line[3:].strip().casefold()
            if heading in preferred:
                starts.insert(0, i + 1)
            else:
                starts.append(i + 1)
    for start in starts:
        bullets: List[str] = []
        current = ""
        for line in lines[start:]:
            if line.startswith("## "):
                break
            m = re.match(r"^\s*[-*]\s+(.*)$", line)
            if m:
                if current:
                    bullets.append(re.sub(r"\s+", " ", current).strip())
                current = m.group(1).strip()
            elif current and line.strip() and not line.startswith("#"):
                current += " " + line.strip()
        if current:
            bullets.append(re.sub(r"\s+", " ", current).strip())
        if bullets:
            return bullets
    return []


def project_title(readme: str, version: str) -> str:
    for line in readme.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            # Prefer removing the current archive version, but also strip a stale
            # trailing semantic version. Historical README titles are sometimes
            # one release behind even when the version-history section is correct.
            title = re.sub(r"\s+" + re.escape(version) + r"\s*$", "", title).strip()
            title = re.sub(
                r"\s+v?\d+(?:\.\d+){1,3}(?:[-+][0-9A-Za-z.-]+)?\s*$",
                "",
                title,
                flags=re.I,
            ).strip()
            return title or "Project"
    return "Project"


def propose_subject(readme: str, history: str, version: str, variant: str) -> Tuple[str, List[str], List[str]]:
    title = project_title(readme, version)
    warnings: List[str] = []
    h1 = next((line[2:].strip() for line in readme.splitlines() if line.startswith("# ")), "")
    if h1 and version not in h1:
        warnings.append(f"README H1 does not contain archive version {version}: {h1}")
    history_bullets = history_section(history, version)
    bullets = history_bullets or readme_summary_bullets(readme)
    if variant.lower() == "development-handoff":
        return f"{title} {version} - development handoff", bullets, warnings
    exact_heading = re.compile(r"^##\s+" + re.escape(version) + r"\s+(.+?)\s*$", re.I)
    for line in readme.splitlines():
        m = exact_heading.match(line)
        if m:
            return f"{title} {version} - {m.group(1).strip()}", bullets, warnings
    preferred = re.compile(
        r"^(added|adds|fixed|fixes|introduc|reorganiz|correct|expand|implement|maintenance|feature|created|builds|rebuilt|changed|changes|new|first|initial)",
        re.I,
    )
    chosen = next(
        (b for b in history_bullets if preferred.match(b)),
        history_bullets[0] if history_bullets else "",
    )
    if not chosen:
        chosen = first_paragraph_after_h1(readme)
    if chosen:
        chosen = re.sub(r"\s+", " ", chosen)
        if len(chosen) > 150:
            chosen = chosen[:147].rstrip() + "..."
        return f"{title} {version} - {chosen}", bullets, warnings
    return f"{title} {version}", bullets, warnings


def matches_any(name: str, patterns: List[str]) -> Optional[str]:
    for pat in patterns:
        if fnmatch.fnmatchcase(name.lower(), pat.lower()):
            return pat
    return None


def delta_counts(prev: Optional[Dict[str, dict]], cur: Dict[str, dict]) -> dict:
    if prev is None:
        return {"added": len(cur), "modified": 0, "deleted": 0, "unchanged": 0}
    pset, cset = set(prev), set(cur)
    common = pset & cset
    modified = sum(prev[p]["sha256"] != cur[p]["sha256"] for p in common)
    return {
        "added": len(cset - pset),
        "modified": modified,
        "deleted": len(pset - cset),
        "unchanged": len(common) - modified,
    }


def mapped_snapshot(files: Dict[str, dict], moves: Dict[str, str]) -> Tuple[Dict[str, dict], List[dict]]:
    out: Dict[str, dict] = {}
    origins: Dict[str, str] = {}
    collisions: List[dict] = []
    for src, rec in files.items():
        dst = moves.get(src, src)
        if dst in out:
            collisions.append({"destination": dst, "sourceA": origins[dst], "sourceB": src})
            continue
        out[dst] = rec
        origins[dst] = src
    return out, collisions



def external_layout_inventory(layout: Path) -> Tuple[Dict[str, dict], str]:
    """Read a canonical layout from a directory or ZIP archive."""
    layout = layout.resolve()
    if layout.is_dir():
        files: Dict[str, dict] = {}
        for fp in sorted(layout.rglob("*")):
            if not fp.is_file():
                continue
            rel = fp.relative_to(layout).as_posix()
            data = fp.read_bytes()
            files[rel] = {"sha256": sha256_bytes(data), "size": len(data)}
        if not files:
            raise HistoryError(f"Layout directory contains no files: {layout}")
        return files, ""
    if layout.is_file() and zipfile.is_zipfile(layout):
        files, prefix = archive_inventory(layout.read_bytes(), include_data=False)
        return files, prefix
    raise HistoryError(f"Layout must be a directory or ZIP archive: {layout}")


def _fmt_elapsed(seconds: float) -> str:
    seconds = max(0, int(seconds))
    return f"{seconds//3600:02d}:{(seconds%3600)//60:02d}:{seconds%60:02d}"


def _progress_done(started: float, done: int, total: int) -> str:
    elapsed = time.monotonic() - started
    if done <= 0 or total <= done:
        return f"elapsed {_fmt_elapsed(elapsed)}"
    eta = elapsed / done * (total - done)
    return f"elapsed {_fmt_elapsed(elapsed)}  estimated remaining {_fmt_elapsed(eta)}"

def inspect_command(args: argparse.Namespace) -> int:
    source_path = Path(args.source)
    exclude = list(args.exclude or [])
    include = list(getattr(args, "include", []) or [])
    replace_unmanaged = list(args.replace_unmanaged or [])
    identity_layout = bool(getattr(args, "identity_layout", False))
    layout_arg = getattr(args, "layout", None)

    if identity_layout and (getattr(args, "final", None) or layout_arg):
        raise HistoryError("--identity-layout cannot be combined with --final or --layout.")

    with VersionSource(source_path) as source:
        entries = source.list_entries()
        if not entries:
            raise HistoryError("No version ZIPs were found.")

        excluded = []
        included_entries = []
        for e in entries:
            if include and not matches_any(e.name, include):
                excluded.append({"archive": e.name, "reason": "not selected by include filter"})
                continue
            pat = matches_any(e.name, exclude)
            if pat:
                excluded.append({"archive": e.name, "reason": f"matches exclude pattern {pat}"})
            else:
                included_entries.append(e)
        if not included_entries:
            raise HistoryError("All discovered archives were excluded.")

        parsed = []
        for e in included_entries:
            nums, ver, variant = parse_version(e.name)
            parsed.append((nums, e.name.casefold(), e.datetime_key, e, ver, variant))
        parsed.sort(key=lambda x: (x[0], x[1], x[2]))

        final_name = ""
        final_prefix = ""
        final_files: Dict[str, dict] = {}
        layout_mode = "identity"

        if identity_layout:
            layout_mode = "identity"
        elif layout_arg:
            layout_mode = "reference"
            lp = Path(layout_arg)
            if lp.exists():
                final_name = str(lp.resolve())
                final_files, final_prefix = external_layout_inventory(lp)
            else:
                final_name = Path(layout_arg).name
                matches = [x for x in parsed if x[3].name == final_name]
                if len(matches) != 1:
                    raise HistoryError(
                        f"Layout reference {layout_arg!r} is neither an existing path nor exactly one included source archive."
                    )
                final_data = source.read_archive_bytes(final_name)
                final_files, final_prefix = archive_inventory(final_data)
        else:
            layout_mode = "reference"
            if args.final:
                final_name = Path(args.final).name
                matches = [x for x in parsed if x[3].name == final_name]
                if len(matches) != 1:
                    raise HistoryError(f"Final archive {final_name!r} is not present exactly once among included revisions.")
                final_tuple = matches[0]
            else:
                final_tuple = parsed[-1]
                final_name = final_tuple[3].name
            final_data = source.read_archive_bytes(final_name)
            final_files, final_prefix = archive_inventory(final_data)

        final_basename: Dict[str, List[str]] = {}
        final_hash: Dict[str, List[str]] = {}
        for q, rec in final_files.items():
            final_basename.setdefault(Path(q).name.casefold(), []).append(q)
            final_hash.setdefault(rec["sha256"], []).append(q)

        revision_raw: List[dict] = []
        all_paths: Dict[str, set] = {}
        path_hashes: Dict[str, set] = {}
        readme_warnings: List[dict] = []

        for order, item in enumerate(parsed, 1):
            _, _, dtkey, e, ver, variant = item
            data = source.read_archive_bytes(e.name)
            files, prefix = archive_inventory(data)
            readme, hist = extract_readme_and_history(data)
            subject, desc, warns = propose_subject(readme, hist, ver, variant)
            for w in warns:
                readme_warnings.append({"archive": e.name, "warning": w})
            for q, rec in files.items():
                all_paths.setdefault(q, set()).add(e.name)
                path_hashes.setdefault(q, set()).add(rec["sha256"])
            revision_raw.append({
                "order": order,
                "archive": e.name,
                "version": ver,
                "variant": variant,
                "archiveSha256": sha256_bytes(data),
                "archiveBytes": len(data),
                "archiveTimestamp": "-".join(map(str, dtkey[:3])) + "T" + ":".join(f"{x:02d}" for x in dtkey[3:6]),
                "stripRoot": prefix.rstrip("/"),
                "sourceFileCount": len(files),
                "subject": subject,
                "description": desc,
                "_files": files,
            })

        moves: Dict[str, str] = {}
        move_records: List[dict] = []
        historical_only: List[dict] = []
        ambiguous: List[dict] = []

        if layout_mode == "reference":
            for q in sorted(all_paths, key=str.casefold):
                if q in final_files:
                    continue
                by_base = final_basename.get(Path(q).name.casefold(), [])
                if len(by_base) == 1:
                    dst = by_base[0]
                    moves[q] = dst
                    move_records.append({"from": q, "to": dst, "reason": "unique-basename-in-final"})
                    continue
                candidates = set()
                for h in path_hashes[q]:
                    for dst in final_hash.get(h, []):
                        candidates.add(dst)
                if len(candidates) == 1:
                    dst = next(iter(candidates))
                    moves[q] = dst
                    move_records.append({"from": q, "to": dst, "reason": "unique-content-match-in-final"})
                    continue
                if by_base or candidates:
                    ambiguous.append({
                        "path": q,
                        "basenameCandidates": sorted(by_base),
                        "contentCandidates": sorted(candidates),
                        "seenIn": sorted(all_paths[q]),
                    })
                else:
                    historical_only.append({
                        "path": q,
                        "action": "keep-original-path",
                        "seenIn": sorted(all_paths[q]),
                    })

        revisions = []
        prev_mapped: Optional[Dict[str, dict]] = None
        all_collisions: List[dict] = []
        generated_candidates = set()
        for raw in revision_raw:
            mapped, collisions = mapped_snapshot(raw["_files"], moves)
            if collisions:
                for c in collisions:
                    c["archive"] = raw["archive"]
                all_collisions.extend(collisions)
            for q in mapped:
                ql = q.casefold()
                if "/__pycache__/" in "/" + ql or ql.endswith(".pyc"):
                    generated_candidates.add(q)
            rec = {k: v for k, v in raw.items() if k != "_files"}
            rec["normalizedFileCount"] = len(mapped)
            rec["normalizedTreeSha256"] = stable_tree_sha256(mapped)
            rec["deltaFromPrevious"] = delta_counts(prev_mapped, mapped)
            revisions.append(rec)
            prev_mapped = mapped

        plan = {
            "schema": SCHEMA,
            "createdUtc": _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat(),
            "source": {
                "name": source_path.name,
                "type": source.mode,
                "finalArchive": final_name or None,
                "excludePatterns": exclude,
                "includePatterns": include,
                "excluded": excluded,
            },
            "policies": {
                "preserveUnmanagedTargetFiles": True,
                "replaceUnmanagedPaths": replace_unmanaged,
                "historicalOnly": "keep-original-path",
                "exactBytes": True,
                "publishCommand": "just_publish.bat historyexact yes messagefile <file> PUBLISH COMMIT",
            },
            "layout": {
                "mode": layout_mode,
                "finalArchive": final_name or None,
                "finalStripRoot": final_prefix.rstrip("/") if final_prefix else "",
                "finalFileCount": len(final_files),
                "moves": move_records,
                "historicalOnly": historical_only,
                "ambiguous": ambiguous,
                "collisions": all_collisions,
            },
            "revisions": revisions,
            "warnings": {
                "readmeVersion": readme_warnings,
                "generatedHistoricalFiles": sorted(generated_candidates),
            },
            "summary": {
                "discoveredArchives": len(entries),
                "includedRevisions": len(revisions),
                "excludedArchives": len(excluded),
                "distinctHistoricalPaths": len(all_paths),
                "finalPaths": len(final_files),
                "inferredMoves": len(move_records),
                "historicalOnlyPaths": len(historical_only),
                "ambiguousMappings": len(ambiguous),
                "collisions": len(all_collisions),
                "generatedHistoricalFileCandidates": len(generated_candidates),
            },
        }
        output = Path(args.output).resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(plan, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")

        print(f"Wrote: {output}")
        for k, v in plan["summary"].items():
            print(f"{k}: {v}")
        if ambiguous or all_collisions:
            print("WARNING: plan contains unresolved mapping problems and replay will refuse to publish.", file=sys.stderr)
            return 3
        return 0

def load_plan(path: Path) -> dict:
    plan = json.loads(path.read_text(encoding="utf-8"))
    if plan.get("schema") != SCHEMA:
        raise HistoryError(f"Unsupported plan schema: {plan.get('schema')!r}")
    return plan


def archive_snapshot_for_revision(source: VersionSource, rev: dict, moves: Dict[str, str], include_data: bool) -> Dict[str, dict]:
    data = source.read_archive_bytes(rev["archive"])
    actual_archive_sha = sha256_bytes(data)
    if actual_archive_sha != rev["archiveSha256"]:
        raise HistoryError(
            f"Archive hash changed for {rev['archive']}: expected {rev['archiveSha256']}, got {actual_archive_sha}"
        )
    files, _ = archive_inventory(data, include_data=include_data)
    mapped, collisions = mapped_snapshot(files, moves)
    if collisions:
        raise HistoryError(f"Mapping collision in {rev['archive']}: {collisions[0]}")
    tree_hash = stable_tree_sha256(mapped)
    if tree_hash != rev["normalizedTreeSha256"]:
        raise HistoryError(
            f"Normalized tree hash changed for {rev['archive']}: expected {rev['normalizedTreeSha256']}, got {tree_hash}"
        )
    return mapped


def safe_target_path(root: Path, rel: str) -> Path:
    rel = normalize_zip_path(rel)
    root_resolved = root.resolve()
    candidate = (root_resolved / Path(*rel.split("/"))).resolve()
    try:
        candidate.relative_to(root_resolved)
    except ValueError as e:
        raise HistoryError(f"Mapped path escapes target: {rel}") from e
    return candidate


def file_sha256_if_exists(path: Path) -> Optional[str]:
    if not path.exists() or not path.is_file():
        return None
    return sha256_file(path)


def copy_baseline(src: Path, dst: Path) -> None:
    if not src.is_dir():
        raise HistoryError(f"Baseline is not a directory: {src}")
    for p in src.rglob("*"):
        rel = p.relative_to(src)
        if ".git" in rel.parts:
            continue
        q = dst / rel
        if p.is_dir():
            q.mkdir(parents=True, exist_ok=True)
        elif p.is_file():
            q.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, q)


def run_git(root: Path, args: List[str], check: bool = True) -> subprocess.CompletedProcess:
    p = subprocess.run(
        ["git", *args],
        cwd=str(root),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        errors="replace",
    )
    if check and p.returncode != 0:
        raise HistoryError(f"git {' '.join(args)} failed ({p.returncode}):\n{p.stdout}")
    return p


def install_exact_attributes(root: Path) -> None:
    git_dir = run_git(root, ["rev-parse", "--git-dir"]).stdout.strip()
    gp = Path(git_dir)
    if not gp.is_absolute():
        gp = (root / gp).resolve()
    attr = gp / "info" / "attributes"
    attr.parent.mkdir(parents=True, exist_ok=True)
    old = attr.read_text(encoding="utf-8", errors="replace") if attr.exists() else ""
    # replace our own marker block only
    pattern = re.compile(
        re.escape(HISTORY_MARKER_BEGIN) + r".*?" + re.escape(HISTORY_MARKER_END) + r"\s*",
        re.S,
    )
    old = pattern.sub("", old)
    block = f"{HISTORY_MARKER_BEGIN}\n* -text\n{HISTORY_MARKER_END}\n"
    if old and not old.endswith("\n"):
        old += "\n"
    attr.write_text(old + block, encoding="utf-8", newline="\n")


def remove_exact_attributes(root: Path) -> None:
    try:
        git_dir = run_git(root, ["rev-parse", "--git-dir"]).stdout.strip()
    except Exception:
        return
    gp = Path(git_dir)
    if not gp.is_absolute():
        gp = (root / gp).resolve()
    attr = gp / "info" / "attributes"
    if not attr.exists():
        return
    old = attr.read_text(encoding="utf-8", errors="replace")
    pattern = re.compile(
        re.escape(HISTORY_MARKER_BEGIN) + r".*?" + re.escape(HISTORY_MARKER_END) + r"\s*",
        re.S,
    )
    new = pattern.sub("", old)
    attr.write_text(new, encoding="utf-8", newline="\n")


def apply_snapshot(
    root: Path,
    previous: Dict[str, dict],
    current: Dict[str, dict],
    managed_paths: set,
    replace_unmanaged: set,
) -> dict:
    # Verify prior managed bytes have not been edited behind our back.
    diverged = []
    for rel, rec in previous.items():
        p = safe_target_path(root, rel)
        if p.exists() and p.is_file():
            actual = sha256_file(p)
            if actual != rec["sha256"]:
                diverged.append(rel)
        elif rel in current:
            diverged.append(rel)
    if diverged:
        raise HistoryError(f"Managed target files changed outside replay; first mismatch: {diverged[0]}")

    deleted = []
    for rel in sorted(set(previous) - set(current), key=str.casefold, reverse=True):
        p = safe_target_path(root, rel)
        if p.is_file() or p.is_symlink():
            p.unlink()
            deleted.append(rel)
            parent = p.parent
            while parent != root and parent.exists():
                try:
                    parent.rmdir()
                except OSError:
                    break
                parent = parent.parent

    written = []
    for rel, rec in current.items():
        p = safe_target_path(root, rel)
        if p.exists() and rel not in managed_paths:
            existing = file_sha256_if_exists(p)
            if existing != rec["sha256"] and rel.casefold() not in replace_unmanaged:
                raise HistoryError(
                    f"Refusing to replace unmanaged target file {rel!r}. "
                    f"Add it to policies.replaceUnmanagedPaths after review."
                )
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(rec["data"])
        written.append(rel)

    bad = []
    for rel, rec in current.items():
        p = safe_target_path(root, rel)
        if file_sha256_if_exists(p) != rec["sha256"]:
            bad.append(rel)
    if bad:
        raise HistoryError(f"Post-write byte verification failed; first mismatch: {bad[0]}")

    return {"written": len(written), "deleted": len(deleted), "verified": len(current)}


def git_tree_map(root: Path) -> Dict[str, str]:
    p = run_git(root, ["ls-tree", "-r", "-z", "HEAD"])
    raw = p.stdout
    out = {}
    for item in raw.split("\0"):
        if not item:
            continue
        meta, path = item.split("\t", 1)
        parts = meta.split()
        if len(parts) >= 3 and parts[1] == "blob":
            out[path.replace("\\", "/")] = parts[2]
    return out


def verify_committed_blobs(root: Path, current: Dict[str, dict]) -> int:
    fmt = run_git(root, ["config", "--get", "extensions.objectFormat"], check=False).stdout.strip().lower()
    algo = "sha256" if fmt == "sha256" else "sha1"
    tree = git_tree_map(root)
    bad = []
    for rel, rec in current.items():
        oid = tree.get(rel)
        expected = git_blob_oid(rec["data"], algo)
        if oid != expected:
            bad.append((rel, oid, expected))
    if bad:
        raise HistoryError(f"Committed blob byte verification failed: {bad[0][0]}")
    return len(current)


def make_message_file(logdir: Path, rev: dict) -> Path:
    msgdir = logdir / "messages"
    msgdir.mkdir(parents=True, exist_ok=True)
    safe = re.sub(r"[^A-Za-z0-9._-]+", "_", f"{rev['order']:03d}-{rev['version']}-{rev.get('variant','')}")
    p = msgdir / (safe.strip("_") + ".txt")
    body = rev.get("description") or []
    text = rev["subject"].strip() + "\n"
    if body:
        text += "\n" + "\n".join("- " + str(x).strip() for x in body if str(x).strip()) + "\n"
    p.write_text(text, encoding="utf-8", newline="\n")
    return p


def publisher_command(target: Path, message_file: Path) -> List[str]:
    # A .bat must run through cmd.exe. Keep the command-line surface limited to
    # reviewed paths; message text itself stays in the message file.
    publisher = target / "just_publish.bat"
    if not publisher.is_file():
        raise HistoryError(f"Publisher not found: {publisher}")
    return [
        "cmd.exe", "/d", "/s", "/c",
        f'call "{publisher}" historyexact yes messagefile "{message_file}" PUBLISH COMMIT'
    ]


def write_logs(logdir: Path, report: dict) -> None:
    logdir.mkdir(parents=True, exist_ok=True)
    (logdir / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    lines = []
    lines.append(f"Mode: {report['mode']}")
    lines.append(f"Source: {report['source']}")
    lines.append(f"Revisions: {len(report['revisions'])}")
    lines.append("")
    for r in report["revisions"]:
        d = r["delta"]
        lines.append(
            f"{r['order']:03d} {r['archive']}  files={r['files']} "
            f"add={d['added']} mod={d['modified']} del={d['deleted']} "
            f"tree={r['treeSha256'][:16]}"
        )
        lines.append(f"    {r['subject']}")
        if "diffCheckRc" in r:
            lines.append(f"    audit git diff --check rc={r['diffCheckRc']} lines={r.get('diffCheckLines',0)}")
        if r.get("commit"):
            lines.append(f"    commit={r['commit']}")
    lines.append("")
    lines.append("Result: PASS" if report.get("ok") else "Result: FAIL")
    (logdir / "report.txt").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def replay_command(args: argparse.Namespace) -> int:
    plan_path = Path(args.plan).resolve()
    plan = load_plan(plan_path)
    if plan["layout"].get("ambiguous") or plan["layout"].get("collisions"):
        raise HistoryError("Plan contains ambiguous mappings or collisions; review/edit before replay.")

    mode = args.mode.lower()
    if mode not in {"dryrun", "rehearse", "publish"}:
        raise HistoryError(f"Unsupported replay mode: {mode}")

    source_path = Path(args.source).resolve()
    logdir = Path(args.logdir).resolve() if args.logdir else plan_path.parent / f"history-{mode}-logs"
    moves = {x["from"]: x["to"] for x in plan["layout"]["moves"]}
    replace_unmanaged = {x.casefold() for x in plan["policies"].get("replaceUnmanagedPaths", [])}

    report = {
        "schema": "history-import-report/v1",
        "mode": mode,
        "createdUtc": _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat(),
        "source": str(source_path),
        "plan": str(plan_path),
        "revisions": [],
        "ok": False,
    }

    with VersionSource(source_path) as source:
        if mode == "dryrun":
            prev = None
            total = len(plan["revisions"])
            started = time.monotonic()
            for idx, rev in enumerate(plan["revisions"], 1):
                print(f"[{idx:02d}/{total:02d}] {rev['version']}  {rev['archive']}  verifying...", flush=True)
                cur = archive_snapshot_for_revision(source, rev, moves, include_data=False)
                rec = {
                    "order": rev["order"],
                    "archive": rev["archive"],
                    "version": rev["version"],
                    "files": len(cur),
                    "treeSha256": stable_tree_sha256(cur),
                    "delta": delta_counts(prev, cur),
                    "subject": rev["subject"],
                }
                report["revisions"].append(rec)
                prev = cur
                print(f"          OK  {_progress_done(started, idx, total)}", flush=True)
            report["ok"] = True
            write_logs(logdir, report)
            print(f"DRY RUN PASS: {len(report['revisions'])} revisions verified.")
            print(f"Logs: {logdir}")
            return 0

        target = Path(args.target).resolve() if args.target else None
        if target is None:
            raise HistoryError(f"--target is required for {mode} mode.")
        try:
            rel_logdir = logdir.relative_to(target)
        except ValueError:
            rel_logdir = None
        if rel_logdir is not None:
            safe_inside = ".git" in rel_logdir.parts
            if not safe_inside and target.exists() and (target / ".git").exists():
                ignored = run_git(
                    target,
                    ["check-ignore", "-q", "--", rel_logdir.as_posix()],
                    check=False,
                ).returncode == 0
                safe_inside = ignored
            if not safe_inside:
                raise HistoryError(
                    "--logdir is inside the replay target and is not Git-ignored. "
                    "Generated reports/message files must be outside the target or explicitly ignored."
                )

        exact_attributes_installed = False
        try:
            if mode == "rehearse":
                if target.exists():
                    if not args.reset_target:
                        raise HistoryError(f"Rehearsal target already exists: {target}. Use --reset-target to replace it.")
                    shutil.rmtree(target)
                target.mkdir(parents=True)
                if args.baseline:
                    copy_baseline(Path(args.baseline).resolve(), target)
                run_git(target, ["init", "-b", "main"])
                run_git(target, ["config", "user.name", "History Replay Rehearsal"])
                run_git(target, ["config", "user.email", "rehearsal@example.invalid"])
                install_exact_attributes(target)
                exact_attributes_installed = True
                run_git(target, ["-c", "core.autocrlf=false", "add", "-A"])
                if run_git(target, ["diff", "--cached", "--quiet"], check=False).returncode != 0:
                    run_git(target, ["commit", "-m", "History replay rehearsal baseline"])
            else:
                if not target.is_dir():
                    raise HistoryError(f"Publish target is not a directory: {target}")
                if run_git(target, ["rev-parse", "--is-inside-work-tree"], check=False).returncode != 0:
                    raise HistoryError(f"Publish target is not a Git worktree: {target}")
                if run_git(target, ["status", "--porcelain"], check=False).stdout.strip():
                    raise HistoryError("Publish target must start clean. Commit/stash unrelated changes first.")
                install_exact_attributes(target)
                exact_attributes_installed = True

            prev: Dict[str, dict] = {}
            managed_paths: set = set()
            start_at = int(args.start_at or 1)
            stop_after = int(args.stop_after) if args.stop_after else None
            selected_revs = [
                r for r in plan["revisions"]
                if int(r["order"]) >= start_at and (stop_after is None or int(r["order"]) <= stop_after)
            ]
            total_selected = len(selected_revs)
            progress_index = 0
            started = time.monotonic()

            for rev in plan["revisions"]:
                order = int(rev["order"])
                if order < start_at:
                    # For safety, resume reconstructs expected previous state in memory
                    # but does not modify target. A publish resume should normally start
                    # from state produced by the immediately preceding revision.
                    prev = archive_snapshot_for_revision(source, rev, moves, include_data=True)
                    managed_paths = set(prev)
                    continue
                if stop_after is not None and order > stop_after:
                    break

                progress_index += 1
                print(f"[{progress_index:02d}/{total_selected:02d}] {rev['version']}  {rev['archive']}", flush=True)
                print(f"          commit message: {rev['subject']}", flush=True)
                print("          materialize...", flush=True)
                cur = archive_snapshot_for_revision(source, rev, moves, include_data=True)
                action = apply_snapshot(target, prev, cur, managed_paths, replace_unmanaged)
                managed_paths = set(cur)

                audit = run_git(target, ["diff", "--check"], check=False)
                msg_file = make_message_file(logdir, rev)
                commit = ""

                if mode == "rehearse":
                    print("          stage...", flush=True)
                    run_git(target, ["-c", "core.autocrlf=false", "add", "-A"])
                    # The historical-exact path records diff-check findings but does not
                    # rewrite or reject archived bytes.
                    print("          commit...", flush=True)
                    run_git(target, ["commit", "-F", str(msg_file)])
                    commit = run_git(target, ["rev-parse", "--short=12", "HEAD"]).stdout.strip()
                    print("          verify committed blobs...", flush=True)
                    verify_committed_blobs(target, cur)
                    if run_git(target, ["status", "--porcelain"]).stdout.strip():
                        raise HistoryError(f"Rehearsal worktree not clean after commit {order}.")
                else:
                    print("          publish...", flush=True)
                    env = os.environ.copy()
                    env["HISTORY_IMPORT_EXACT"] = "1"
                    cmd = publisher_command(target, msg_file)
                    p = subprocess.run(cmd, cwd=str(target), env=env)
                    if p.returncode != 0:
                        raise HistoryError(f"just_publish failed for revision {order} ({rev['archive']}) with rc={p.returncode}")
                    commit = run_git(target, ["rev-parse", "--short=12", "HEAD"]).stdout.strip()
                    verify_committed_blobs(target, cur)
                    if run_git(target, ["status", "--porcelain"]).stdout.strip():
                        raise HistoryError(f"Publish worktree not clean after revision {order}.")

                report["revisions"].append({
                    "order": order,
                    "archive": rev["archive"],
                    "version": rev["version"],
                    "files": len(cur),
                    "treeSha256": stable_tree_sha256(cur),
                    "delta": delta_counts(prev, cur),
                    "subject": rev["subject"],
                    "messageFile": str(msg_file),
                    "written": action["written"],
                    "deleted": action["deleted"],
                    "verified": action["verified"],
                    "diffCheckRc": audit.returncode,
                    "diffCheckLines": len([x for x in audit.stdout.splitlines() if x.strip()]),
                    "commit": commit,
                })
                prev = cur
                print(f"          OK commit={commit}  {_progress_done(started, progress_index, total_selected)}", flush=True)

            report["ok"] = True
            write_logs(logdir, report)
        except Exception as exc:
            report["ok"] = False
            report["error"] = str(exc)
            try:
                write_logs(logdir, report)
            except Exception:
                pass
            raise
        finally:
            if exact_attributes_installed:
                remove_exact_attributes(target)

        print(f"{mode.upper()} PASS: {len(report['revisions'])} revisions processed.")
        print(f"Logs: {logdir}")
        return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Inspect and replay archived project versions into canonical Git history.")
    sub = p.add_subparsers(dest="command", required=True)

    i = sub.add_parser("inspect", help="Inspect version ZIPs and create a reviewable import plan.")
    i.add_argument("--source", required=True, help="Outer ZIP containing version ZIPs, or directory of version ZIPs.")
    i.add_argument("--output", required=True, help="JSON plan to write.")
    i.add_argument("--final", help="Included archive filename whose layout is canonical. Defaults to highest included version.")
    i.add_argument("--layout", help="External layout directory/ZIP, or included archive name used as the canonical layout.")
    i.add_argument("--identity-layout", action="store_true", help="Do not reorganize paths; every revision keeps its own layout.")
    i.add_argument("--include", action="append", default=[], help="Archive filename wildcard to include; repeatable.")
    i.add_argument("--exclude", action="append", default=[], help="Archive filename wildcard to exclude; repeatable.")
    i.add_argument("--replace-unmanaged", action="append", default=[], help="Target path intentionally allowed to replace; repeatable.")
    i.set_defaults(func=inspect_command)

    r = sub.add_parser("replay", help="Dry-run, rehearse, or publish an inspected plan.")
    r.add_argument("--plan", required=True, help="Plan JSON produced by inspect.")
    r.add_argument("--source", required=True, help="Same source bundle/directory inspected into the plan.")
    r.add_argument("--mode", required=True, choices=["dryrun", "rehearse", "publish"])
    r.add_argument("--target", help="Rehearsal directory or existing Git worktree for publish.")
    r.add_argument("--baseline", help="Directory copied into a fresh rehearsal target before history replay.")
    r.add_argument("--reset-target", action="store_true", help="Allow rehearse mode to delete/recreate an existing target.")
    r.add_argument("--logdir", help="Log directory; defaults beside plan.")
    r.add_argument("--start-at", type=int, help="Start at one-based revision order (advanced/resume use).")
    r.add_argument("--stop-after", type=int, help="Stop after one-based revision order.")
    r.set_defaults(func=replay_command)
    return p


def main(argv: Optional[List[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except HistoryError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("ERROR: interrupted.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
