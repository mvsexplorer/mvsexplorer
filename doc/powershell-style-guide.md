# MVS Explorer Toolkit — Embedded PowerShell Style Guide

**Guide version:** 0.1.0  
**Context:** Companion to Batch File Style Guide v1.8.0 and the MVS Explorer Toolkit addendum.

This guide applies to PowerShell source embedded inside standalone MVS Explorer Toolkit `.bat` files.

## 1. Role of PowerShell

Batch remains the public executable format.

Use embedded PowerShell for work that is disproportionately awkward or fragile in pure batch, especially:

- HTML parsing/normalization;
- structured collections/dictionaries;
- parser-sensitive arbitrary text;
- complex joins;
- Unicode-aware text handling.

Do not move trivial batch work into PowerShell merely because PowerShell can do it.

## 2. Standalone requirement

PowerShell code required by a tool must be embedded in that tool.

Do not require an external `.ps1` for the tool's core function.

Prefer the style guide's multiline-between-labels mechanism for substantial code.

## 3. Invocation

Use:

```text
powershell.exe -NoLogo -NoProfile -NonInteractive -Command ...
```

Do not add `-ExecutionPolicy Bypass` to ordinary embedded `-Command` execution.

Avoid temporary PowerShell files.

## 4. Source/data separation

Do not construct executable PowerShell source from arbitrary MVS data.

Pass configuration through controlled environment variables or argument arrays and treat dump content strictly as data.

The batch side may select a known embedded block name; dump titles, notes, filenames, and other catalog values must never become executable PowerShell fragments.

## 5. Error handling

At the embedded script entry point:

```powershell
$ErrorActionPreference = 'Stop'
```

Use explicit nonzero exits for defined input/data failures where practical.

Human-mode errors and machine-mode errors go to stderr.

Do not mix normal data and diagnostic messages on machine-readable stdout.

## 6. Function design

Prefer small functions with descriptive verb-noun names where practical.

Functions should have:

- a narrow responsibility;
- explicit parameters;
- explicit return/output behavior;
- no hidden modification of unrelated state.

For short private helpers inside one embedded block, full comment-based help is optional; important behavior belongs in the surrounding project documentation and source comments where needed.

## 7. Naming

Use readable PascalCase function names:

```text
Resolve-DumpFolder
Normalize-Title
Convert-NoteHtmlToText
Write-Line
```

Use descriptive local variables.

Environment variables used to cross the batch/PowerShell boundary use the `mvsq_` namespace for the scalar query tools.

## 8. Text and encoding

Set console output encoding deliberately when machine-readable Unicode output is expected.

For current tools:

```powershell
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
```

Do not silently rewrite source date/time values into another timezone or format unless the tool explicitly promises conversion.

Normalize only what the output contract requires.

## 9. Machine-readable scalar output

For `read_` tools:

- write only records to stdout;
- one record per product;
- TAB delimiter;
- no header;
- normalize embedded TAB/CR/LF to spaces;
- keep missing fields empty;
- errors to stderr.

Use `[Console]::Out.WriteLine()` rather than formatting cmdlets that may add presentation behavior.

## 10. Collections and joins

Use dictionaries/hashtables for keyed joins where the source provides a key.

Current rules:

- date: join by numeric product ID;
- note: join by normalized title because the note source lacks ID.

Do not infer a stronger key than the source supports.

When multiple note blocks share one normalized title, de-duplicate identical normalized blocks and preserve distinct blocks in source order.

## 11. HTML note normalization

The current scalar tools use lightweight normalization rather than claiming full HTML DOM semantics.

They:

- convert common structural closing tags and `<br>` to spaces;
- strip remaining tags;
- HTML-decode entities;
- replace NBSP with normal space;
- collapse whitespace.

If note rendering later requires semantic HTML preservation, create a new explicit output mode rather than silently changing the scalar text contract.

## 12. Performance

For current scalar tools, one PowerShell startup per tool invocation is acceptable.

Avoid spawning PowerShell once per product or once per field.

Read each source file at most once per invocation where practical.

Optimization should follow measurement, consistent with the batch guide.

## 13. Compatibility

Write for Windows PowerShell as invoked by `powershell.exe`, not only PowerShell 7 (`pwsh`).

Avoid syntax/features unavailable in Windows PowerShell when compatibility is part of the current project requirement.

## 14. Testing

Test both human and machine output.

Important cases include:

- dump folder with spaces;
- named-folder resolution;
- missing dump;
- missing required source file;
- titles containing parser-sensitive characters;
- Unicode title/note text;
- empty/missing note;
- duplicate titles across IDs;
- duplicate note headings;
- note HTML with entities and line breaks;
- redirection and piping of `read_` output.

## 15. Versioning documentation

The embedded PowerShell is part of the tool implementation.

A material PowerShell behavior/interface change increments the containing tool version and is recorded in that tool's history. If the project-wide PowerShell conventions change, update this guide's version as well.
