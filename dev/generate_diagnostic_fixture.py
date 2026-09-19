#!/usr/bin/env python3
"""Regenerate the synthetic diagnostic MVS dump source files.

Version: 0.1.0

Expected diagnostic stdout files are intentionally maintained as fixed
regression artifacts under test/expected-diagnostics and are refreshed
only when the documented diagnostic output contract changes.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "test" / "test-mvs-dump-diagnostics"
FIXTURE.mkdir(parents=True, exist_ok=True)

FILES = {
    'mvs_ids.txt': 'Common One [ID: 1]\nCommon Two [ID: 2]\nIDs Only [ID: 101]\nDuplicate ID First [ID: 201]\nDuplicate ID Second [ID: 201]\nIDs Duplicate Title [ID: 202]\nIDs Duplicate Title [ID: 203]\n',
    'mvs_dates.txt': '2004-06-01T16:55:00 - Common One [ID: 1]\n2005-06-01T16:55:00 - Common Two [ID: 2]\n2010-01-01T00:00:00 - Dates Only [ID: 102]\n2011-01-01T00:00:00 - Dates Duplicate ID A [ID: 301]\n2012-01-01T00:00:00 - Dates Duplicate ID B [ID: 301]\n2013-01-01T00:00:00 - Dates Duplicate Title [ID: 302]\n2014-01-01T00:00:00 - Dates Duplicate Title [ID: 303]\n2020-01-01T00:00:00 - Dates Duplicate Date A [ID: 304]\n2020-01-01T00:00:00 - Dates Duplicate Date B [ID: 305]\n',
    'mvs.txt': '--- Common One [ID: 1] ---\n1111111111111111111111111111111111111111 *common-one.iso\n\n--- Common Two [ID: 2] ---\n2222222222222222222222222222222222222222 *common-two.iso\n\n--- TXT Only [ID: 103] ---\n3333333333333333333333333333333333333333 *txt-only.iso\n\n--- TXT Duplicate ID A [ID: 401] ---\n4444444444444444444444444444444444444444 *txt-dup-id-a.iso\n4444444444444444444444444444444444444445 *txt-dup-id-a-extra.iso\n\n--- TXT Duplicate ID B [ID: 401] ---\n5555555555555555555555555555555555555555 *txt-dup-id-b.iso\n\n--- TXT Duplicate Title [ID: 402] ---\n6666666666666666666666666666666666666666 *txt-dup-title-a.iso\n\n--- TXT Duplicate Title [ID: 403] ---\n7777777777777777777777777777777777777777 *txt-dup-title-b.iso\n\n--- TXT Filename Owner A [ID: 404] ---\n8888888888888888888888888888888888888888 *txt-duplicate-filename.iso\n\n--- TXT Filename Owner B [ID: 405] ---\n9999999999999999999999999999999999999999 *txt-duplicate-filename.iso\n',
    'mvs_names.txt': '--- Common One Variant [ID: 1] ---\naaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *common-one.iso\n\n--- Common Two Variant [ID: 2] ---\nbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb *common-two.iso\n\n--- Names Only [ID: 104] ---\ncccccccccccccccccccccccccccccccccccccccc *names-only.iso\n\n--- Names Duplicate ID A [ID: 501] ---\ndddddddddddddddddddddddddddddddddddddddd *names-dup-id-a.iso\nddddddddddddddddddddddddddddddddddddddde *names-dup-id-a-extra.iso\n\n--- Names Duplicate ID B [ID: 501] ---\neeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee *names-dup-id-b.iso\n\n--- Names Duplicate Title [ID: 502] ---\nffffffffffffffffffffffffffffffffffffffff *names-dup-title-a.iso\n\n--- Names Duplicate Title [ID: 503] ---\n0123456789012345678901234567890123456789 *names-dup-title-b.iso\n\n--- Names Filename Owner A [ID: 504] ---\n1123456789012345678901234567890123456789 *names-duplicate-filename.iso\n\n--- Names Filename Owner B [ID: 505] ---\n2123456789012345678901234567890123456789 *names-duplicate-filename.iso\n',
    'mvs_notes.html': '<h1>Common One</h1><p>Common one note.</p>\n<h1>Common Two</h1><p>Common two note.</p>\n<h1>Note Duplicate</h1><p>First duplicate note.</p>\n<h1>Note Duplicate</h1><p>Second duplicate note.</p>\n<h1>Legacy Note A [ID: 601]</h1><p>Legacy note A.</p>\n<h1>Legacy Note B [ID: 601]</h1><p>Legacy note B.</p>\n',
    'mvs.sha1': '1111111111111111111111111111111111111111 *common-one.iso\n2222222222222222222222222222222222222222 *common-two.iso\n',
    'mvs.sha256': '1111111111111111111111111111111111111111111111111111111111111111 *common-one.iso\n2222222222222222222222222222222222222222222222222222222222222222 *common-two.iso\n',
    'README.txt': 'MVS Explorer Toolkit synthetic diagnostic test dump\n\nPurpose:\n  This is intentionally inconsistent data. It exists to make duplicate and\n  orphan finders produce known positive findings.\n\nDesigned cases:\n  - duplicate IDs in mvs_ids.txt, mvs_dates.txt, mvs.txt, mvs_names.txt;\n  - literal duplicate [ID] markers in mvs_notes.html for the requested\n    notes-ID diagnostic, even though normal archive notes do not use IDs;\n  - duplicate titles in all title-bearing sources;\n  - duplicate date in mvs_dates.txt;\n  - duplicate filenames in mvs.txt and mvs_names.txt;\n  - source-exclusive IDs/titles in each main text source, creating\n    directional orphan cases;\n  - source-exclusive filenames and intentionally sparse SHA manifests,\n    creating filename-orphan cases.\n\nDo not treat this folder as representative catalog data. It is a test fixture.\n',
    'EXPECTED-FINDINGS.txt': 'Every diagnostic tool in dev\\diagnostic-tool-spec.json is expected to emit at least one finding for this fixture.\nExact expected stdout is stored in test\\expected-diagnostics\\.\n',
}

def main():
    for name, content in FILES.items():
        (FIXTURE / name).write_text(content, encoding="utf-8", newline="\n")
    print(f"Regenerated {len(FILES)} diagnostic fixture files in {FIXTURE}")

if __name__ == "__main__":
    main()
