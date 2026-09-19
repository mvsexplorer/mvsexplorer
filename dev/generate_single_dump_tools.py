#!/usr/bin/env python3
"""Generate standalone single-dump completeness tools.

Version: 0.1.2

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
    spec = json.loads((DEV / "single-dump-tool-spec.json").read_text(encoding="utf-8"))
    template = read(DEV / "templates/single-dump.bat.tpl")
    batch_common = read(DEV / "library/batch-common.inc.bat")
    powershell = read(DEV / "library/single-dump-query.inc.ps1")

    for tool in spec["tools"]:
        text = template
        values = {
            "TOOL_VERSION": spec["tool_version"],
            "TOOL_NAME": tool["name"],
            "MODE": tool.get("mode", "human"),
            "OPERATION": tool["operation"],
            "FIELDS": ",".join(tool.get("fields", [])),
            "SEARCH_SOURCE": tool.get("search_source", ""),
            "ALGORITHM_FILTER": tool.get("algorithm_filter", ""),
            "SOURCE_FILE": tool.get("source_file", ""),
            "DIAGNOSTIC_KIND": tool.get("diagnostic_kind", ""),
            "BATCH_COMMON": batch_common,
            "SINGLE_DUMP_POWERSHELL": powershell,
        }
        for key, value in values.items():
            text = text.replace("@@" + key + "@@", value)
        if "@@" in text:
            raise ValueError("Unresolved single-dump template marker: " + tool["name"])
        write_bat(ROOT / (tool["name"] + ".bat"), text)

if __name__ == "__main__":
    main()
