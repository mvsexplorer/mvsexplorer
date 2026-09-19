# MVS Explorer Toolkit — Development Directives

These directives are distilled from the user's project prompts. They are the working requirements for future development.

## Product direction

1. Build **MVS Explorer Toolkit** as a collection of simple console-oriented tools, primarily `.bat` scripts and helpers.
2. The toolkit should collect, search, transform, and display information from MVS dump snapshots.
3. Development should culminate in a graphical application named **MVS Explorer**.
4. Console tools should establish reusable data semantics and output contracts that the later GUI can consume.

## Source model

5. A dump is selected by dump folder/date name, for example `mvs_2021-08-17` or `mvs_2021-06-21-1830`.
6. Treat product ID as the primary product identity when the source supplies it.
7. Product scalar data currently consists of ID, title, release date, and note.
8. Variants are child records associated with product IDs and are expected to expose variant name, filename, and hash information.
9. Do not invent stronger source relationships than the files actually support; document inferred/convenience joins.

## Tool naming and outputs

10. Human-readable tools use the `print_` prefix.
11. Machine-readable tools use the `read_` prefix.
12. Tool names should describe their projection, for example `print_mvs_dump_id_title_date`.
13. Field order in output follows field order in the tool name.
14. Machine-readable output should be simple and stable for scripts and future application code.
15. Human-readable and machine-readable output are separate interfaces and need not look identical.

## Standalone requirement

16. Every delivered tool file must be fully standalone.
17. A delivered `.bat` must include all code required for its own function.
18. Do not require another toolkit source/helper file at runtime for the advertised core function.
19. Shared development-time generation is acceptable if final delivered tools remain independent.

## Language/style

20. Follow the supplied Batch File Style Guide for `.bat` code.
21. Use batch when practical.
22. Use PowerShell when the operation is genuinely too awkward or fragile in pure batch.
23. Apply the batch guide's principles in spirit to PowerShell and other languages.
24. Maintain a project-specific style-guide addendum when development reveals clarifications or local conventions.
25. Maintain a PowerShell style guide specifically for embedded PowerShell used by this project.

## Documentation/history

26. Keep the supplied batch style guide inside `doc\`.
27. Maintain a developer diary.
28. Maintain a project version history.
29. Maintain a separate version history for every tool.
30. Preserve the user's development prompts in a development-prompts document.
31. Maintain this distilled development-directives document.
32. Maintain an observation journal capturing source/data/implementation discoveries.
33. Update relevant development documents as the project evolves rather than treating documentation as static boilerplate.

## Current scalar milestone

34. Provide all useful scalar combinations of ID, title, date, and note.
35. Preserve one product per output record for scalar tools.
36. Human output should be readable on the console.
37. Machine output should avoid decorative content and remain pipe/redirection friendly.
