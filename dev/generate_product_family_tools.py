#!/usr/bin/env python3
"""Generate standalone product-family index/query tools.

Version: 0.2.1
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
DEV = ROOT / "dev"
TOOLS = ROOT / "tools"
TOOLS.mkdir(parents=True, exist_ok=True)

def read(path):
    return path.read_text(encoding="utf-8").replace("\r\n", "\n").rstrip()

def write_bat(path, text):
    path.write_bytes((text.rstrip() + "\n").replace("\n", "\r\n").encode("utf-8"))

def main():
    spec = json.loads((DEV / "product-family-tool-spec.json").read_text(encoding="utf-8"))
    batch_common = read(DEV / "library/batch-common.inc.bat")

    builder_template = read(DEV / "templates/product-family-builder.bat.tpl")
    builder_ps = read(DEV / "library/product-family-builder.inc.ps1")
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
