#!/usr/bin/env python3
"""Generate the modular create/update database workflow and summary launcher.

Version: 0.2.0
"""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEV=ROOT/"dev"
OUT=ROOT/"create_or_update_mvs_database"
TOOL_VERSION="0.2.1"
PROJECT_VERSION="0.20.2"

def read(path):
    return path.read_text(encoding="utf-8").replace("\r\n","\n").rstrip()
def write_bat(path,text):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes((text.rstrip()+"\n").replace("\n","\r\n").encode("utf-8"))
def inject(template, values):
    text=template
    for key,value in values.items(): text=text.replace("@@"+key+"@@",value)
    if "@@" in text: raise ValueError("unresolved template marker")
    return text
def main():
    common=read(DEV/"library"/"database-maintenance-common.inc.ps1")
    batch=read(DEV/"library"/"batch-common.inc.bat")
    component_tpl=read(DEV/"templates"/"database-maintenance-component.bat.tpl")
    components=[
        ("01_discover_archives","database-maintenance-discover.inc.ps1",False),
        ("02_prepare_archive_update","database-maintenance-prepare.inc.ps1",True),
        ("03_run_archive_update","database-maintenance-run-archive.inc.ps1",True),
        ("04_rebuild_family_index","database-maintenance-family.inc.ps1",True),
        ("05_rebuild_compact_index","database-maintenance-compact.inc.ps1",True),
        ("06_validate_database","database-maintenance-validate.inc.ps1",True),
        ("07_create_html_browser","database-maintenance-html.inc.ps1",True),
        ("08_write_database_summary","database-maintenance-state.inc.ps1",True),
    ]
    for name,source,use_common in components:
        ps=(common+"\n\n" if use_common else "")+read(DEV/"library"/source)
        text=inject(component_tpl,{"TOOL_VERSION":TOOL_VERSION,"PROJECT_VERSION":PROJECT_VERSION,"APP_NAME":name,"BATCH_COMMON":batch,"POWERSHELL":ps})
        write_bat(OUT/(name+".bat"),text)
    launcher=inject(read(DEV/"templates"/"database-maintenance-launcher.bat.tpl"),{
        "TOOL_VERSION":TOOL_VERSION,"PROJECT_VERSION":PROJECT_VERSION,"BATCH_COMMON":batch,"POWERSHELL":read(DEV/"library"/"database-maintenance-launcher.inc.ps1")})
    write_bat(ROOT/"create_or_update_mvs_database.bat",launcher)
    display=inject(read(DEV/"templates"/"database-summary-display.bat.tpl"),{
        "TOOL_VERSION":TOOL_VERSION,"PROJECT_VERSION":PROJECT_VERSION,"BATCH_COMMON":batch,"POWERSHELL":read(DEV/"library"/"database-summary-display.inc.ps1")})
    write_bat(ROOT/"display_mvs_database_summary.bat",display)
if __name__=="__main__": main()
