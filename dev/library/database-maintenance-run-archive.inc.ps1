$staging=Join-Path $SlotRoot ('archive-analysis.staging-'+$RunId)
if(   -not   (Test-Path -LiteralPath (Join-Path $staging 'update-state.json') -PathType Leaf)){throw ('Prepared staging state missing: '+$staging)}
$state=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $staging 'update-state.json')))
Write-Line ('Updating archive analysis: pending checks='+$state.pending_checks+', already seeded='+$state.seeded_checks+'.')
$sweep=Join-Path $ProjectRoot 'test\test_all_dumps.bat'
$cache=Join-Path $SlotRoot 'cache'
Invoke-BatChecked $sweep @($ArchiveRoot,$staging,'--resume','--workers',[string]$Workers,'--cache-folder',$cache) 'archive analysis update'
$quality=Join-Path $ProjectRoot 'test\check_archive_sweep_quality.bat'
Invoke-BatChecked $quality @($staging) 'archive quality validation'
$current=Join-Path $SlotRoot 'archive-analysis'
Swap-Directory $staging $current
Write-Utf8 (Join-Path $SlotRoot 'source-path.txt') ($ArchiveRoot+"`r`n")
Write-Utf8 (Join-Path $SlotRoot 'archive-name.txt') ((Split-Path -Leaf $ArchiveRoot)+"`r`n")
Write-Utf8 (Join-Path $SlotRoot 'last-archive-update.txt') ((Get-Date).ToString('o')+"`r`n")
Write-Line ('Archive analysis committed: '+$current)
