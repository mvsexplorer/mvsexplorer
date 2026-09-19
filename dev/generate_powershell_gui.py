#!/usr/bin/env python3
"""Generate the standalone PowerShell/WinForms MVS Explorer GUI.

Version: 0.1.0
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEV = ROOT / "dev"
TOOL_VERSION = "0.1.0"

def read(path):
    return path.read_text(encoding="utf-8").replace("\r\n", "\n").rstrip()

def write_bat(path, text):
    path.write_bytes((text.rstrip() + "\n").replace("\n", "\r\n").encode("utf-8"))

def main():
    text = read(DEV / "templates" / "powershell-gui.bat.tpl")
    values = {
        "TOOL_VERSION": TOOL_VERSION,
        "BATCH_COMMON": read(DEV / "library" / "batch-common.inc.bat"),
        "GUI_POWERSHELL": read(DEV / "library" / "powershell-gui.inc.ps1"),
    }
    for key, value in values.items():
        text = text.replace("@@" + key + "@@", value)
    if "@@" in text:
        raise ValueError("Unresolved PowerShell GUI template marker")
    write_bat(ROOT / "mvs_explorer_gui.bat", text)

if __name__ == "__main__":
    main()
