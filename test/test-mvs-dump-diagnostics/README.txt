MVS Explorer Toolkit synthetic diagnostic test dump

Purpose:
  This is intentionally inconsistent data. It exists to make duplicate and
  orphan finders produce known positive findings.

Designed cases:
  - duplicate IDs in mvs_ids.txt, mvs_dates.txt, mvs.txt, mvs_names.txt;
  - literal duplicate [ID] markers in mvs_notes.html for the requested
    notes-ID diagnostic, even though normal archive notes do not use IDs;
  - duplicate titles in all title-bearing sources;
  - duplicate date in mvs_dates.txt;
  - duplicate filenames in mvs.txt and mvs_names.txt;
  - source-exclusive IDs/titles in each main text source, creating
    directional orphan cases;
  - source-exclusive filenames and intentionally sparse SHA manifests,
    creating filename-orphan cases.

Do not treat this folder as representative catalog data. It is a test fixture.
