#!/usr/bin/env python3
"""Static validator for generated public batch files.

Version: 0.4.1
"""
from pathlib import Path
import collections
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    issues = []
    files = sorted(ROOT.glob("*.bat"))
    for path in files:
        raw = path.read_bytes()
        if raw.startswith(b"\xef\xbb\xbf"):
            issues.append(f"{path.name}: UTF-8 BOM")
        if b"\n" in raw.replace(b"\r\n", b""):
            issues.append(f"{path.name}: non-CRLF newline")
        text = raw.decode("utf-8").replace("\r\n", "\n")
        for label in (":setup", ":main", ":end", ":RunPowerShellFromLabel", ":SetErrorLevel"):
            if label not in text:
                issues.append(f"{path.name}: missing {label}")
        if ":_MVSQuery_start" not in text and ":_MVSLookup_start" not in text and ":_MVSDiagnostic_start" not in text and ":_MVSRelationship_start" not in text and ":_MVSSingleDump_start" not in text:
            issues.append(f"{path.name}: missing embedded PowerShell block")
        if "dev\\library" in text or "generate_tools.py" in text:
            issues.append(f"{path.name}: development dependency leaked into runtime")
        if ":_MVSSingleDump_start" in text:
            bad_section_array = (
                "[string]$section.occurrence," in text
                and "[string]$section.id," in text
                and "Normalize-Scalar ([string]$section.title)," in text
            )
            if bad_section_array:
                issues.append(f"{path.name}: parser-sensitive single-dump section array form")
            if "if ($Name -eq 'mvs_names.txt')" not in text or r"(?<id>[^\]]+?)" not in text:
                issues.append(f"{path.name}: missing textual mvs_names ID parser")
            if "$match = Matches-Exact $row.id $Needle" not in text:
                issues.append(f"{path.name}: missing textual variant ID matcher")
        labels = []
        for line in text.splitlines():
            if re.match(r"^:[A-Za-z_]", line):
                labels.append(line.strip().split()[0][1:])
            if line.endswith("^"):
                issues.append(f"{path.name}: trailing caret continuation")
        dup = [k for k, v in collections.Counter(x.casefold() for x in labels).items() if v > 1]
        if dup:
            issues.append(f"{path.name}: duplicate labels {dup}")
    if issues:
        print("\n".join(issues), file=sys.stderr)
        return 1
    print(f"PASS: {len(files)} public standalone batch files")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
