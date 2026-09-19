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

## Prompt 8

```text
ok here's the output and see results attached

C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.6.0>test\test_all.bat ..\mvs_dumps_archive\mvs_2020-09-15_2
Test results: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.6.0\test\test-results-20260827-122202
Dump: C:\Users\user\Downloads\mvs_dumps_archive\mvs_2020-09-15_2
Products parsed for expectations: 1984
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
[PASS] lookup_mvs_title_from_id [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]
[PASS] lookup_mvs_title_from_date [exact: 2004-06-01T16:55:00]
[PASS] lookup_mvs_title_from_date [wildcard-all: *]
[PASS] lookup_mvs_title_from_date [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]
[PASS] lookup_mvs_note_from_id [exact: 18]
[PASS] lookup_mvs_note_from_id [wildcard-all: *]
[PASS] lookup_mvs_note_from_id [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]
[PASS] lookup_mvs_note_from_title [exact: Groove 2007]
[PASS] lookup_mvs_note_from_title [wildcard-all: *]
[PASS] lookup_mvs_note_from_title [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]
[PASS] lookup_mvs_note_from_date [exact: 2007-07-03T20:26:24]
[PASS] lookup_mvs_note_from_date [wildcard-all: *]
[PASS] lookup_mvs_note_from_date [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]
[PASS] lookup_mvs_date_from_id [exact: 1]
[PASS] lookup_mvs_date_from_id [wildcard-all: *]
[PASS] lookup_mvs_date_from_id [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]
[PASS] lookup_mvs_date_from_title [exact: Access 2.0]
[PASS] lookup_mvs_date_from_title [wildcard-all: *]
[PASS] lookup_mvs_date_from_title [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]
[PASS] lookup_mvs_title_from_id [prefix-wildcard: 1*]
[PASS] lookup_mvs_title_from_id [suffix-wildcard: *0]
[PASS] lookup_mvs_title_from_id [contains-wildcard: *1*]

SUMMARY: passed=272 failed=0 skipped=0
Results: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.6.0\test\test-results-20260827-122202

C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.6.0>
```

Attached result archive: `test-results-20260827-122202.zip`.

## Prompt 9

```text
Ok great
next I want 
find_mvs_duplicate_id_in_mvs.txt.bat
find_mvs_duplicate_id_in_mvs_dates.txt.bat
find_mvs_duplicate_id_in_mvs_ids.txt.bat
find_mvs_duplicate_id_in_mvs_names.txt.bat
find_mvs_duplicate_id_in_mvs_notes.html.bat
This should search all files that have id so mvs.txt  mvs_dates.txt and mvs_ids.txt
for each file, are there duplicate id, and if so, print them both with the title, or the date or or the hash or the note of each duplicate depending on which file it is 

in the case of mvs.txt and mvs_names.txt, those ID come with a series of lines associated with it , if duplicates are found, print the ID, title and all associated lines after until the next empty line

and also we will need the same but for the properties other than ID
find_mvs_duplicate_title_in_mvs.txt.bat
find_mvs_duplicate_title_in_mvs_dates.txt.bat
find_mvs_duplicate_title_in_mvs_ids.txt.bat
find_mvs_duplicate_title_in_mvs_names.txt.bat
find_mvs_duplicate_title_in_mvs_notes.html.bat
and
find_mvs_duplicate_date_in_mvs_date.txt.bat
find_mvs_duplicate_filename_in_mvs_names.txt.bat  (print their associated title & id)
find_mvs_duplicate_filename_in_mvs.txt.bat   (print their associated title & id)

we will also need 
find_mvs_orphan
these will look for a value that should be referenced in another document

example 
find_mvs_orphan_id_from_mvs_ids.txt_in_mvs_dates.txt.bat
so for each id in mvs_ids.txt, search in mvs_date.txt if there is one or not, if not that is an orphan to report
and there are other like this
find_mvs_orphan_id_from_mvs_ids.txt_in_mvs.txt.bat
find_mvs_orphan_id_from_mvs_ids.txt_in_mvs_dates.txt.bat
find_mvs_orphan_id_from_mvs_ids.txt_in_mvs_names.txt.bat
(the id aren't used in mvs_notes.html)

and for the other variables as well 
find_mvs_orphan_title_from_mvs_ids.txt_in_mvs.txt.bat
find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_dates.txt.bat
find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_names.txt.bat
find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_names.txt.bat
find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_notes.html.bat

and it other directions
find_mvs_orphan_id_from_mvs_dates.txt_in_mvs.txt.bat
find_mvs_orphan_id_from_mvs_dates.txt_in_mvs_ids.txt.bat
find_mvs_orphan_id_from_mvs_dates.txt_in_mvs_names.txt.bat
find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs.txt.bat
find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs_ids.txt.bat
find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs_names.txt.bat

find_mvs_orphan_id_from_mvs.txt_in_mvs_ids.txt.bat
find_mvs_orphan_id_from_mvs.txt_in_mvs_dates.txt.bat
find_mvs_orphan_id_from_mvs.txt_in_mvs_names.txt.bat
find_mvs_orphan_titles_from_mvs.txt_in_mvs_ids.txt.bat
find_mvs_orphan_titles_from_mvs.txt_in_mvs_dates.txt.bat
find_mvs_orphan_titles_from_mvs.txt_in_mvs_names.txt.bat

find_mvs_orphan_id_from_mvs_names.txt_in_mvs.txt.bat
find_mvs_orphan_id_from_mvs_names.txt_in_mvs_ids.txt.bat
find_mvs_orphan_id_from_mvs_names.txt_in_mvs_dates.txt.bat
find_mvs_orphan_titles_from_mvs_names.txt_in_mvs.txt.bat
find_mvs_orphan_titles_from_mvs_names.txt_in_mvs_ids.txt.bat
find_mvs_orphan_titles_from_mvs_names.txt_in_mvs_dates.txt.bat

find_mvs_orphan_filenames_from_mvs.txt_in_mvs_names.txt.bat
find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.txt.bat
find_mvs_orphan_filenames_from_mvs.txt_in_mvs.sha1.bat
find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.sha1.bat
find_mvs_orphan_filenames_from_mvs.txt_in_mvs.sha256.bat
find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.sha256.bat

and create the tests for these new files
also create test mvs dump in test\ designed find test all these functions
```

## Prompt 10

```text
Ok here are the results

```

```text
C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.7.0>test\test_all.bat ..\mvs_dumps_archive\mvs_2020-10-20
Test results: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.7.0\test\test-results-20260827-141412
Dump: C:\Users\user\Downloads\mvs_dumps_archive\mvs_2020-10-20
Products parsed for expectations: 1990
=== Structure tests ===
[PASS] root public .bat count = 172
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
[PASS] standalone find_mvs_duplicate_id_in_mvs.txt.bat
[PASS] standalone find_mvs_duplicate_id_in_mvs_dates.txt.bat
[PASS] standalone find_mvs_duplicate_id_in_mvs_ids.txt.bat
[PASS] standalone find_mvs_duplicate_id_in_mvs_names.txt.bat
[PASS] standalone find_mvs_duplicate_id_in_mvs_notes.html.bat
[PASS] standalone find_mvs_duplicate_title_in_mvs.txt.bat
[PASS] standalone find_mvs_duplicate_title_in_mvs_dates.txt.bat
[PASS] standalone find_mvs_duplicate_title_in_mvs_ids.txt.bat
[PASS] standalone find_mvs_duplicate_title_in_mvs_names.txt.bat
[PASS] standalone find_mvs_duplicate_title_in_mvs_notes.html.bat
[PASS] standalone find_mvs_duplicate_date_in_mvs_date.txt.bat
[PASS] standalone find_mvs_duplicate_date_in_mvs_dates.txt.bat
[PASS] standalone find_mvs_duplicate_filename_in_mvs_names.txt.bat
[PASS] standalone find_mvs_duplicate_filename_in_mvs.txt.bat
[PASS] standalone find_mvs_orphan_id_from_mvs_ids.txt_in_mvs.txt.bat
[PASS] standalone find_mvs_orphan_id_from_mvs_ids.txt_in_mvs_dates.txt.bat
[PASS] standalone find_mvs_orphan_id_from_mvs_ids.txt_in_mvs_names.txt.bat
[PASS] standalone find_mvs_orphan_title_from_mvs_ids.txt_in_mvs.txt.bat
[PASS] standalone find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_dates.txt.bat
[PASS] standalone find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_names.txt.bat
[PASS] standalone find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_notes.html.bat
[PASS] standalone find_mvs_orphan_id_from_mvs_dates.txt_in_mvs.txt.bat
[PASS] standalone find_mvs_orphan_id_from_mvs_dates.txt_in_mvs_ids.txt.bat
[PASS] standalone find_mvs_orphan_id_from_mvs_dates.txt_in_mvs_names.txt.bat
[PASS] standalone find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs.txt.bat
[PASS] standalone find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs_ids.txt.bat
[PASS] standalone find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs_names.txt.bat
[PASS] standalone find_mvs_orphan_id_from_mvs.txt_in_mvs_ids.txt.bat
[PASS] standalone find_mvs_orphan_id_from_mvs.txt_in_mvs_dates.txt.bat
[PASS] standalone find_mvs_orphan_id_from_mvs.txt_in_mvs_names.txt.bat
[PASS] standalone find_mvs_orphan_titles_from_mvs.txt_in_mvs_ids.txt.bat
[PASS] standalone find_mvs_orphan_titles_from_mvs.txt_in_mvs_dates.txt.bat
[PASS] standalone find_mvs_orphan_titles_from_mvs.txt_in_mvs_names.txt.bat
[PASS] standalone find_mvs_orphan_id_from_mvs_names.txt_in_mvs.txt.bat
[PASS] standalone find_mvs_orphan_id_from_mvs_names.txt_in_mvs_ids.txt.bat
[PASS] standalone find_mvs_orphan_id_from_mvs_names.txt_in_mvs_dates.txt.bat
[PASS] standalone find_mvs_orphan_titles_from_mvs_names.txt_in_mvs.txt.bat
[PASS] standalone find_mvs_orphan_titles_from_mvs_names.txt_in_mvs_ids.txt.bat
[PASS] standalone find_mvs_orphan_titles_from_mvs_names.txt_in_mvs_dates.txt.bat
[PASS] standalone find_mvs_orphan_filenames_from_mvs.txt_in_mvs_names.txt.bat
[PASS] standalone find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.txt.bat
[PASS] standalone find_mvs_orphan_filenames_from_mvs.txt_in_mvs.sha1.bat
[PASS] standalone find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.sha1.bat
[PASS] standalone find_mvs_orphan_filenames_from_mvs.txt_in_mvs.sha256.bat
[PASS] standalone find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.sha256.bat
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
[PASS] lookup_mvs_title_from_id [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]
[PASS] lookup_mvs_title_from_date [exact: 2004-06-01T16:55:00]
[PASS] lookup_mvs_title_from_date [wildcard-all: *]
[PASS] lookup_mvs_title_from_date [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]
[PASS] lookup_mvs_note_from_id [exact: 18]
[PASS] lookup_mvs_note_from_id [wildcard-all: *]
[PASS] lookup_mvs_note_from_id [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]
[PASS] lookup_mvs_note_from_title [exact: Groove 2007]
[PASS] lookup_mvs_note_from_title [wildcard-all: *]
[PASS] lookup_mvs_note_from_title [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]
[PASS] lookup_mvs_note_from_date [exact: 2007-07-03T20:26:24]
[PASS] lookup_mvs_note_from_date [wildcard-all: *]
[PASS] lookup_mvs_note_from_date [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]
[PASS] lookup_mvs_date_from_id [exact: 1]
[PASS] lookup_mvs_date_from_id [wildcard-all: *]
[PASS] lookup_mvs_date_from_id [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]
[PASS] lookup_mvs_date_from_title [exact: Access 2.0]
[PASS] lookup_mvs_date_from_title [wildcard-all: *]
[PASS] lookup_mvs_date_from_title [no-match: __MVS_TEST_NO_MATCH_9E3779B97F4A7C15__]
[PASS] lookup_mvs_title_from_id [prefix-wildcard: 1*]
[PASS] lookup_mvs_title_from_id [suffix-wildcard: *0]
[PASS] lookup_mvs_title_from_id [contains-wildcard: *1*]
=== Duplicate/orphan diagnostic tests ===
[PASS] diagnostic synthetic dump present
[PASS] find_mvs_duplicate_id_in_mvs.txt
[PASS] find_mvs_duplicate_id_in_mvs_dates.txt
[PASS] find_mvs_duplicate_id_in_mvs_ids.txt
[PASS] find_mvs_duplicate_id_in_mvs_names.txt
[PASS] find_mvs_duplicate_id_in_mvs_notes.html
[PASS] find_mvs_duplicate_title_in_mvs.txt
[PASS] find_mvs_duplicate_title_in_mvs_dates.txt
[PASS] find_mvs_duplicate_title_in_mvs_ids.txt
[PASS] find_mvs_duplicate_title_in_mvs_names.txt
[PASS] find_mvs_duplicate_title_in_mvs_notes.html
[PASS] find_mvs_duplicate_date_in_mvs_date.txt
[PASS] find_mvs_duplicate_date_in_mvs_dates.txt
[PASS] find_mvs_duplicate_filename_in_mvs_names.txt
[PASS] find_mvs_duplicate_filename_in_mvs.txt
[PASS] find_mvs_orphan_id_from_mvs_ids.txt_in_mvs.txt
[PASS] find_mvs_orphan_id_from_mvs_ids.txt_in_mvs_dates.txt
[PASS] find_mvs_orphan_id_from_mvs_ids.txt_in_mvs_names.txt
[PASS] find_mvs_orphan_title_from_mvs_ids.txt_in_mvs.txt
[PASS] find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_dates.txt
[PASS] find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_names.txt
[PASS] find_mvs_orphan_title_from_mvs_ids.txt_in_mvs_notes.html
[PASS] find_mvs_orphan_id_from_mvs_dates.txt_in_mvs.txt
[PASS] find_mvs_orphan_id_from_mvs_dates.txt_in_mvs_ids.txt
[PASS] find_mvs_orphan_id_from_mvs_dates.txt_in_mvs_names.txt
[PASS] find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs.txt
[PASS] find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs_ids.txt
[PASS] find_mvs_orphan_titles_from_mvs_dates.txt_in_mvs_names.txt
[PASS] find_mvs_orphan_id_from_mvs.txt_in_mvs_ids.txt
[PASS] find_mvs_orphan_id_from_mvs.txt_in_mvs_dates.txt
[PASS] find_mvs_orphan_id_from_mvs.txt_in_mvs_names.txt
[PASS] find_mvs_orphan_titles_from_mvs.txt_in_mvs_ids.txt
[PASS] find_mvs_orphan_titles_from_mvs.txt_in_mvs_dates.txt
[PASS] find_mvs_orphan_titles_from_mvs.txt_in_mvs_names.txt
[PASS] find_mvs_orphan_id_from_mvs_names.txt_in_mvs.txt
[PASS] find_mvs_orphan_id_from_mvs_names.txt_in_mvs_ids.txt
[PASS] find_mvs_orphan_id_from_mvs_names.txt_in_mvs_dates.txt
[PASS] find_mvs_orphan_titles_from_mvs_names.txt_in_mvs.txt
[PASS] find_mvs_orphan_titles_from_mvs_names.txt_in_mvs_ids.txt
[PASS] find_mvs_orphan_titles_from_mvs_names.txt_in_mvs_dates.txt
[PASS] find_mvs_orphan_filenames_from_mvs.txt_in_mvs_names.txt
[PASS] find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.txt
[PASS] find_mvs_orphan_filenames_from_mvs.txt_in_mvs.sha1
[PASS] find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.sha1
[PASS] find_mvs_orphan_filenames_from_mvs.txt_in_mvs.sha256
[PASS] find_mvs_orphan_filenames_from_mvs_names.txt_in_mvs.sha256

SUMMARY: passed=363 failed=0 skipped=0
Results: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.7.0\test\test-results-20260827-141412

C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.7.0>
```

```text
and results attached
```

Attached result archive: `test-results-20260827-141412.zip`.

## Prompt 11

```text
Ok, now I'd like to have the print_* script which also obtain the filenames and the hashes

so for an id or title 
we get filenames and from filenames we can get hashes, 
hashes from mvs.txt and from mvs.sha1

we should also be able to do the reverse from the sha1 and sha256 hash print the filename and then print the title and/or id and/or date

so print_mvs_dump_ or read_mvs_dump_
print_mvs_dump_id_from_filename
print_mvs_dump_title_from_filename
print_mvs_dump_date_from_filename
print_mvs_dump_note_from_filename
print_mvs_dump_filenames_from_filename
print_mvs_dump_id_title_from_filename
print_mvs_dump_id_date_from_filename
print_mvs_dump_id_title_date_from_filename
print_mvs_dump_id_title_note_from_filename
print_mvs_dump_id_title_date_note_from_filename
print_mvs_dump_title_from_filename
print_mvs_dump_title_date_from_filename
print_mvs_dump_title_note_from_filename
print_mvs_dump_title_date_note_from_filename
print_mvs_dump_date_note_from_filename

print_mvs_dump_id_title_filenames_from_filename
print_mvs_dump_id_date_filenames_from_filename
print_mvs_dump_id_title_date_filenames_from_filename
print_mvs_dump_id_title_note_filenames_from_filename
print_mvs_dump_id_title_date_note_filenames_from_filename
print_mvs_dump_title_filenames_from_filename
print_mvs_dump_title_date_filenames_from_filename
print_mvs_dump_title_note_filenames_from_filename
print_mvs_dump_title_date_note_filenames_from_filename
print_mvs_dump_date_note_filenames_from_filename
print_mvs_dump_id_from_hash
print_mvs_dump_title_from_hash
print_mvs_dump_date_from_hash
print_mvs_dump_note_from_hash
print_mvs_dump_filenames_from_hash
print_mvs_dump_id_title_from_hash
print_mvs_dump_id_date_from_hash
print_mvs_dump_id_title_date_from_hash
print_mvs_dump_id_title_note_from_hash
print_mvs_dump_id_title_date_note_from_hash
print_mvs_dump_title_from_hash
print_mvs_dump_title_date_from_hash
print_mvs_dump_title_note_from_hash
print_mvs_dump_title_date_note_from_hash
print_mvs_dump_date_note_from_hash
print_mvs_dump_id_title_filenames_from_hash
print_mvs_dump_id_date_filenames_from_hash
print_mvs_dump_id_title_date_filenames_from_hash
print_mvs_dump_id_title_note_filenames_from_hash
print_mvs_dump_id_title_date_note_filenames_from_hash
print_mvs_dump_title_filenames_from_hash
print_mvs_dump_title_date_filenames_from_hash
print_mvs_dump_title_note_filenames_from_hash
print_mvs_dump_title_date_note_filenames_from_hash
print_mvs_dump_date_note_filenames_from_hash

and add all the tests for this as well
```

## Prompt 13

```text
Ok create all suggestion and all versions implied by them
```

## Prompt 14

```text
Ok I want running the output on this particular dump, but there were errors

[Two complete/partial Windows 0.9.0 test console transcripts were supplied:
 mvs_2019-10-16 and mvs_2020-09-23.]

So I ran it on another random dump

and it gave these results

[Second console transcript.]

and I attach both sets of results
```

The exact persisted test artifacts are analyzed in
`doc\test-run-analysis-0.9.0.md`; the uploaded archive contains the full
console logs and per-failure stderr files.

## Prompt 15

```text
here are the results

[Complete Windows 0.9.1 test_all console transcript supplied for
 mvs_2019-10-16.]

SUMMARY: passed=762 failed=166 skipped=3
Results: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.9.1\test\test-results-20260827-173744
```

All 166 single-dump failures in the supplied transcript reported return code 5
and `ERROR: You cannot call a method on a null-valued expression.` The
transcript is analyzed in `doc\test-run-analysis-0.9.1.md`.



## Prompt 16

```text
results

[Complete Windows 0.9.2 test_all console transcript supplied for
 mvs_2020-04-21.]

SUMMARY: passed=928 failed=0 skipped=3
Results: C:\Users\user\Downloads\MVS-Explorer-Toolkit-0.9.2\test\test-results-20260827-180704
```

The attached timestamped result archive is analyzed in
`doc\test-run-analysis-0.9.2.md` and establishes 0.9.2 as the clean
single-dump Windows baseline.

## Prompt 17

```text
Ok now we need
compare_mvs_dump_id_from_mvs.txt.bat
compare_mvs_dump_id_from_mvs_ids.txt.bat
compare_mvs_dump_id_from_mvs_names.txt.bat
compare_mvs_dump_id_from_mvs_names.txt.bat
and parameter are going to be two mvs dump folders
if something is in the first but not the second, we consider that removed
it will be in red, and start with a - sign
if something is not in the first but in the second that is added, and it will be in green and start with a plus sign
output is just what is removed and then what is added

and also for titles
compare_mvs_dump_title_from_mvs.txt.bat
compare_mvs_dump_title_from_mvs_ids.txt.bat
compare_mvs_dump_title_from_mvs_names.txt.bat
compare_mvs_dump_title_from_mvs_dates.txt.bat
and dates ?
compare_mvs_dump_dates_from_mvs_dates.txt.bat

and the sha1 the sha256 and the filenames
and create tests
```

The repeated `mvs_names.txt` ID entry is implemented once; the natural
`mvs_dates.txt` ID comparison is supplied as the fourth source-specific ID
form. SHA-1/SHA-256 and filename comparisons are expanded across every source
that actually contains the corresponding value type.


## 2026-08-27 — Archive added/removed records and all-ever accumulation

> Ok now we will need two things
> I want to create tool that, for each piece of data, create a record of everything added from dump to dump
> a record of everything removed from dump to dump
> and also something that will accumulate all the addition from dump to dump, to each of the values, so that we end up with the most complete record of all


## Prompt 18

```text
Ok, now I want to run all the tools on all the dumps

[The complete tree of the 79-snapshot mvs_dumps_archive was supplied,
including the two nested mvs_dmp snapshots.]
```

This request is implemented as the scope-aware `test\test_all_dumps.bat`
archive sweep rather than a blind one-argument loop. The current public surface
produces 34,822 planned invocations across the supplied archive.

## 2026-08-28 — Fast sweep Windows parser failure

> test\test_fast_archive_sweep.bat
> [FAIL] fast-combined sweep
> ...
> Exception calling "Create" with "1" argument(s):
> Missing closing ')' in expression.


## 2026-08-29 — Archive tail appears stuck after resume

> Planned invocations: 34822
> Already completed: 34820
> === Archive builders [literal] ===
>
> It seems to be stuck here for a couple hours already.

The attached result bundle confirmed indices 1-34820 were committed with zero
FAIL rows; only the two archive-wide builder rows remained. This led to the
0.13.3 one-pass fast archive worker.

## 2026-08-30 — Archive evolution, non-destructive exclusions, frequent testing, and HTML sanity report

> I want to understand how much of what kind of data did each dump add to the running total.
> I want to discover duplication and dumps where the same products may have entirely new IDs.
> I may add an exclusion list for known bad dumps, but I need to know whether excluded dumps contain information not in later dumps.
> Notes may be unique to one dump, so capture each unique note as completely as possible.
> This must work with future dumps, run faster on fresh/repeated tests, and produce an interactive HTML summary.

## 2026-08-30 — Comprehensive performance regression loop

> Include a tester bat which runs test on all tools including quality and performance checking so performance outliers can be found and optimized and the test run again to ensure no regression.
> Include the suggested optimizations, interactive HTML report, and the other suggested additions.

## 2026-09-07 - native 0.16.4 acceptance, performance, and hash stability

The user supplied the native Windows resume result for 0.16.4. The run passed
487/487 structure checks, archive quality reported zero errors, the
generated-database validator passed 57/57 including all 32 family-query tools,
all three database ZIP phases passed, the deferred log ZIP completed after
writer disposal, and the final pipeline status was PASS.

Follow-up directive:

> Do what you can to improve performance and also resolve the over stringent hash check, which I suspect might be hashing dates or something

Development response for 0.16.5 therefore targets the real retained
family-query timings first and treats ZIP timestamps as packaging metadata
without weakening content-addressed evidence hashes.

