#!/usr/bin/env python3
"""Generate standalone filename/hash relationship query tools.

Version: 0.1.1

Development-time only. Generated root .bat files contain all batch and
PowerShell implementation required at runtime.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
DEV = ROOT / "dev"

def read(path):
    return path.read_text(encoding="utf-8").replace("\r\n", "\n").rstrip()

def write_bat(path, text):
    path.write_bytes((text.rstrip() + "\n").replace("\n", "\r\n").encode("utf-8"))

def main():
    spec = json.loads((DEV / "relationship-tool-spec.json").read_text(encoding="utf-8"))
    template = read(DEV / "templates/relationship.bat.tpl")
    batch_common = read(DEV / "library/batch-common.inc.bat")
    powershell = read(DEV / "library/relationship-query.inc.ps1")

    for projection in spec["projections"]:
        suffix = projection["suffix"]
        fields = ",".join(projection["fields"])
        for source in spec["sources"]:
            for prefix, mode in (("print", "human"), ("read", "machine")):
                name = f"{prefix}_mvs_dump_{suffix}_from_{source}"
                text = template
                values = {
                    "TOOL_VERSION": spec["tool_version"],
                    "TOOL_NAME": name,
                    "MODE": mode,
                    "FIELDS": fields,
                    "SOURCE": source,
                    "BATCH_COMMON": batch_common,
                    "RELATIONSHIP_POWERSHELL": powershell,
                }
                for key, value in values.items():
                    text = text.replace("@@" + key + "@@", value)
                if "@@" in text:
                    raise ValueError("Unresolved relationship template marker: " + name)
                write_bat(ROOT / (name + ".bat"), text)

if __name__ == "__main__":
    main()
