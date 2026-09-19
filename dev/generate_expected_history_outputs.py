#!/usr/bin/env python3
"""Generate fixed expected archive-history outputs with an independent parser.

Version: 0.1.0

This script does not invoke or parse the generated public .bat tools.
"""
from pathlib import Path
from collections import OrderedDict
import json, re, html, shutil

ROOT = Path(__file__).resolve().parents[1]
DEV = ROOT / "dev"
FIXTURE = ROOT / "test" / "test-mvs-dump-history"
EXPECTED = ROOT / "test" / "expected-history"

def norm_title(v):
    return re.sub(r"\s+", " ", html.unescape(v)).strip()

def norm_id(v, mode):
    v = v.strip()
    if mode == "numeric" and v.isdigit():
        v = v.lstrip("0") or "0"
    return v

def display(v, kind, mode=""):
    if kind == "id": return norm_id(v, mode)
    if kind == "title": return norm_title(v)
    if kind == "date": return v.strip()
    if kind in ("sha1","sha256"): return v.strip().lower()
    return v.strip()

def key(v, kind, mode=""):
    d = display(v, kind, mode)
    return d if kind == "date" else d.casefold()

def add(store, v, kind, mode=""):
    d = display(v, kind, mode)
    if not d: return
    k = key(d, kind, mode)
    store.setdefault(k, d)

def read_source(path, source):
    sets = {x: OrderedDict() for x in ("id","title","date","sha1","sha256","filename")}
    lines = path.read_text(encoding="utf-8").splitlines()
    if source == "mvs_ids.txt":
        rx = re.compile(r"^(.*?)\s*\[ID:\s*(\d+)\]\s*$")
        for line in lines:
            m = rx.match(line)
            if m:
                add(sets["title"], m.group(1), "title")
                add(sets["id"], m.group(2), "id", "numeric")
    elif source == "mvs_dates.txt":
        rx = re.compile(r"^(.*?)\s+-\s+(.*?)\s*\[ID:\s*(\d+)\]\s*$")
        for line in lines:
            m = rx.match(line)
            if m:
                add(sets["date"], m.group(1), "date")
                add(sets["title"], m.group(2), "title")
                add(sets["id"], m.group(3), "id", "numeric")
    elif source in ("mvs.sha1","mvs.sha256"):
        n = 40 if source == "mvs.sha1" else 64
        rx = re.compile(r"^\s*([0-9A-Fa-f]{%d})\s+\*(.+?)\s*$" % n)
        for line in lines:
            m = rx.match(line)
            if m:
                add(sets["sha1" if n == 40 else "sha256"], m.group(1), "sha1" if n == 40 else "sha256")
                add(sets["filename"], m.group(2), "filename")
    elif source in ("mvs.txt","mvs_names.txt"):
        inside = False
        hrx = (re.compile(r"^---\s*(.*?)\s*\[ID:\s*([^\]]+?)\s*\]\s*---\s*$")
               if source == "mvs_names.txt"
               else re.compile(r"^---\s*(.*?)\s*\[ID:\s*(\d+)\]\s*---\s*$"))
        frx = re.compile(r"^\s*([0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})\s+\*(.+?)\s*$")
        mode = "text" if source == "mvs_names.txt" else "numeric"
        for line in lines:
            hm = hrx.match(line)
            if hm:
                inside = True
                add(sets["title"], hm.group(1), "title")
                add(sets["id"], hm.group(2), "id", mode)
                continue
            if not line.strip():
                inside = False
                continue
            if not inside:
                continue
            fm = frx.match(line)
            if fm:
                hv, fn = fm.groups()
                add(sets["filename"], fn, "filename")
                add(sets["sha1" if len(hv)==40 else "sha256"], hv, "sha1" if len(hv)==40 else "sha256")
    return sets

def snapshot_key(p):
    m = re.match(r"^mvs_(\d{4}-\d{2}-\d{2})(?:-(\d{4}))?(?:_(\d+))?$", p.name)
    if not m: return None
    return (m.group(1), m.group(2) or "0000", int(m.group(3) or 0), p.name.casefold())

def write_tsv(path, columns, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    def clean(v):
        return str(v).replace("\t"," ").replace("\r"," ").replace("\n"," ")
    text = "\t".join(columns) + "\n"
    for row in rows:
        text += "\t".join(clean(row.get(c,"")) for c in columns) + "\n"
    path.write_text(text, encoding="utf-8", newline="\n")

def main():
    spec = json.loads((DEV / "history-tool-spec.json").read_text(encoding="utf-8"))
    domains = spec["domains"]
    snapshots = sorted([p for p in FIXTURE.iterdir() if p.is_dir() and snapshot_key(p)], key=snapshot_key)
    sources = []
    for d in domains:
        if d["source_file"] not in sources:
            sources.append(d["source_file"])

    if EXPECTED.exists():
        shutil.rmtree(EXPECTED)
    hist = EXPECTED / "history"
    ever = EXPECTED / "all-ever"
    cache = {}
    def source_path(snap, src):
        direct = snap / src
        if direct.is_file():
            return direct
        nested = snap / "mvs_dmp" / src
        if nested.is_file():
            return nested
        return None

    def model(snap, src):
        p = source_path(snap, src)
        if p is None: return None
        k = (snap.name, src)
        if k not in cache: cache[k] = read_source(p, src)
        return cache[k]

    # Snapshot tables.
    snap_rows = [{"index":i+1,"dump":p.name} for i,p in enumerate(snapshots)]
    write_tsv(hist / "history-snapshots.tsv", ["index","dump"], snap_rows)
    write_tsv(ever / "all-ever-snapshots.tsv", ["index","dump"], snap_rows)

    # Source coverage.
    cov = []
    for a,b in zip(snapshots, snapshots[1:]):
        for src in sources:
            ap, bp = source_path(a,src) is not None, source_path(b,src) is not None
            status = "compared" if ap and bp else "missing-second" if ap else "missing-first" if bp else "missing-both"
            cov.append({"from_dump":a.name,"to_dump":b.name,"source_file":src,"status":status})
    write_tsv(hist / "history-coverage.tsv", ["from_dump","to_dump","source_file","status"], cov)

    ecov = []
    for snap in snapshots:
        for src in sources:
            ecov.append({"dump":snap.name,"source_file":src,"present":"1" if source_path(snap,src) is not None else "0"})
    write_tsv(ever / "all-ever-coverage.tsv", ["dump","source_file","present"], ecov)

    # Added/removed ledgers.
    for d in domains:
        added, removed = [], []
        for a,b in zip(snapshots, snapshots[1:]):
            ma, mb = model(a,d["source_file"]), model(b,d["source_file"])
            if ma is None or mb is None:
                continue
            aa, bb = ma[d["property"]], mb[d["property"]]
            for k,v in aa.items():
                if k not in bb:
                    removed.append({"from_dump":a.name,"to_dump":b.name,"value":v})
            for k,v in bb.items():
                if k not in aa:
                    added.append({"from_dump":a.name,"to_dump":b.name,"value":v})
        write_tsv(hist / "added" / (d["name"]+".tsv"), ["from_dump","to_dump","value"], added)
        write_tsv(hist / "removed" / (d["name"]+".tsv"), ["from_dump","to_dump","value"], removed)

    # All-ever source-local unions.
    for d in domains:
        union = OrderedDict()
        for snap in snapshots:
            m = model(snap,d["source_file"])
            if m is None: continue
            for k,v in m[d["property"]].items():
                if k not in union:
                    union[k] = {
                        "first_seen_dump":snap.name,
                        "last_seen_dump":snap.name,
                        "observed_snapshots":1,
                        "value":v,
                    }
                else:
                    union[k]["last_seen_dump"] = snap.name
                    union[k]["observed_snapshots"] += 1
        write_tsv(ever / "all-ever" / (d["name"]+".tsv"),
                  ["first_seen_dump","last_seen_dump","observed_snapshots","value"],
                  list(union.values()))

if __name__ == "__main__":
    main()
