#!/usr/bin/env python3
"""Generate archive quality/performance helper tools.

Version: 0.2.3
"""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; DEV=ROOT/"dev"
def read(p): return p.read_text(encoding="utf-8").replace("\r\n","\n").rstrip()
def write_bat(p,t): p.write_bytes((t.rstrip()+"\n").replace("\n","\r\n").encode("utf-8"))
def inject(t,vals):
    for k,v in vals.items(): t=t.replace("@@"+k+"@@",v)
    if "@@" in t: raise ValueError("Unresolved template marker")
    return t
def main():
    common=read(DEV/"library"/"batch-common.inc.bat")
    write_bat(ROOT/"test"/"check_archive_sweep_quality.bat",inject(read(DEV/"templates"/"archive-quality.bat.tpl"),{
        "VERSION":"0.1.1","BATCH_COMMON":common,"QUALITY_POWERSHELL":read(DEV/"library"/"archive-quality.inc.ps1")}))
    write_bat(ROOT/"test"/"analyze_test_performance.bat",inject(read(DEV/"templates"/"test-performance.bat.tpl"),{
        "VERSION":"0.1.1","BATCH_COMMON":common,"TEST_PERFORMANCE_POWERSHELL":read(DEV/"library"/"test-performance.inc.ps1")}))
    write_bat(ROOT/"test"/"test_everything.bat",inject(read(DEV/"templates"/"test-everything.bat.tpl"),{
        "VERSION":"0.2.2","PROJECT_VERSION":"0.21.1","BATCH_COMMON":common,"TEST_EVERYTHING_POWERSHELL":read(DEV/"library"/"test-everything.inc.ps1")}))
if __name__=="__main__": main()
