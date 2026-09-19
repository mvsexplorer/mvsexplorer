#!/usr/bin/env python3
"""Static validation for the archive-wide sweep harness.

Version: 0.1.0
"""
from pathlib import Path
import hashlib
import sys

ROOT = Path(__file__).resolve().parents[1]

def fail(message):
    print("FAIL:", message)
    raise SystemExit(1)

def main():
    batch = ROOT / "test" / "test_all_dumps.bat"
    if not batch.is_file():
        fail("missing test/test_all_dumps.bat")

    raw = batch.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        fail("test_all_dumps.bat has UTF-8 BOM")
    if b"\n" in raw.replace(b"\r\n", b""):
        fail("test_all_dumps.bat contains non-CRLF newlines")
    text = raw.decode("utf-8")

    for marker in (
        "@echo off\r\n:setup\r\n",
        "\r\n:main\r\n",
        "\r\n:end\r\n",
        "\r\nGoTo :EOF\r\n",
        "\r\n:_MVSArchiveSweep_start\r\n",
        "\r\n:_MVSArchiveSweep_end\r\n",
    ):
        if marker not in text:
            fail("missing batch marker: " + repr(marker))
    if "@@" in text:
        fail("unresolved template marker")
    if any(line.rstrip("\r\n").endswith("^") for line in text.splitlines(True)):
        fail("trailing-caret continuation found")

    for token in (
        "--plan-only",
        "--resume",
        "plan-sha256.txt",
        "runs.tsv",
        "SOURCE_MISSING",
        "NO_RESULT",
        "archive-output",
        "mvs_dmp",
        "compare_mvs_dump_*.bat",
        "build_mvs_dump_change_history.bat",
        "build_mvs_dump_all_ever.bat",
    ):
        if token not in text:
            fail("missing archive-sweep feature token: " + token)

    public = sorted(ROOT.glob("*.bat"))
    compare = [p for p in public if p.name.startswith("compare_mvs_dump_")]
    archive_names = {"build_mvs_dump_change_history.bat", "build_mvs_dump_all_ever.bat"}
    archive = [p for p in public if p.name in archive_names]
    single = [p for p in public if p not in compare and p not in archive]
    if len(public) != 443:
        fail("expected 443 public root tools, got %d" % len(public))
    if len(single) != 422 or len(compare) != 19 or len(archive) != 2:
        fail("unexpected scope counts: single=%d compare=%d archive=%d" %
             (len(single), len(compare), len(archive)))

    supplied_snapshot_count = 79
    planned = len(single) * supplied_snapshot_count + len(compare) * (supplied_snapshot_count - 1) + len(archive)
    if planned != 34822:
        fail("79-snapshot plan count mismatch: %d" % planned)

    generator = ROOT / "dev" / "generate_archive_sweep.py"
    library = ROOT / "dev" / "library" / "archive-sweep.inc.ps1"
    template = ROOT / "dev" / "templates" / "archive-sweep.bat.tpl"
    for path in (generator, library, template, ROOT / "doc" / "archive-sweep.md"):
        if not path.is_file():
            fail("missing maintained file: " + str(path.relative_to(ROOT)))

    print("PASS: archive sweep static validation")
    print("public tools: 443 (single=422 compare=19 archive=2)")
    print("supplied archive plan: 34,822 invocations for 79 snapshots")

if __name__ == "__main__":
    main()
