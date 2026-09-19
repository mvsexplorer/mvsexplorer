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
