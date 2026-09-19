#!/usr/bin/env python3
"""Generate standalone product-family index/query tools.

Version: 0.2.2
"""
from pathlib import Path
import csv
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
DEV = ROOT / "dev"
TOOLS = ROOT / "tools"
TOOLS.mkdir(parents=True, exist_ok=True)

def read(path):
    return path.read_text(encoding="utf-8").replace("\r\n", "\n").rstrip()

def write_bat(path, text):
    path.write_bytes((text.rstrip() + "\n").replace("\n", "\r\n").encode("utf-8"))


def ps_single(value):
    return "'" + str(value).replace("'", "''") + "'"

def build_hint_block():
    path = DEV / "product-family-classification-hints.tsv"
    raw = path.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    with path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    required = {"kind","prefix","broad_family","product_family","release","confidence","rationale"}
    if not rows or set(rows[0].keys()) != required:
        raise ValueError("Unexpected product-family classification hint columns")
    lines = [
        "$EmbeddedFamilyHintSource = 'dev/product-family-classification-hints.tsv'",
        "$EmbeddedFamilyHintSha256 = '" + digest + "'",
        "$EmbeddedFamilyHintCount = " + str(len(rows)),
        "$EmbeddedFamilyHints = @("
    ]
    for row in rows:
        fields = ";".join(
            key + "=" + ps_single(row[key])
            for key in ("kind","prefix","broad_family","product_family","release","confidence","rationale")
        )
        lines.append("    [pscustomobject]@{" + fields + "}")
    lines.append(")")
    return "\n".join(lines)

def main():
    spec = json.loads((DEV / "product-family-tool-spec.json").read_text(encoding="utf-8"))
    batch_common = read(DEV / "library/batch-common.inc.bat")

    builder_template = read(DEV / "templates/product-family-builder.bat.tpl")
    builder_ps = read(DEV / "library/product-family-builder.inc.ps1")
    builder_ps = builder_ps.replace("@@PRODUCT_FAMILY_HINTS_POWERSHELL@@", build_hint_block())
    if "@@" in builder_ps:
        raise ValueError("Unresolved marker in product-family builder PowerShell")
    text = builder_template
    for key, value in {
        "TOOL_VERSION": spec.get("builder_version", spec["version"]),
        "BATCH_COMMON": batch_common,
        "PRODUCT_FAMILY_BUILDER_POWERSHELL": builder_ps,
    }.items():
        text = text.replace("@@" + key + "@@", value)
    if "@@" in text:
        raise ValueError("Unresolved product-family builder template marker")
    write_bat(TOOLS / (spec["builder"] + ".bat"), text)

    compact_template = read(DEV / "templates/product-family-compact-builder.bat.tpl")
    compact_ps = read(DEV / "library/product-family-compact-builder.inc.ps1")
    text = compact_template
    for key, value in {
        "TOOL_VERSION": spec.get("compact_builder_version", spec["version"]),
        "BATCH_COMMON": batch_common,
        "PRODUCT_FAMILY_COMPACT_POWERSHELL": compact_ps,
    }.items():
        text = text.replace("@@" + key + "@@", value)
    if "@@" in text:
        raise ValueError("Unresolved compact product-family builder template marker")
    write_bat(TOOLS / (spec["compact_builder"] + ".bat"), text)

    query_template = read(DEV / "templates/product-family-query.bat.tpl")
    query_ps = read(DEV / "library/product-family-query.inc.ps1")
    for item in spec["operations"]:
        for prefix, mode in (("print","human"),("read","machine")):
            name = prefix + "_mvs_" + item["base"]
            text = query_template
            for key, value in {
                "TOOL_VERSION": spec["version"],
                "TOOL_NAME": name,
                "MODE": mode,
                "OPERATION": item["operation"],
                "BATCH_COMMON": batch_common,
                "PRODUCT_FAMILY_QUERY_POWERSHELL": query_ps,
            }.items():
                text = text.replace("@@" + key + "@@", value)
            if "@@" in text:
                raise ValueError("Unresolved product-family query template marker: " + name)
            write_bat(TOOLS / (name + ".bat"), text)

if __name__ == "__main__":
    main()
