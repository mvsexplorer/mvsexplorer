#!/usr/bin/env python3
"""Regenerate the synthetic product-family test archive.

Version: 0.1.0
"""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "test" / "test-mvs-product-family"

FILES = {
    'family-overrides.tsv': 'product_title\taction\tbroad_family\tproduct_family\trelease\tspecific_release_family\tbroad_release_family\tconfidence\treason\nContoso Office Add-in 1.0\tset\tMicrosoft Office\tMicrosoft Office Add-ins\t1.0\tMicrosoft Office Add-ins 1.0\t\toverride\ttest fixture exact-title taxonomy decision\n',
    'mvs_2020-01-01/mvs.txt': '--- Microsoft Office Communications Server 2007 Standard Edition (English) [ID: 101] ---\n1111111111111111111111111111111111111111 *ocs2007-standard.iso\naaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *ocs2007-standard.iso\n\n--- Office 2007 Proofing Tools (x86) - DVD (English) [ID: 102] ---\n2222222222222222222222222222222222222222 *office2007-proofing.iso\n\n--- Microsoft Office System Developer Kit 3.0 (English) [ID: 103] ---\n3333333333333333333333333333333333333333 *office-sdk-3.iso\n\n--- Contoso Security for Microsoft Office Communications Server 2007 [ID: 104] ---\n4444444444444444444444444444444444444444 *contoso-security.iso\n\n--- Microsoft Mystery Suite 1.0 [ID: 105] ---\n5555555555555555555555555555555555555555 *mystery-suite.iso\n',
    'mvs_2020-01-01/mvs_dates.txt': '2007-10-01T00:00:00Z - Microsoft Office Communications Server 2007 Standard Edition (English) [ID: 101]\n2007-11-01T00:00:00Z - Office 2007 Proofing Tools (x86) - DVD (English) [ID: 102]\n2006-05-01T00:00:00Z - Microsoft Office System Developer Kit 3.0 (English) [ID: 103]\n2008-01-01T00:00:00Z - Contoso Security for Microsoft Office Communications Server 2007 [ID: 104]\n2010-01-01T00:00:00Z - Microsoft Mystery Suite 1.0 [ID: 105]\n',
    'mvs_2020-01-01/mvs_ids.txt': 'Microsoft Office Communications Server 2007 Standard Edition (English) [ID: 101]\nOffice 2007 Proofing Tools (x86) - DVD (English) [ID: 102]\nMicrosoft Office System Developer Kit 3.0 (English) [ID: 103]\nContoso Security for Microsoft Office Communications Server 2007 [ID: 104]\nMicrosoft Mystery Suite 1.0 [ID: 105]\n',
    'mvs_2020-01-01/mvs_notes.html': '<h3>Microsoft Office Communications Server 2007 Standard Edition (English) [ID: 101]</h3>\n<p>OCS standard note.</p>\n<h3>Office 2007 Proofing Tools (x86) - DVD (English) [ID: 102]</h3>\n<p>Proofing tools note.</p>\n<h3>Microsoft Office System Developer Kit 3.0 (English) [ID: 103]</h3>\n<p>Office SDK note.</p>\n<h3>Microsoft Mystery Suite 1.0 [ID: 105]</h3>\n<p>Review this generic Microsoft family.</p>\n',
    'mvs_2020-01-02/mvs_dmp/mvs.txt': '--- Microsoft Office Communications Server 2007 Enterprise Edition (English) [ID: 201] ---\n6666666666666666666666666666666666666666 *ocs2007-enterprise.iso\nbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb *ocs2007-enterprise.iso\n\n--- Office 2007 Proofing Tools (x86) - DVD (English) [ID: 202] ---\n2222222222222222222222222222222222222222 *office2007-proofing.iso\n\n--- Microsoft SQL Server 2008 Standard Edition (English) [ID: 203] ---\n7777777777777777777777777777777777777777 *sql2008-standard.iso\n\n--- Microsoft Office Professional Plus 2007 (English) [ID: 204] ---\n8888888888888888888888888888888888888888 *office2007-proplus.iso\n',
    'mvs_2020-01-02/mvs_dmp/mvs_dates.txt': '2007-10-15T00:00:00Z - Microsoft Office Communications Server 2007 Enterprise Edition (English) [ID: 201]\n2007-11-01T00:00:00Z - Office 2007 Proofing Tools (x86) - DVD (English) [ID: 202]\n2008-08-01T00:00:00Z - Microsoft SQL Server 2008 Standard Edition (English) [ID: 203]\n2007-01-30T00:00:00Z - Microsoft Office Professional Plus 2007 (English) [ID: 204]\n',
    'mvs_2020-01-02/mvs_dmp/mvs_ids.txt': 'Microsoft Office Communications Server 2007 Enterprise Edition (English) [ID: 201]\nOffice 2007 Proofing Tools (x86) - DVD (English) [ID: 202]\nMicrosoft SQL Server 2008 Standard Edition (English) [ID: 203]\nMicrosoft Office Professional Plus 2007 (English) [ID: 204]\n',
    'mvs_2020-01-02/mvs_dmp/mvs_notes.html': '<h1>Microsoft Office Communications Server 2007 Enterprise Edition (English)</h1>\n<p>OCS enterprise note.</p>\n<h1>Microsoft SQL Server 2008 Standard Edition (English)</h1>\n<p>SQL Server note.</p>\n<h1>Microsoft Office Professional Plus 2007 (English)</h1>\n<p>Office ProPlus note.</p>\n',
    'mvs_2020-01-03_2/mvs.txt': '--- Microsoft Office Communications Server 2007 Standard Edition (English) [ID: 301] ---\n9999999999999999999999999999999999999999 *ocs2007-standard.iso\n\n--- Microsoft Office Professional Plus 2010 (English) [ID: 302] ---\naaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *office2010-proplus.iso\n\n--- FabriKam 3.1: The Microsoft Office System Solutions Learning Kit [ID: 303] ---\nbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb *fabrikam-learning.iso\n\n--- Contoso Office Add-in 1.0 [ID: 304] ---\ncccccccccccccccccccccccccccccccccccccccc *contoso-office-addin.iso\n\n--- SQL Server 2019 Standard Edition (English) [ID: 305] ---\ndddddddddddddddddddddddddddddddddddddddd *sql2019-standard.iso\n\n--- Windows Server 2019 Standard (English) [ID: 306] ---\neeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee *windows-server-2019.iso\n\n--- Agents for Visual Studio 2012 (English) [ID: 307] ---\nffffffffffffffffffffffffffffffffffffffff *vs2012-agents.iso\n\n--- Office Online Server 2019 (English) [ID: 308] ---\n1212121212121212121212121212121212121212 *office-online-2019.iso\n',
    'mvs_2020-01-03_2/mvs_dates.txt': '2007-10-01T00:00:00Z - Microsoft Office Communications Server 2007 Standard Edition (English) [ID: 301]\n2010-06-01T00:00:00Z - Microsoft Office Professional Plus 2010 (English) [ID: 302]\n2011-01-01T00:00:00Z - FabriKam 3.1: The Microsoft Office System Solutions Learning Kit [ID: 303]\n2012-01-01T00:00:00Z - Contoso Office Add-in 1.0 [ID: 304]\n2019-01-01T00:00:00Z - SQL Server 2019 Standard Edition (English) [ID: 305]\n2019-02-01T00:00:00Z - Windows Server 2019 Standard (English) [ID: 306]\n2012-03-01T00:00:00Z - Agents for Visual Studio 2012 (English) [ID: 307]\n2019-04-01T00:00:00Z - Office Online Server 2019 (English) [ID: 308]\n',
    'mvs_2020-01-03_2/mvs_ids.txt': 'Microsoft Office Communications Server 2007 Standard Edition (English) [ID: 301]\nMicrosoft Office Professional Plus 2010 (English) [ID: 302]\nFabriKam 3.1: The Microsoft Office System Solutions Learning Kit [ID: 303]\nContoso Office Add-in 1.0 [ID: 304]\nSQL Server 2019 Standard Edition (English) [ID: 305]\nWindows Server 2019 Standard (English) [ID: 306]\nAgents for Visual Studio 2012 (English) [ID: 307]\nOffice Online Server 2019 (English) [ID: 308]\n',
    'mvs_2020-01-03_2/mvs_notes.html': '<h1>Microsoft Office Professional Plus 2010 (English)</h1>\n<p>Office 2010 note.</p>\n<h1>FabriKam 3.1: The Microsoft Office System Solutions Learning Kit</h1>\n<p>This merely references Microsoft Office in the title.</p>\n<h1>Contoso Office Add-in 1.0</h1>\n<p>Curated by an exact-title override.</p>\n',
}

def main():
    if FIXTURE.exists():
        shutil.rmtree(FIXTURE)
    for relative, text in FILES.items():
        path = FIXTURE / Path(relative)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

if __name__ == "__main__":
    main()
