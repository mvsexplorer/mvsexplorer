$ErrorActionPreference='Stop'
$utf8=New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8
$ProjectRoot=[IO.Path]::GetFullPath([string]$env:mvsdbm_arg1)
$InvocationDir=[IO.Path]::GetFullPath([string]$env:mvsdbm_arg2)
$Manifest=[IO.Path]::GetFullPath([string]$env:mvsdbm_arg3)
$Pattern='^mvs_\d{4}-\d{2}-\d{2}(?:-\d{4})?(?:_\d+)?$'
function Write-Line{param([string]$Text)[Console]::Out.WriteLine($Text)}
function Get-Sha256Text{param([string]$Text)$sha=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($Text)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}}
$roots=New-Object System.Collections.ArrayList
[void]$roots.Add($InvocationDir)
$parent=Split-Path -Parent $InvocationDir
if($parent    -and       -not   [StringComparer]::OrdinalIgnoreCase.Equals($parent,$InvocationDir)){[void]$roots.Add($parent)}
$seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$found=New-Object System.Collections.ArrayList
foreach($root in $roots){
    foreach($dir in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue|Where-Object{$_.Name  -like  'mvs_dumps_archive*'}|Sort-Object Name)){
        $resolved=(Resolve-Path -LiteralPath $dir.FullName).Path
        if($seen.Add($resolved)){
            $snaps=@(Get-ChildItem -LiteralPath $resolved -Directory -ErrorAction SilentlyContinue|Where-Object{$_.Name  -match  $Pattern})
            [void]$found.Add([pscustomobject]@{name=$dir.Name;path=$resolved;snapshot_count=$snaps.Count})
        }
    }
}
if($found.Count -eq 0){[Console]::Error.WriteLine('ERROR: No mvs_dumps_archive* folders found in current or parent folder.');[Environment]::Exit(3)}
$nameCounts=@{}
foreach($item in $found){$k=$item.name.ToLowerInvariant();if(   -not   $nameCounts.ContainsKey($k)){$nameCounts[$k]=0};$nameCounts[$k]++}
$lines=New-Object System.Collections.ArrayList
[void]$lines.Add("slot`tname`tpath`tsnapshot_count")
foreach($item in @($found|Sort-Object path)){
    $slot=[regex]::Replace($item.name,'[^A-Za-z0-9._-]+','_').Trim('_')
    if([string]::IsNullOrWhiteSpace($slot)){$slot='archive'}
    if($nameCounts[$item.name.ToLowerInvariant()] -gt 1){$slot+='-'+(Get-Sha256Text $item.path).Substring(0,8)}
    [void]$lines.Add(($slot+"`t"+$item.name+"`t"+$item.path+"`t"+$item.snapshot_count))
    Write-Line ('Found archive: '+$item.path+' ['+$item.snapshot_count+' snapshots] -> '+$slot)
}
[IO.File]::WriteAllText($Manifest,(($lines -join "`r`n")+"`r`n"),$utf8)
Write-Line ('Discovery manifest: '+$Manifest)
