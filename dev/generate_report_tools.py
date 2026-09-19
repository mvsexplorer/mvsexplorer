#!/usr/bin/env python3
"""Generate archive HTML report helper.

Version: 0.1.0
"""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEV=ROOT/"dev"
def read(p): return p.read_text(encoding="utf-8").replace("\r\n","\n").rstrip()
def write_bat(p,t): p.write_bytes((t.rstrip()+"\n").replace("\n","\r\n").encode("utf-8"))
def main():
    t=read(DEV/"templates"/"archive-report.bat.tpl")
    vals={
        "TOOL_VERSION":"0.1.0",
        "BATCH_COMMON":read(DEV/"library"/"batch-common.inc.bat"),
        "ARCHIVE_REPORT_POWERSHELL":read(DEV/"library"/"archive-report.inc.ps1"),
    }
    for k,v in vals.items(): t=t.replace("@@"+k+"@@",v)
    if "@@" in t: raise ValueError("Unresolved archive-report template marker")
    write_bat(ROOT/"test"/"build_archive_html_report.bat",t)
if __name__=="__main__": main()
