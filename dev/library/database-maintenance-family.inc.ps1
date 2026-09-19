$archiveAnalysis=Join-Path $SlotRoot 'archive-analysis'
if(   -not   (Test-Path -LiteralPath $archiveAnalysis -PathType Container)){throw 'Committed archive analysis is missing.'}
$tool=Join-Path $ProjectRoot 'tools\build_mvs_product_family_index.bat'
$toolHash=Get-Sha256File $tool
$hashPath=Join-Path $SlotRoot 'family-toolset-sha256.txt'
$oldHash=if(Test-Path -LiteralPath $hashPath -PathType Leaf){([IO.File]::ReadAllText($hashPath)).Trim()}else{''}
$current=Join-Path $SlotRoot 'family-index'
$statePath=Join-Path $archiveAnalysis 'update-state.json'
$pending=1
if(Test-Path -LiteralPath $statePath -PathType Leaf){$pending=[int](ConvertFrom-Json ([IO.File]::ReadAllText($statePath))).pending_checks}
$need=($pending -gt 0)   -or   (   -not   (Test-Path -LiteralPath $current -PathType Container))   -or   (   -not   [StringComparer]::Ordinal.Equals($oldHash,$toolHash))
$marker=Join-Path $SlotRoot ('family-rebuilt-'+$RunId+'.flag')
if(Test-Path -LiteralPath $marker){Remove-Item -LiteralPath $marker -Force}
if(   -not   $need){
    Write-Line 'Already done: full product-family database is current.'
    [Environment]::Exit(0)
}
$staging=Join-Path $SlotRoot ('family-index.staging-'+$RunId)
foreach($oldStage in @(Get-ChildItem -LiteralPath $SlotRoot -Directory -Filter 'family-index.staging-*' -ErrorAction SilentlyContinue)){Remove-Item -LiteralPath $oldStage.FullName -Recurse -Force}
Write-Line 'Building full product-family evidence database ...'
Invoke-BatChecked $tool @($ArchiveRoot,$staging) 'full product-family builder'
Swap-Directory $staging $current
Write-Utf8 $hashPath ($toolHash+"`r`n")
Write-Utf8 $marker "rebuilt`r`n"
Write-Line ('Full product-family database committed: '+$current)
