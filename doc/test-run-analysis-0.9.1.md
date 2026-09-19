# Windows Test Run Analysis — MVS Explorer Toolkit 0.9.1

## Supplied run

Command:

```text
test\test_all.bat ..\mvs_dumps_archive\mvs_2019-10-16
```

Result folder reported by the harness:

```text
test\test-results-20260827-173744
```

The supplied console transcript reports:

```text
Products parsed for expectations: 1791
SUMMARY: passed=762 failed=166 skipped=3
```

The three skips are the expected data-dependent exact note lookup cases for a
dump with no non-empty note association.

## Failure signature

Every single-dump completeness behavioral case failed. Positive cases expected
return code 0 but received 5; no-result cases expected return code 1 but
received 5. The stderr signature was identical:

```text
ERROR: You cannot call a method on a null-valued expression.
```

Earlier scalar, lookup, duplicate/orphan diagnostic, and filename/hash
relationship families continued to pass. The 422-file structure enumeration
also passed.

This proves the 0.9.0 `ScriptBlock.Create()` parse-time failure was repaired in
0.9.1. The new single-dump block compiled and began execution, then failed in a
shared initialization/runtime path before individual operations produced
stdout.

## Root cause

The shared single-dump PowerShell library defined:

```text
function New-ArrayList {
    return (New-Object System.Collections.ArrayList)
}
```

PowerShell enumerates collection objects emitted by a function. Because a new
ArrayList is empty, this function emits zero pipeline objects. An assignment
such as:

```text
$rows = New-ArrayList
```

therefore assigns `$null`, not an empty ArrayList. The first call such as:

```text
[void]$rows.Add(...)
```

throws the observed null-valued-expression exception.

## 0.9.2 correction

The helper now forces the empty collection itself to be emitted as one object:

```text
function New-ArrayList {
    return ,(New-Object System.Collections.ArrayList)
}
```

All 154 single-dump public tools are regenerated from the shared development
source. A structure guard and the static generated-tool validator both require
this non-enumerating return form.

No expected output contracts changed. The full suite remains 931 assertions.
For `mvs_2019-10-16`, the expected clean result is 928 passed, 0 failed, and 3
data-dependent skips.
