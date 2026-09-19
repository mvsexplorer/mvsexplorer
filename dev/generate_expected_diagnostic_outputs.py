#!/usr/bin/env python3
"""Regenerate fixed expected stdout for duplicate/orphan diagnostic tests.

Version: 0.1.0

This is an independent Python reference implementation. It reads the
synthetic dump and diagnostic-tool specification; it does not invoke or
parse the generated public .bat tools.
"""
from pathlib import Path
from collections import OrderedDict
import html
import json
import re

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "test" / "test-mvs-dump-diagnostics"
EXPECTED = ROOT / "test" / "expected-diagnostics"
SPEC = ROOT / "dev" / "diagnostic-tool-spec.json"

def norm_title(value):
    return re.sub(r"\s+", " ", html.unescape(value)).strip()

def note_text(value):
    value = re.sub(r"(?is)<br\s*/?>", " ", value)
    value = re.sub(r"(?is)</(?:p|li|div)\s*>", " ", value)
    value = re.sub(r"(?is)<[^>]+>", " ", value)
    value = html.unescape(value).replace("\xa0", " ")
    return re.sub(r"\s+", " ", value).strip()

def record(kind, order, id_value="", title="", date="", raw=None, files=None, note=""):
    return {
        "kind": kind,
        "order": order,
        "id": str(id_value) if id_value != "" else "",
        "title": title,
        "date": date,
        "raw": raw or [],
        "files": files or [],
        "note": note,
    }

def read_records(name):
    text = (FIXTURE / name).read_text(encoding="utf-8")
    lines = text.splitlines()
    result = []

    if name == "mvs_ids.txt":
        for line in lines:
            match = re.match(r"^(.*?)\s*\[ID:\s*(\d+)\]\s*$", line)
            if match:
                result.append(record("ids", len(result)+1, int(match.group(2)), norm_title(match.group(1)), raw=[line]))
        return result

    if name == "mvs_dates.txt":
        for line in lines:
            match = re.match(r"^(.*?)\s+-\s+(.*?)\s*\[ID:\s*(\d+)\]\s*$", line)
            if match:
                result.append(record("dates", len(result)+1, int(match.group(3)), norm_title(match.group(2)), match.group(1).strip(), [line]))
        return result

    if name in ("mvs.txt", "mvs_names.txt"):
        kind = "mvs" if name == "mvs.txt" else "names"
        index = 0
        while index < len(lines):
            match = re.match(r"^---\s*(.*?)\s*\[ID:\s*(\d+)\]\s*---\s*$", lines[index])
            if not match:
                index += 1
                continue
            raw = [lines[index]]
            files = []
            title = norm_title(match.group(1))
            id_value = int(match.group(2))
            index += 1
            while index < len(lines):
                line = lines[index]
                if not line.strip():
                    index += 1
                    break
                if re.match(r"^---\s*.*?\[ID:\s*\d+\]\s*---\s*$", line):
                    break
                raw.append(line)
                file_match = re.match(r"^\s*\S+\s+\*(.+?)\s*$", line)
                if file_match:
                    files.append({"filename": file_match.group(1).strip(), "rawLine": line})
                index += 1
            result.append(record(kind, len(result)+1, id_value, title, raw=raw, files=files))
        return result

    if name == "mvs_notes.html":
        for match in re.finditer(r"(?is)<h1>(.*?)</h1>(.*?)(?=<h1>|\Z)", text):
            heading = norm_title(re.sub(r"(?is)<[^>]+>", " ", match.group(1)))
            id_match = re.search(r"\[ID:\s*(\d+)\]", heading)
            id_value = int(id_match.group(1)) if id_match else ""
            title = norm_title(re.sub(r"\s*\[ID:\s*\d+\]\s*$", "", heading))
            result.append(record("notes", len(result)+1, id_value, title, note=note_text(match.group(2))))
        return result

    if name in ("mvs.sha1", "mvs.sha256"):
        kind = "sha1" if name.endswith("sha1") else "sha256"
        for line in lines:
            file_match = re.match(r"^\s*\S+\s+\*(.+?)\s*$", line)
            if file_match:
                result.append(record(kind, len(result)+1, raw=[line], files=[{
                    "filename": file_match.group(1).strip(),
                    "rawLine": line,
                }]))
        return result

    raise ValueError("Unsupported fixture source: " + name)

def prop_key(prop, value):
    value = str(value)
    if not value.strip():
        return ""
    if prop == "id":
        return str(int(value))
    if prop == "title":
        return norm_title(value).lower()
    if prop == "date":
        return value.strip()
    if prop == "filename":
        return value.strip().lower()
    return value.strip()

def occurrences(records, prop):
    result = []
    for item in records:
        if prop == "filename":
            for file_item in item["files"]:
                value = file_item["filename"]
                key = prop_key(prop, value)
                if key:
                    result.append({"value": value, "key": key, "record": item, "matched": file_item["rawLine"]})
            continue
        value = item[prop]
        key = prop_key(prop, value)
        if key:
            result.append({"value": str(value), "key": key, "record": item, "matched": ""})
    return result

LABELS = {"id":"ID", "title":"Title", "date":"Date", "filename":"Filename"}

def context(item, prop):
    record_item = item["record"]
    if prop == "filename" and record_item["kind"] in ("mvs", "names"):
        return [
            "  ID: " + record_item["id"],
            "  Title: " + record_item["title"],
            "  " + item["matched"],
        ]
    if record_item["kind"] in ("mvs", "names"):
        return ["  " + line for line in record_item["raw"]]
    if record_item["kind"] == "notes":
        lines = []
        if record_item["id"]:
            lines.append("  ID: " + record_item["id"])
        lines.extend(["  Title: " + record_item["title"], "  Note: " + record_item["note"]])
        return lines
    return ["  " + line for line in record_item["raw"]]

def duplicate_output(prop, source):
    groups = OrderedDict()
    for item in occurrences(read_records(source), prop):
        groups.setdefault(item["key"], []).append(item)
    lines = []
    for items in groups.values():
        if len(items) < 2:
            continue
        lines.append(f"Duplicate {LABELS[prop]}: {items[0]['value']}")
        for number, item in enumerate(items, 1):
            lines.append(f"Occurrence {number}:")
            lines.extend(context(item, prop))
        lines.append("")
    return "\n".join(lines) + ("\n" if lines else "")

def orphan_output(prop, source, target):
    source_items = occurrences(read_records(source), prop)
    target_keys = {item["key"] for item in occurrences(read_records(target), prop)}
    lines = []
    for item in source_items:
        if item["key"] in target_keys:
            continue
        lines.extend([
            f"Orphan {LABELS[prop]}: {item['value']}",
            f"Source: {source}",
            f"Target: {target}",
        ])
        lines.extend(context(item, prop))
        lines.append("")
    return "\n".join(lines) + ("\n" if lines else "")

def main():
    EXPECTED.mkdir(parents=True, exist_ok=True)
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    empty = []
    for tool in spec["tools"]:
        if tool["operation"] == "duplicate":
            output = duplicate_output(tool["property"], tool["source"])
        else:
            output = orphan_output(tool["property"], tool["source"], tool["target"])
        if not output:
            empty.append(tool["name"])
        (EXPECTED / (tool["name"] + ".expected.txt")).write_text(output, encoding="utf-8", newline="\n")
    if empty:
        raise SystemExit("Fixture produced no positive finding for: " + ", ".join(empty))
    print(f"Regenerated {len(spec['tools'])} expected diagnostic outputs.")

if __name__ == "__main__":
    main()
