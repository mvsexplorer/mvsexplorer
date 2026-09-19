#!/usr/bin/env python3
"""Generate standalone MVS duplicate/orphan diagnostic tools.

Version: 0.1.0

Development-time only. Generated root .bat files contain all injected
batch and PowerShell code and do not depend on dev\ at runtime.
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
    spec = json.loads((DEV / "diagnostic-tool-spec.json").read_text(encoding="utf-8"))
    batch_common = read(DEV / "library/batch-common.inc.bat")
    powershell = read(DEV / "library/diagnostic-query.inc.ps1")
    template = read(DEV / "templates/diagnostic.bat.tpl")

    expected = set()
    for tool in spec["tools"]:
        name = tool["name"]
        expected.add(name + ".bat")
        text = template
        values = {
            "TOOL_VERSION": spec["tool_version"],
            "TOOL_NAME": name,
            "OPERATION": tool["operation"],
            "PROPERTY": tool["property"],
            "SOURCE": tool["source"],
            "TARGET": tool["target"],
            "BATCH_COMMON": batch_common,
            "DIAGNOSTIC_POWERSHELL": powershell,
        }
        for key, value in values.items():
            text = text.replace("@@" + key + "@@", value)
        if "@@" in text:
            raise ValueError("Unresolved diagnostic template marker: " + name)
        write_bat(ROOT / (name + ".bat"), text)

if __name__ == "__main__":
    main()
