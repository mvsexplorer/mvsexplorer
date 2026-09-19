#!/usr/bin/env python3
"""Static validation for archive sweep, quality, reporting, and performance helpers.

Version: 0.5.2
"""
from pathlib import Path
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


def check_unique_labels(path,text):
    labels={}
    for number,line in enumerate(text.replace("\r\n","\n").split("\n"),1):
        stripped=line.strip()
        if not stripped.startswith(":") or stripped.startswith("::"):
            continue
        token=stripped.split()[0][1:].lower()
        if not token:
            continue
        if token in labels:
            fail("%s duplicate batch label :%s at lines %d and %d" %
                 (str(path.relative_to(ROOT)),token,labels[token],number))
        labels[token]=number
    return labels

def main():
    batch=ROOT/"test"/"test_all_dumps.bat"
    text=check_batch(batch,(
        "@echo off\r\n:setup\r\n","\r\n:main\r\n","\r\n:end\r\n","\r\nGoTo :EOF\r\n",
        "\r\n:_MVSArchiveSweep_start\r\n","\r\n:_MVSArchiveSweep_end\r\n",
        "--plan-only","--resume","--external-tools","--workers","--exclusions","--no-report",
        "--cache-folder","--no-cache","fast-combined","external-public","engine_version",
        "plan-sha256.txt","runs.tsv","fast-batches.tsv","SOURCE_MISSING","NO_RESULT",
        "archive-output","mvs_dmp","run_snapshot_tools_fast.bat","run_compare_tools_fast.bat",
        "run_archive_tools_fast.bat","Start-FastWorkerJob","Complete-FastWorkerJob",
        "build_archive_html_report.bat","Content cache:"
    ))
    if "'index','executor','engine_version','scope','snapshot'" not in text:
        fail("plan engine/executor identity is not serialized")
    if "& $WorkerPath $ArchiveRoot $ArchiveOutput 1> $null 2> $stderrPath" in text:
        fail("fast archive worker progress is still suppressed")
    if "& $WorkerPath $ArchiveRoot $ArchiveOutput 2> $stderrPath | ForEach-Object { Write-Line ([string]$_) }" not in text:
        fail("fast archive worker progress is not streamed through the sweep logger")

    snap=check_batch(ROOT/"test"/"fast"/"run_snapshot_tools_fast.bat",(
        ':_MVSFastSweep_start','mvsf_mode=snapshot','Get-SingleStatus','Read-FastModel',
        'product_files_by_filename','hash_records_by_hash','Get-IndexRows',
        'Get-SourceInventory','Assert-SourceInventoryUnchanged','Get-SnapshotCacheKey',
        'mvsf_cache_root','<h[13][^>]*>','Groups[\'heading\']'
    ))
    if "([string]$Entry.search_source -eq 'hash' -and (Matches-Exact" in snap:
        fail("snapshot fast worker contains the old parser-sensitive nested hash predicate")
    if "$Model.product_files | Where-Object" in snap:
        fail("indexed snapshot worker regressed to full product-file scans")
    if "$Model.hash_records | Where-Object" in snap:
        fail("indexed snapshot worker regressed to full hash-record scans")

    check_batch(ROOT/"test"/"fast"/"run_compare_tools_fast.bat",(
        ':_MVSFastSweep_start','mvsf_mode=compare','Get-CompareStatus','Assert-SourceInventoryUnchanged'
    ))
    check_batch(ROOT/"test"/"fast"/"run_archive_tools_fast.bat",(
        ':_MVSFastArchive_start','Fast archive snapshot','history-coverage.tsv','all-ever-coverage.tsv',
        'fast-archive-summary.txt','System.IO.StreamReader','per-dump-contributions.tsv',
        'per-dump-quality.tsv','variant-id-transitions.tsv','note-versions.tsv',
        'note-observations.tsv','variant_source_ids','note-raw-variants.tsv','per-dump-retention.tsv',
        'suggested-exclusions.tsv','raw-html','noteVersionsSeenThisSnapshot','noteBodiesSeenThisSnapshot',
        'noteRawSeenThisSnapshot','$FileCount -eq 1','state_primary_id','fast-archive-timings.tsv','BitConverter','New-Object \'string[]\' $Fields.Count'
    ))
    check_batch(ROOT/"test"/"build_archive_html_report.bat",(
        ':_MVSArchiveReport_start','Archive Summary','What This Dump Added','Re-ID / ID Regimes',
        'Duplicates / Quality','Canonical exclusions are non-destructive','Performance',
        'domain_additions','retention','Source-local domain additions','Introduced here vs. seen later'
    ))
    check_batch(ROOT/"test"/"check_archive_sweep_quality.bat",(
        ':_MVSArchiveQuality_start','unexpected SOURCE_MISSING','performance-outliers.tsv',
        'performance-by-batch.tsv','performance-batch-outliers.tsv','performance-archive-outliers.tsv',
        'Archive batch outliers:','per-dump-retention.tsv','note_raw_variants_all_ever',
        'summary counter mismatch','strict performance check failed'
    ))
    check_batch(ROOT/"test"/"analyze_test_performance.bat",(
        ':_MVSTestPerformance_start','performance-outliers.tsv','performance-by-tool.tsv',
        'elapsed_ms','Threshold milliseconds'
    ))
    everything=check_batch(ROOT/"test"/"test_everything.bat",(
        ':_MVSTestEverything_start','--full-archive','--strict-performance','--archive-results',
        'test_all.bat','test_fast_archive_sweep.bat','check_archive_sweep_quality.bat','--no-cache',
        'param([string]$Tool,[object[]]$ToolArgs)','& $Tool @ToolArgs'
    ))
    if 'param([string]$Tool,[object[]]$Args)' in everything or '& $Tool @Args' in everything:
        fail("test_everything Run helper collides with PowerShell automatic $args variable")
    check_batch(ROOT/"test"/"analyze_archive_sweep_performance.bat",(
        ':_MVSPerformance_start','performance-by-tool.tsv','fast-batches.tsv'
    ))
    fast_test=check_batch(ROOT/"test"/"test_fast_archive_sweep.bat",(
        'fast-combined 1306 logical checks and archive outputs','Fast archive snapshot 1/3: mvs_2020-01-01',
        '--external-tools','--plan-only','--no-cache','AssertExpectedTree',':AssertMetadataLine',
        'Get-Content -LiteralPath $env:mvs_assert_file -Encoding UTF8','Artifacts retained at:'
    ))
    if 'findstr /x /c:"Executor:' in fast_test:
        fail("fast acceptance test still uses brittle FINDSTR exact metadata checks")
    fast_labels=check_unique_labels(ROOT/"test"/"test_fast_archive_sweep.bat",fast_test)
    required_fast_labels=("assertmetadataline","asserttsvmetric","assertrunstatus","assertnoteversion","assertexpectedtree","showfailure")
    for label in required_fast_labels:
        if label not in fast_labels:
            fail("fast acceptance test missing subroutine label :"+label)
    main_exit=fast_test.find("echo SUMMARY: passed=3 failed=0\r\nexit /b 0\r\n")
    first_sub=fast_test.find("\r\n:AssertMetadataLine\r\n")
    if main_exit < 0 or first_sub < 0 or first_sub < main_exit:
        fail("fast acceptance test subroutines are not placed after the main exit")
    for token in (
        '"product_states_all_ever" "4"',
        '"variant_states_all_ever" "4"',
        '"note_versions_all_ever" "5"',
        '"note_bodies_all_ever" "5"',
        '"note_raw_variants_all_ever" "5"',
        '"Keep Product" "Keep note" "3"',
        '"read_mvs_dump_note_records" "PASS"',
        '"read_mvs_dump_note_records_from_title" "PASS"',
        ':AssertTsvMetric',
    ):
        if token not in fast_test:
            fail("fast acceptance test missing concrete evolution assertion "+token)

    # PowerShell 5.1 must serialize summary/run-info metadata as one field per line.
    # Unparenthesized array-entry concatenation can split labels from values.
    sweep_lib=(ROOT/"dev"/"library"/"archive-sweep.inc.ps1").read_text(encoding="utf-8")
    if "(?is)<h[13]\\b[^>]*>(?<title>.*?)</h[13]>" not in sweep_lib:
        fail("archive snapshot profile does not recognize both legacy h3 and current h1 note headings")
    if "$noteTitle = Convert-HeadingToText $Matches.title" not in sweep_lib:
        fail("archive snapshot profile does not strip legacy note [ID: ...] heading suffix")
    if sweep_lib.count("('Executor: ' + $Executor),") < 2:
        fail("archive sweep metadata writers must parenthesize Executor concatenation in summary and run-info")
    for bad in (
        "\n        'Mode: ' + $Mode,",
        "\n        'Executor: ' + $Executor,",
        "\n    'Sweep script: ' + $Caller,",
        "\n    'Executor: ' + $Executor,",
    ):
        if bad in sweep_lib:
            fail("archive sweep metadata writer contains PowerShell-5.1-sensitive unparenthesized array concatenation")

    if '"%fastout%\\run-info.txt" "Executor: fast-combined"' not in fast_test:
        fail("fast acceptance test does not validate fast-combined run-info metadata")
    if '"%extout%\\run-info.txt" "Executor: external-public"' not in fast_test:
        fail("fast acceptance test does not validate external-public run-info metadata")

    # Synthetic history notes exercise both legacy h3+ID and newer h1 heading forms.
    fixture_notes=(
        ROOT/"test"/"test-mvs-dump-history"/"mvs_2020-01-01"/"mvs_notes.html",
        ROOT/"test"/"test-mvs-dump-history"/"mvs_2020-01-02"/"mvs_dmp"/"mvs_notes.html",
        ROOT/"test"/"test-mvs-dump-history"/"mvs_2020-01-03_2"/"mvs_notes.html",
    )
    for note_path in fixture_notes:
        if not note_path.is_file():
            fail("synthetic history note fixture missing: "+str(note_path.relative_to(ROOT)))
    if "<h3>" not in fixture_notes[0].read_text(encoding="utf-8"):
        fail("synthetic history fixture no longer exercises legacy h3 notes")
    if "<h1>" not in fixture_notes[2].read_text(encoding="utf-8"):
        fail("synthetic history fixture no longer exercises h1 notes")

    # All delivered batch labels are unique case-insensitively. This catches
    # accidental subroutine insertion inside a parenthesized error branch.
    for delivered in ROOT.rglob("*.bat"):
        delivered_text=delivered.read_text(encoding="utf-8")
        check_unique_labels(delivered,delivered_text)

    # Public surface remains fixed.
    public=sorted(ROOT.glob("*.bat"))
    compare=[p for p in public if p.name.startswith("compare_mvs_dump_")]
    archive_names={"build_mvs_dump_change_history.bat","build_mvs_dump_all_ever.bat"}
    archive=[p for p in public if p.name in archive_names]
    single=[p for p in public if p not in compare and p not in archive]
    if (len(public),len(single),len(compare),len(archive)) != (443,422,19,2):
        fail("unexpected public scope counts: public=%d single=%d compare=%d archive=%d" %
             (len(public),len(single),len(compare),len(archive)))
    planned=len(single)*79+len(compare)*78+len(archive)
    synthetic=len(single)*3+len(compare)*2+len(archive)
    if planned != 34822: fail("79-snapshot plan count mismatch: %d"%planned)
    if synthetic != 1306: fail("3-snapshot fast-test plan mismatch: %d"%synthetic)

    exclusions=ROOT/"test"/"archive-exclusions.tsv"
    if not exclusions.is_file(): fail("missing test/archive-exclusions.tsv")
    if exclusions.read_text(encoding="utf-8").splitlines()[0] != "snapshot\tscope\tcanonical\treason":
        fail("archive-exclusions.tsv header mismatch")

    # Test harness must capture per-invocation elapsed time.
    test_all=check_batch(ROOT/"test"/"test_all.bat",("elapsed_ms","Diagnostics.Stopwatch","all-results.tsv"))
    if "expected_rc`tactual_rc`telapsed_ms" not in test_all:
        fail("test result TSV does not include elapsed_ms")

    maintained=(
        "dev/generate_archive_sweep.py","dev/generate_performance_tools.py","dev/generate_report_tools.py",
        "dev/generate_quality_tools.py","dev/library/archive-sweep.inc.ps1","dev/library/fast-sweep.inc.ps1",
        "dev/library/fast-archive.inc.ps1","dev/library/archive-report.inc.ps1",
        "dev/library/archive-quality.inc.ps1","dev/library/test-performance.inc.ps1",
        "dev/library/test-everything.inc.ps1","dev/templates/archive-report.bat.tpl",
        "dev/templates/archive-quality.bat.tpl","dev/templates/test-performance.bat.tpl",
        "dev/templates/test-everything.bat.tpl","doc/archive-sweep.md","doc/performance-architecture.md",
    )
    for rel in maintained:
        if not (ROOT/rel).is_file(): fail("missing maintained file: "+rel)

    print("PASS: archive sweep/quality/performance static validation")
    print("public tools: 443 (single=422 compare=19 archive=2)")
    print("fast executor: indexed + source-stable + bounded parallel workers + content cache")
    print("analysis: per-dump contributions, quality, re-ID, notes, exclusions, interactive HTML")
    print("supplied archive plan: 34,822 logical checks for 79 snapshots")
    print("fast-test plan: 1,306 logical checks for 3 snapshots")

if __name__=="__main__":
    main()
