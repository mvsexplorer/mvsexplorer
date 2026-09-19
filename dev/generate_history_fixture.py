#!/usr/bin/env python3
"""Generate the synthetic archive-history regression fixture.

Version: 0.2.0
"""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "test" / "test-mvs-dump-history"

SNAPS = {
"mvs_2020-01-01": {
"mvs_ids.txt": """Alpha Product [ID: 1]
Keep Product [ID: 2]
""",
"mvs_dates.txt": """2020-01-01T00:00:00Z - Alpha Product [ID: 1]
2020-01-02T00:00:00Z - Keep Product [ID: 2]
""",
"mvs.txt": """--- Alpha Product [ID: 1] ---
1111111111111111111111111111111111111111 *alpha.iso
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *alpha.iso

--- Keep Product [ID: 2] ---
2222222222222222222222222222222222222222 *keep.iso
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb *keep.iso
""",
"mvs_names.txt": """--- Alpha Variant [ID: VarAlpha] ---
3333333333333333333333333333333333333333 *variant-alpha.iso
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc *variant-alpha.iso

--- Keep Variant [ID: VarKeep] ---
4444444444444444444444444444444444444444 *variant-keep.iso
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd *variant-keep.iso
""",
"mvs_notes.html": """<h3>Alpha Product [ID: 1]</h3>
<p>Alpha note v1</p>
<h3>Keep Product [ID: 2]</h3>
<p>Keep note</p>
""",
"mvs.sha1": """5555555555555555555555555555555555555555 *manifest-alpha.iso
6666666666666666666666666666666666666666 *manifest-keep.iso
""",
"mvs.sha256": """eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee *manifest-alpha-256.iso
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff *manifest-keep-256.iso
""",
},
"mvs_2020-01-02": {
"mvs_ids.txt": """Keep Product [ID: 002]
Beta Product [ID: 3]
""",
"mvs_dates.txt": """2020-01-02T00:00:00Z - Keep Product [ID: 002]
2020-01-03T00:00:00Z - Beta Product [ID: 3]
""",
"mvs.txt": """--- Keep   Product [ID: 002] ---
2222222222222222222222222222222222222222 *KEEP.ISO
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb *KEEP.ISO

--- Beta Product [ID: 3] ---
7777777777777777777777777777777777777777 *beta.iso
1111111111111111111111111111111111111111111111111111111111111111 *beta.iso
""",
"mvs_names.txt": """--- Keep Variant [ID: varkeep] ---
4444444444444444444444444444444444444444 *VARIANT-KEEP.ISO
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd *VARIANT-KEEP.ISO

--- Beta Variant [ID: VarBeta] ---
8888888888888888888888888888888888888888 *variant-beta.iso
2222222222222222222222222222222222222222222222222222222222222222 *variant-beta.iso
""",
"mvs_notes.html": """<h3>Keep Product [ID: 002]</h3>
<p>Keep note</p>
<h3>Beta Product [ID: 3]</h3>
<p>Beta one-off note</p>
""",
"mvs.sha1": """6666666666666666666666666666666666666666 *MANIFEST-KEEP.ISO
9999999999999999999999999999999999999999 *manifest-beta.iso
""",
"mvs.sha256": """ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff *MANIFEST-KEEP-256.ISO
3333333333333333333333333333333333333333333333333333333333333333 *manifest-beta-256.iso
""",
},
"mvs_2020-01-03_2": {
"mvs_ids.txt": """Alpha Product [ID: 1]
Keep Product [ID: 2]
Gamma Product [ID: 4]
""",
"mvs_dates.txt": """2020-01-01T00:00:00Z - Alpha Product [ID: 1]
2020-01-02T00:00:00Z - Keep Product [ID: 2]
2020-01-04T00:00:00Z - Gamma Product [ID: 4]
""",
"mvs.txt": """--- Alpha Product [ID: 1] ---
1111111111111111111111111111111111111111 *alpha.iso
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *alpha.iso

--- Keep Product [ID: 2] ---
2222222222222222222222222222222222222222 *keep.iso
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb *keep.iso

--- Gamma Product [ID: 4] ---
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *gamma.iso
4444444444444444444444444444444444444444444444444444444444444444 *gamma.iso
""",
"mvs_names.txt": """--- Alpha Variant [ID: VarAlpha] ---
3333333333333333333333333333333333333333 *variant-alpha.iso
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc *variant-alpha.iso

--- Keep Variant [ID: VarKeep] ---
4444444444444444444444444444444444444444 *variant-keep.iso
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd *variant-keep.iso

--- Gamma Variant [ID: VarGamma] ---
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb *variant-gamma.iso
5555555555555555555555555555555555555555555555555555555555555555 *variant-gamma.iso
""",
"mvs_notes.html": """<h1>Alpha Product</h1>
<p>Alpha note v2</p>
<h1>Keep Product</h1>
<p>Keep note</p>
<h1>Gamma Product</h1>
<p>Gamma note</p>
""",
"mvs.sha1": """5555555555555555555555555555555555555555 *manifest-alpha.iso
6666666666666666666666666666666666666666 *manifest-keep.iso
cccccccccccccccccccccccccccccccccccccccc *manifest-gamma.iso
""",
"mvs.sha256": """eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee *manifest-alpha-256.iso
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff *manifest-keep-256.iso
6666666666666666666666666666666666666666666666666666666666666666 *manifest-gamma-256.iso
""",
}
}

def main():
    if FIXTURE.exists():
        shutil.rmtree(FIXTURE)
    FIXTURE.mkdir(parents=True)
    for snap, files in SNAPS.items():
        folder = FIXTURE / snap
        folder.mkdir()
        source_folder = folder / "mvs_dmp" if snap == "mvs_2020-01-02" else folder
        source_folder.mkdir(exist_ok=True)
        for name, content in files.items():
            (source_folder / name).write_text(content, encoding="utf-8", newline="\n")
    (FIXTURE / "README.txt").write_text(
        "Synthetic three-snapshot archive for change-history/all-ever tests.\n"
        "Snapshot 2 uses the nested mvs_dmp layout, removes Alpha, and adds Beta;\n"
        "snapshot 3 restores Alpha, removes Beta, and adds Gamma. Keep values vary spelling,\n"
        "case, whitespace, and numeric ID zero-padding to exercise normalization. Notes exercise legacy h3+ID and newer h1 headings.\n",
        encoding="utf-8", newline="\n"
    )

if __name__ == "__main__":
    main()
