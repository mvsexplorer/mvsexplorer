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
