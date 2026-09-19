# MVS Explorer Toolkit — Development Directives

These directives are distilled from the user's project prompts.

## Product direction

1. Build MVS Explorer Toolkit mainly from simple console-oriented `.bat` tools and helpers.
2. Use the tools to collect, search, transform, and display information from named MVS dump snapshots.
3. Evolve the toolkit toward a graphical application named **MVS Explorer**.

## Standalone delivery and shared development source

4. Every delivered public `.bat` must be fully standalone.
5. Common libraries and generation/injection scripts are allowed during development.
6. Common code must be injected into the resulting public `.bat`; the public tool must not require the library/generator at runtime.
7. Prefer generation to manual duplication when it reduces drift while preserving standalone delivery.

## Scalar model

8. Treat product ID as the primary scalar key when present.
9. Current scalar product fields are ID, title, release date, and note.
10. Notes are a documented title-level convenience join because `mvs_notes.html` lacks an ID-native note key.
11. Do not silently strengthen inferred relationships beyond what source files support.

## Scalar output families

12. Human-readable tools use `print_`.
13. Machine-readable tools use `read_`.
14. Preserve unsuffixed source-order scalar tools.
15. Every scalar `print_` and `read_` tool must also have:
    - `_sorted_by_id`
    - `_sorted_by_title`
    - `_sorted_by_date`
16. Sort ID numerically ascending.
17. Sort title naturally/alphanumerically ascending, case-insensitively, with numeric ID tie-break.
18. Sort date chronologically ascending where parseable with deterministic tie-breaks.
19. Do not create note-sorted scalar tools unless a later requirement establishes a useful purpose.
20. A sort field may control order even when it is not part of the printed/read projection.

## Lookup family

21. Lookup naming is `lookup_mvs_<target>_from_<source>.bat`.
22. Lookup arguments are `dump-folder search-value`.
23. Initial relationships:
    - TITLE from ID
    - TITLE from DATE
    - NOTE from ID
    - NOTE from TITLE
    - NOTE from DATE
    - DATE from ID
    - DATE from TITLE
24. Search values support `*` at the beginning, middle, and/or end.
25. `*` means zero or more characters.
26. Matching is case-insensitive.
27. All non-`*` characters are literal.
28. Multiple associated results must be printed.
29. Emit distinct non-empty target values, one per line.
30. Sort multiple matching rows by the natural order of the searched/source field.
31. No associated value emits no stdout and returns `1`.

## Output contracts

32. `print_`: human-oriented labeled rows.
33. `read_`: machine-oriented headerless TSV.
34. `lookup_`: raw associated values, one per line.
35. Machine/plain output must not contain ANSI, banners, progress, pauses, or explanatory text on stdout.
36. Errors go to stderr.

## Language and style

37. Follow the supplied Batch File Style Guide for `.bat`.
38. Use batch where practical.
39. Use embedded PowerShell when pure batch would be disproportionately awkward or fragile.
40. Apply the guide in spirit to PowerShell and development helper languages.
41. Maintain the project batch addendum and project embedded PowerShell guide.

## Documentation

42. Keep the supplied batch style guide in `doc\`.
43. Maintain a developer diary.
44. Maintain an observation journal.
45. Maintain project version history.
46. Maintain a tool-specific version history for every public and development tool.
47. Preserve all user project prompts in `development-prompts.md`.
48. Maintain these distilled development directives as requirements evolve.
49. Update style-guide documents as implementation reveals project-specific conventions.


## Automated testing

50. Maintain automated Windows batch tests under `test\`.
51. `test\test_all.bat dump-folder` is the root-level full-suite entry point.
52. Test batch files must be fully standalone after development-time injection.
53. The full suite must execute every public `.bat` tool.
54. Scalar tool tests compare exact stdout and return code against expectations derived from the selected dump.
55. Sorted tools must be tested for their documented numeric/natural/chronological ordering.
56. Lookup tests must cover exact, wildcard, no-match, and multiple-result behavior.
57. Test success returns `0`; any failed assertion returns nonzero.
58. Keep subset test entry points for structural, scalar, and lookup testing.


## Test result retention

59. Every automated test invocation creates one timestamped result directory beneath `test\`.
60. Result directory naming is `test-results-YYYYMMDD-HHMMSS`, with a collision suffix when necessary.
61. Preserve the complete harness console transcript in `console.log`.
62. Preserve machine-readable assertion results in `all-results.tsv` and scope-specific TSV files.
63. Preserve run path/platform/version information in `run-info.txt`.
64. Preserve the final totals in `summary.txt`.
65. For each behavioral comparison failure, preserve complete expected stdout, actual stdout, stderr, and failure metadata.
66. Keep all files belonging to one test invocation inside that single result directory.


## Return-code propagation

67. Public return codes must be verified end-to-end from the embedded language through the standalone `.bat` process to the calling `cmd.exe`.
68. `:RunPowerShellFromLabel` returns the captured `powershell.exe` exit code directly.
69. Avoid an indirect re-entry/pending-carrier path when a direct `exit /b captured-code` is clearer and empirically more reliable.
70. At top-level `:end`, explicitly `exit /b` on a nonzero application return code before the normal `GoTo :EOF`.
71. Lookup no-match remains a normal non-error-output condition: no stdout, no stderr, return code `1`.
72. The automated no-match lookup tests are mandatory acceptance tests for return-code propagation.


## Duplicate/orphan diagnostic layer

73. Duplicate/orphan public tools use the `find_mvs_` prefix and remain fully standalone after generation.
74. A duplicate scan returning findings is successful and returns `0`; no findings also returns `0`.
75. Duplicate ID/title findings in `mvs.txt` and `mvs_names.txt` preserve the full source section through its associated nonblank lines.
76. Duplicate filename findings from section files identify the owning ID/title and exact matched filename line.
77. Duplicate title and filename keys compare case-insensitively after normalization; IDs compare numerically; dates compare as trimmed source values.
78. Orphan scans are directional set-membership checks: each source occurrence is reported when its normalized property value is absent from the target.
79. Orphan section findings preserve full section context for ID/title and owner ID/title plus matched line for filename.
80. Do not interpret every literal duplicate/orphan as corruption; document source-model cases where repetition or differing title domains are expected.
81. Treat IDs in `mvs_names.txt` as source-level IDs; do not assume they are product IDs or product foreign keys.
82. `mvs_names.txt` heading titles are variant/display titles and are not generally the same title domain as product titles.
83. `mvs_notes.html` normally has no ID field; an ID diagnostic there recognizes only explicit literal `[ID: N]` markers if present.
84. SHA-1/SHA-256 orphan diagnostics in this phase compare filenames only.
85. Maintain a synthetic intentionally inconsistent dump under `test\test-mvs-dump-diagnostics\`.
86. Every diagnostic public tool must have a positive regression case against that fixture.
87. Diagnostic expected stdout is fixed and independently generated without invoking the public batch file under test.
88. `test\test_all.bat` includes diagnostic regression in addition to the established real-dump scalar/lookup regression.


## Filename/hash relationship query layer

89. Generate both `print_` and `read_` forms for every requested filename/hash relationship projection.
90. Relationship naming is `print_mvs_dump_<projection>_from_filename`, `read_mvs_dump_<projection>_from_filename`, and equivalent `_from_hash` forms.
91. Relationship invocation is `tool.bat dump-folder search-value`.
92. Filename and hash search values match exactly and case-insensitively; do not silently introduce wildcard semantics for this family.
93. `mvs.txt` is the canonical product-to-filename ownership source for this relationship family.
94. Do not use `mvs_names.txt` headings as product titles in this family; they are variant/display titles.
95. Hash-to-filename lookup indexes observed 40/64-hex hashes from `mvs.txt` plus flat `mvs.sha1` and `mvs.sha256` manifests when present.
96. Treat each observed hash->filename edge independently; do not infer a SHA-1/SHA-256 pair merely because filenames match.
97. Hash/filename pairs repeated across sources may be deduplicated for traversal.
98. A relationship result row represents one matched filename plus one owning `mvs.txt` product section, or a filename-only row when a manifest filename has no owner.
99. Preserve one-to-many filename->product and hash->filename relationships; do not collapse genuinely distinct associations.
100. Suppress exact duplicate projected rows only after relationship traversal.
101. ID/title come from `mvs.txt`; date joins by ID from `mvs_dates.txt`; note follows the established normalized title-level note policy.
102. The plural `filenames` token in a public tool name maps to one `Filename` field per emitted relationship row; multiple filenames appear as multiple rows.
103. `print_` relationship output uses labeled ` | `-separated fields and `(none)` for missing projected scalar values.
104. `read_` relationship output is headerless TSV with empty missing fields.
105. No associated projected result returns `1` with no stdout.
106. Missing `mvs.sha256` in older snapshots is not fatal; manifests supplement the required `mvs.txt` relationship source.
107. Maintain a synthetic relationship fixture under `test\test-mvs-dump-relationships\`.
108. Every filename-query public relationship tool receives a positive exact behavior test.
109. Every hash-query public relationship tool is tested with both a SHA-1 that exists only in `mvs.sha1` and a SHA-256 that exists only in `mvs.sha256`.
110. Maintain additional regression cases proving hash discovery directly from `mvs.txt`.
111. Relationship expected outputs must be independently generated without invoking the public batch tools under test.


## Single-dump completeness layer

112. Complete the single-dump model before implementing cross-dump comparison.
113. Forward product queries traverse `mvs.txt` product ID/title -> filename -> all observed hashes for that filename.
114. Hash observations preserve provenance from `mvs.txt`, `mvs_names.txt`, `mvs.sha1`, and `mvs.sha256`.
115. Do not infer digest-pair identity solely from shared filenames.
116. Model `mvs_names.txt` section occurrence as variant identity; title+ID is not unique.
117. Preserve empty variant sections in first-class variant enumeration.
118. Expose raw product file rows and raw product section lines independently of normalized scalar projections.
119. Expose raw note occurrences independently of combined title-level note convenience data.
120. Provide unparsed-line reporting for every line-oriented source used by the toolkit.
121. Hash-integrity diagnostics report duplicate hashes, hash->multiple-filename, filename->multiple-hash, and cross-source filename/hash mismatches.
122. Whole-dump summary/statistics must remain key/value oriented and machine-readable.
123. Summary metrics keep `mvs_names.txt` IDs separate from product IDs and report any numeric overlap only as literal overlap, not ownership.
124. All new query selectors are exact; wildcard semantics remain confined to the explicit lookup family.
125. The single-dump synthetic fixture must force every new public tool through a positive output/finding path.
126. Every new public single-dump tool gets an exact expected stdout regression file produced by an independent Python reference implementation.
127. Add no-result return-code regression for each new query operation family.

128. Real-dump validation on `mvs_2019-10-16` proves that `mvs_names.txt` IDs are not product IDs: the variant-source ID domain extends far beyond the product-ID range.
129. A product-to-variant association must be derived from source-supported file/hash edges and preserve ambiguity; never join `mvs_names.txt` to products by numeric ID alone.
130. PowerShell 5.1 embedded blocks must avoid parser-sensitive comma-separated cast/function expressions inside array subexpressions; prefer the established ArrayList emitter pattern.

131. Preserve `mvs_names.txt` IDs as trimmed source text; do not cast them to integers.
132. Variant `..._from_id` queries compare source IDs case-insensitively as text; product `..._from_id` queries remain numeric.
133. Synthetic variant fixtures must use IDs outside the product-ID domain, including an alphanumeric ID and a hyphenated ID.

134. PowerShell helper functions that return empty mutable collections must suppress collection enumeration so callers receive the collection object, not `$null`.
135. The shared single-dump `New-ArrayList` helper must use a non-enumerating return form and generated-tool validation must enforce it.
136. A Windows failure shared by every tool in one generated family should first be treated as a common injected-runtime defect before individual operation logic is changed.


137. Two-dump comparison tools accept the earlier/baseline dump first and the later/new dump second.
138. A source value present only in the first dump is removed and is emitted with a `-` prefix; a value present only in the second is added and is emitted with a `+` prefix.
139. Emit all removals before all additions; preserve first-source order for removals and second-source order for additions.
140. Comparison output is set-based: duplicate occurrences within one source do not create repeated diff lines.
141. Interactive comparison output colors removed lines red and added lines green; redirected output remains plain text with no terminal-control bytes.
142. No differences is a successful comparison with empty stdout and return code 0.
143. `mvs_names.txt` IDs remain textual source IDs during comparison; product-source IDs use numeric normalization.
144. Title comparison uses HTML decode, whitespace collapse, trim, and case-insensitive membership; date comparison uses trimmed source text.
145. Hash comparison is algorithm-specific and filename comparison is source-specific; do not infer cross-source ownership from a filename-only comparison.
146. Every comparison tool must be exercised on a synthetic before/after pair and on an identical pair.
147. Cross-dump comparison must build on the validated 0.9.2 single-dump baseline without changing the existing 422 public tools.


## Archive history and all-ever layer

136. Archive-wide history operates on the same 19 source-local domains and normalization rules as the two-dump comparison layer.
137. History ordering is derived deterministically from recognized `mvs_YYYY-MM-DD` snapshot directory names, including optional time/revision suffixes.
138. The change-history builder records every adjacent comparable transition in separate added and removed TSV ledgers.
139. A missing source file is a coverage gap, not an empty source; do not synthesize additions/removals across a missing-source boundary.
140. Preserve transition provenance (`from_dump`, `to_dump`) on every addition/removal row.
141. The all-ever builder is a monotonic union: once a normalized value has been observed, later removals do not delete it from the accumulated record.
142. Seed all-ever unions from the first available snapshot for each source so values already present in the archive baseline are retained.
143. Preserve first-seen dump, last-seen dump, and observed-snapshot count for every all-ever value.
144. Keep all-ever records source-local; do not merge `mvs_names.txt` IDs or titles into product-source domains merely because the labels look similar.
145. Both archive builders may target the same output directory without erasing each other's outputs.
146. Maintain a synthetic multi-snapshot history fixture and fixed independently generated expected files for every history domain.
147. `test\test_all.bat` and `test\test_history_tools.bat` must execute both public history builders on Windows.

## Performance / archive-sweep directives

148. Public performance optimizations must not change a public tool's name, command-line arguments, scope, stdout contract, or return-code contract.
149. Keep the public root count at 443 unless a separately approved public feature changes it.
150. Fast archive-sweep utilities belong under `test\fast` and are not public root tools.
151. `test\test_all_dumps.bat` defaults to `fast-combined`; `--external-tools` forces literal public-tool execution.
152. Serialize executor identity into plan/run metadata and include it in the plan hash used for resume safety.
153. Combined execution may reuse parsed models across logical checks but must preserve PASS/NO_RESULT/SOURCE_MISSING/FAIL classification semantics.
154. External sweep mode should not materialize successful stdout merely to measure it; capture full payloads only when needed for failures.
155. Optimize source loading by operation: do not parse unrelated sources or enrichment fields.
156. Prefer indexed/HashSet membership for large repeated lookup operations.
157. Preserve a dedicated small synthetic acceptance path for the combined executor.
158. Preserve elapsed-time data and provide an analyzer so performance regressions can be investigated without another full archive run.
