#!/usr/bin/env python3
"""Generate public standalone MVS Explorer Toolkit batch tools.

Version: 0.1.0

Development-time only. Generated root .bat files contain the injected
functions and embedded PowerShell and do not require dev\ at runtime.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
DEV = ROOT / "dev"
LIB = DEV / "library"
TPL = DEV / "templates"

def read(path):
    return path.read_text(encoding="utf-8").replace("\r\n", "\n").rstrip()

def write_bat(path, text):
    path.write_bytes((text.rstrip() + "\n").replace("\n", "\r\n").encode("utf-8"))

def inject(template, values):
    text = template
    for key, value in values.items():
        text = text.replace("@@" + key + "@@", value)
    if "@@" in text:
        raise ValueError("Unresolved template marker in " + values.get("TOOL_NAME", "tool"))
    return text

def main():
    spec = json.loads((DEV / "tool-spec.json").read_text(encoding="utf-8"))
    batch_common = read(LIB / "batch-common.inc.bat")
    scalar_ps = read(LIB / "scalar-query.inc.ps1")
    lookup_ps = read(LIB / "lookup-query.inc.ps1")
    scalar_tpl = read(TPL / "scalar.bat.tpl")
    lookup_tpl = read(TPL / "lookup.bat.tpl")

    for suffix, fields in spec["projections"]:
        for prefix, mode in (("print", "human"), ("read", "machine")):
            base = f"{prefix}_mvs_dump_{suffix}"
            write_bat(ROOT / f"{base}.bat", inject(scalar_tpl, {
                "TOOL_VERSION": "0.3.0",
                "TOOL_NAME": base,
                "MODE": mode,
                "FIELDS": ",".join(fields),
                "SORT": "",
                "BATCH_COMMON": batch_common,
                "SCALAR_POWERSHELL": scalar_ps,
            }))
            for sort_key in spec["sort_keys"]:
                name = f"{base}_sorted_by_{sort_key}"
                write_bat(ROOT / f"{name}.bat", inject(scalar_tpl, {
                    "TOOL_VERSION": "0.1.0",
                    "TOOL_NAME": name,
                    "MODE": mode,
                    "FIELDS": ",".join(fields),
                    "SORT": sort_key,
                    "BATCH_COMMON": batch_common,
                    "SCALAR_POWERSHELL": scalar_ps,
                }))

    for name, source, target in spec["lookups"]:
        write_bat(ROOT / f"{name}.bat", inject(lookup_tpl, {
            "TOOL_VERSION": "0.1.0",
            "TOOL_NAME": name,
            "SOURCE": source,
            "TARGET": target,
            "BATCH_COMMON": batch_common,
            "LOOKUP_POWERSHELL": lookup_ps,
        }))

if __name__ == "__main__":
    main()
