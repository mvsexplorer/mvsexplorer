#!/usr/bin/env python3
"""Static validator for generated public batch files.

Version: 0.10.0
"""
from pathlib import Path
import collections
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    issues = []
    root_files = sorted(ROOT.glob("*.bat"))
    tool_files = sorted((ROOT / "tools").glob("*.bat"))
    standalone_root_names = {
        "mvs_explorer_gui.bat",
        "all_test_then_all_database_then_test_database_and_all_tools.bat",
    }
    files = tool_files + [p for p in root_files if p.name in standalone_root_names]
    optimized = {"scalar":0,"lookup":0,"relationship":0,"single":0}
    family = {"builder":0,"compact_builder":0,"query":0}
    pipeline = 0
    browser = 0
    gui = 0
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
        if ":_MVSProductFamily_start" in text:
            family["builder"] += 1
            if "product-family-memberships.tsv" not in text or "family-parent-relationships.tsv" not in text or "mvs_dmp" not in text:
                issues.append(f"{path.name}: product-family builder missing normalized DAG/source-resolution markers")
        if ":_MVSProductFamilyCompact_start" in text:
            family["compact_builder"] += 1
            if "snapshot-sets.tsv" not in text or "product-file-hashes-all-ever.tsv" not in text or "filename-hash-conflicts.tsv" not in text:
                issues.append(f"{path.name}: compact product-family builder missing collapse/conflict markers")
        if ":_MVSProductFamilyQuery_start" in text:
            family["query"] += 1
            if "product-family-memberships.tsv" not in text or "Matches-Pattern" not in text:
                issues.append(f"{path.name}: product-family query missing index/wildcard markers")
        if ":_MVSHtmlBrowser_start" in text:
            browser += 1
            for marker in ("product-classifications.tsv","product-file-hashes-all-ever.tsv","type=\"application/json\"","Files &amp; hashes","Unclassified / historical","yyyyMMdd-HHmmss"):
                if marker not in text:
                    issues.append(f"{path.name}: HTML browser builder missing {marker}")
            if "http://" in text or "https://" in text or "<script src=" in text:
                issues.append(f"{path.name}: HTML browser builder is not self-contained/offline")
            if "[Array]::Sort[string]" in text or "[Array]::Sort($a,[StringComparer]::OrdinalIgnoreCase)" not in text:
                issues.append(f"{path.name}: HTML browser builder must use Windows PowerShell 5.1-safe array sorting")
        if ":_MVSExplorerGui_start" in text:
            gui += 1
            for marker in ("System.Windows.Forms","FolderBrowserDialog","CheckedListBox","DataGridView","product-classifications.tsv","product-file-hashes-all-ever.tsv","(Unclassified / historical)","Files & hashes","Find-CompactIndexCandidates","Choose-CompactIndex","mvs_databases"):
                if marker not in text:
                    issues.append(f"{path.name}: PowerShell GUI missing {marker}")
            if "[Array]::Sort[string]" in text or "[Array]::Sort($a,[StringComparer]::OrdinalIgnoreCase)" not in text:
                issues.append(f"{path.name}: PowerShell GUI must use Windows PowerShell 5.1-safe array sorting")
        if ":_MVSAllPipeline_start" in text:
            pipeline += 1
            for marker in ("ALL TESTS","BUILD ARCHIVE ANALYSIS DATABASE","BUILD FULL PRODUCT-FAMILY EVIDENCE DATABASE","BUILD COMPACT ALL-EVER PRODUCT-FAMILY DATABASE","test_generated_databases.bat","SEND-ME-","phase-performance.tsv","--resume-built","mvspipe_arg9","RESUME PRECHECK: STRUCTURE + DATABASE-VALIDATOR GUARDS","Get-StatusTokenColor","Write-ConsoleTokenized","[IO.FileShare]::ReadWrite","[Console]::ForegroundColor"):
                if marker not in text:
                    issues.append(f"{path.name}: orchestration pipeline missing {marker}")
        for label in (":setup", ":main", ":end", ":RunPowerShellFromLabel", ":SetErrorLevel"):
            if label not in text:
                issues.append(f"{path.name}: missing {label}")
        if ":_MVSQuery_start" not in text and ":_MVSLookup_start" not in text and ":_MVSDiagnostic_start" not in text and ":_MVSRelationship_start" not in text and ":_MVSSingleDump_start" not in text and ":_MVSCompare_start" not in text and ":_MVSHistory_start" not in text and ":_MVSProductFamily_start" not in text and ":_MVSProductFamilyCompact_start" not in text and ":_MVSProductFamilyQuery_start" not in text and ":_MVSHtmlBrowser_start" not in text and ":_MVSExplorerGui_start" not in text and ":_MVSAllPipeline_start" not in text:
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
    # PowerShell keywords require a token boundary before variables/type literals.
    # This specifically guards the 0.16.0 regression where `return $true` was
    # hand-compacted to invalid `return$true` inside the new database validator.
    ps_boundary_files = [
        ROOT / "dev" / "library" / "database-validation.inc.ps1",
        ROOT / "dev" / "library" / "all-pipeline.inc.ps1",
        ROOT / "test" / "test_generated_databases.bat",
        ROOT / "all_test_then_all_database_then_test_database_and_all_tools.bat",
    ]
    for ps_path in ps_boundary_files:
        if not ps_path.exists():
            issues.append(f"{ps_path.relative_to(ROOT)}: missing PowerShell boundary-check target")
            continue
        ps_text = ps_path.read_text(encoding="utf-8").replace("\r\n", "\n")
        for match in re.finditer(r"\breturn(?=[\$\[\'\"\d])", ps_text):
            line = ps_text.count("\n", 0, match.start()) + 1
            issues.append(f"{ps_path.relative_to(ROOT)}:{line}: invalid/missing whitespace after PowerShell return keyword")
    db_source = ROOT / "dev" / "library" / "database-validation.inc.ps1"
    if db_source.exists():
        db_text = db_source.read_text(encoding="utf-8")
        if "return ($seen-eq$indegree.Count)" not in db_text:
            issues.append("database-validation DAG check must compare visited nodes with unique indegree keys, not raw family-node rows")
        if "return ($seen-eq$Nodes.Count)" in db_text:
            issues.append("database-validation DAG check incorrectly counts duplicate family-node role rows")
    expected_root_names = {
        "mvs_explorer_gui.bat",
        "all_test_then_all_database_then_test_database_and_all_tools.bat",
        "create_or_update_mvs_database.bat",
        "display_mvs_database_summary.bat",
    }
    actual_root_names = {p.name for p in root_files}
    if len(tool_files) != 478:
        issues.append(f"tools public .bat count expected 478, got {len(tool_files)}")
    if actual_root_names != expected_root_names:
        issues.append(f"root launcher set mismatch: expected {sorted(expected_root_names)}, got {sorted(actual_root_names)}")
    component_dir = ROOT / "create_or_update_mvs_database"
    component_files = sorted(component_dir.glob("*.bat"))
    if len(component_files) != 8:
        issues.append(f"create/update component count expected 8, got {len(component_files)}")
    else:
        for component in component_files:
            raw = component.read_bytes()
            text = raw.decode("utf-8", errors="replace")
            if raw.startswith(b"\xef\xbb\xbf"):
                issues.append(f"{component.relative_to(ROOT)}: UTF-8 BOM")
            if b"\n" in raw.replace(b"\r\n", b""):
                issues.append(f"{component.relative_to(ROOT)}: non-CRLF newline")
            if ":_MVSDatabaseMaintenance_start" not in text:
                issues.append(f"{component.relative_to(ROOT)}: missing embedded maintenance PowerShell")
    maintenance = ROOT / "create_or_update_mvs_database.bat"
    display = ROOT / "display_mvs_database_summary.bat"
    if maintenance.exists():
        mt = maintenance.read_text(encoding="utf-8")
        for marker in ("mvs_dumps_archive*","create-or-update-","CreateFromDirectory","archives.tsv","08_write_database_summary.bat"):
            if marker not in mt:
                issues.append(f"create_or_update_mvs_database.bat missing {marker}")
    else:
        issues.append("missing create_or_update_mvs_database.bat")
    prepare = component_dir / "02_prepare_archive_update.bat"
    if prepare.exists():
        pt = prepare.read_text(encoding="utf-8")
        for marker in ("source-fingerprints.tsv","Already done:","Processing from scratch:","toolset-sha256.txt","pending_checks"):
            if marker not in pt:
                issues.append(f"{prepare.relative_to(ROOT)} missing {marker}")
        if "LastWriteTime" in pt or "CreationTime" in pt:
            issues.append(f"{prepare.relative_to(ROOT)}: source-reuse fingerprint must not depend on filesystem timestamps")
    if display.exists():
        dt = display.read_text(encoding="utf-8")
        for marker in ("OVERALL HEALTH:","Completeness:","mvs_databases*","ForegroundColor","source-fingerprints.tsv"):
            if marker not in dt:
                issues.append(f"display_mvs_database_summary.bat missing {marker}")
    else:
        issues.append("missing display_mvs_database_summary.bat")
    if pipeline != 1:
        issues.append(f"pipeline tool count expected 1, got {pipeline}")
    if browser != 1:
        issues.append(f"HTML browser builder count expected 1, got {browser}")
    if gui != 1:
        issues.append(f"PowerShell GUI tool count expected 1, got {gui}")
    if family != {"builder":1,"compact_builder":1,"query":32}:
        issues.append(f"product-family tool counts expected builder=1 compact_builder=1 query=32, got {family}")
    expected_optimized = {"scalar":120,"lookup":7,"relationship":96,"single":154}
    if optimized != expected_optimized:
        issues.append(f"optimized family counts expected {expected_optimized}, got {optimized}")
    if issues:
        print("\n".join(issues), file=sys.stderr)
        return 1
    print(f"PASS: {len(tool_files)} public tools\\ batch files + {len(files)-len(tool_files)} standalone root applications")
    print(f"PASS: 377 optimized generated legacy public tools ({optimized})")
    print(f"PASS: 34 product-family public tools ({family})")
    print(f"PASS: {browser} self-contained HTML browser builder public tool")
    print(f"PASS: {gui} standalone PowerShell GUI public tool")
    print(f"PASS: {pipeline} full-pipeline orchestration public tool")
    print("PASS: modular create/update database workflow (8 components) + colored database summary launcher")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
