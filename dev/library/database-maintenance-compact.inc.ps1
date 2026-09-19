$full=Join-Path $SlotRoot 'family-index'
if(   -not   (Test-Path -LiteralPath $full -PathType Container)){throw 'Full product-family database is missing.'}
$tool=Join-Path $ProjectRoot 'tools\build_mvs_product_family_compact_index.bat'
$toolHash=Get-Sha256File $tool
$hashPath=Join-Path $SlotRoot 'compact-toolset-sha256.txt'
$oldHash=if(Test-Path -LiteralPath $hashPath -PathType Leaf){([IO.File]::ReadAllText($hashPath)).Trim()}else{''}
$current=Join-Path $SlotRoot 'compact-index'
$familyMarker=Join-Path $SlotRoot ('family-rebuilt-'+$RunId+'.flag')
$need=(Test-Path -LiteralPath $familyMarker -PathType Leaf)   -or   (   -not   (Test-Path -LiteralPath $current -PathType Container))   -or   (   -not   [StringComparer]::Ordinal.Equals($oldHash,$toolHash))
if(   -not   $need){
    Write-Line 'Already done: compact product-family database is current.'
    [Environment]::Exit(0)
}
$staging=Join-Path $SlotRoot ('compact-index.staging-'+$RunId)
foreach($oldStage in @(Get-ChildItem -LiteralPath $SlotRoot -Directory -Filter 'compact-index.staging-*' -ErrorAction SilentlyContinue)){Remove-Item -LiteralPath $oldStage.FullName -Recurse -Force}
Write-Line 'Building compact product-family database ...'
Invoke-BatChecked $tool @($full,$staging) 'compact product-family builder'
Swap-Directory $staging $current
Write-Utf8 $hashPath ($toolHash+"`r`n")
Write-Line ('Compact product-family database committed: '+$current)
