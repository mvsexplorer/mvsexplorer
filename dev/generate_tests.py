#!/usr/bin/env python3
"""Generate standalone test batch files.

Version: 0.11.13
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEV = ROOT / "dev"
TEST = ROOT / "test"

TESTS = [
    ("test_all", "all"),
    ("test_structure", "structure"),
    ("test_scalar_tools", "scalar"),
    ("test_lookup_tools", "lookup"),
    ("test_diagnostic_tools", "diagnostic"),
    ("test_relationship_tools", "relationship"),
    ("test_single_dump_tools", "single_dump"),
    ("test_compare_tools", "compare"),
    ("test_history_tools", "history"),
]

def read(path):
    return path.read_text(encoding="utf-8").replace("\r\n", "\n").rstrip()

def write_bat(path, text):
    path.write_bytes((text.rstrip() + "\n").replace("\n", "\r\n").encode("utf-8"))

def main():
    batch_common = read(DEV / "library/batch-common.inc.bat")
    harness = read(DEV / "library/test-harness.inc.ps1")
    template = read(DEV / "templates/test.bat.tpl")
    for name, mode in TESTS:
        text = template
        values = {
            "TEST_VERSION": "0.11.13",
            "PROJECT_VERSION": "0.19.1",
            "TEST_NAME": name,
            "TEST_MODE": mode,
            "BATCH_COMMON": batch_common,
            "TEST_POWERSHELL": harness,
        }
        for key, value in values.items():
            text = text.replace("@@" + key + "@@", value)
        if "@@" in text:
            raise ValueError("Unresolved test template marker: " + name)
        write_bat(TEST / (name + ".bat"), text)

if __name__ == "__main__":
    main()
