#!/usr/bin/env python3
"""Static validation for archive sweep, quality, reporting, and performance helpers.

Version: 0.8.2
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
        "--plan-only","--quiet-plan","--resume","--external-tools","--workers","--start-workers","--max-workers","--exclusions","--no-report",
        "--cache-folder","--no-cache","fast-combined","external-public","engine_version",
        "plan-sha256.txt","runs.tsv","fast-batches.tsv","worker-scaling.tsv","Get-SystemHeadroom",
        "Win32_Processor","Win32_OperatingSystem","Win32_PerfFormattedData_PerfDisk_PhysicalDisk","SOURCE_MISSING","NO_RESULT",
        "archive-output","mvs_dmp","run_snapshot_tools_fast.bat","run_compare_tools_fast.bat",
        "run_archive_tools_fast.bat","Start-FastWorkerJob","Complete-FastWorkerJob",
        "build_archive_html_report.bat","Content cache:","Family tools:",
        "build_mvs_product_family_index.bat","build_mvs_product_family_compact_index.bat","^(?:print|read)_mvs_product_",
        "Starting snapshot ","Completed snapshot ","Starting compare ","Completed compare ","Elapsed.TotalSeconds","__MVS_TRANSIENT__","Write-Transient","SNAPSHOT ANALYSIS START","SNAPSHOT ANALYSIS END"
    ))
    if "'index','executor','engine_version','scope','snapshot'" not in text:
        fail("plan engine/executor identity is not serialized")
    if "& $WorkerPath $ArchiveRoot $ArchiveOutput 1> $null 2> $stderrPath" in text:
        fail("fast archive worker progress is still suppressed")
    if "& $WorkerPath $ArchiveRoot $ArchiveOutput 2> $stderrPath | ForEach-Object {" not in text or "Write-Transient $childLine" not in text or "Write-Line $childLine" not in text:
        fail("fast archive worker progress is not streamed through transient/permanent sweep logging")

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
        'test_all.bat','test_fast_archive_sweep.bat','check_archive_sweep_quality.bat','--no-cache','--quiet-plan','--skip-real-archive-plan',
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

    # Public tool surface lives under tools\; root contains application/orchestration launchers only.
    public=sorted((ROOT/"tools").glob("*.bat"))
    root_public=sorted(ROOT.glob("*.bat"))
    compare=[p for p in public if p.name.startswith("compare_mvs_dump_")]
    archive_names={"build_mvs_dump_change_history.bat","build_mvs_dump_all_ever.bat"}
    archive=[p for p in public if p.name in archive_names]
    family=[p for p in public if p.name in {"build_mvs_product_family_index.bat","build_mvs_product_family_compact_index.bat"} or
            p.name.startswith("print_mvs_product_") or p.name.startswith("read_mvs_product_")]
    browser=[p for p in public if p.name=="build_mvs_html_browser.bat"]
    gui=[p for p in root_public if p.name=="mvs_explorer_gui.bat"]
    pipeline=[p for p in root_public if p.name=="all_test_then_all_database_then_test_database_and_all_tools.bat"]
    single=[p for p in public if p not in compare and p not in archive and p not in family and p not in browser]
    if (len(public),len(single),len(compare),len(archive),len(family),len(browser),len(gui),len(pipeline),len(root_public)) != (478,422,19,2,34,1,1,1,4):
        fail("unexpected public scope counts: tools=%d single=%d compare=%d archive=%d family=%d browser=%d gui=%d pipeline=%d root=%d" %
             (len(public),len(single),len(compare),len(archive),len(family),len(browser),len(gui),len(pipeline),len(root_public)))
    planned=len(single)*79+len(compare)*78+len(archive)
    synthetic=len(single)*3+len(compare)*2+len(archive)
    if planned != 34822: fail("79-snapshot plan count mismatch: %d"%planned)
    if synthetic != 1306: fail("3-snapshot fast-test plan mismatch: %d"%synthetic)

    family_builder=check_batch(ROOT/"tools"/"build_mvs_product_family_index.bat",(
        ":_MVSProductFamily_start","product-family-memberships.tsv","family-parent-relationships.tsv",
        "product-ids.tsv","product-dates.tsv","product-files.tsv","product-hashes.tsv",
        "product-notes.tsv","unclassified-products.tsv","overrides-applied.tsv","mvs_dmp",
        "OFFICE_OCS","OFFICE_PROOFING","OFFICE_SDK","GENERIC_MICROSOFT_REVIEW",
        "Get-ReleaseToken","Microsoft Office Online Server","(?:last\\s+)?updated",
        "\\bversion\\s+"
    ))
    compact_builder=check_batch(ROOT/"tools"/"build_mvs_product_family_compact_index.bat",(
        ":_MVSProductFamilyCompact_start","snapshot-sets.tsv","product-file-hashes-all-ever.tsv",
        "file-hashes-all-ever.tsv","filename-hash-conflicts.tsv","product-file-hash-conflicts.tsv",
        "hash-filename-aliases.tsv","CROSS_PRODUCT_FILENAME_REUSE","PRODUCT_HASH_DISAGREEMENT"
    ))
    gui_tool=check_batch(ROOT/"mvs_explorer_gui.bat",(
        ":_MVSExplorerGui_start","System.Windows.Forms","FolderBrowserDialog","CheckedListBox","DataGridView",
        "product-classifications.tsv","product-file-hashes-all-ever.tsv","(Unclassified / historical)","Files & hashes"
    ))
    family_queries=[p for p in public if p.name.startswith("print_mvs_product_") or p.name.startswith("read_mvs_product_")]
    if len(family_queries)!=32:
        fail("expected 32 product-family query tools, got %d"%len(family_queries))
    for p in family_queries:
        check_batch(p,(":_MVSProductFamilyQuery_start","product-family-memberships.tsv","Matches-Pattern"))
    pipeline_tool=check_batch(ROOT/"all_test_then_all_database_then_test_database_and_all_tools.bat",(
        ":_MVSAllPipeline_start","Project version:","ALL TESTS","BUILD ARCHIVE ANALYSIS DATABASE",
        "BUILD FULL PRODUCT-FAMILY EVIDENCE DATABASE","BUILD COMPACT ALL-EVER PRODUCT-FAMILY DATABASE",
        "test_generated_databases.bat","phase-performance.tsv","SEND-ME-","Get-StatusTokenColor",
        "Write-ConsoleTokenized","COLLECT LOGS, CREATE DATABASE HARDLINKS, PREPARE FINAL PACKAGE",
        "Finalizing log ZIP after active log writers are closed ...","[Console]::ForegroundColor","'Green'","'Red'","'Yellow'"
    ))
    phase_marker="$sw=Begin-Phase 'COLLECT LOGS, CREATE DATABASE HARDLINKS, PREPARE FINAL PACKAGE'"
    dispose_marker='if($null-ne$script:MasterWriter){$script:MasterWriter.Flush();$script:MasterWriter.Dispose();$script:MasterWriter=$null}'
    final_marker="Write-Console 'Finalizing log ZIP after active log writers are closed ...'"
    phase_pos=pipeline_tool.find(phase_marker)
    dispose_pos=pipeline_tool.find(dispose_marker)
    final_pos=pipeline_tool.find(final_marker)
    if phase_pos < 0 or dispose_pos <= phase_pos or final_pos <= dispose_pos:
        fail("pipeline log-ZIP ordering markers are invalid")
    active_window=pipeline_tool[phase_pos:dispose_pos]
    if "New-ZipFromDirectory $script:LogsRoot $script:LogZip" in active_window or "Finish-LogZip" in active_window:
        fail("pipeline attempts to ZIP live logs before writer disposal")
    db_validator=check_batch(ROOT/"test"/"test_generated_databases.bat",(
        ":_MVSDatabaseValidation_start","DB TEST","all-family-tools-performance.tsv",
        "snapshot-set dictionary is internally consistent","same-product filename/hash disagreement ledger",
        "all 32 public family query tools","$planByIndex=@{}","foreach($r in $runs)",
        "[string[]]$names=@()","$names=@(([string]$r.snapshots)-split"
    ))
    family_test=check_batch(ROOT/"test"/"test_product_family_tools.bat",(
        ":_MVSProductFamilyTest_start","SUMMARY: passed=","expected 108 assertions",
        "embedded Office reference is not ownership","raw note HTML references are content-addressed",
        "Office Online update stamp is not a release",
        ".NET semantic version beats referenced year",
        "explicit non-year version beats update timestamp",
        "mvspf_project_version=0.21.1"
    ))
    test_all_text=(ROOT/"test"/"test_all.bat").read_text(encoding="utf-8")
    if ("public layout = tools\\ 478 BATs, root 4 launchers, create/update 8 components" not in test_all_text or
        "product-family regression 108 assertions" not in test_all_text or
        "SUMMARY: passed=108 failed=0" not in test_all_text or
        ("SUMMARY: passed=96 failed=0" in test_all_text or "SUMMARY: passed=92 failed=0" in test_all_text)):
        fail("test_all.bat is not integrated with the 108-assertion product-family regression")

    exclusions=ROOT/"test"/"archive-exclusions.tsv"
    if not exclusions.is_file(): fail("missing test/archive-exclusions.tsv")
    if exclusions.read_text(encoding="utf-8").splitlines()[0] != "snapshot\tscope\tcanonical\treason":
        fail("archive-exclusions.tsv header mismatch")

    archive_sweep_text=(ROOT/"test"/"test_all_dumps.bat").read_text(encoding="utf-8")
    for marker in ('set "mvsa_argc=0"', ':mvsa_capture_args', 'set "mvsa_arg_%mvsa_argc%=%~1"', "GetEnvironmentVariable(('mvsa_arg_{0}' -f $CapturedArgIndex))"):
        if marker not in archive_sweep_text:
            fail("test_all_dumps.bat lacks arbitrary-length argument transport marker: "+marker)
    if 'set "mvsa_arg9=%~9"' in archive_sweep_text:
        fail("test_all_dumps.bat still truncates options at cmd.exe positional argument 9")

    # Test harness must capture per-invocation elapsed time.
    test_all=check_batch(ROOT/"test"/"test_all.bat",("elapsed_ms","Diagnostics.Stopwatch","all-results.tsv","[TEST ","Project: MVS Explorer Toolkit","mvst_project_version=0.21.1"))
    if "expected_rc`tactual_rc`telapsed_ms" not in test_all:
        fail("test result TSV does not include elapsed_ms")
    check_batch(ROOT/"test"/"test_everything.bat",("[SUITE TEST ","Project version:","0.21.1","--start-workers","--max-workers"))

    maintained=(
        "dev/generate_archive_sweep.py","dev/generate_performance_tools.py","dev/generate_report_tools.py",
        "dev/generate_quality_tools.py","dev/library/archive-sweep.inc.ps1","dev/library/fast-sweep.inc.ps1",
        "dev/library/fast-archive.inc.ps1","dev/library/archive-report.inc.ps1",
        "dev/library/archive-quality.inc.ps1","dev/library/test-performance.inc.ps1",
        "dev/library/test-everything.inc.ps1","dev/templates/archive-report.bat.tpl",
        "dev/templates/archive-quality.bat.tpl","dev/templates/test-performance.bat.tpl",
        "dev/templates/test-everything.bat.tpl","doc/archive-sweep.md","doc/performance-architecture.md",
        "dev/generate_product_family_tools.py","dev/generate_product_family_fixture.py","dev/product-family-tool-spec.json",
        "dev/library/product-family-builder.inc.ps1","dev/library/product-family-compact-builder.inc.ps1","dev/library/product-family-query.inc.ps1",
        "dev/templates/product-family-builder.bat.tpl","dev/templates/product-family-compact-builder.bat.tpl","dev/templates/product-family-query.bat.tpl",
        "test/test_product_family_tools.bat","doc/product-family-tools.md","doc/product-family-tool-matrix.tsv",
        "dev/generate_all_pipeline.py","dev/library/all-pipeline.inc.ps1","dev/library/database-validation.inc.ps1",
        "dev/templates/all-pipeline.bat.tpl","dev/templates/database-validation.bat.tpl","test/test_generated_databases.bat",
    )
    for rel in maintained:
        if not (ROOT/rel).is_file(): fail("missing maintained file: "+rel)

    print("PASS: archive sweep/quality/performance static validation")
    print("public tools: tools\\=478 (single=422 compare=19 archive=2 family=34 browser=1) + root apps=4 (gui=1 pipeline=1 maintenance=2)")
    print("fast executor: indexed + source-stable + adaptive CPU/memory/I/O/throughput workers + content cache")
    print("analysis: per-dump contributions, quality, re-ID, notes, exclusions, interactive HTML")
    print("supplied archive plan: 34,822 logical checks for 79 snapshots")
    print("fast-test plan: 1,306 logical checks for 3 snapshots")

if __name__=="__main__":
    main()
