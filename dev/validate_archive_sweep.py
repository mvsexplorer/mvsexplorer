#!/usr/bin/env python3
"""Static validation for the dual-executor archive-wide sweep.

Version: 0.3.0
"""
from pathlib import Path
import re
import sys

ROOT=Path(__file__).resolve().parents[1]

def fail(message):
    print("FAIL:",message,file=sys.stderr)
    raise SystemExit(1)

def check_batch(path,markers=()):
    if not path.is_file(): fail("missing "+str(path.relative_to(ROOT)))
    raw=path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"): fail(str(path.relative_to(ROOT))+" has UTF-8 BOM")
    if b"\n" in raw.replace(b"\r\n",b""): fail(str(path.relative_to(ROOT))+" contains non-CRLF newlines")
    text=raw.decode("utf-8")
    if "@@" in text: fail(str(path.relative_to(ROOT))+" has unresolved template marker")
    if any(line.rstrip("\r\n").endswith("^") for line in text.splitlines(True)):
        fail(str(path.relative_to(ROOT))+" has trailing-caret continuation")
    for marker in markers:
        if marker not in text: fail(str(path.relative_to(ROOT))+" missing token "+marker)
    return text

def main():
    batch=ROOT/"test"/"test_all_dumps.bat"
    text=check_batch(batch,(
        "@echo off\r\n:setup\r\n", "\r\n:main\r\n", "\r\n:end\r\n", "\r\nGoTo :EOF\r\n",
        "\r\n:_MVSArchiveSweep_start\r\n", "\r\n:_MVSArchiveSweep_end\r\n",
        "--plan-only","--resume","--external-tools","fast-combined","external-public",
        "plan-sha256.txt","runs.tsv","fast-batches.tsv","SOURCE_MISSING","NO_RESULT",
        "archive-output","mvs_dmp","run_snapshot_tools_fast.bat","run_compare_tools_fast.bat","run_archive_tools_fast.bat",
        "1> $null","Executor: "
    ))
    if 'executor`tscope`tsnapshot' not in text:
        fail("plan/runs executor identity is not serialized")

    snap=check_batch(ROOT/"test"/"fast"/"run_snapshot_tools_fast.bat",(
        ':_MVSFastSweep_start','mvsf_mode=snapshot','Get-SingleStatus','Read-FastModel',
        "$searchSource=[string]$Entry.search_source",
        "if($searchSource -eq 'hash'){",
        "return (Matches-Exact ([string]$_.hash) $searchValue)"
    ))
    if "([string]$Entry.search_source -eq 'hash' -and (Matches-Exact" in snap:
        fail("snapshot fast worker contains the PowerShell 5.1-sensitive nested hash predicate")
    comp=check_batch(ROOT/"test"/"fast"/"run_compare_tools_fast.bat",(
        ':_MVSFastSweep_start','mvsf_mode=compare','Get-CompareStatus'
    ))
    arch=check_batch(ROOT/"test"/"fast"/"run_archive_tools_fast.bat",(
        ':_MVSFastArchive_start','Fast archive snapshot','history-coverage.tsv',
        'all-ever-coverage.tsv','fast-archive-summary.txt','System.IO.StreamReader'
    ))
    analyzer=check_batch(ROOT/"test"/"analyze_archive_sweep_performance.bat",(
        ':_MVSPerformance_start','performance-by-tool.tsv','fast-batches.tsv'
    ))
    fast_test=check_batch(ROOT/"test"/"test_fast_archive_sweep.bat",(
        'fast-combined 1306 logical checks and archive outputs','--external-tools','--plan-only','AssertExpectedTree',
        ':AssertMetadataLine','Get-Content -LiteralPath $env:mvs_assert_file -Encoding UTF8',
        'Artifacts retained at:'
    ))
    if 'findstr /x /c:"Executor:' in fast_test:
        fail("fast acceptance test still uses brittle FINDSTR exact metadata checks")

    public=sorted(ROOT.glob("*.bat"))
    compare=[p for p in public if p.name.startswith("compare_mvs_dump_")]
    archive_names={"build_mvs_dump_change_history.bat","build_mvs_dump_all_ever.bat"}
    archive=[p for p in public if p.name in archive_names]
    single=[p for p in public if p not in compare and p not in archive]
    if (len(public),len(single),len(compare),len(archive)) != (443,422,19,2):
        fail("unexpected public scope counts: public=%d single=%d compare=%d archive=%d" %
             (len(public),len(single),len(compare),len(archive)))

    planned=len(single)*79+len(compare)*78+len(archive)
    if planned != 34822: fail("79-snapshot plan count mismatch: %d"%planned)
    synthetic=len(single)*3+len(compare)*2+len(archive)
    if synthetic != 1306: fail("3-snapshot fast-test plan mismatch: %d"%synthetic)

    maintained=(
        ROOT/"dev"/"generate_archive_sweep.py",
        ROOT/"dev"/"generate_performance_tools.py",
        ROOT/"dev"/"library"/"archive-sweep.inc.ps1",
        ROOT/"dev"/"library"/"fast-sweep.inc.ps1",
        ROOT/"dev"/"library"/"fast-archive.inc.ps1",
        ROOT/"dev"/"library"/"archive-performance.inc.ps1",
        ROOT/"dev"/"templates"/"archive-sweep.bat.tpl",
        ROOT/"dev"/"templates"/"fast-sweep.bat.tpl",
        ROOT/"dev"/"templates"/"fast-archive.bat.tpl",
        ROOT/"dev"/"templates"/"performance-analyzer.bat.tpl",
        ROOT/"dev"/"templates"/"fast-archive-test.bat.tpl",
        ROOT/"doc"/"archive-sweep.md",
        ROOT/"doc"/"performance-architecture.md",
    )
    for p in maintained:
        if not p.is_file(): fail("missing maintained file: "+str(p.relative_to(ROOT)))

    print("PASS: archive sweep/performance static validation")
    print("public tools: 443 (single=422 compare=19 archive=2)")
    print("executors: fast-combined (default), external-public (--external-tools)")
    print("supplied archive plan: 34,822 logical checks for 79 snapshots")
    print("fast-test plan: 1,306 logical checks for 3 snapshots")

if __name__=="__main__":
    main()
