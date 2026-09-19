# MVS Explorer Toolkit — Development Prompts

This document records the user's project-development prompts from this conversation in chronological order. Line wrapping is preserved where practical; Markdown fencing is used only to distinguish prompt text from document headings.

## Prompt 1

```text
Please review and understand the structure and contents of this archive
```

## Prompt 2

```text
Ok I want to create MVS Explorer Toolkit which will consist mostly of simple .bat scripts and helpers, tools for collecting, searching and displaying the information mostly on the console and ultimately culiminating in a graphical application called MVS Explorer

To write these .bat you will follow the batch style guide I include and when using other languages you will try to follow the guide at least in spirit

I think the first thing I want is a way to output 
for a particular named dump or dump date/folder
for example
mvs_2021-08-17
or 
mvs_2021-06-21-1830
A collection of script that will print the list of each of the main element

for example 
print all mvs product id
print all mvs product titles
print all mvs product id and titles (one line per entry)
print all mvs product id and release date (one line per entry)
print all mvs product id and note (one line per entry)
print all mvs product id and sha1 (one line per entry)
print all mvs product id and sha256 (one line per entry)
print all mvs product title and sha1 (one line per entry)
print all mvs product title and sha256 (one line per entry)
print all mvs product id and titles and release date (one line per entry)
print all mvs product titles and release date (one line per entry)
print all mvs product id and titles and release date on one line and note on second line
print all mvs product id and titles and release date all and note (one line per entry)
print all mvs product titles and note (one line per entry)
print all mvs product id and note (one line per entry)
print all mvs product id and all variant
print all mvs product id and all filenames
print all mvs product id and title and all variant
print all mvs product id and title and all filenames

in fact, before creating those scripts

Let's review every possibility that we can ask to "print all"
```

## Prompt 3

```text
ok so if I understand correctly 
each ID can only have one name 
so example in mvs_ids we get

Windows 7 Ultimate  [ID: 748]
Windows 7 Ultimate N [ID: 749]
Windows 7 Ultimate K [ID: 751]
Windows 7 Ultimate KN [ID: 752]
Windows 7 Enterprise  [ID: 753]
Windows 7 Enterprise N [ID: 754]
Windows 7 Enterprise K [ID: 756]
Windows 7 Enterprise KN [ID: 757]
Windows 7 Starter  [ID: 758]
Windows 7 Starter N [ID: 759]
Windows 7 Starter K [ID: 761]
Windows 7 Starter KN [ID: 762]
Windows 7 Language Pack [ID: 763]
Windows 7 Windows Automated Installation Kit (WAIK) [ID: 765]
Windows 7 Windows Driver Kit (WDK) [ID: 766]
Windows 7 Home Basic  [ID: 767]
Windows 7 Home Premium K [ID: 769]
Windows 7 Home Premium KN [ID: 770]
Windows 7 Home Premium N [ID: 771]
Windows 7 Home Premium  [ID: 772]
Windows 7 Professional K [ID: 774]
Windows 7 Professional KN [ID: 775]
Windows 7 Professional N [ID: 776]
Windows 7 Software Development Kit (SDK) [ID: 778]
Windows 7 Debug-Checked [ID: 779]

And these ID
can only have one release date , and that date is in mvs_dates.txt

and that is something like this

2009-08-06T09:59:56 - Windows 7 Ultimate  [ID: 748]
2009-10-22T08:59:40 - Windows 7 Ultimate N [ID: 749]
2009-08-28T10:18:15 - Windows 7 Ultimate K [ID: 751]
2009-08-28T10:18:15 - Windows 7 Ultimate KN [ID: 752]
2009-08-06T09:59:56 - Windows 7 Enterprise  [ID: 753]
2009-10-22T08:57:31 - Windows 7 Enterprise N [ID: 754]
2009-08-28T10:05:11 - Windows 7 Enterprise K [ID: 756]
2009-08-28T10:05:10 - Windows 7 Enterprise KN [ID: 757]
2009-08-06T09:59:56 - Windows 7 Starter  [ID: 758]
2009-10-22T08:59:19 - Windows 7 Starter N [ID: 759]
2009-08-28T10:24:36 - Windows 7 Starter K [ID: 761]
2009-08-28T10:24:36 - Windows 7 Starter KN [ID: 762]
2009-08-06T07:00:00 - Windows 7 Language Pack [ID: 763]
2009-08-06T07:00:00 - Windows 7 Windows Automated Installation Kit (WAIK) [ID: 765]
2009-08-06T07:00:00 - Windows 7 Windows Driver Kit (WDK) [ID: 766]
2009-08-06T09:59:56 - Windows 7 Home Basic  [ID: 767]
2009-08-28T10:11:56 - Windows 7 Home Premium K [ID: 769]
2009-08-28T10:11:54 - Windows 7 Home Premium KN [ID: 770]
2009-10-22T08:58:16 - Windows 7 Home Premium N [ID: 771]
2009-08-06T09:59:56 - Windows 7 Home Premium  [ID: 772]
2009-08-28T10:15:05 - Windows 7 Professional K [ID: 774]
2009-08-28T10:15:06 - Windows 7 Professional KN [ID: 775]
2009-10-22T08:58:47 - Windows 7 Professional N [ID: 776]
2009-08-06T09:59:56 - Windows 7 Software Development Kit (SDK) [ID: 778]
2009-08-14T09:55:36 - Windows 7 Debug-Checked [ID: 779]


and then in mvs_names.txt
we have, what I think we can call variants
and each variant has its own name, a filename and a hash that looks like SHA-1

example
--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Arabic) [ID: 758] ---
c3a75729b20cb4f15d5aa7537eaafebdff29cba1 *ar_windows_7_starter_with_sp1_x86_dvd_u_678504.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Bulgarian) [ID: 758] ---
f08482227f26009c5d2b96ca0333399c5b656e72 *bg_windows_7_starter_with_sp1_x86_dvd_u_678517.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Chinese-Simplified) [ID: 758] ---
9522d435348353bad69047c0161b7a9115a3c2a6 *cn_windows_7_starter_with_sp1_x86_dvd_u_678536.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Czech) [ID: 758] ---
5dffa187802106307a89458cbbc9480dedc28735 *cs_windows_7_starter_with_sp1_x86_dvd_u_678526.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Danish) [ID: 758] ---
8a547d17c2ef415978578a8c1173c47c13c74535 *da_windows_7_starter_with_sp1_x86_dvd_u_678537.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (German) [ID: 758] ---
37bb946b83ef5ed801a634bd644abf03bf15952a *de_windows_7_starter_with_sp1_x86_dvd_u_678545.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Greek) [ID: 758] ---
16ec828f04759059e4e304525bfdf2bbdae87ffe *el_windows_7_starter_with_sp1_x86_dvd_u_678555.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (English) [ID: 758] ---
e1653b111c4c6fd75b1be8f9b4c9bcbb0b39b209 *en_windows_7_starter_with_sp1_x86_dvd_u_678562.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Spanish) [ID: 758] ---
9d29f62bd8698011173fe5c407a6e2719f950aa8 *es_windows_7_starter_with_sp1_x86_dvd_u_678236.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Estonian) [ID: 758] ---
c98cab59b87aea08ee924d930b1963033b5d547c *et_windows_7_starter_with_sp1_x86_dvd_u_678249.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Finnish) [ID: 758] ---
73e36fb9559fd2ac1ab1abd52795103b50b86393 *fi_windows_7_starter_with_sp1_x86_dvd_u_678263.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (French) [ID: 758] ---
570a86902fcd505fe03d278eabbe6c8fda0808d6 *fr_windows_7_starter_with_sp1_x86_dvd_u_678275.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Hebrew) [ID: 758] ---
e2125ae15a4dd131d93946389616169dcb4d14d2 *he_windows_7_starter_with_sp1_x86_dvd_u_678290.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Chinese-Hong Kong SAR) [ID: 758] ---
eee454ab1d9e0f9f0cc06e7821ee289d7975747b *hk_windows_7_starter_with_sp1_x86_dvd_u_678543.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Croatian) [ID: 758] ---
26378d9b6b38d55d55f2ff6cef82cff97317e835 *hr_windows_7_starter_with_sp1_x86_dvd_u_678304.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Hungarian) [ID: 758] ---
a864101b0860ba1757576e892174cd80ea96c22b *hu_windows_7_starter_with_sp1_x86_dvd_u_678318.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Italian) [ID: 758] ---
f43e6ccb2520a65c91b86da6ab31662221c922da *it_windows_7_starter_with_sp1_x86_dvd_u_678331.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Japanese) [ID: 758] ---
e5b6fbce404b7faa176e4f3bf09ef80198bd6779 *ja_windows_7_starter_with_sp1_x86_dvd_u_678344.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Lithuanian) [ID: 758] ---
8b065342411e2a377668a3462d2c875d36454b94 *lt_windows_7_starter_with_sp1_x86_dvd_u_678360.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Latvian) [ID: 758] ---
ba21560d866ccdc9491db9c0c467a4b45c7b0431 *lv_windows_7_starter_with_sp1_x86_dvd_u_678374.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Dutch) [ID: 758] ---
a27264f2b83c34f61b194c197574bc15890cd773 *nl_windows_7_starter_with_sp1_x86_dvd_u_678399.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Norwegian) [ID: 758] ---
6823f9cf153b9197c29a2879ea88aa3a8d1a6957 *no_windows_7_starter_with_sp1_x86_dvd_u_678386.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Polish) [ID: 758] ---
bd8908c8b47688058b6472e9ba56b548072f6dd9 *pl_windows_7_starter_with_sp1_x86_dvd_u_678412.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Portuguese-Portugal) [ID: 758] ---
ace5ae2efb7bad29aa8a9b633b77e90fdc874311 *pp_windows_7_starter_with_sp1_x86_dvd_u_678439.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Portuguese-Brazil) [ID: 758] ---
fa175603c4b6fa1c4321004304134d07b8010f0f *pt_windows_7_starter_with_sp1_x86_dvd_u_678426.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Romanian) [ID: 758] ---
51b1c8eab65a41a7ab55f19bb91b07948a607092 *ro_windows_7_starter_with_sp1_x86_dvd_u_678452.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Russian) [ID: 758] ---
2905edb076dec9ece03568be264aafb0f955fe08 *ru_windows_7_starter_with_sp1_x86_dvd_u_678466.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Slovak) [ID: 758] ---
9722520d5302c7cc03f257257253840b3f2d7397 *sk_windows_7_starter_with_sp1_x86_dvd_u_678478.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Slovenian) [ID: 758] ---
57c62c171483ee07302ae22b380bf1ae00b753e7 *sl_windows_7_starter_with_sp1_x86_dvd_u_678490.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Serbian) [ID: 758] ---
81e7c1392c9b5739a75042b7dc08a9f946537ed7 *sr_windows_7_starter_with_sp1_x86_dvd_u_678501.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Swedish) [ID: 758] ---
f93588d185a210a22d045862553897174c187142 *sv_windows_7_starter_with_sp1_x86_dvd_u_678508.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Thai) [ID: 758] ---
0bcd1019bd5073d0cf818282f030d1900726d642 *th_windows_7_starter_with_sp1_x86_dvd_u_678516.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Turkish) [ID: 758] ---
7e3db71b43fb72197ff2b4f945b9eb8a8b2ea280 *tr_windows_7_starter_with_sp1_x86_dvd_u_678523.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Chinese-Taiwan) [ID: 758] ---
a7397ffc4d17e35115d7fb74f6f07dab4a7b67c2 *tw_windows_7_starter_with_sp1_x86_dvd_u_678549.iso

--- Windows 7 Starter with Service Pack 1 (x86) - DVD (Ukrainian) [ID: 758] ---
8a458512c667614eac0df6aee022c9ef77991aeb *uk_windows_7_starter_with_sp1_x86_dvd_u_678529.iso

and in mvs.sha1
we get something like
6823f9cf153b9197c29a2879ea88aa3a8d1a6957 *no_windows_7_starter_with_sp1_x86_dvd_u_678386.iso
bd8908c8b47688058b6472e9ba56b548072f6dd9 *pl_windows_7_starter_with_sp1_x86_dvd_u_678412.iso
ace5ae2efb7bad29aa8a9b633b77e90fdc874311 *pp_windows_7_starter_with_sp1_x86_dvd_u_678439.iso
fa175603c4b6fa1c4321004304134d07b8010f0f *pt_windows_7_starter_with_sp1_x86_dvd_u_678426.iso
51b1c8eab65a41a7ab55f19bb91b07948a607092 *ro_windows_7_starter_with_sp1_x86_dvd_u_678452.iso
2905edb076dec9ece03568be264aafb0f955fe08 *ru_windows_7_starter_with_sp1_x86_dvd_u_678466.iso
9722520d5302c7cc03f257257253840b3f2d7397 *sk_windows_7_starter_with_sp1_x86_dvd_u_678478.iso
57c62c171483ee07302ae22b380bf1ae00b753e7 *sl_windows_7_starter_with_sp1_x86_dvd_u_678490.iso
81e7c1392c9b5739a75042b7dc08a9f946537ed7 *sr_windows_7_starter_with_sp1_x86_dvd_u_678501.iso
f93588d185a210a22d045862553897174c187142 *sv_windows_7_starter_with_sp1_x86_dvd_u_678508.iso
0bcd1019bd5073d0cf818282f030d1900726d642 *th_windows_7_starter_with_sp1_x86_dvd_u_678516.iso
7e3db71b43fb72197ff2b4f945b9eb8a8b2ea280 *tr_windows_7_starter_with_sp1_x86_dvd_u_678523.iso
a7397ffc4d17e35115d7fb74f6f07dab4a7b67c2 *tw_windows_7_starter_with_sp1_x86_dvd_u_678549.iso
8a458512c667614eac0df6aee022c9ef77991aeb *uk_windows_7_starter_with_sp1_x86_dvd_u_678529.iso

and in sha256, these ones are not found in the particular dump I'm looking at

so 
ID
has name(title), release date and note 
and a list of variants
each variant has
name (variant name?) 
filename
sha1
sha256
and maybe a .cat filename and a .txt filename

so I think we can have something like this 
print_mvs_dump_id dumpfoldernamehere
and that would print all id
print_mvs_dump_id_title dumpfoldernamehere
print_mvs_dump_id_date dumpfoldernamehere
print_mvs_dump_id_note dumpfoldernamehere
print_mvs_dump_id_title_date dumpfoldernamehere
print_mvs_dump_id_title_note dumpfoldernamehere
print_mvs_dump_id_title_date_note dumpfoldernamehere
print_mvs_dump_title dumpfoldernamehere
print_mvs_dump_title_date dumpfoldernamehere
print_mvs_dump_title_note dumpfoldernamehere
print_mvs_dump_title_date_note dumpfoldernamehere
print_mvs_dump_date dumpfoldernamehere
print_mvs_dump_note dumpfoldernamehere
print_mvs_dump_date_note dumpfoldernamehere

and we could have all of these human readable and machine printable, I would use read_ as the machine friendly output version

Create these and put them in a project zip and give them to me
```

## Prompt 4

```text
all files must be fully standalone, please re-write all files to include all code necessary for their inner function

also create a doc\ folder
place the style guide in it
write a developper diary in it, write a project version history and for each tool also write a tool specific version history
also write all my prompts in a development prompts and from that write a document of development directive distilled from my prompts
as you write more script and need to clarify the style guide, write a style guide addendum, also write the style guide for the powershell that you use as part of this project inside the context of the batch style guide
and also keep a journal of observation from development of this project
```

## Prompt 5

```text
It is ok to maintain a function library and to use a script to inject the common function into each of the .bat
as long as the result .bat are fully standalone

One thing I notice with all of these, is that while it works
the output is not sorted

so I think every script here should also have a version that is _sorted
and here we can sort by id, numerically, by title alphanumerically and by date
sort by note does not seem useful

so for example
print_mvs_dump_id_title_date_note.bat
would also have
print_mvs_dump_id_title_date_note_sorted_by_id.bat
print_mvs_dump_id_title_date_note_sorted_by_title.bat
print_mvs_dump_id_title_date_note_sorted_by_date.bat


also I think we should have lookup_ scripts
where you give one value and it returns the value associated with it

example
lookup_mvs_title_from_id dumpfolderhere 28
and that would return the title of id 28
lookup_mvs_title_from_date 
returns all titles with that date
lookup_mvs_note_from_id
lookup_mvs_note_from_title
lookup_mvs_note_from_date
lookup_mvs_date_from_id
lookup_mvs_date_from_title
if there is more than one result, it should print it
and it should be possible to add wildcard for the search
lookup_mvs_title_from_id dumpfolderhere 28
lookup_mvs_title_from_id dumpfolderhere 2*
lookup_mvs_title_from_id dumpfolderhere *28
lookup_mvs_title_from_id dumpfolderhere *2*
```

## Prompt 6

```text
ok create test scripts that will ensure the proper functioning of all scripts automatically
put the in test\

and from root I should be able to run them like

test\test_all.bat path_to_mvs_dump_folder
```

## Prompt 7

The user supplied the full Windows console results from:

```text
test\test_all.bat ..\mvs_dumps_archive\mvs_2021-01-12-1901
```

The supplied run parsed 2003 products and ended:

```text
SUMMARY: passed=265 failed=7 skipped=0
```

All seven failures were lookup no-match return-code mismatches (`expected 1, got 0`); the complete findings are recorded in `doc\test-run-analysis-0.4.0.md`.

The user's requested test-output change was:

```text
These test should create test results files we can observed, all in one test\test-results-datestamp-timestamp folder
```

## Prompt 8

```text
OK here are the results

```

```text
C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.5.0>test\test_all.bat ..\mvs_dumps_archive\mvs_2020-08-14
Test results: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.5.0\test\test-results-20260827-111852
Dump: C:\Users\user\Downloads\mvs_dumps_archive\mvs_2020-08-14
Products parsed for expectations: 1961
=== Structure tests ===
[PASS] root public .bat count = 127
[PASS] standalone print_mvs_dump_id.bat
[PASS] standalone print_mvs_dump_id_sorted_by_id.bat
[PASS] standalone print_mvs_dump_id_sorted_by_title.bat
[PASS] standalone print_mvs_dump_id_sorted_by_date.bat
[PASS] standalone read_mvs_dump_id.bat
[PASS] standalone read_mvs_dump_id_sorted_by_id.bat
[PASS] standalone read_mvs_dump_id_sorted_by_title.bat
[PASS] standalone read_mvs_dump_id_sorted_by_date.bat
[PASS] standalone print_mvs_dump_id_title.bat
[PASS] standalone print_mvs_dump_id_title_sorted_by_id.bat
[PASS] standalone print_mvs_dump_id_title_sorted_by_title.bat
[PASS] standalone print_mvs_dump_id_title_sorted_by_date.bat
[PASS] standalone read_mvs_dump_id_title.bat
[PASS] standalone read_mvs_dump_id_title_sorted_by_id.bat
[PASS] standalone read_mvs_dump_id_title_sorted_by_title.bat
[PASS] standalone read_mvs_dump_id_title_sorted_by_date.bat
[PASS] standalone print_mvs_dump_id_date.bat
[PASS] standalone print_mvs_dump_id_date_sorted_by_id.bat
[PASS] standalone print_mvs_dump_id_date_sorted_by_title.bat
[PASS] standalone print_mvs_dump_id_date_sorted_by_date.bat
[PASS] standalone read_mvs_dump_id_date.bat
[PASS] standalone read_mvs_dump_id_date_sorted_by_id.bat
[PASS] standalone read_mvs_dump_id_date_sorted_by_title.bat
[PASS] standalone read_mvs_dump_id_date_sorted_by_date.bat
[PASS] standalone print_mvs_dump_id_note.bat
[PASS] standalone print_mvs_dump_id_note_sorted_by_id.bat
[PASS] standalone print_mvs_dump_id_note_sorted_by_title.bat
[PASS] standalone print_mvs_dump_id_note_sorted_by_date.bat
[PASS] standalone read_mvs_dump_id_note.bat
[PASS] standalone read_mvs_dump_id_note_sorted_by_id.bat
[PASS] standalone read_mvs_dump_id_note_sorted_by_title.bat
[PASS] standalone read_mvs_dump_id_note_sorted_by_date.bat
[PASS] standalone print_mvs_dump_id_title_date.bat
[PASS] standalone print_mvs_dump_id_title_date_sorted_by_id.bat
[PASS] standalone print_mvs_dump_id_title_date_sorted_by_title.bat
[PASS] standalone print_mvs_dump_id_title_date_sorted_by_date.bat
[PASS] standalone read_mvs_dump_id_title_date.bat
[PASS] standalone read_mvs_dump_id_title_date_sorted_by_id.bat
[PASS] standalone read_mvs_dump_id_title_date_sorted_by_title.bat
[PASS] standalone read_mvs_dump_id_title_date_sorted_by_date.bat
[PASS] standalone print_mvs_dump_id_title_note.bat
[PASS] standalone print_mvs_dump_id_title_note_sorted_by_id.bat
[PASS] standalone print_mvs_dump_id_title_note_sorted_by_title.bat
[PASS] standalone print_mvs_dump_id_title_note_sorted_by_date.bat
[PASS] standalone read_mvs_dump_id_title_note.bat
[PASS] standalone read_mvs_dump_id_title_note_sorted_by_id.bat
[PASS] standalone read_mvs_dump_id_title_note_sorted_by_title.bat
[PASS] standalone read_mvs_dump_id_title_note_sorted_by_date.bat
[PASS] standalone print_mvs_dump_id_title_date_note.bat
[PASS] standalone print_mvs_dump_id_title_date_note_sorted_by_id.bat
[PASS] standalone print_mvs_dump_id_title_date_note_sorted_by_title.bat
[PASS] standalone print_mvs_dump_id_title_date_note_sorted_by_date.bat
[PASS] standalone read_mvs_dump_id_title_date_note.bat
[PASS] standalone read_mvs_dump_id_title_date_note_sorted_by_id.bat
[PASS] standalone read_mvs_dump_id_title_date_note_sorted_by_title.bat
[PASS] standalone read_mvs_dump_id_title_date_note_sorted_by_date.bat
[PASS] standalone print_mvs_dump_title.bat
[PASS] standalone print_mvs_dump_title_sorted_by_id.bat
[PASS] standalone print_mvs_dump_title_sorted_by_title.bat
[PASS] standalone print_mvs_dump_title_sorted_by_date.bat
[PASS] standalone read_mvs_dump_title.bat
[PASS] standalone read_mvs_dump_title_sorted_by_id.bat
[PASS] standalone read_mvs_dump_title_sorted_by_title.bat
[PASS] standalone read_mvs_dump_title_sorted_by_date.bat
[PASS] standalone print_mvs_dump_title_date.bat
[PASS] standalone print_mvs_dump_title_date_sorted_by_id.bat
[PASS] standalone print_mvs_dump_title_date_sorted_by_title.bat
[PASS] standalone print_mvs_dump_title_date_sorted_by_date.bat
[PASS] standalone read_mvs_dump_title_date.bat
[PASS] standalone read_mvs_dump_title_date_sorted_by_id.bat
[PASS] standalone read_mvs_dump_title_date_sorted_by_title.bat
[PASS] standalone read_mvs_dump_title_date_sorted_by_date.bat
[PASS] standalone print_mvs_dump_title_note.bat
[PASS] standalone print_mvs_dump_title_note_sorted_by_id.bat
[PASS] standalone print_mvs_dump_title_note_sorted_by_title.bat
[PASS] standalone print_mvs_dump_title_note_sorted_by_date.bat
[PASS] standalone read_mvs_dump_title_note.bat
[PASS] standalone read_mvs_dump_title_note_sorted_by_id.bat
[PASS] standalone read_mvs_dump_title_note_sorted_by_title.bat
[PASS] standalone read_mvs_dump_title_note_sorted_by_date.bat
[PASS] standalone print_mvs_dump_title_date_note.bat
[PASS] standalone print_mvs_dump_title_date_note_sorted_by_id.bat
[PASS] standalone print_mvs_dump_title_date_note_sorted_by_title.bat
[PASS] standalone print_mvs_dump_title_date_note_sorted_by_date.bat
[PASS] standalone read_mvs_dump_title_date_note.bat
[PASS] standalone read_mvs_dump_title_date_note_sorted_by_id.bat
[PASS] standalone read_mvs_dump_title_date_note_sorted_by_title.bat
[PASS] standalone read_mvs_dump_title_date_note_sorted_by_date.bat
[PASS] standalone print_mvs_dump_date.bat
[PASS] standalone print_mvs_dump_date_sorted_by_id.bat
[PASS] standalone print_mvs_dump_date_sorted_by_title.bat
[PASS] standalone print_mvs_dump_date_sorted_by_date.bat
[PASS] standalone read_mvs_dump_date.bat
[PASS] standalone read_mvs_dump_date_sorted_by_id.bat
[PASS] standalone read_mvs_dump_date_sorted_by_title.bat
[PASS] standalone read_mvs_dump_date_sorted_by_date.bat
[PASS] standalone print_mvs_dump_note.bat
[PASS] standalone print_mvs_dump_note_sorted_by_id.bat
[PASS] standalone print_mvs_dump_note_sorted_by_title.bat
[PASS] standalone print_mvs_dump_note_sorted_by_date.bat
[PASS] standalone read_mvs_dump_note.bat
[PASS] standalone read_mvs_dump_note_sorted_by_id.bat
[PASS] standalone read_mvs_dump_note_sorted_by_title.bat
[PASS] standalone read_mvs_dump_note_sorted_by_date.bat
[PASS] standalone print_mvs_dump_date_note.bat
[PASS] standalone print_mvs_dump_date_note_sorted_by_id.bat
[PASS] standalone print_mvs_dump_date_note_sorted_by_title.bat
[PASS] standalone print_mvs_dump_date_note_sorted_by_date.bat
[PASS] standalone read_mvs_dump_date_note.bat
[PASS] standalone read_mvs_dump_date_note_sorted_by_id.bat
[PASS] standalone read_mvs_dump_date_note_sorted_by_title.bat
[PASS] standalone read_mvs_dump_date_note_sorted_by_date.bat
[PASS] standalone print_mvs_dump_id_date_note.bat
[PASS] standalone print_mvs_dump_id_date_note_sorted_by_id.bat
[PASS] standalone print_mvs_dump_id_date_note_sorted_by_title.bat
[PASS] standalone print_mvs_dump_id_date_note_sorted_by_date.bat
[PASS] standalone read_mvs_dump_id_date_note.bat
[PASS] standalone read_mvs_dump_id_date_note_sorted_by_id.bat
[PASS] standalone read_mvs_dump_id_date_note_sorted_by_title.bat
[PASS] standalone read_mvs_dump_id_date_note_sorted_by_date.bat
[PASS] standalone lookup_mvs_title_from_id.bat
[PASS] standalone lookup_mvs_title_from_date.bat
[PASS] standalone lookup_mvs_note_from_id.bat
[PASS] standalone lookup_mvs_note_from_title.bat
[PASS] standalone lookup_mvs_note_from_date.bat
[PASS] standalone lookup_mvs_date_from_id.bat
[PASS] standalone lookup_mvs_date_from_title.bat
=== Scalar tool tests ===
[PASS] print_mvs_dump_id
[PASS] print_mvs_dump_id_sorted_by_id
[PASS] print_mvs_dump_id_sorted_by_title
[PASS] print_mvs_dump_id_sorted_by_date
[PASS] read_mvs_dump_id
[PASS] read_mvs_dump_id_sorted_by_id
[PASS] read_mvs_dump_id_sorted_by_title
[PASS] read_mvs_dump_id_sorted_by_date
[PASS] print_mvs_dump_id_title
[PASS] print_mvs_dump_id_title_sorted_by_id
[PASS] print_mvs_dump_id_title_sorted_by_title
[PASS] print_mvs_dump_id_title_sorted_by_date
[PASS] read_mvs_dump_id_title
[PASS] read_mvs_dump_id_title_sorted_by_id
[PASS] read_mvs_dump_id_title_sorted_by_title
[PASS] read_mvs_dump_id_title_sorted_by_date
[PASS] print_mvs_dump_id_date
[PASS] print_mvs_dump_id_date_sorted_by_id
[PASS] print_mvs_dump_id_date_sorted_by_title
[PASS] print_mvs_dump_id_date_sorted_by_date
[PASS] read_mvs_dump_id_date
[PASS] read_mvs_dump_id_date_sorted_by_id
[PASS] read_mvs_dump_id_date_sorted_by_title
[PASS] read_mvs_dump_id_date_sorted_by_date
[PASS] print_mvs_dump_id_note
[PASS] print_mvs_dump_id_note_sorted_by_id
[PASS] print_mvs_dump_id_note_sorted_by_title
[PASS] print_mvs_dump_id_note_sorted_by_date
[PASS] read_mvs_dump_id_note
[PASS] read_mvs_dump_id_note_sorted_by_id
[PASS] read_mvs_dump_id_note_sorted_by_title
[PASS] read_mvs_dump_id_note_sorted_by_date
[PASS] print_mvs_dump_id_title_date
[PASS] print_mvs_dump_id_title_date_sorted_by_id
[PASS] print_mvs_dump_id_title_date_sorted_by_title
[PASS] print_mvs_dump_id_title_date_sorted_by_date
[PASS] read_mvs_dump_id_title_date
[PASS] read_mvs_dump_id_title_date_sorted_by_id
[PASS] read_mvs_dump_id_title_date_sorted_by_title
[PASS] read_mvs_dump_id_title_date_sorted_by_date
[PASS] print_mvs_dump_id_title_note
[PASS] print_mvs_dump_id_title_note_sorted_by_id
[PASS] print_mvs_dump_id_title_note_sorted_by_title
[PASS] print_mvs_dump_id_title_note_sorted_by_date
[PASS] read_mvs_dump_id_title_note
[PASS] read_mvs_dump_id_title_note_sorted_by_id
[PASS] read_mvs_dump_id_title_note_sorted_by_title
[PASS] read_mvs_dump_id_title_note_sorted_by_date
[PASS] print_mvs_dump_id_title_date_note
[PASS] print_mvs_dump_id_title_date_note_sorted_by_id
[PASS] print_mvs_dump_id_title_date_note_sorted_by_title
[PASS] print_mvs_dump_id_title_date_note_sorted_by_date
[PASS] read_mvs_dump_id_title_date_note
[PASS] read_mvs_dump_id_title_date_note_sorted_by_id
[PASS] read_mvs_dump_id_title_date_note_sorted_by_title
[PASS] read_mvs_dump_id_title_date_note_sorted_by_date
[PASS] print_mvs_dump_title
[PASS] print_mvs_dump_title_sorted_by_id
[PASS] print_mvs_dump_title_sorted_by_title
[PASS] print_mvs_dump_title_sorted_by_date
[PASS] read_mvs_dump_title
[PASS] read_mvs_dump_title_sorted_by_id
[PASS] read_mvs_dump_title_sorted_by_title
[PASS] read_mvs_dump_title_sorted_by_date
[PASS] print_mvs_dump_title_date
[PASS] print_mvs_dump_title_date_sorted_by_id
[PASS] print_mvs_dump_title_date_sorted_by_title
[PASS] print_mvs_dump_title_date_sorted_by_date
[PASS] read_mvs_dump_title_date
[PASS] read_mvs_dump_title_date_sorted_by_id
[PASS] read_mvs_dump_title_date_sorted_by_title
[PASS] read_mvs_dump_title_date_sorted_by_date
[PASS] print_mvs_dump_title_note
[PASS] print_mvs_dump_title_note_sorted_by_id
[PASS] print_mvs_dump_title_note_sorted_by_title
[PASS] print_mvs_dump_title_note_sorted_by_date
[PASS] read_mvs_dump_title_note
[PASS] read_mvs_dump_title_note_sorted_by_id
[PASS] read_mvs_dump_title_note_sorted_by_title
[PASS] read_mvs_dump_title_note_sorted_by_date
[PASS] print_mvs_dump_title_date_note
[PASS] print_mvs_dump_title_date_note_sorted_by_id
[PASS] print_mvs_dump_title_date_note_sorted_by_title
[PASS] print_mvs_dump_title_date_note_sorted_by_date
[PASS] read_mvs_dump_title_date_note
[PASS] read_mvs_dump_title_date_note_sorted_by_id
[PASS] read_mvs_dump_title_date_note_sorted_by_title
[PASS] read_mvs_dump_title_date_note_sorted_by_date
[PASS] print_mvs_dump_date
[PASS] print_mvs_dump_date_sorted_by_id
[PASS] print_mvs_dump_date_sorted_by_title
[PASS] print_mvs_dump_date_sorted_by_date
[PASS] read_mvs_dump_date
[PASS] read_mvs_dump_date_sorted_by_id
[PASS] read_mvs_dump_date_sorted_by_title
[PASS] read_mvs_dump_date_sorted_by_date
[PASS] print_mvs_dump_note
[PASS] print_mvs_dump_note_sorted_by_id
[PASS] print_mvs_dump_note_sorted_by_title
[PASS] print_mvs_dump_note_sorted_by_date
[PASS] read_mvs_dump_note
[PASS] read_mvs_dump_note_sorted_by_id
[PASS] read_mvs_dump_note_sorted_by_title
[PASS] read_mvs_dump_note_sorted_by_date
[PASS] print_mvs_dump_date_note
[PASS] print_mvs_dump_date_note_sorted_by_id
[PASS] print_mvs_dump_date_note_sorted_by_title
[PASS] print_mvs_dump_date_note_sorted_by_date
[PASS] read_mvs_dump_date_note
[PASS] read_mvs_dump_date_note_sorted_by_id
[PASS] read_mvs_dump_date_note_sorted_by_title
[PASS] read_mvs_dump_date_note_sorted_by_date
[PASS] print_mvs_dump_id_date_note
[PASS] print_mvs_dump_id_date_note_sorted_by_id
[PASS] print_mvs_dump_id_date_note_sorted_by_title
[PASS] print_mvs_dump_id_date_note_sorted_by_date
[PASS] read_mvs_dump_id_date_note
[PASS] read_mvs_dump_id_date_note_sorted_by_id
[PASS] read_mvs_dump_id_date_note_sorted_by_title
[PASS] read_mvs_dump_id_date_note_sorted_by_date
=== Lookup tool tests ===
[PASS] lookup_mvs_title_from_id [exact: 1]
[PASS] lookup_mvs_title_from_id [wildcard-all: *]
[FAIL] lookup_mvs_title_from_id [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__] - rc expected 1, got 0
[PASS] lookup_mvs_title_from_date [exact: 2004-06-01T16:55:00]
[PASS] lookup_mvs_title_from_date [wildcard-all: *]
[FAIL] lookup_mvs_title_from_date [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__] - rc expected 1, got 0
[PASS] lookup_mvs_note_from_id [exact: 18]
[PASS] lookup_mvs_note_from_id [wildcard-all: *]
[FAIL] lookup_mvs_note_from_id [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__] - rc expected 1, got 0
[PASS] lookup_mvs_note_from_title [exact: Groove 2007]
[PASS] lookup_mvs_note_from_title [wildcard-all: *]
[FAIL] lookup_mvs_note_from_title [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__] - rc expected 1, got 0
[PASS] lookup_mvs_note_from_date [exact: 2007-07-03T20:26:24]
[PASS] lookup_mvs_note_from_date [wildcard-all: *]
[FAIL] lookup_mvs_note_from_date [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__] - rc expected 1, got 0
[PASS] lookup_mvs_date_from_id [exact: 1]
[PASS] lookup_mvs_date_from_id [wildcard-all: *]
[FAIL] lookup_mvs_date_from_id [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__] - rc expected 1, got 0
[PASS] lookup_mvs_date_from_title [exact: Access 2.0]
[PASS] lookup_mvs_date_from_title [wildcard-all: *]
[FAIL] lookup_mvs_date_from_title [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__] - rc expected 1, got 0
[PASS] lookup_mvs_title_from_id [prefix-wildcard: 1*]
[PASS] lookup_mvs_title_from_id [suffix-wildcard: *0]
[PASS] lookup_mvs_title_from_id [contains-wildcard: *1*]

SUMMARY: passed=265 failed=7 skipped=0
Results: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.5.0\test\test-results-20260827-111852

C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.5.0>
```

```text
see attached results file
```

Attached result archive: `test-results-20260827-111852.zip`.
