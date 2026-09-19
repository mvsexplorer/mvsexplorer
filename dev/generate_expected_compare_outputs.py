#!/usr/bin/env python3
"""Generate fixed expected stdout for two-dump comparison tools.

Version: 0.1.0

This is an independent Python reference implementation. It reads only the
comparison specification and synthetic dump pair; it does not invoke or parse
the generated public batch tools.
"""
from pathlib import Path
import html
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
DEV = ROOT / "dev"
FIXTURE = ROOT / "test" / "test-mvs-dump-compare"
EXPECTED = ROOT / "test" / "expected-compare"

def norm_title(value):
    return re.sub(r"\s+", " ", html.unescape(value)).strip()

def norm_id(value, mode):
    text = value.strip()
    if mode == "numeric" and re.fullmatch(r"\d+", text):
        text = re.sub(r"^0+(?=\d)", "", text)
    return text

def display(value, kind, mode):
    if kind == "id":
        return norm_id(value, mode)
    if kind == "title":
        return norm_title(value)
    if kind in ("sha1", "sha256"):
        return value.strip().lower()
    return value.strip()

def key(value, kind, mode):
    out = display(value, kind, mode)
    if kind == "date":
        return out
    return out.casefold()

def add(rows, seen, value, kind, mode):
    out = display(value, kind, mode)
    if not out:
        return
    k = key(out, kind, mode)
    if k not in seen:
        seen.add(k)
        rows.append((k, out))

def read_values(path, source, kind, mode):
    rows = []
    seen = set()
    lines = path.read_text(encoding="utf-8").splitlines()

    if source == "mvs_ids.txt":
        rx = re.compile(r"^(.*?)\s*\[ID:\s*(\d+)\]\s*$")
        for line in lines:
            m = rx.match(line)
            if not m:
                continue
            if kind == "id":
                add(rows, seen, m.group(2), kind, mode)
            elif kind == "title":
                add(rows, seen, m.group(1), kind, mode)
        return rows

    if source == "mvs_dates.txt":
        rx = re.compile(r"^(.*?)\s+-\s+(.*?)\s*\[ID:\s*(\d+)\]\s*$")
        for line in lines:
            m = rx.match(line)
            if not m:
                continue
            if kind == "date":
                add(rows, seen, m.group(1), kind, mode)
            elif kind == "title":
                add(rows, seen, m.group(2), kind, mode)
            elif kind == "id":
                add(rows, seen, m.group(3), kind, mode)
        return rows

    if source in ("mvs.sha1", "mvs.sha256"):
        length = 40 if source == "mvs.sha1" else 64
        rx = re.compile(r"^\s*([0-9A-Fa-f]{%d})\s+\*(.+?)\s*$" % length)
        for line in lines:
            m = rx.match(line)
            if not m:
                continue
            if kind == "filename":
                add(rows, seen, m.group(2), kind, mode)
            elif (kind == "sha1" and length == 40) or (kind == "sha256" and length == 64):
                add(rows, seen, m.group(1), kind, mode)
        return rows

    if source in ("mvs.txt", "mvs_names.txt"):
        if source == "mvs_names.txt":
            header = re.compile(r"^---\s*(.*?)\s*\[ID:\s*([^\]]+?)\s*\]\s*---\s*$")
        else:
            header = re.compile(r"^---\s*(.*?)\s*\[ID:\s*(\d+)\]\s*---\s*$")
        file_rx = re.compile(r"^\s*([0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})\s+\*(.+?)\s*$")
        inside = False
        for line in lines:
            h = header.match(line)
            if h:
                inside = True
                if kind == "title":
                    add(rows, seen, h.group(1), kind, mode)
                elif kind == "id":
                    add(rows, seen, h.group(2), kind, mode)
                continue
            if not line.strip():
                inside = False
                continue
            if not inside:
                continue
            m = file_rx.match(line)
            if not m:
                continue
            digest, filename = m.group(1), m.group(2)
            if kind == "filename":
                add(rows, seen, filename, kind, mode)
            elif kind == "sha1" and len(digest) == 40:
                add(rows, seen, digest, kind, mode)
            elif kind == "sha256" and len(digest) == 64:
                add(rows, seen, digest, kind, mode)
        return rows

    raise ValueError("unsupported source: " + source)

def main():
    spec = json.loads((DEV / "compare-tool-spec.json").read_text(encoding="utf-8"))
    if EXPECTED.exists():
        shutil.rmtree(EXPECTED)
    EXPECTED.mkdir(parents=True)

    before = FIXTURE / "before"
    after = FIXTURE / "after"
    for tool in spec["tools"]:
        mode = tool.get("id_mode", "")
        a = read_values(before / tool["source_file"], tool["source_file"], tool["property"], mode)
        b = read_values(after / tool["source_file"], tool["source_file"], tool["property"], mode)
        akeys = {k for k, _ in a}
        bkeys = {k for k, _ in b}
        lines = []
        lines.extend("- " + value for k, value in a if k not in bkeys)
        lines.extend("+ " + value for k, value in b if k not in akeys)
        text = "".join(line + "\n" for line in lines)
        (EXPECTED / (tool["name"] + ".expected.txt")).write_text(text, encoding="utf-8", newline="\n")

if __name__ == "__main__":
    main()
