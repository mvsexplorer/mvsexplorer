#!/usr/bin/env python3
"""Regenerate the synthetic complete single-dump test fixture.

Version: 0.2.0
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "test" / "test-mvs-dump-single-complete"
FIXTURE.mkdir(parents=True, exist_ok=True)

FILES = {
    'README.txt': 'MVS Explorer Toolkit synthetic single-dump completeness fixture\n\nThis dump is intentionally inconsistent.\n\nPositive cases include:\n- product ID/title -> filenames -> hashes;\n- filename/hash reverse traversal;\n- SHA-1 and SHA-256 records from multiple sources;\n- mvs_names.txt variant occurrence records, including an empty variant section;\n- repeated note headings with distinct note bodies;\n- duplicate hashes in mvs.txt, mvs_names.txt, mvs.sha1, and mvs.sha256;\n- hashes mapped to multiple filenames in both flat manifests;\n- filenames mapped to multiple hashes in mvs.txt and mvs_names.txt;\n- hash-set mismatch for alpha.iso between mvs.txt and mvs.sha1;\n- hash-set mismatch for alpha.iso between mvs.txt and mvs.sha256;\n- malformed lines in every source covered by the unparsed-line tools.\n\nPrimary test values:\n  ID: 10\n  Title: Alpha Product\n  Filename: alpha.iso\n  Hash: 3333333333333333333333333333333333333333\n  Variant ID: pAlpha10x64len\n  Variant filename: variant-alpha.iso\n  Variant hash: 6666666666666666666666666666666666666666\n\nVariant IDs are deliberately separate from product IDs and include both alphanumeric and hyphenated forms.\n',
    'TEST-VALUES.txt': 'id=10\ntitle=Alpha Product\nfilename=alpha.iso\nhash=3333333333333333333333333333333333333333\nvariant_id=pAlpha10x64len\nvariant_filename=variant-alpha.iso\nvariant_hash=6666666666666666666666666666666666666666\nnote_title=Alpha Product\n',
    'mvs.sha1': '3333333333333333333333333333333333333333 *alpha.iso\n8888888888888888888888888888888888888888 *manifest-one.iso\n8888888888888888888888888888888888888888 *manifest-two.iso\n4444444444444444444444444444444444444444 *shared.iso\nMALFORMED SHA1 LINE\n',
    'mvs.sha256': 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb *alpha.iso\ncccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc *manifest-one-256.iso\ncccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc *manifest-two-256.iso\nMALFORMED SHA256 LINE\n',
    'mvs.txt': '--- Alpha Product [ID: 10] ---\n1111111111111111111111111111111111111111 *alpha.iso\n2222222222222222222222222222222222222222 *alpha.iso\n1111111111111111111111111111111111111111 *alpha-copy.iso\naaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *alpha.iso\nBROKEN PRODUCT FILE LINE\n\n--- Beta Product [ID: 20] ---\n4444444444444444444444444444444444444444 *shared.iso\n\n--- Gamma Product [ID: 30] ---\n5555555555555555555555555555555555555555 *gamma.iso\n',
    'mvs_dates.txt': '2020-01-10T00:00:00Z - Alpha Product [ID: 10]\n2020-02-20T00:00:00Z - Beta Product [ID: 20]\n2020-03-30T00:00:00Z - Gamma Product [ID: 30]\nBROKEN DATE ROW\n',
    'mvs_ids.txt': 'Alpha Product [ID: 10]\nBeta Product [ID: 20]\nGamma Product [ID: 30]\nTHIS IS NOT A VALID ID ROW\n',
    'mvs_names.txt': '--- Alpha Variant One [ID: pAlpha10x64len] ---\n6666666666666666666666666666666666666666 *variant-alpha.iso\n7777777777777777777777777777777777777777 *variant-alpha.iso\n6666666666666666666666666666666666666666 *variant-alpha-copy.iso\ndddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd *variant-alpha.iso\nBROKEN VARIANT FILE LINE\n\n--- Alpha Variant Empty [ID: v-empty-10] ---\n\n--- Beta Variant [ID: F77120Ax64Lcn] ---\n4444444444444444444444444444444444444444 *shared.iso\n\n--- Gamma Variant [ID: vGamma30] ---\n5555555555555555555555555555555555555555 *gamma.iso\n',
    'mvs_notes.html': '<h1>Alpha Product</h1><p>Alpha note one.</p>\n<h1>Alpha Product</h1><p>Alpha note two.</p>\n<h1>Beta Product</h1><p>Beta note.</p>\n<h1>Gamma Product</h1><p>Gamma note.</p>\n',
}

def main():
    for name, content in FILES.items():
        (FIXTURE / name).write_text(content, encoding="utf-8", newline="\n")
    print(f"Regenerated {len(FILES)} single-dump fixture files in {FIXTURE}")

if __name__ == "__main__":
    main()
