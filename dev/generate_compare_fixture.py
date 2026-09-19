#!/usr/bin/env python3
"""Generate the synthetic before/after dump pair for comparison tests.

Version: 0.1.0
"""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "test" / "test-mvs-dump-compare"

BEFORE = {
    "mvs_ids.txt": """Alpha Product [ID: 10]
Removed IDs Product [ID: 20]
Stable Product [ID: 30]
""",
    "mvs_dates.txt": """2020-01-10T00:00:00Z - Alpha Date Product [ID: 10]
2020-02-20T00:00:00Z - Removed Date Product [ID: 20]
2020-03-30T00:00:00Z - Stable Date Product [ID: 30]
""",
    "mvs.txt": """--- Alpha TXT Product [ID: 10] ---
1111111111111111111111111111111111111111 *alpha-common.iso
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *alpha-common.iso

--- Removed TXT Product [ID: 20] ---
2222222222222222222222222222222222222222 *removed-txt.iso
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb *removed-txt.iso

--- Stable TXT Product [ID: 30] ---
3333333333333333333333333333333333333333 *stable-txt.iso
""",
    "mvs_names.txt": """--- Alpha Variant [ID: common-id] ---
1111111111111111111111111111111111111111 *variant-common.iso
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *variant-common.iso

--- Removed Variant [ID: old-variant-id] ---
6666666666666666666666666666666666666666 *removed-variant.iso
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd *removed-variant.iso

--- Stable Variant [ID: stable-id] ---
7777777777777777777777777777777777777777 *stable-variant.iso
""",
    "mvs.sha1": """8888888888888888888888888888888888888888 *manifest-common.iso
9999999999999999999999999999999999999999 *manifest-removed.iso
""",
    "mvs.sha256": """eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee *manifest-common-256.iso
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff *manifest-removed-256.iso
""",
}

AFTER = {
    "mvs_ids.txt": """Alpha Product [ID: 10]
Added IDs Product [ID: 40]
Stable Product [ID: 30]
""",
    "mvs_dates.txt": """2020-01-10T00:00:00Z - Alpha Date Product [ID: 10]
2020-04-20T00:00:00Z - Added Date Product [ID: 40]
2020-03-30T00:00:00Z - Stable Date Product [ID: 30]
""",
    "mvs.txt": """--- Alpha TXT Product [ID: 10] ---
1111111111111111111111111111111111111111 *alpha-common.iso
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *alpha-common.iso

--- Added TXT Product [ID: 40] ---
4444444444444444444444444444444444444444 *added-txt.iso
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc *added-txt.iso

--- Stable TXT Product [ID: 30] ---
3333333333333333333333333333333333333333 *stable-txt.iso
""",
    "mvs_names.txt": """--- Alpha Variant [ID: common-id] ---
1111111111111111111111111111111111111111 *variant-common.iso
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *variant-common.iso

--- Added Variant [ID: new-variant-id] ---
5555555555555555555555555555555555555555 *added-variant.iso
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb *added-variant.iso

--- Stable Variant [ID: stable-id] ---
7777777777777777777777777777777777777777 *stable-variant.iso
""",
    "mvs.sha1": """8888888888888888888888888888888888888888 *manifest-common.iso
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *manifest-added.iso
""",
    "mvs.sha256": """eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee *manifest-common-256.iso
abababababababababababababababababababababababababababababababab *manifest-added-256.iso
""",
}

README = """MVS Explorer Toolkit two-dump comparison fixture

before\\ contains values that are intentionally removed in after\\.
after\\ contains values that are intentionally added relative to before\\.
Every comparison tool has at least one removal and one addition.
Shared values remain in both snapshots so tests also verify set membership.
"""

def write_tree(folder, files):
    folder.mkdir(parents=True, exist_ok=True)
    for name, text in files.items():
        (folder / name).write_text(text, encoding="utf-8", newline="\n")

def main():
    if FIXTURE.exists():
        shutil.rmtree(FIXTURE)
    FIXTURE.mkdir(parents=True)
    write_tree(FIXTURE / "before", BEFORE)
    write_tree(FIXTURE / "after", AFTER)
    (FIXTURE / "README.txt").write_text(README, encoding="utf-8", newline="\n")

if __name__ == "__main__":
    main()
