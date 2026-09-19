## 0.16.4 pipeline maintenance

`generate_all_pipeline.py` maintains the root one-command orchestration batch
and `test\test_generated_databases.bat` from
`library\all-pipeline.inc.ps1`, `library\database-validation.inc.ps1` and their
templates. The pipeline is a separate public orchestration class and must stay
excluded from the 422 single-snapshot / 19 compare / 2 archive legacy plan.

Test generators inject project version 0.16.4 into progress output. The
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

`generate_tools.py` injects common source into each public root `.bat`.

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
