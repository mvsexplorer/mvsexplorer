#!/usr/bin/env python3
"""Regenerate the synthetic filename/hash relationship test dump.

Version: 0.1.0
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "test" / "test-mvs-dump-relationships"
FIXTURE.mkdir(parents=True, exist_ok=True)

FILES = {
    'mvs_ids.txt': 'Alpha Product [ID: 10]\nBeta Product [ID: 20]\nGamma Product [ID: 30]\n',
    'mvs_dates.txt': '2020-01-10T00:00:00 - Alpha Product [ID: 10]\n2020-02-20T00:00:00 - Beta Product [ID: 20]\n2020-03-30T00:00:00 - Gamma Product [ID: 30]\n',
    'mvs.txt': '--- Alpha Product [ID: 10] ---\n1234512345123451234512345123451234512345 *alpha-main.iso\n9876598765987659876598765987659876598765 *alpha-extra.iso\n\n--- Beta Product [ID: 20] ---\n3333333333333333333333333333333333333333 *shared.iso\n\n--- Gamma Product [ID: 30] ---\nfedcbafedcbafedcbafedcbafedcbafedcbafedc *shared.iso\n',
    'mvs_notes.html': '<h1>Alpha Product</h1><p>Alpha note.</p>\n<h1>Beta Product</h1><p>Beta note.</p>\n<h1>Gamma Product</h1><p>Gamma note.</p>\n',
    'mvs.sha1': 'abcdefabcdefabcdefabcdefabcdefabcdefabcd *shared.iso\naaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *manifest-only.iso\n',
    'mvs.sha256': 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789 *shared.iso\nbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb *manifest-only-256.iso\n',
    'README.txt': 'MVS Explorer Toolkit synthetic relationship test dump\n\nThis fixture intentionally contains relationship ambiguity and cross-source\nhash mappings.\n\nPrimary filename test:\n  Search input: SHARED.ISO\n  Canonical filename: shared.iso\n  Owners: Beta Product [ID: 20], Gamma Product [ID: 30]\n\nPrimary SHA-1 test:\n  abcdefabcdefabcdefabcdefabcdefabcdefabcd\n  Exists only in mvs.sha1 and maps to shared.iso.\n\nPrimary SHA-256 test:\n  abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789\n  Exists only in mvs.sha256 and maps to shared.iso.\n\nmvs.txt-only hash test:\n  1234512345123451234512345123451234512345\n  Exists only on the alpha-main.iso line in mvs.txt.\n\nManifest-only orphan filenames are also present so future tests can exercise\nhash-to-filename rows that have no mvs.txt product owner.\n\nThis fixture is intentionally synthetic and inconsistent; it is not catalog\nreference data.\n',
    'TEST-VALUES.txt': 'filename=SHARED.ISO\nsha1=ABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCD\nsha256=ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789\nmvs_txt_hash=1234512345123451234512345123451234512345\n',
}

def main():
    for name, content in FILES.items():
        (FIXTURE / name).write_text(content, encoding="utf-8", newline="\n")
    print(f"Regenerated {len(FILES)} relationship fixture files in {FIXTURE}")

if __name__ == "__main__":
    main()
