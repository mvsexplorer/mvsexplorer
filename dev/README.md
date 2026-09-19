## 0.21.2 HTML browser controls

`library/html-browser-builder.inc.ps1` is the maintained source for the
self-contained browser UI. Hierarchy actions must preserve the same semantics as
the Explorer controls: Select all means all currently available values (not
search-visible values), Clear cascades to dependent columns, and copy actions
distinguish selected values from the complete available list.

Variant hierarchy badges count product-backed Files & hashes rows (`p[11]`)
for the exact title. Result-table sorting is presentation-only; table and column
clipboard export must use the complete filtered/sorted row set across every
page. Page-size `All` is an explicit user choice and may render the full result
set.

## 0.21.0 reporting/UI/taxonomy/performance rules

## 0.21.1 maintained classification hints and concise runtime reporting

`product-family-classification-hints.tsv` is the maintained, reviewable source
for product-family prior-knowledge hints. `generate_product_family_tools.py`
embeds it into the standalone builder and records its SHA-256 provenance.
Archive/database/family console progress uses transient status for repetitive
successful work while machine-readable result files retain full detail.


`test-harness.inc.ps1` owns section-level interactive PASS compaction; do not
remove assertion rows from the result files or detailed test log.

`archive-sweep.inc.ps1` and `all-pipeline.inc.ps1` share the
`__MVS_TRANSIENT__` protocol. The child always keeps detailed archive logging;
the parent turns protocol rows into one overwriteable console line while
preserving them in the pipeline master log.

`database-maintenance-prepare.inc.ps1` aggregates unchanged reuse decisions on
screen and writes per-slot `reuse-decisions.tsv`; processing-from-scratch
reasons remain permanent console messages.

`powershell-gui.inc.ps1` treats language only as explicit title evidence.
Hierarchy sorting/copying and all-pages result export must not change checked
selection semantics. Clear is cascading to the right.

`product-family-builder.inc.ps1` applies `WINDOWS_BRANDED_SUBPRODUCT` before
generic Windows aliases. Prefer narrow curated rules over guessed lexical
splits. Snapshot-local dedupe optimization is valid only for rows whose identity
already contains the snapshot key.

## 0.20.2 caller-root hotfix

`templates\archive-sweep.bat.tpl` must freeze `mvsa_caller` and
`mvsa_script_root` before the first `shift`. The 0.20.1 arbitrary-length
argument bridge remains required; only its ordering changes. The structure
harness checks both properties.

## 0.20.1 native argument-transport/test-metadata hotfix

`templates\archive-sweep.bat.tpl` must capture arbitrary-length option lists;
do not restore fixed `%1`..`%9` transport. `library\archive-sweep.inc.ps1`
reconstructs the indexed captured arguments and keeps the first value as the
archive input.

`test\test_product_family_tools.bat` remains a maintained regression artifact.
Its embedded project version must be advanced with each project release because
the generated structure harness verifies both the `tools\` query path and the
current project version.

Archive-processing result semantics and the semantic result-producer reuse
fingerprint are unchanged.

## 0.19.3 pipeline-gate hotfix

`library\test-harness.inc.ps1` must compare expected embedded PowerShell source
markers as literals; do not use double-quoted expected strings containing
variables such as `$slot`, `$stamp`, `$Root`, or `$ToolName`.

`library\all-pipeline.inc.ps1` captures a newly created test-results directory
from the ALL TESTS phase in a `finally` block so a nonzero child return does not
erase assertion evidence. Early gate failures report downstream archive work as
explicitly NOT RUN.

Archive-processing tools and plan semantics are unchanged.

## 0.19.2 native follow-up

`generate_powershell_gui.py` 0.2.1 fixes multi-candidate discovery by returning
the sorted candidate objects as a flat PowerShell sequence. Do not restore the
extra unary comma around that array.

`generate_database_maintenance.py` 0.1.2 injects both maintenance tool version
and toolkit project version. Component common code uses the project version for
database validator/state metadata.

Stage 03 has an explicit zero-pending/archive-reused exit path and must not call
`test_all_dumps.bat` or archive quality in that branch. Stage 06 can reuse a
prior managed validation PASS only when the validator/query toolset fingerprint
and database metadata fingerprint match and no upstream layer rebuilt;
`--force-validate` bypasses it.

`database-summary-display.inc.ps1` parses only numeric quality counters and uses
persisted database-summary update time for root recency.

`test\test_product_family_tools.bat` is a maintained regression artifact; after
the 0.19.0 layout change its query wrappers must resolve from `tools\`.

## 0.19.1 validation-output ownership hotfix

`database-maintenance-validate.inc.ps1` must not call
`Ensure-Directory $validationDir` before `test_generated_databases.bat`.
The validator rejects a pre-existing output path by design and owns creation of
that directory. Structure tests enforce this contract.

The 0.19.1 maintenance hotfix intentionally does not regenerate the
archive-sweep/family/compact processing surfaces, preserving their 0.19.0 bytes
and therefore the toolset fingerprints needed to reuse a successful 0.19.0
database.

## 0.19.0 layout and database-maintenance generation

0.19.0 makes `tools\` the generated output directory for the 478 utility BATs
whose public names begin with `build_mvs_`, `compare_mvs_`, `find_mvs_`,
`lookup_mvs_`, `print_mvs_`, or `read_mvs_`. Generators must write directly to
that directory; release assembly must not move generated files afterward.
Archive/test callers resolve those tools from `tools\` while preserving the
existing 422 single / 19 compare / 2 archive sweep scope.

`generate_database_maintenance.py` maintains the new incremental database
workflow from these sources:

```text
library\database-maintenance-common.inc.ps1
library\database-maintenance-discover.inc.ps1
library\database-maintenance-prepare.inc.ps1
library\database-maintenance-run-archive.inc.ps1
library\database-maintenance-family.inc.ps1
library\database-maintenance-compact.inc.ps1
library\database-maintenance-validate.inc.ps1
library\database-maintenance-html.inc.ps1
library\database-maintenance-state.inc.ps1
library\database-maintenance-launcher.inc.ps1
library\database-summary-display.inc.ps1
templates\database-maintenance-component.bat.tpl
templates\database-maintenance-launcher.bat.tpl
templates\database-summary-display.bat.tpl
```

The generator emits eight ordered component BATs under
`create_or_update_mvs_database\`, plus root
`create_or_update_mvs_database.bat` and `display_mvs_database_summary.bat`.
Components are orchestration artifacts and may call the delivered `tools\` and
`test\` surfaces, but they must not depend on `dev\` at runtime.

Incremental reuse is keyed by source-content fingerprints and an
archive-processing toolset fingerprint. Never substitute filesystem dates for
source-content identity. Reuse requires a complete compatible prior plan/run
ledger with terminal PASS/NO_RESULT/SOURCE_MISSING rows. A changed or
incomplete snapshot must be rerun as a complete snapshot batch. Staging
directories are disposable and only validated archive results are promoted.

`generate_powershell_gui.py` also maintains the no-argument compact-database
discovery behavior: search current and parent directories, auto-open exactly
one usable compact index, present a chooser plus Browse for multiple matches,
and use the folder picker when none is found.

`generate_html_browser.py` supplies the project-root timestamped default HTML
name. Database-maintenance stage 07 gives multi-archive output an additional
archive-slot component.

0.19.0 structure expects 495 assertions and all mode 1,108. The current known
legacy archive plan remains 34,822 logical checks.

## 0.18.0 standalone PowerShell GUI maintenance

`generate_powershell_gui.py` maintains `mvs_explorer_gui.bat` from
`templates/powershell-gui.bat.tpl` and `library/powershell-gui.inc.ps1`.

The delivered GUI is one standalone BAT. It reads an external compact family
database with WinForms under Windows PowerShell 5.1, mirrors the HTML
broad-family/product-family/release/exact-title hierarchy, and preserves the
same product-backed file/hash and title-level note boundaries. Large fact rows
are held as compact per-title strings instead of a PSCustomObject per row.

The GUI is a separate public class, excluded from the legacy archive sweep.
0.18.0 structure has 494 assertions and all mode has 1,107.

## 0.17.1 browser-builder PS5.1 compatibility maintenance

The first native 0.17.0 browser-builder run exposed a Windows PowerShell 5.1
parser incompatibility in `library/html-browser-builder.inc.ps1`:
`[Array]::Sort[string](...)` is generic static-method invocation syntax that
Windows PowerShell 5.1 does not parse. The maintained source now uses
`[Array]::Sort($a,[StringComparer]::OrdinalIgnoreCase)`.

`test-harness.inc.ps1` and `validate_generated.py` both guard this contract.
0.17.1 structure has 492 assertions and all mode has 1,105.

## 0.17.0 self-contained HTML browser maintenance

`generate_html_browser.py` maintains `build_mvs_html_browser.bat` from
`templates/html-browser-builder.bat.tpl` and
`library/html-browser-builder.inc.ps1`.

The delivered builder must remain standalone. Its generated HTML must contain
all CSS, JavaScript, and browser data inline, and must preserve the compact
family database's conservative evidence boundaries. The browser builder is a
separate public class: it is excluded from the 422 single-snapshot / 19 compare
/ 2 archive legacy sweep plan.

0.17.0 structure has 491 assertions and all mode has 1,104. The browser-specific
structure guard checks the standalone marker, compact-family source tables,
inline application/json payload, files/hashes view, and absence of external
script/HTTP dependencies in the generated builder template.

## 0.16.5 performance and deterministic packaging maintenance

The maintained product-family query library now streams large fact TSVs instead
of eagerly importing every row before filtering. Exact searches use a native
literal candidate prefilter followed by field verification; wildcard/escaped
patterns retain one-pass PowerShell wildcard semantics. Narrow family->fact
queries prefilter by exact member titles, while broad families scan once
against the membership-title map.

`all-pipeline.inc.ps1` now creates ZIP entries explicitly and fixes entry
timestamps at 1980-01-01 UTC. This removes package-hash drift caused solely by
quality-validation files receiving new filesystem last-write dates. Strict
content-addressed evidence hashes are unchanged.

Regenerate product-family tools, the pipeline/database validator, and tests
after editing these maintained sources. 0.16.5 structure has 489 assertions
and all mode has 1,102.

## 0.16.4 pipeline maintenance

`generate_all_pipeline.py` maintains the root one-command orchestration batch
and `test\test_generated_databases.bat` from
`library\all-pipeline.inc.ps1`, `library\database-validation.inc.ps1` and their
templates. The pipeline is a separate public orchestration class and must stay
excluded from the 422 single-snapshot / 19 compare / 2 archive legacy plan.

The 0.16.4 test generators injected project version 0.16.4 into progress output. The
fast-archive maintained PowerShell source is synchronized with the accepted
optimized generated worker; generator idempotence must retain that worker.

The 0.16.1 return-token and DAG guards, 0.16.2 plan-index/singleton-array/timed
progress/`--quiet-plan` guards, and 0.16.3 token-level semantic console-color
guard remain in force. 0.16.4 replaces the ineffective live-log read-sharing
acceptance condition with an ordering invariant: the pipeline must not ZIP its
log directory while `MasterWriter` or `PhaseWriter` can still be open. Final
log ZIP creation occurs only after the outer writer-disposal `finally` block.
Child and retained logs remain plain text. Resume-mode parsing/packaging is
maintained in the same pipeline source and must remain generator-idempotent.

# Development-time source

Files under `dev\` are not runtime dependencies of public tools.

```text
library\batch-common.inc.bat
library\powershell-common.inc.ps1
library\scalar-query.inc.ps1
library\lookup-query.inc.ps1
templates\scalar.bat.tpl
templates\lookup.bat.tpl
tool-spec.json
generate_tools.py
validate_generated.py
```

`generate_tools.py` injects common source into each generated public utility `.bat` under `tools\`.

The required release invariant is:

```text
shared source during development -> injected code -> standalone delivered .bat
```


Diagnostic development files:

```text
diagnostic-tool-spec.json
library\diagnostic-query.inc.ps1
templates\diagnostic.bat.tpl
generate_diagnostic_tools.py
generate_diagnostic_fixture.py
```

`generate_diagnostic_tools.py` injects the diagnostic PowerShell implementation
and common batch functions into every `find_mvs_*` public batch file.

`generate_diagnostic_fixture.py` regenerates the intentionally inconsistent
synthetic dump source under `test\test-mvs-dump-diagnostics\`.


Filename/hash relationship development files:

```text
relationship-tool-spec.json
library\relationship-query.inc.ps1
templates\relationship.bat.tpl
generate_relationship_tools.py
generate_relationship_fixture.py
generate_expected_relationship_outputs.py
```

`generate_relationship_tools.py` injects complete relationship-query code into
every public `*_from_filename.bat` and `*_from_hash.bat`.

The synthetic relationship fixture deliberately separates hash provenance:
selected SHA-1 exists only in `mvs.sha1`, selected SHA-256 exists only in
`mvs.sha256`, and a third tested hash exists only in `mvs.txt`.

Expected outputs are produced by a separate Python reference implementation
that never invokes the public batch files.


Single-dump completeness development files:

```text
single-dump-tool-spec.json
library\single-dump-query.inc.ps1
templates\single-dump.bat.tpl
generate_single_dump_tools.py
generate_single_dump_fixture.py
generate_expected_single_dump_outputs.py
```

`generate_single_dump_tools.py` injects the complete implementation into all
154 public 0.9.x single-dump tools.

`generate_expected_single_dump_outputs.py` is an independent Python reference
parser and never invokes the public batch files.


Two-dump comparison development files:

```text
compare-tool-spec.json
library\compare-query.inc.ps1
templates\compare.bat.tpl
generate_compare_tools.py
generate_compare_fixture.py
generate_expected_compare_outputs.py
```

`generate_compare_tools.py` injects the complete two-folder comparison
implementation into all 19 public `compare_mvs_dump_*` tools.

The synthetic pair under `test\test-mvs-dump-compare\` forces both removals and
additions for every tool. `generate_expected_compare_outputs.py` is an
independent Python reference implementation and never invokes the public batch
files.


Archive-wide sweep development files:

```text
library\archive-sweep.inc.ps1
templates\archive-sweep.bat.tpl
generate_archive_sweep.py
```

`generate_archive_sweep.py` injects the maintained PowerShell implementation
and common batch functions into `test\test_all_dumps.bat`. The delivered test
harness is standalone and does not read `dev\` at runtime.

- `library\fast-archive.inc.ps1` — one-pass combined archive history/all-ever runtime.
- `templates\fast-archive.bat.tpl` — standalone fast archive worker template.

## 0.14.0 archive quality/performance/reporting sources

The archive execution and analysis layer is generated from maintained source:

```text
library\archive-sweep.inc.ps1
library\fast-sweep.inc.ps1
library\fast-archive.inc.ps1
library\archive-quality.inc.ps1
library\archive-report.inc.ps1
library\test-performance.inc.ps1
library\test-everything.inc.ps1

templates\archive-sweep.bat.tpl
templates\fast-snapshot.bat.tpl
templates\fast-compare.bat.tpl
templates\fast-archive.bat.tpl
templates\fast-archive-test.bat.tpl
templates\archive-quality.bat.tpl
templates\archive-report.bat.tpl
templates\test-performance.bat.tpl
templates\test-everything.bat.tpl

generate_archive_sweep.py
generate_performance_tools.py
generate_quality_tools.py
generate_report_tools.py
```

The fast snapshot worker uses snapshot-local lookup indexes, frozen source
inventories, and content-addressed result keys. The archive worker emits the
legacy history/all-ever products plus evidence-preserving evolution data.

`validate_archive_sweep.py` checks the 443-tool legacy sweep surface plus the separate 34-tool family surface, generated
fast/test artifacts, duplicate batch labels, CRLF/no-BOM requirements, concrete
synthetic evolution assertions, indexed-worker markers, and the 34,822/1,306
logical plan counts.

The synthetic archive fixture is maintained by
`generate_history_fixture.py`. Its notes intentionally exercise both historical
h3+ID and current h1 heading forms.

## 0.15.0 product-family sources

The standalone product-family feature is generated from:

```text
product-family-tool-spec.json
library\product-family-builder.inc.ps1
library\product-family-compact-builder.inc.ps1
library\product-family-query.inc.ps1
templates\product-family-builder.bat.tpl
templates\product-family-compact-builder.bat.tpl
templates\product-family-query.bat.tpl
generate_product_family_tools.py
generate_product_family_fixture.py
```

`generate_product_family_tools.py` injects the complete runtime into the full index builder, compact all-ever builder,
and 32 print/read query wrappers. Public family tools have no runtime
dependency on `dev\`.

The synthetic acceptance lives at:

```text
test\test-mvs-product-family\
test\test_product_family_tools.bat
```

Family classification is analytical. Development changes must not reinterpret
`mvs_names.txt` IDs as product identities, infer SHA-1/SHA-256 pairings by
filename, or turn embedded product-name references into ownership.

## 0.19.3 test/pipeline hotfix

`library\test-harness.inc.ps1` now uses literal-safe source markers for the
timestamped HTML and moved-family-tool structure checks. `library\all-pipeline.inc.ps1`
captures failed ALL TESTS result folders before the gate exception propagates
and reports downstream archive work as NOT RUN when appropriate. Processing
tools and archive-plan semantics are unchanged.

## 0.20.0 adaptive scheduler

`library\archive-sweep.inc.ps1` owns the adaptive snapshot scheduler. Keep the
resource/throughput controller in maintained source and regenerate
`test\test_all_dumps.bat`; never patch the generated BAT directly.

The semantic maintenance fingerprint intentionally excludes
`test\test_all_dumps.bat` orchestration but continues to include all
result-producing dump tools and the three fast workers. This distinction is
what allows scheduler-only changes to reuse previously accepted logical rows
without weakening content or processing compatibility.

