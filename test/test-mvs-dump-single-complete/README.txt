MVS Explorer Toolkit synthetic single-dump completeness fixture

This dump is intentionally inconsistent.

Positive cases include:
- product ID/title -> filenames -> hashes;
- filename/hash reverse traversal;
- SHA-1 and SHA-256 records from multiple sources;
- mvs_names.txt variant occurrence records, including an empty variant section;
- repeated note headings with distinct note bodies;
- duplicate hashes in mvs.txt, mvs_names.txt, mvs.sha1, and mvs.sha256;
- hashes mapped to multiple filenames in both flat manifests;
- filenames mapped to multiple hashes in mvs.txt and mvs_names.txt;
- hash-set mismatch for alpha.iso between mvs.txt and mvs.sha1;
- hash-set mismatch for alpha.iso between mvs.txt and mvs.sha256;
- malformed lines in every source covered by the unparsed-line tools.

Primary test values:
  ID: 10
  Title: Alpha Product
  Filename: alpha.iso
  Hash: 3333333333333333333333333333333333333333
  Variant filename: variant-alpha.iso
  Variant hash: 6666666666666666666666666666666666666666
