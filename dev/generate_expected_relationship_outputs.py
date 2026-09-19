#!/usr/bin/env python3
"""Generate fixed relationship regression expectations independently.

Version: 0.1.0

This parser does not invoke the generated public batch files.
"""
from pathlib import Path
from collections import OrderedDict
import html
import json
import re

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "test" / "test-mvs-dump-relationships"
EXPECTED = ROOT / "test" / "expected-relationships"
SPEC = ROOT / "dev" / "relationship-tool-spec.json"

def normalize_title(value):
    return re.sub(r"\s+", " ", html.unescape(value)).strip()

def normalize_scalar(value):
    return re.sub(r"[\t\r\n]+", " ", "" if value is None else str(value)).strip()

def note_text(value):
    value = re.sub(r"(?is)<br\s*/?>", " ", value)
    value = re.sub(r"(?is)</(?:p|li|div)\s*>", " ", value)
    value = re.sub(r"(?is)<[^>]+>", " ", value)
    value = html.unescape(value).replace("\xa0", " ")
    return re.sub(r"\s+", " ", value).strip()

def read_values():
    result = {}
    for line in (FIXTURE / "TEST-VALUES.txt").read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            result[key.strip()] = value.strip()
    return result

def read_fixture():
    dates = {}
    for line in (FIXTURE / "mvs_dates.txt").read_text(encoding="utf-8").splitlines():
        match = re.match(r"^(.*?)\s+-\s+.*?\[ID:\s*(\d+)\]\s*$", line)
        if match:
            key = str(int(match.group(2)))
            dates.setdefault(key, match.group(1).strip())

    notes = {}
    source = (FIXTURE / "mvs_notes.html").read_text(encoding="utf-8")
    for match in re.finditer(r"(?is)<h1>(.*?)</h1>(.*?)(?=<h1>|\Z)", source):
        heading = normalize_title(re.sub(r"(?is)<[^>]+>", " ", match.group(1)))
        note = note_text(match.group(2))
        if heading and note:
            key = heading.lower()
            notes.setdefault(key, [])
            if note not in notes[key]:
                notes[key].append(note)

    owners = OrderedDict()
    catalog = OrderedDict()
    hash_index = OrderedDict()

    def add_catalog(filename):
        display = filename.strip()
        catalog.setdefault(display.lower(), display)

    def add_hash(hash_value, filename):
        if not re.fullmatch(r"[0-9A-Fa-f]{40}|[0-9A-Fa-f]{64}", hash_value):
            return
        display = filename.strip()
        hash_key = hash_value.lower()
        hash_index.setdefault(hash_key, OrderedDict())
        hash_index[hash_key].setdefault(display.lower(), display)

    lines = (FIXTURE / "mvs.txt").read_text(encoding="utf-8").splitlines()
    index = 0
    section_order = 0
    while index < len(lines):
        header = re.match(r"^---\s*(.*?)\s*\[ID:\s*(\d+)\]\s*---\s*$", lines[index])
        if not header:
            index += 1
            continue

        section_order += 1
        title = normalize_title(header.group(1))
        id_value = str(int(header.group(2)))
        owner = {
            "order": section_order,
            "id": id_value,
            "title": title,
            "date": dates.get(id_value, ""),
            "note": " || ".join(notes.get(title.lower(), [])),
        }
        index += 1

        while index < len(lines):
            line = lines[index]
            if not line.strip():
                index += 1
                break
            if re.match(r"^---\s*.*?\[ID:\s*\d+\]\s*---\s*$", line):
                break
            match = re.match(r"^\s*([0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})\s+\*(.+?)\s*$", line)
            if match:
                hash_value = match.group(1)
                filename = match.group(2).strip()
                add_catalog(filename)
                add_hash(hash_value, filename)
                owners.setdefault(filename.lower(), [])
                if not any(item["order"] == owner["order"] for item in owners[filename.lower()]):
                    owners[filename.lower()].append(owner)
            index += 1

    for manifest_name, length in (("mvs.sha1", 40), ("mvs.sha256", 64)):
        path = FIXTURE / manifest_name
        if not path.exists():
            continue
        pattern = re.compile(rf"^\s*([0-9A-Fa-f]{{{length}}})\s+\*(.+?)\s*$")
        for line in path.read_text(encoding="utf-8").splitlines():
            match = pattern.match(line)
            if match:
                hash_value = match.group(1)
                filename = match.group(2).strip()
                add_catalog(filename)
                add_hash(hash_value, filename)

    return owners, catalog, hash_index

def matched_filenames(source, search, catalog, hash_index):
    if source == "filename":
        key = search.strip().lower()
        return [catalog[key]] if key in catalog else []
    return list(hash_index.get(search.strip().lower(), OrderedDict()).values())

def relationship_rows(source, search, owners, catalog, hash_index):
    rows = []
    for filename in matched_filenames(source, search, catalog, hash_index):
        owner_items = owners.get(filename.lower(), [])
        if owner_items:
            for owner in owner_items:
                rows.append({
                    "id": owner["id"],
                    "title": owner["title"],
                    "date": owner["date"],
                    "note": owner["note"],
                    "filename": filename,
                })
        else:
            rows.append({"id":"", "title":"", "date":"", "note":"", "filename":filename})
    return rows

LABELS = {
    "id":"ID",
    "title":"Title",
    "date":"Date",
    "note":"Note",
    "filename":"Filename",
}

def output_for(source, search, fields, mode, owners, catalog, hash_index):
    seen = set()
    lines = []
    for row in relationship_rows(source, search, owners, catalog, hash_index):
        values = [normalize_scalar(row[field]) for field in fields]
        if not any(values):
            continue
        key = tuple(values)
        if key in seen:
            continue
        seen.add(key)
        if mode == "machine":
            lines.append("\t".join(values))
        else:
            parts = []
            for field, value in zip(fields, values):
                parts.append(f"{LABELS[field]}: {value if value else '(none)'}")
            lines.append(" | ".join(parts))
    return "\n".join(lines) + ("\n" if lines else "")

def main():
    EXPECTED.mkdir(parents=True, exist_ok=True)
    values = read_values()
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    owners, catalog, hash_index = read_fixture()
    count = 0

    for projection in spec["projections"]:
        suffix = projection["suffix"]
        fields = projection["fields"]
        for source in spec["sources"]:
            case_names = ["filename"] if source == "filename" else ["sha1", "sha256"]
            for prefix, mode in (("print", "human"), ("read", "machine")):
                tool = f"{prefix}_mvs_dump_{suffix}_from_{source}"
                for case_name in case_names:
                    source_name = "filename" if case_name == "filename" else "hash"
                    output = output_for(
                        source_name, values[case_name], fields, mode,
                        owners, catalog, hash_index
                    )
                    if not output:
                        raise SystemExit(f"Unexpected empty expectation: {tool} / {case_name}")
                    (EXPECTED / f"{tool}__{case_name}.expected.txt").write_text(
                        output, encoding="utf-8", newline="\n"
                    )
                    count += 1

    for prefix, mode in (("print","human"), ("read","machine")):
        tool = f"{prefix}_mvs_dump_filenames_from_hash"
        output = output_for(
            "hash", values["mvs_txt_hash"], ["filename"], mode,
            owners, catalog, hash_index
        )
        (EXPECTED / f"{tool}__mvs-txt.expected.txt").write_text(
            output, encoding="utf-8", newline="\n"
        )
        count += 1

    print(f"Regenerated {count} fixed relationship expectations.")

if __name__ == "__main__":
    main()
