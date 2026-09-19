#!/usr/bin/env python3
"""Static validator for generated public batch files.

Version: 0.7.0
"""
from pathlib import Path
import collections
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    issues = []
    files = sorted(ROOT.glob("*.bat"))
    optimized = {"scalar":0,"lookup":0,"relationship":0,"single":0}
    for path in files:
        raw = path.read_bytes()
        if raw.startswith(b"\xef\xbb\xbf"):
            issues.append(f"{path.name}: UTF-8 BOM")
        if b"\n" in raw.replace(b"\r\n", b""):
            issues.append(f"{path.name}: non-CRLF newline")
        text = raw.decode("utf-8").replace("\r\n", "\n")
        if ":_MVSQuery_start" in text:
            optimized["scalar"] += 1
            if "$needsDate" not in text or "$needsNote" not in text:
                issues.append(f"{path.name}: scalar projection-aware enrichment optimization missing")
        if ":_MVSLookup_start" in text:
            optimized["lookup"] += 1
            if "$needsDate" not in text or "$needsNote" not in text:
                issues.append(f"{path.name}: lookup projection-aware enrichment optimization missing")
        if ":_MVSRelationship_start" in text:
            optimized["relationship"] += 1
            if "$needsDate = $Fields -contains 'date'" not in text or "$HashFilenameSeen" not in text:
                issues.append(f"{path.name}: relationship optimization missing")
        if ":_MVSSingleDump_start" in text:
            optimized["single"] += 1
            if "$needed.Contains('mvs_names.txt')" not in text or "hash_by_filename" not in text or "New-IgnoreCaseSet" not in text:
                issues.append(f"{path.name}: single-dump lazy/index/hashset optimization missing")
        for label in (":setup", ":main", ":end", ":RunPowerShellFromLabel", ":SetErrorLevel"):
            if label not in text:
                issues.append(f"{path.name}: missing {label}")
        if ":_MVSQuery_start" not in text and ":_MVSLookup_start" not in text and ":_MVSDiagnostic_start" not in text and ":_MVSRelationship_start" not in text and ":_MVSSingleDump_start" not in text and ":_MVSCompare_start" not in text and ":_MVSHistory_start" not in text:
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
            if "return ,(New-Object System.Collections.ArrayList)" not in text:
                issues.append(f"{path.name}: New-ArrayList may collapse empty collection to null")
        if ":_MVSHistory_start" in text:
            if "return ,(New-Object 'System.Collections.Generic.HashSet[string]'" not in text:
                issues.append(f"{path.name}: history HashSet factory may collapse empty collection to null")
            if "return ,(New-Object 'System.Collections.Generic.Dictionary[string,object]'" not in text:
                issues.append(f"{path.name}: history Dictionary factory may collapse empty collection to null")
            if "$union.rows.Add($entry)" not in text:
                issues.append(f"{path.name}: all-ever output lacks explicit first-seen order list")
            if "Get-SnapshotSourcePath" not in text or "'mvs_dmp'" not in text:
                issues.append(f"{path.name}: history tool lacks nested mvs_dmp source resolution")
        if ":_MVSCompare_start" in text:
            if "[Console]::IsOutputRedirected" not in text:
                issues.append(f"{path.name}: comparison output does not suppress console colors when redirected")
            if "([System.ConsoleColor]::Red)" not in text or "([System.ConsoleColor]::Green)" not in text:
                issues.append(f"{path.name}: comparison output missing red/green console colors")
            if "mvsc_first_dump" not in text or "mvsc_second_dump" not in text:
                issues.append(f"{path.name}: comparison tool missing two dump arguments")
        labels = []
        for line in text.splitlines():
            if re.match(r"^:[A-Za-z_]", line):
                labels.append(line.strip().split()[0][1:])
            if line.endswith("^"):
                issues.append(f"{path.name}: trailing caret continuation")
        dup = [k for k, v in collections.Counter(x.casefold() for x in labels).items() if v > 1]
        if dup:
            issues.append(f"{path.name}: duplicate labels {dup}")
    if len(files) != 443:
        issues.append(f"root public .bat count expected 443, got {len(files)}")
    expected_optimized = {"scalar":120,"lookup":7,"relationship":96,"single":154}
    if optimized != expected_optimized:
        issues.append(f"optimized family counts expected {expected_optimized}, got {optimized}")
    if issues:
        print("\n".join(issues), file=sys.stderr)
        return 1
    print(f"PASS: {len(files)} public standalone batch files")
    print(f"PASS: 377 optimized generated public tools ({optimized})")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
