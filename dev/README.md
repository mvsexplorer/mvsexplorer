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
154 public 0.9.0 single-dump tools.

`generate_expected_single_dump_outputs.py` is an independent Python reference
parser and never invokes the public batch files.
