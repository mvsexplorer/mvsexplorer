Ensure-Directory $DatabaseRoot
Ensure-Directory $SlotRoot
$status=if([string]::IsNullOrWhiteSpace($Extra)){'PASS'}else{$Extra.ToUpperInvariant()}
$archive=Join-Path $SlotRoot 'archive-analysis'
$full=Join-Path $SlotRoot 'family-index'
$compact=Join-Path $SlotRoot 'compact-index'
$sourceSnapshots=@(Get-SnapshotDirectories $ArchiveRoot|Select-Object -ExpandProperty Name)
$dbSnapshots=@()
$planned=0;$completed=0;$fail=0
if(Test-Path -LiteralPath (Join-Path $archive 'snapshots.tsv') -PathType Leaf){$dbSnapshots=@(Import-Csv -LiteralPath (Join-Path $archive 'snapshots.tsv') -Delimiter "`t"|ForEach-Object{[string]$_.snapshot})}
if(Test-Path -LiteralPath (Join-Path $archive 'plan.tsv') -PathType Leaf){$planned=@(Import-Csv -LiteralPath (Join-Path $archive 'plan.tsv') -Delimiter "`t").Count}
if(Test-Path -LiteralPath (Join-Path $archive 'runs.tsv') -PathType Leaf){$runs=@(Import-Csv -LiteralPath (Join-Path $archive 'runs.tsv') -Delimiter "`t");$completed=$runs.Count;$fail=@($runs|Where-Object{$_.status   -eq   'FAIL'}).Count}
$validation=''
if(Test-Path -LiteralPath (Join-Path $SlotRoot 'validation-status.txt') -PathType Leaf){$validation=((Get-Content -LiteralPath (Join-Path $SlotRoot 'validation-status.txt') -First 1).Trim())}
$html=''
if(Test-Path -LiteralPath (Join-Path $SlotRoot 'latest-html.txt') -PathType Leaf){$html=([IO.File]::ReadAllText((Join-Path $SlotRoot 'latest-html.txt'))).Trim()}
$state=[ordered]@{
    database_format='mvs_databases/1';project_version=$Version;run_id=$RunId;updated=(Get-Date).ToString('o');status=$status;
    slot=(Split-Path -Leaf $SlotRoot);archive_name=(Split-Path -Leaf $ArchiveRoot);archive_path=$ArchiveRoot;
    source_snapshots=$sourceSnapshots.Count;database_snapshots=$dbSnapshots.Count;planned_checks=$planned;completed_checks=$completed;fail_checks=$fail;
    archive_database=$archive;family_database=$full;compact_database=$compact;validation=$validation;latest_html=$html
}
Write-Utf8 (Join-Path $SlotRoot 'database-state.json') ((ConvertTo-Json $state -Depth 5)+"`r`n")
$states=New-Object System.Collections.ArrayList
foreach($slotDir in @(Get-ChildItem -LiteralPath $DatabaseRoot -Directory -ErrorAction SilentlyContinue|Sort-Object Name)){
    $sp=Join-Path $slotDir.FullName 'database-state.json'
    if(Test-Path -LiteralPath $sp -PathType Leaf){try{[void]$states.Add((ConvertFrom-Json ([IO.File]::ReadAllText($sp))))}catch{}}
}
$overall=if(@($states|Where-Object{$_.status   -ne   'PASS'}).Count  -gt  0){'FAIL'}else{'PASS'}
$summary=[ordered]@{database_format='mvs_databases/1';project_version=$Version;updated=(Get-Date).ToString('o');status=$overall;archive_count=$states.Count;archives=@($states)}
Write-Utf8 (Join-Path $DatabaseRoot 'database-summary.json') ((ConvertTo-Json $summary -Depth 8)+"`r`n")
Write-Utf8 (Join-Path $DatabaseRoot 'README.txt') ("MVS Explorer Toolkit maintained databases`r`nDatabase format: mvs_databases/1`r`nUpdated: "+(Get-Date).ToString('o')+"`r`nUse display_mvs_database_summary.bat for health/completeness.`r`n")
Write-Line ('Database state updated: '+(Join-Path $SlotRoot 'database-state.json'))

$familyMarker=Join-Path $SlotRoot ('family-rebuilt-'+$RunId+'.flag')
if(Test-Path -LiteralPath $familyMarker -PathType Leaf){Remove-Item -LiteralPath $familyMarker -Force}
