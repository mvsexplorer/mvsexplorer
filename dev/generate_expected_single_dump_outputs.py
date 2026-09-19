#!/usr/bin/env python3
"""Generate fixed expected stdout for single-dump completeness tests.

Version: 0.1.0

This is an independent Python reference implementation. It reads the
synthetic fixture and the declarative tool specification; it never invokes
or parses output from the public .bat tools under test.
"""
from __future__ import annotations

from collections import OrderedDict, defaultdict
from datetime import datetime, timezone
from pathlib import Path
import html
import json
import re

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "test" / "test-mvs-dump-single-complete"
EXPECTED = ROOT / "test" / "expected-single-dump"
SPEC = ROOT / "dev" / "single-dump-tool-spec.json"

SOURCES = [
    "mvs.txt", "mvs_names.txt", "mvs.sha1", "mvs.sha256",
    "mvs_ids.txt", "mvs_dates.txt"
]

LABELS = {
    "id": "ID",
    "title": "Title",
    "date": "Date",
    "note": "Note",
    "filename": "Filename",
    "hash": "Hash",
    "algorithm": "Algorithm",
    "source": "Source",
    "line": "Line",
    "raw": "Raw",
    "occurrence": "Occurrence",
    "section_occurrence": "Section",
    "line_offset": "Offset",
    "variant_title": "Variant",
}

def norm_scalar(value):
    if value is None:
        return ""
    return re.sub(r"[\t\r\n]+", " ", str(value)).strip()

def norm_title(value):
    return re.sub(r"\s+", " ", html.unescape(value or "")).strip()

def note_text(value):
    value = re.sub(r"(?is)<br\s*/?>", " ", value)
    value = re.sub(r"(?is)</p\s*>", " ", value)
    value = re.sub(r"(?is)</li\s*>", " ", value)
    value = re.sub(r"(?is)</div\s*>", " ", value)
    value = re.sub(r"(?is)<[^>]+>", " ", value)
    value = html.unescape(value).replace("\xa0", " ")
    return re.sub(r"\s+", " ", value).strip()

def algorithm(hash_value):
    return "SHA1" if len(hash_value) == 40 else "SHA256" if len(hash_value) == 64 else ""

def read_values():
    values = {}
    for line in (FIXTURE / "TEST-VALUES.txt").read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values

def add_unparsed(model, source, line, raw):
    model["unparsed"][source].append({"line": line, "raw": raw})

def parse_one_line(model, name):
    path = FIXTURE / name
    if not path.exists():
        return []
    rows = []
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip():
            continue
        if name == "mvs_ids.txt":
            match = re.match(r"^(.*?)\s*\[ID:\s*(\d+)\]\s*$", raw)
            if match:
                rows.append({
                    "line": line_no,
                    "id": str(int(match.group(2))),
                    "title": norm_title(match.group(1)),
                    "date": "",
                    "raw": raw,
                })
            else:
                add_unparsed(model, name, line_no, raw)
        else:
            match = re.match(r"^(.*?)\s+-\s+(.*?)\s*\[ID:\s*(\d+)\]\s*$", raw)
            if match:
                rows.append({
                    "line": line_no,
                    "id": str(int(match.group(3))),
                    "title": norm_title(match.group(2)),
                    "date": match.group(1).strip(),
                    "raw": raw,
                })
            else:
                add_unparsed(model, name, line_no, raw)
    return rows

def parse_section_file(model, name):
    path = FIXTURE / name
    if not path.exists():
        return [], []
    lines = path.read_text(encoding="utf-8").splitlines()
    sections, file_rows = [], []
    section = None
    occurrence = 0

    def complete():
        nonlocal section
        if section is not None:
            sections.append(section)
        section = None

    for index, raw in enumerate(lines):
        line_no = index + 1
        match = re.match(r"^---\s*(.*?)\s*\[ID:\s*(\d+)\]\s*---\s*$", raw)
        if match:
            complete()
            occurrence += 1
            section = {
                "occurrence": occurrence,
                "id": str(int(match.group(2))),
                "title": norm_title(match.group(1)),
                "start_line": line_no,
                "raw_lines": [{"offset": 0, "line": line_no, "raw": raw}],
                "file_count": 0,
            }
            continue

        if not raw.strip():
            complete()
            continue

        if section is None:
            add_unparsed(model, name, line_no, raw)
            continue

        section["raw_lines"].append({
            "offset": len(section["raw_lines"]),
            "line": line_no,
            "raw": raw,
        })

        fm = re.match(r"^\s*([0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})\s+\*(.+?)\s*$", raw)
        if fm and fm.group(2).strip():
            hash_value = fm.group(1).lower()
            filename = fm.group(2).strip()
            row = {
                "source": name,
                "line": line_no,
                "section_occurrence": section["occurrence"],
                "id": section["id"],
                "title": section["title"],
                "filename": filename,
                "hash": hash_value,
                "algorithm": algorithm(hash_value),
            }
            file_rows.append(row)
            section["file_count"] += 1
            model["hash_records"].append({
                "source": name,
                "line": line_no,
                "id": section["id"],
                "title": section["title"] if name == "mvs.txt" else "",
                "variant_title": section["title"] if name == "mvs_names.txt" else "",
                "filename": filename,
                "hash": hash_value,
                "algorithm": algorithm(hash_value),
            })
        else:
            add_unparsed(model, name, line_no, raw)

    complete()
    return sections, file_rows

def parse_manifest(model, name, length):
    path = FIXTURE / name
    if not path.exists():
        return []
    rows = []
    pattern = re.compile(rf"^\s*([0-9A-Fa-f]{{{length}}})\s+\*(.+?)\s*$")
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip():
            continue
        match = pattern.match(raw)
        if match and match.group(2).strip():
            hash_value = match.group(1).lower()
            filename = match.group(2).strip()
            row = {
                "source": name,
                "line": line_no,
                "id": "",
                "title": "",
                "variant_title": "",
                "filename": filename,
                "hash": hash_value,
                "algorithm": algorithm(hash_value),
            }
            rows.append(row)
            model["hash_records"].append(row.copy())
        else:
            add_unparsed(model, name, line_no, raw)
    return rows

def parse_notes():
    path = FIXTURE / "mvs_notes.html"
    if not path.exists():
        return []
    source = path.read_text(encoding="utf-8")
    rows = []
    for occurrence, match in enumerate(
        re.finditer(r"(?is)<h1>(.*?)</h1>(.*?)(?=<h1>|\Z)", source), 1
    ):
        title = norm_title(re.sub(r"(?is)<[^>]+>", " ", match.group(1)))
        rows.append({
            "occurrence": occurrence,
            "title": title,
            "note": note_text(match.group(2)),
        })
    return rows

def build_model():
    model = {
        "root": FIXTURE,
        "unparsed": {source: [] for source in SOURCES},
        "hash_records": [],
    }
    model["ids"] = parse_one_line(model, "mvs_ids.txt")
    model["dates"] = parse_one_line(model, "mvs_dates.txt")
    product_sections, raw_product_files = parse_section_file(model, "mvs.txt")
    variant_sections, raw_variant_files = parse_section_file(model, "mvs_names.txt")
    model["sha1"] = parse_manifest(model, "mvs.sha1", 40)
    model["sha256"] = parse_manifest(model, "mvs.sha256", 64)
    model["notes"] = parse_notes()

    date_by_id = OrderedDict()
    for row in model["dates"]:
        date_by_id.setdefault(row["id"], row["date"])

    note_by_title = OrderedDict()
    for row in model["notes"]:
        if not row["title"] or not row["note"]:
            continue
        key = row["title"].lower()
        note_by_title.setdefault(key, [])
        if row["note"] not in note_by_title[key]:
            note_by_title[key].append(row["note"])

    section_by_occ = {}
    for section in product_sections:
        section["date"] = date_by_id.get(section["id"], "")
        section["note"] = " || ".join(note_by_title.get(section["title"].lower(), []))
        section_by_occ[str(section["occurrence"])] = section

    product_files = []
    for row in raw_product_files:
        section = section_by_occ[str(row["section_occurrence"])]
        product_files.append({
            **row,
            "date": section["date"],
            "note": section["note"],
        })

    sections_with_files = {str(row["section_occurrence"]) for row in raw_variant_files}
    variants = []
    for row in raw_variant_files:
        variants.append({
            "occurrence": row["section_occurrence"],
            "id": row["id"],
            "variant_title": row["title"],
            "filename": row["filename"],
            "hash": row["hash"],
            "algorithm": row["algorithm"],
            "source": row["source"],
            "line": row["line"],
        })
    for section in variant_sections:
        if str(section["occurrence"]) not in sections_with_files:
            variants.append({
                "occurrence": section["occurrence"],
                "id": section["id"],
                "variant_title": section["title"],
                "filename": "",
                "hash": "",
                "algorithm": "",
                "source": "mvs_names.txt",
                "line": section["start_line"],
            })
    variants.sort(key=lambda row: (int(row["occurrence"]), int(row["line"])))

    model["product_sections"] = product_sections
    model["product_files"] = product_files
    model["variant_sections"] = variant_sections
    model["variants"] = variants
    return model

def exact(value, needle):
    return str(value or "").strip().lower() == str(needle or "").strip().lower()

def emit_rows(rows, fields, mode, dedupe=True):
    seen = set()
    lines = []
    for row in rows:
        values = [norm_scalar(row.get(field, "")) for field in fields]
        if not any(values):
            continue
        key = tuple(values)
        if dedupe and key in seen:
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

def detail_rows(model, source, needle, algorithm_filter=""):
    seeds = []
    if source in ("id", "title"):
        seen = set()
        for row in model["product_files"]:
            matched = (
                int(row["id"]) == int(needle)
                if source == "id"
                else exact(row["title"], needle)
            )
            if not matched:
                continue
            key = (str(row["section_occurrence"]), row["filename"].lower())
            if key not in seen:
                seen.add(key)
                seeds.append({"owner": row, "filename": row["filename"]})
    elif source in ("filename", "hash"):
        filenames = []
        seen_fn = set()
        for record in model["hash_records"]:
            matched = (
                exact(record["filename"], needle)
                if source == "filename"
                else exact(record["hash"], needle)
            )
            if matched and record["filename"].lower() not in seen_fn:
                seen_fn.add(record["filename"].lower())
                filenames.append(record["filename"])
        for filename in filenames:
            owners = []
            seen_sections = set()
            for row in model["product_files"]:
                if exact(row["filename"], filename) and row["section_occurrence"] not in seen_sections:
                    seen_sections.add(row["section_occurrence"])
                    owners.append(row)
            if owners:
                for owner in owners:
                    seeds.append({"owner": owner, "filename": filename})
            else:
                seeds.append({"owner": None, "filename": filename})

    rows = []
    for seed in seeds:
        records = [
            r for r in model["hash_records"]
            if exact(r["filename"], seed["filename"])
            and (not algorithm_filter or r["algorithm"] == algorithm_filter)
        ]
        if not records:
            owner = seed["owner"]
            rows.append({
                "id": owner["id"] if owner else "",
                "title": owner["title"] if owner else "",
                "date": owner["date"] if owner else "",
                "note": owner["note"] if owner else "",
                "filename": seed["filename"],
                "hash": "",
                "algorithm": "",
                "source": "",
            })
        else:
            for record in records:
                owner = seed["owner"]
                rows.append({
                    "id": owner["id"] if owner else "",
                    "title": owner["title"] if owner else "",
                    "date": owner["date"] if owner else "",
                    "note": owner["note"] if owner else "",
                    "filename": seed["filename"],
                    "hash": record["hash"],
                    "algorithm": record["algorithm"],
                    "source": record["source"],
                })
    return rows

def variant_rows(model, source, needle):
    if not source:
        return list(model["variants"])
    rows = []
    for row in model["variants"]:
        if source == "id":
            try:
                matched = int(row["id"]) == int(needle)
            except ValueError:
                matched = False
        elif source == "filename":
            matched = exact(row["filename"], needle)
        else:
            matched = exact(row["hash"], needle)
        if matched:
            rows.append(row)
    return rows

def hash_rows(model, source, needle, algorithm_filter):
    rows = []
    for row in model["hash_records"]:
        if algorithm_filter and row["algorithm"] != algorithm_filter:
            continue
        if source == "filename" and not exact(row["filename"], needle):
            continue
        if source == "hash" and not exact(row["hash"], needle):
            continue
        rows.append(row)
    return rows

def product_file_rows(model, source, needle):
    if not source:
        return list(model["product_files"])
    result = []
    for row in model["product_files"]:
        if source == "id":
            try:
                matched = int(row["id"]) == int(needle)
            except ValueError:
                matched = False
        else:
            matched = exact(row["title"], needle)
        if matched:
            result.append(row)
    return result

def product_sections(model, source, needle):
    if not source:
        return list(model["product_sections"])
    result = []
    for section in model["product_sections"]:
        if source == "id":
            try:
                matched = int(section["id"]) == int(needle)
            except ValueError:
                matched = False
        else:
            matched = exact(section["title"], needle)
        if matched:
            result.append(section)
    return result

def emit_sections(sections, mode):
    if mode == "human":
        chunks = []
        for section in sections:
            chunks.append("\n".join(item["raw"] for item in section["raw_lines"]))
        return "\n\n".join(chunks) + ("\n" if chunks else "")
    lines = []
    for section in sections:
        for item in section["raw_lines"]:
            lines.append("\t".join([
                str(section["occurrence"]),
                str(section["id"]),
                norm_scalar(section["title"]),
                str(item["offset"]),
                str(item["line"]),
                norm_scalar(item["raw"]),
            ]))
    return "\n".join(lines) + ("\n" if lines else "")

def note_rows(model, source, needle):
    if not source:
        return list(model["notes"])
    return [row for row in model["notes"] if exact(row["title"], needle)]

def source_hash_rows(model, source, algorithm_filter=""):
    return [
        row for row in model["hash_records"]
        if row["source"] == source
        and (not algorithm_filter or row["algorithm"] == algorithm_filter)
    ]

def diagnostic_output(model, kind, source_spec, algorithm_filter):
    lines = []
    if kind == "hash_mismatch":
        left_name, right_name = source_spec.split("|", 1)
        left = source_hash_rows(model, left_name, algorithm_filter)
        right = source_hash_rows(model, right_name, algorithm_filter)
        left_map, right_map = OrderedDict(), OrderedDict()
        for row in left:
            key = row["filename"].lower()
            left_map.setdefault(key, [])
            if row["hash"] not in left_map[key]:
                left_map[key].append(row["hash"])
        for row in right:
            key = row["filename"].lower()
            right_map.setdefault(key, [])
            if row["hash"] not in right_map[key]:
                right_map[key].append(row["hash"])
        for key in sorted(left_map):
            if key not in right_map:
                continue
            left_set = sorted(left_map[key])
            right_set = sorted(right_map[key])
            if left_set == right_set:
                continue
            display = next(row["filename"] for row in left if row["filename"].lower() == key)
            lines.append(f"Hash mismatch for Filename: {display}")
            lines.append(f"  {left_name}: {', '.join(left_set)}")
            lines.append(f"  {right_name}: {', '.join(right_set)}")
            lines.append("")
    else:
        rows = source_hash_rows(model, source_spec, algorithm_filter)
        groups = OrderedDict()
        key_field = "hash" if kind in ("duplicate_hash", "hash_multiple_filenames") else "filename"
        for row in rows:
            key = row[key_field].lower() if key_field == "filename" else row[key_field]
            groups.setdefault(key, []).append(row)

        if kind == "duplicate_hash":
            for key, group in groups.items():
                if len(group) < 2:
                    continue
                lines.append(f"Duplicate Hash: {group[0]['hash']}")
                for row in group:
                    lines.append(f"  Source: {row['source']} | Line: {row['line']} | Filename: {row['filename']}")
                lines.append("")
        elif kind == "hash_multiple_filenames":
            for key, group in groups.items():
                filenames = []
                seen = set()
                for row in group:
                    if row["filename"] not in seen:
                        seen.add(row["filename"])
                        filenames.append(row["filename"])
                if len(filenames) < 2:
                    continue
                lines.append(f"Hash with multiple filenames: {group[0]['hash']}")
                for filename in filenames:
                    lines.append(f"  Filename: {filename}")
                lines.append("")
        elif kind == "filename_multiple_hashes":
            for key, group in groups.items():
                hashes = []
                seen = set()
                for row in group:
                    if row["hash"] not in seen:
                        seen.add(row["hash"])
                        hashes.append(row["hash"])
                if len(hashes) < 2:
                    continue
                lines.append(f"Filename with multiple hashes: {group[0]['filename']}")
                for hash_value in hashes:
                    lines.append(f"  Hash: {hash_value}")
                lines.append("")
    return "\n".join(lines) + ("\n" if lines else "")

def parse_date(value):
    value = value.strip()
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(value)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)

def summary_rows(model):
    rows = []
    def add(key, value):
        rows.append({"key": key, "value": str(value)})

    for name in ["mvs_ids.txt","mvs_dates.txt","mvs.txt","mvs_names.txt","mvs_notes.html","mvs.sha1","mvs.sha256"]:
        add("source.present." + name, "1" if (FIXTURE / name).is_file() else "0")

    add("products.mvs_ids.rows", len(model["ids"]))
    add("products.mvs_dates.rows", len(model["dates"]))
    add("products.mvs.sections", len(model["product_sections"]))
    add("products.mvs.unique_ids", len(list(dict.fromkeys(row["id"] for row in model["product_sections"]))))
    add("products.mvs.unique_titles", len(list(dict.fromkeys(row["title"] for row in model["product_sections"]))))
    add("product_files.rows", len(model["product_files"]))
    add("product_files.unique_filenames", len(list(dict.fromkeys(row["filename"] for row in model["product_files"]))))
    add("product_files.unique_hashes", len(list(dict.fromkeys(row["hash"] for row in model["product_files"]))))
    add("product_files.sha1_rows", sum(row["algorithm"] == "SHA1" for row in model["product_files"]))
    add("product_files.sha256_rows", sum(row["algorithm"] == "SHA256" for row in model["product_files"]))

    product_ids = list(dict.fromkeys(row["id"] for row in model["product_sections"]))
    product_file_ids = list(dict.fromkeys(row["id"] for row in model["product_files"]))
    add("product_files.product_ids_with_files", len(product_file_ids))
    add("product_files.product_ids_without_files", sum(pid not in product_file_ids for pid in product_ids))
    file_groups_by_id = defaultdict(int)
    for row in model["product_files"]:
        file_groups_by_id[row["id"]] += 1
    add("product_files.max_rows_per_product_id", max(file_groups_by_id.values(), default=0))
    filename_groups_for_stats = defaultdict(int)
    for row in model["product_files"]:
        filename_groups_for_stats[row["filename"].lower()] += 1
    add("product_files.reused_filename_groups", sum(count > 1 for count in filename_groups_for_stats.values()))

    ids_numeric = sorted(int(row["id"]) for row in model["product_sections"])
    add("products.id_min", ids_numeric[0] if ids_numeric else "")
    add("products.id_max", ids_numeric[-1] if ids_numeric else "")

    parsed_dates = [(parse_date(row["date"]), row["date"]) for row in model["dates"] if row["date"]]
    parsed_dates = [(dt, raw) for dt, raw in parsed_dates if dt is not None]
    parsed_dates.sort(key=lambda item: item[0])
    add("products.date_min", parsed_dates[0][1] if parsed_dates else "")
    add("products.date_max", parsed_dates[-1][1] if parsed_dates else "")

    add("variants.sections", len(model["variant_sections"]))
    add("variants.rows", len(model["variants"]))
    add("variants.unique_titles", len(list(dict.fromkeys(row["title"] for row in model["variant_sections"]))))
    add("variants.unique_filenames", len(list(dict.fromkeys(row["filename"] for row in model["variants"] if row["filename"]))))
    variant_ids = list(dict.fromkeys(row["id"] for row in model["variant_sections"]))
    add("variants.product_ids_with_variants", len(variant_ids))
    add("variants.product_ids_without_variants", sum(pid not in variant_ids for pid in product_ids))
    variant_groups_by_id = defaultdict(int)
    for row in model["variant_sections"]:
        variant_groups_by_id[row["id"]] += 1
    add("variants.max_sections_per_product_id", max(variant_groups_by_id.values(), default=0))
    add("variants.repeated_product_id_groups", sum(count > 1 for count in variant_groups_by_id.values()))

    add("notes.records", len(model["notes"]))
    add("notes.unique_titles", len(list(dict.fromkeys(row["title"] for row in model["notes"]))))
    note_title_keys = list(dict.fromkeys(row["title"].lower() for row in model["notes"] if row["note"]))
    product_ids_with_notes = list(dict.fromkeys(
        row["id"] for row in model["product_sections"] if row["title"].lower() in note_title_keys
    ))
    add("notes.product_ids_with_notes", len(product_ids_with_notes))
    add("notes.product_ids_without_notes", sum(pid not in product_ids_with_notes for pid in product_ids))
    note_title_groups = defaultdict(int)
    for row in model["notes"]:
        note_title_groups[row["title"].lower()] += 1
    add("notes.duplicate_title_groups", sum(count > 1 for count in note_title_groups.values()))

    add("sha1.rows", len(model["sha1"]))
    add("sha1.unique_hashes", len(list(dict.fromkeys(row["hash"] for row in model["sha1"]))))
    add("sha1.unique_filenames", len(list(dict.fromkeys(row["filename"] for row in model["sha1"]))))
    add("sha256.rows", len(model["sha256"]))
    add("sha256.unique_hashes", len(list(dict.fromkeys(row["hash"] for row in model["sha256"]))))
    add("sha256.unique_filenames", len(list(dict.fromkeys(row["filename"] for row in model["sha256"]))))

    add("hash_records.rows", len(model["hash_records"]))
    add("hash_records.unique_hashes", len(list(dict.fromkeys(row["hash"] for row in model["hash_records"]))))
    add("hash_records.unique_filenames", len(list(dict.fromkeys(row["filename"] for row in model["hash_records"]))))
    add("hash_records.unique_sha1", len(list(dict.fromkeys(row["hash"] for row in model["hash_records"] if row["algorithm"] == "SHA1"))))
    add("hash_records.unique_sha256", len(list(dict.fromkeys(row["hash"] for row in model["hash_records"] if row["algorithm"] == "SHA256"))))

    id_groups = defaultdict(int)
    title_groups = defaultdict(int)
    filename_groups = defaultdict(int)
    for row in model["product_sections"]:
        id_groups[row["id"]] += 1
        title_groups[row["title"].lower()] += 1
    for row in model["product_files"]:
        filename_groups[row["filename"].lower()] += 1
    add("integrity.duplicate_product_ids", sum(count > 1 for count in id_groups.values()))
    add("integrity.duplicate_product_titles", sum(count > 1 for count in title_groups.values()))
    add("integrity.duplicate_product_filenames", sum(count > 1 for count in filename_groups.values()))

    ids_from_ids = list(dict.fromkeys(row["id"] for row in model["ids"]))
    ids_from_dates = list(dict.fromkeys(row["id"] for row in model["dates"]))
    ids_from_mvs = list(dict.fromkeys(row["id"] for row in model["product_sections"]))
    ids_from_names = list(dict.fromkeys(row["id"] for row in model["variant_sections"]))
    add("integrity.orphan_ids_ids_to_dates", sum(value not in ids_from_dates for value in ids_from_ids))
    add("integrity.orphan_ids_ids_to_mvs", sum(value not in ids_from_mvs for value in ids_from_ids))
    add("integrity.orphan_ids_ids_to_names", sum(value not in ids_from_names for value in ids_from_ids))

    mvs_filenames = list(dict.fromkeys(row["filename"] for row in model["product_files"]))
    name_filenames = list(dict.fromkeys(row["filename"] for row in model["variants"] if row["filename"]))
    sha1_filenames = list(dict.fromkeys(row["filename"] for row in model["sha1"]))
    sha256_filenames = list(dict.fromkeys(row["filename"] for row in model["sha256"]))
    add("integrity.orphan_filenames_mvs_to_names", sum(value not in name_filenames for value in mvs_filenames))
    add("integrity.orphan_filenames_names_to_mvs", sum(value not in mvs_filenames for value in name_filenames))
    add("integrity.orphan_filenames_mvs_to_sha1", sum(value not in sha1_filenames for value in mvs_filenames))
    add("integrity.orphan_filenames_names_to_sha1", sum(value not in sha1_filenames for value in name_filenames))
    add("integrity.orphan_filenames_mvs_to_sha256", sum(value not in sha256_filenames for value in mvs_filenames))
    add("integrity.orphan_filenames_names_to_sha256", sum(value not in sha256_filenames for value in name_filenames))

    total = 0
    for name in SOURCES:
        count = len(model["unparsed"][name])
        total += count
        add("integrity.unparsed." + name, count)
    add("integrity.unparsed.total", total)
    return rows

def emit_summary(rows, mode):
    lines = [
        (f"{row['key']}\t{row['value']}" if mode == "machine"
         else f"{row['key']}: {row['value']}")
        for row in rows
    ]
    return "\n".join(lines) + ("\n" if lines else "")

def search_value(tool, values):
    source = tool.get("search_source", "")
    if not source:
        return ""
    if tool["operation"] == "variant_query":
        if source == "filename":
            return values["variant_filename"]
        if source == "hash":
            return values["variant_hash"]
    if tool["operation"] == "note_query":
        return values["note_title"]
    return values[source]

def output_for(tool, model, values):
    op = tool["operation"]
    mode = tool.get("mode", "human")
    fields = tool.get("fields", [])
    source = tool.get("search_source", "")
    needle = search_value(tool, values)
    alg = tool.get("algorithm_filter", "")

    if op == "detail_query":
        return emit_rows(detail_rows(model, source, needle, alg), fields, mode, True)
    if op == "variant_query":
        return emit_rows(variant_rows(model, source, needle), fields, mode, True)
    if op == "hash_query":
        return emit_rows(hash_rows(model, source, needle, alg), fields, mode, True)
    if op == "product_file_query":
        return emit_rows(product_file_rows(model, source, needle), fields, mode, False)
    if op == "product_section_query":
        return emit_sections(product_sections(model, source, needle), mode)
    if op == "note_query":
        return emit_rows(note_rows(model, source, needle), fields, mode, False)
    if op == "unparsed_query":
        rows = model["unparsed"][tool["source_file"]]
        if mode == "machine":
            lines = [f"{row['line']}\t{norm_scalar(row['raw'])}" for row in rows]
        else:
            lines = [f"Line {row['line']}: {row['raw']}" for row in rows]
        return "\n".join(lines) + ("\n" if lines else "")
    if op == "hash_diagnostic":
        return diagnostic_output(
            model, tool["diagnostic_kind"], tool["source_file"], alg
        )
    if op == "summary_query":
        return emit_summary(summary_rows(model), mode)
    raise ValueError("Unsupported operation: " + op)

def main():
    EXPECTED.mkdir(parents=True, exist_ok=True)
    values = read_values()
    model = build_model()
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    empty = []
    for tool in spec["tools"]:
        output = output_for(tool, model, values)
        if not output and tool["operation"] not in ("unparsed_query", "hash_diagnostic"):
            empty.append(tool["name"])
        if tool["operation"] in ("unparsed_query", "hash_diagnostic") and not output:
            empty.append(tool["name"])
        (EXPECTED / (tool["name"] + ".expected.txt")).write_text(
            output, encoding="utf-8", newline="\n"
        )
    if empty:
        raise SystemExit("Fixture produced no positive output for: " + ", ".join(empty))
    print(f"Regenerated {len(spec['tools'])} fixed single-dump expectations.")

if __name__ == "__main__":
    main()
