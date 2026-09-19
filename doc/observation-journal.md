# Development Observation Journal

## 2026-08-27

### Source order and sorted order serve different purposes

Source order preserves provenance from `mvs_ids.txt`. Sorted order improves exploration. Explicit companion tools preserve both.

### Sort key should be independent of projection

A tool can print NOTE while sorting by TITLE. Sorting therefore belongs before projection in the data pipeline.

### Natural title sorting is preferable to plain lexical sorting

Product titles often contain version numbers. Plain lexical ordering can put `10` before `7`; natural/alphanumeric ordering better matches user expectation.

### Date ordering should parse rather than merely compare strings

ISO-like source values often sort lexically, but zone and representation differences make chronological parsing more robust. The emitted source string should remain unchanged.

### Wildcard syntax should be intentionally small

The requested wildcard behavior is `*`. Reusing PowerShell `-like` directly would silently expose bracket expressions and other wildcard semantics.

Escaping first and translating only `*` provides the requested language and nothing more.

### Duplicate lookup target values are not useful row identity

A lookup that returns only a target field cannot explain why the same target appears twice. Current lookup tools therefore emit exact distinct non-empty target values. A future row-level lookup/report should include ID if multiplicity matters.

### Missing target and missing source match are collapsed at lookup output level

A matched product can have no note under the title-based note join. Lookup tools omit empty targets and return `1` when no non-empty associated value is emitted.

### Generated standalone files solve the maintenance/deployment tension

There are now 127 public tools. Manually synchronizing common functions would be error-prone. Development-time generation keeps one maintained common source while producing independent deliverables.

### Tool discovery is becoming a project concern

The scalar matrix alone produces 120 tools: 15 projections × 2 output modes × 4 orderings. A machine-readable tool catalog is now useful and will be even more important for MVS Explorer GUI integration.

### Windows runtime testing remains required

Static validation can verify generation, labels, CRLF/BOM, injection, naming, and obvious dependency leakage here. Actual `cmd.exe` and Windows PowerShell execution should be part of Windows milestone testing.


### Testing public scripts requires invoking `cmd.exe`, not only testing parser functions

A parser-only unit test can pass while a generated batch wrapper, environment handoff, return code, or output stream is broken. The automated suite therefore launches each actual public `.bat`.

### Capturing both stdout and stderr can deadlock if done sequentially

Some scalar outputs can be large. The test harness reads redirected stdout and stderr asynchronously before waiting for completion.

### Dynamic command data should not be concatenated directly into test command source

Dump paths and lookup patterns may contain spaces or parser-sensitive characters. The harness transports these through child-process environment variables and uses a fixed `cmd.exe` command form.

### Exact output tests intentionally include empty machine fields/lines

For projections such as NOTE-only machine output, missing notes legitimately create empty records. Whole-stream comparison preserves those cases instead of using `for /f`, which would silently discard empty lines.
