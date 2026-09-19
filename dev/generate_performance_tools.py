#!/usr/bin/env python3
"""Generate archive-sweep high-performance workers and analyzer.

Version: 0.1.2
"""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEV=ROOT/"dev"
def read(p): return p.read_text(encoding="utf-8").replace("\r\n","\n").rstrip()
def write_bat(p,text): p.write_bytes((text.rstrip()+"\n").replace("\n","\r\n").encode("utf-8"))
def inject(template,values):
    text=template
    for k,v in values.items(): text=text.replace("@@"+k+"@@",v)
    if "@@" in text: raise ValueError("Unresolved template marker")
    return text
def main():
    common=read(DEV/"library"/"batch-common.inc.bat")
    fast=read(DEV/"library"/"fast-sweep.inc.ps1")
    ftpl=read(DEV/"templates"/"fast-sweep.bat.tpl")
    out=ROOT/"test"/"fast";out.mkdir(parents=True,exist_ok=True)
    configs={
      "snapshot": 'set "mvsf_first_data=%~1"\nset "mvsf_second_data="\nset "mvsf_plan=%~2"\nset "mvsf_output=%~3"',
      "compare": 'set "mvsf_first_data=%~1"\nset "mvsf_second_data=%~2"\nset "mvsf_plan=%~3"\nset "mvsf_output=%~4"',
    }
    for mode,args in configs.items():
        write_bat(out/f"run_{mode}_tools_fast.bat",inject(ftpl,{
          "VERSION":"0.1.1","MODE":mode,"ARGS":args,"BATCH_COMMON":common,"FAST_POWERSHELL":fast}))
    perf=read(DEV/"library"/"archive-performance.inc.ps1")
    ptpl=read(DEV/"templates"/"performance-analyzer.bat.tpl")
    write_bat(ROOT/"test"/"analyze_archive_sweep_performance.bat",inject(ptpl,{
      "VERSION":"0.1.0","BATCH_COMMON":common,"PERFORMANCE_POWERSHELL":perf}))
    fast_test=read(DEV/"templates"/"fast-archive-test.bat.tpl")
    write_bat(ROOT/"test"/"test_fast_archive_sweep.bat",fast_test)
if __name__=="__main__": main()
