function Get-ValidationToolsetFingerprint {
    param([string]$Root)
    $paths=New-Object System.Collections.ArrayList
    $validator=Join-Path $Root 'test\test_generated_databases.bat'
    if(Test-Path -LiteralPath $validator -PathType Leaf){[void]$paths.Add((Get-Item -LiteralPath $validator))}
    $tools=Join-Path $Root 'tools'
    foreach($file in @(Get-ChildItem -LiteralPath $tools -File -Filter '*mvs_product*.bat' -ErrorAction Stop|Sort-Object Name)){
        [void]$paths.Add($file)
    }
    $rows=New-Object System.Collections.ArrayList
    foreach($file in @($paths|Sort-Object FullName)){
        $relative=$file.FullName.Substring($Root.TrimEnd('\').Length).TrimStart('\').Replace('\','/')
        [void]$rows.Add(($relative+'='+(Get-Sha256File $file.FullName)))
    }
    return Get-Sha256Text (($rows -join "`n")+"`n")
}
function Get-DatabaseMetadataFingerprint {
    param([string[]]$Roots)
    $rows=New-Object System.Collections.ArrayList
    foreach($dbRoot in $Roots){
        if(   -not   (Test-Path -LiteralPath $dbRoot -PathType Container)){
            [void]$rows.Add(($dbRoot+'=MISSING'))
            continue
        }
        $prefix=$dbRoot.TrimEnd('\').Length
        foreach($file in @(Get-ChildItem -LiteralPath $dbRoot -File -Recurse -ErrorAction Stop|Sort-Object FullName)){
            if($file.Name -in @('update-state.json','source-fingerprints.tsv','toolset-sha256.txt')){continue}
            $relative=$file.FullName.Substring($prefix).TrimStart('\').Replace('\','/')
            [void]$rows.Add(($dbRoot+'|'+$relative+'|'+$file.Length+'|'+$file.LastWriteTimeUtc.Ticks))
        }
    }
    return Get-Sha256Text (($rows -join "`n")+"`n")
}

$archive=Join-Path $SlotRoot 'archive-analysis'
$full=Join-Path $SlotRoot 'family-index'
$compact=Join-Path $SlotRoot 'compact-index'
foreach($pair in @(@('archive',$archive),@('family',$full),@('compact',$compact))){if(   -not   (Test-Path -LiteralPath $pair[1] -PathType Container)){throw ($pair[0]+' database missing: '+$pair[1])}}

$force=[StringComparer]::OrdinalIgnoreCase.Equals([string]$Extra,'force-validate')
$validationStatusPath=Join-Path $SlotRoot 'validation-status.txt'
$toolsetPath=Join-Path $SlotRoot 'validation-toolset-sha256.txt'
$metadataPath=Join-Path $SlotRoot 'validation-database-metadata-sha256.txt'
$currentToolset=Get-ValidationToolsetFingerprint $ProjectRoot
$currentMetadata=Get-DatabaseMetadataFingerprint @($archive,$full,$compact)
$oldToolset=if(Test-Path -LiteralPath $toolsetPath -PathType Leaf){([IO.File]::ReadAllText($toolsetPath)).Trim()}else{''}
$oldMetadata=if(Test-Path -LiteralPath $metadataPath -PathType Leaf){([IO.File]::ReadAllText($metadataPath)).Trim()}else{''}
$oldStatus=if(Test-Path -LiteralPath $validationStatusPath -PathType Leaf){(Get-Content -LiteralPath $validationStatusPath -First 1).Trim()}else{''}
$archiveStatePath=Join-Path $archive 'update-state.json'
$archivePending=1
if(Test-Path -LiteralPath $archiveStatePath -PathType Leaf){$archivePending=[int](ConvertFrom-Json ([IO.File]::ReadAllText($archiveStatePath))).pending_checks}
$familyMarker=Join-Path $SlotRoot ('family-rebuilt-'+$RunId+'.flag')
$compactMarker=Join-Path $SlotRoot ('compact-rebuilt-'+$RunId+'.flag')
$rebuilt=(Test-Path -LiteralPath $familyMarker -PathType Leaf) -or (Test-Path -LiteralPath $compactMarker -PathType Leaf)

$canReuse=(   -not   $force) -and ($archivePending -eq 0) -and (   -not   $rebuilt) -and
    [StringComparer]::Ordinal.Equals($oldStatus,'PASS') -and
    [StringComparer]::Ordinal.Equals($oldToolset,$currentToolset) -and
    [StringComparer]::Ordinal.Equals($oldMetadata,$currentMetadata)
if($canReuse){
    Write-Line 'Already done: database validation is current; use --force-validate for a fresh deep validation.'
    [Environment]::Exit(0)
}

$validationDir=Join-Path (Join-Path $RunLogs (Split-Path -Leaf $SlotRoot)) 'database-validation'
$validator=Join-Path $ProjectRoot 'test\test_generated_databases.bat'
Invoke-BatChecked $validator @($archive,$full,$compact,$validationDir,$Version) 'database validator and family-query smoke test'
Write-Utf8 $validationStatusPath ("PASS`r`n"+(Get-Date).ToString('o')+"`r`n")
Write-Utf8 $toolsetPath ($currentToolset+"`r`n")
Write-Utf8 $metadataPath ($currentMetadata+"`r`n")
Write-Line 'Database validation: PASS.'
