$compact=Join-Path $SlotRoot 'compact-index'
if(   -not   (Test-Path -LiteralPath $compact -PathType Container)){throw 'Compact database is missing.'}
$slot=Split-Path -Leaf $SlotRoot
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$output=Join-Path $ProjectRoot ('mvs-browser-'+$slot+'-'+$stamp+'.html')
$builder=Join-Path $ProjectRoot 'tools\build_mvs_html_browser.bat'
Invoke-BatChecked $builder @($compact,$output) 'self-contained HTML browser builder'
Write-Utf8 (Join-Path $SlotRoot 'latest-html.txt') ($output+"`r`n")
Write-Line ('HTML browser: '+$output)
