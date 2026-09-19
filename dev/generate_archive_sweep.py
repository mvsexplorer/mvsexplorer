#!/usr/bin/env python3
"""Generate the standalone archive-wide tool sweep harness.

Version: 0.5.2
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEV = ROOT / "dev"

def read(path):
    return path.read_text(encoding="utf-8").replace("\r\n", "\n").rstrip()

def write_bat(path, text):
    path.write_bytes((text.rstrip() + "\n").replace("\n", "\r\n").encode("utf-8"))

def main():
    template = read(DEV / "templates" / "archive-sweep.bat.tpl")
    batch_common = read(DEV / "library" / "batch-common.inc.bat")
    powershell = read(DEV / "library" / "archive-sweep.inc.ps1")
    text = template
    values = {
        "TOOL_VERSION": "0.5.2",
        "BATCH_COMMON": batch_common,
        "ARCHIVE_SWEEP_POWERSHELL": powershell,
    }
    for key, value in values.items():
        text = text.replace("@@" + key + "@@", value)
    if "@@" in text:
        raise ValueError("Unresolved archive-sweep template marker")
    write_bat(ROOT / "test" / "test_all_dumps.bat", text)

if __name__ == "__main__":
    main()
