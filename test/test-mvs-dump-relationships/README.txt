MVS Explorer Toolkit synthetic relationship test dump

This fixture intentionally contains relationship ambiguity and cross-source
hash mappings.

Primary filename test:
  Search input: SHARED.ISO
  Canonical filename: shared.iso
  Owners: Beta Product [ID: 20], Gamma Product [ID: 30]

Primary SHA-1 test:
  abcdefabcdefabcdefabcdefabcdefabcdefabcd
  Exists only in mvs.sha1 and maps to shared.iso.

Primary SHA-256 test:
  abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789
  Exists only in mvs.sha256 and maps to shared.iso.

mvs.txt-only hash test:
  1234512345123451234512345123451234512345
  Exists only on the alpha-main.iso line in mvs.txt.

Manifest-only orphan filenames are also present so future tests can exercise
hash-to-filename rows that have no mvs.txt product owner.

This fixture is intentionally synthetic and inconsistent; it is not catalog
reference data.
