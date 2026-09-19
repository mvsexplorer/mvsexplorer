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
