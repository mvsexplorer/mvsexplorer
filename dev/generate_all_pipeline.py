#!/usr/bin/env python3
"""Generate the one-command full validation/database pipeline.

Version: 1.0.7
"""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DEV=ROOT/"dev"
PROJECT_VERSION="0.19.1"

def read(path):
    return path.read_text(encoding="utf-8").replace("\r\n","\n").rstrip()

def write_bat(path,text):
    path.write_bytes((text.rstrip()+"\n").replace("\n","\r\n").encode("utf-8"))

def main():
    text=read(DEV/"templates"/"all-pipeline.bat.tpl")
    values={
        "PROJECT_VERSION":PROJECT_VERSION,
        "BATCH_COMMON":read(DEV/"library"/"batch-common.inc.bat"),
        "PIPELINE_POWERSHELL":read(DEV/"library"/"all-pipeline.inc.ps1"),
    }
    for key,value in values.items():
        text=text.replace("@@"+key+"@@",value)
    if "@@" in text:
        raise ValueError("Unresolved all-pipeline template marker")
    write_bat(ROOT/"all_test_then_all_database_then_test_database_and_all_tools.bat",text)

    text=read(DEV/"templates"/"database-validation.bat.tpl")
    values={
        "BATCH_COMMON":read(DEV/"library"/"batch-common.inc.bat"),
        "DATABASE_VALIDATION_POWERSHELL":read(DEV/"library"/"database-validation.inc.ps1"),
    }
    for key,value in values.items():
        text=text.replace("@@"+key+"@@",value)
    if "@@" in text:
        raise ValueError("Unresolved database-validation template marker")
    write_bat(ROOT/"test"/"test_generated_databases.bat",text)

if __name__=="__main__":
    main()
