$staging=Join-Path $SlotRoot ('archive-analysis.staging-'+$RunId)
if(   -not   (Test-Path -LiteralPath (Join-Path $staging 'update-state.json') -PathType Leaf)){throw ('Prepared staging state missing: '+$staging)}
$state=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $staging 'update-state.json')))
Write-Line ('Updating archive analysis: pending checks='+$state.pending_checks+', already seeded='+$state.seeded_checks+'.')
$current=Join-Path $SlotRoot 'archive-analysis'
if(([int]$state.pending_checks -eq 0) -and ([bool]$state.archive_reused) -and (Test-Path -LiteralPath $current -PathType Container)){
    foreach($name in @('source-fingerprints.tsv','toolset-sha256.txt','update-state.json')){
        $fresh=Join-Path $staging $name
        if(Test-Path -LiteralPath $fresh -PathType Leaf){Copy-Item -LiteralPath $fresh -Destination (Join-Path $current $name) -Force}
    }
    Write-Utf8 (Join-Path $SlotRoot 'source-path.txt') ($ArchiveRoot+"`r`n")
    Write-Utf8 (Join-Path $SlotRoot 'archive-name.txt') ((Split-Path -Leaf $ArchiveRoot)+"`r`n")
    Write-Utf8 (Join-Path $SlotRoot 'last-archive-update.txt') ((Get-Date).ToString('o')+"`r`n")
    Remove-Item -LiteralPath $staging -Recurse -Force
    Write-Line 'Already done: committed archive analysis is current; no archive processing required.'
    [Environment]::Exit(0)
}
$sweep=Join-Path $ProjectRoot 'test\test_all_dumps.bat'
$cache=Join-Path $SlotRoot 'cache'
$workerArgs=if($WorkerMode -eq 'fixed'){@('--workers',[string]$WorkerStart)}else{@('--start-workers',[string]$WorkerStart,'--max-workers',[string]$WorkerMax)}
Invoke-BatChecked $sweep (@($ArchiveRoot,$staging,'--resume')+@($workerArgs)+@('--cache-folder',$cache)) 'archive analysis update'
$quality=Join-Path $ProjectRoot 'test\check_archive_sweep_quality.bat'
Invoke-BatChecked $quality @($staging) 'archive quality validation'
Swap-Directory $staging $current
Write-Utf8 (Join-Path $SlotRoot 'source-path.txt') ($ArchiveRoot+"`r`n")
Write-Utf8 (Join-Path $SlotRoot 'archive-name.txt') ((Split-Path -Leaf $ArchiveRoot)+"`r`n")
Write-Utf8 (Join-Path $SlotRoot 'last-archive-update.txt') ((Get-Date).ToString('o')+"`r`n")
Write-Line ('Archive analysis committed: '+$current)
