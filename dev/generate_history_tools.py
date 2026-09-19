#!/usr/bin/env python3
"""Generate standalone archive-history tools.

Version: 0.1.0
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

def ps_quote(value):
    return "'" + value.replace("'", "''") + "'"

def main():
    spec = json.loads((DEV / "history-tool-spec.json").read_text(encoding="utf-8"))
    template = read(DEV / "templates/history.bat.tpl")
    batch_common = read(DEV / "library/batch-common.inc.bat")
    powershell = read(DEV / "library/history-query.inc.ps1")

    domain_rows = []
    source_files = []
    for domain in spec["domains"]:
        domain_rows.append(
            "    [pscustomobject]@{ name=%s; property=%s; source_file=%s; id_mode=%s }" % (
                ps_quote(domain["name"]),
                ps_quote(domain["property"]),
                ps_quote(domain["source_file"]),
                ps_quote(domain.get("id_mode", "")),
            )
        )
        if domain["source_file"] not in source_files:
            source_files.append(domain["source_file"])

    injected = powershell.replace("@@DOMAIN_ROWS@@", ",\n".join(domain_rows))
    injected = injected.replace("@@SOURCE_ROWS@@", ",\n".join("    " + ps_quote(x) for x in source_files))

    for tool in spec["tools"]:
        text = template
        values = {
            "TOOL_VERSION": spec["tool_version"],
            "TOOL_NAME": tool["name"],
            "MODE": tool["mode"],
            "BATCH_COMMON": batch_common,
            "HISTORY_POWERSHELL": injected,
        }
        for key, value in values.items():
            text = text.replace("@@" + key + "@@", value)
        if "@@" in text:
            raise ValueError("Unresolved history template marker: " + tool["name"])
        write_bat(TOOLS / (tool["name"] + ".bat"), text)

if __name__ == "__main__":
    main()
