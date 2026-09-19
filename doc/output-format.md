# Output Format

## print_ tools

Human-oriented output.

Each product is one physical line. Requested fields are labeled and separated with:

```text
 | 
```

Example:

```text
ID: 748 | Title: Windows 7 Ultimate | Date: 2009-08-06T09:59:56
```

Missing values are displayed as:

```text
(none)
```

## read_ tools

Machine-oriented output.

Properties:

- one physical record per product;
- headerless;
- literal TAB field delimiter;
- source order follows `mvs_ids.txt`;
- field order follows the tool name;
- no color;
- no banner;
- no progress/status text on stdout;
- missing values are empty fields;
- embedded TAB/CR/LF in values are replaced with spaces;
- errors are written to stderr.

Example logical representation:

```text
748<TAB>Windows 7 Ultimate<TAB>2009-08-06T09:59:56
```

The actual stream contains TAB characters, not the text `<TAB>`.
