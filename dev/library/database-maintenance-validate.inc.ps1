$archive=Join-Path $SlotRoot 'archive-analysis'
$full=Join-Path $SlotRoot 'family-index'
$compact=Join-Path $SlotRoot 'compact-index'
foreach($pair in @(@('archive',$archive),@('family',$full),@('compact',$compact))){if(   -not   (Test-Path -LiteralPath $pair[1] -PathType Container)){throw ($pair[0]+' database missing: '+$pair[1])}}
$validationDir=Join-Path (Join-Path $RunLogs (Split-Path -Leaf $SlotRoot)) 'database-validation'
Ensure-Directory $validationDir
$validator=Join-Path $ProjectRoot 'test\test_generated_databases.bat'
Invoke-BatChecked $validator @($archive,$full,$compact,$validationDir,$Version) 'database validator and family-query smoke test'
Write-Utf8 (Join-Path $SlotRoot 'validation-status.txt') ("PASS`r`n"+(Get-Date).ToString('o')+"`r`n")
Write-Line 'Database validation: PASS.'
