@echo off
:setup
set "app.version=0.7.0"
set "app.name=git_compare_repo_version"
set "app.self=%~f0"
set "app.rc=0"
:main
set "RunPowerShellFromLabel.function=GitCompareRepoVersion"
call :RunPowerShellFromLabel %*
set "app.rc=%errorlevel%"
:end
call :SetErrorLevel %app.rc%
GoTo :EOF

:: ============================================================
:: :SetErrorLevel
:: Restores the intended application return code.
::
:: Version:
::   1.0.0
::
:: Usage: call :SetErrorLevel returnCode
::
:: Arguments:
::   returnCode  integer process return code
::
:: Output:
::   None
::
:: Returns:
::   returnCode
:: ============================================================
:SetErrorLevel
exit /b %~1

:: ============================================================
:: :RunPowerShellFromLabel
:: Reads this batch file, extracts PowerShell between
:: :_Block_start and :_Block_end, and executes it.
::
:: Version:
::   1.2.0
::
:: Usage:
::   call :RunPowerShellFromLabel BlockName [arguments...]
::
:: Arguments:
::   BlockName  embedded PowerShell block name
::   arguments  arguments forwarded to the block
::
:: Output:
::   embedded PowerShell stdout/stderr
::
:: Returns:
::   PowerShell exit code
::   2 for invalid arguments
:: ============================================================
:RunPowerShellFromLabel
for /f "tokens=1 delims==" %%v in ('set rps_ 2^>nul') do set "%%v="
if defined _rps_rc (set "_rps_rc=" & exit /b %_rps_rc%)
set "rps_self=%~f0" & set "rps_argc=0"
if defined app.self set "rps_self=%app.self%"
if defined RunPowerShellFromLabel.function (set "rps_label=%RunPowerShellFromLabel.function%" & set "RunPowerShellFromLabel.function=" & goto :_RunPowerShellFromLabel_capture)
set "rps_label=%~1"
if not defined rps_label (set "_rps_rc=2" & goto :RunPowerShellFromLabel)
shift
:_RunPowerShellFromLabel_capture
if "%~1"=="" goto :_RunPowerShellFromLabel_run
set "rps_arg%rps_argc%=%~1"
set /a rps_argc+=1
shift
goto :_RunPowerShellFromLabel_capture
:_RunPowerShellFromLabel_run
if "%rps_label:~0,1%"==":" set "rps_label=%rps_label:~1%"
set "rps_start=:_%rps_label%_start" & set "rps_end=:_%rps_label%_end"
powershell.exe -NoLogo -NoProfile -Command "& { try { $ErrorActionPreference='Stop'; $path=$env:rps_self; $start=$env:rps_start; $end=$env:rps_end; $argc=[int]$env:rps_argc; $lines=@(Get-Content -LiteralPath $path); $s=-1; $e=-1; for($i=0;$i-lt$lines.Count;$i++){ $t=$lines[$i].Trim(); if($s-lt 0-and$t-eq$start){$s=$i;continue}; if($s-ge 0-and$t-eq$end){$e=$i;break} }; if($s-lt 0-or$e-le$s){throw ('Could not find valid PowerShell block: '+$start+' / '+$end)}; $code=if($e-gt($s+1)){$lines[($s+1)..($e-1)]-join[Environment]::NewLine}else{''}; $arguments=@(); for($n=0;$n-lt$argc;$n++){$arguments += [Environment]::GetEnvironmentVariable(('rps_arg{0}'-f$n))}; & ([ScriptBlock]::Create($code)) @arguments; if(-not $?){exit 1}; exit 0 } catch { Write-Error $_; exit 1 } }"
set "rps_rc=%errorlevel%"
if not "%rps_rc%"=="0" (set "_rps_rc=%rps_rc%" & goto :RunPowerShellFromLabel)
exit /b 0

:_GitCompareRepoVersion_start
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArgs
)

$ErrorActionPreference='Stop'
$ToolVersion='0.7.0'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Write-Heading {
    param([string]$Text)
    Write-Host ''
    Write-Host ('='*60) -ForegroundColor DarkCyan
    Write-Host (' '+$Text) -ForegroundColor Cyan
    Write-Host ('='*60) -ForegroundColor DarkCyan
    Write-Host ''
}

function Write-InfoPair {
    param([string]$Name,[string]$Value,[ConsoleColor]$ValueColor=[ConsoleColor]::White)
    Write-Host ($Name.PadRight(18)) -NoNewline -ForegroundColor DarkCyan
    Write-Host $Value -ForegroundColor $ValueColor
}

function Invoke-Captured {
    param([string]$File,[string[]]$Arguments,[string]$WorkingDirectory)
    $oldLocation=Get-Location
    $oldPreference=$ErrorActionPreference
    try{
        if($WorkingDirectory){Set-Location -LiteralPath $WorkingDirectory}
        $ErrorActionPreference='Continue'
        $global:LASTEXITCODE=0
        $nativeOutput=& $File @Arguments 2>&1 | ForEach-Object{$_.ToString()}
        $nativeRc=$LASTEXITCODE
        if($null -eq $nativeRc){$nativeRc=0}
        return [pscustomobject]@{Rc=[int]$nativeRc;Output=($nativeOutput -join "`n")}
    }finally{
        $ErrorActionPreference=$oldPreference
        Set-Location -LiteralPath $oldLocation
    }
}

function Invoke-Git {
    param([string]$Root,[string[]]$Arguments,[switch]$AllowFailure)
    $gitResult=Invoke-Captured 'git.exe' $Arguments $Root
    if(-not $AllowFailure -and $gitResult.Rc -ne 0){throw "git $($Arguments -join ' ') failed with rc=$($gitResult.Rc).`n$($gitResult.Output)"}
    return $gitResult
}

function Get-RepositoryRoot {
    $cwd=(Get-Location).Path
    $gitResult=Invoke-Captured 'git.exe' @('rev-parse','--show-toplevel') $cwd
    if($gitResult.Rc -ne 0 -or -not $gitResult.Output.Trim()){throw 'Run this tool from inside a Git repository.'}
    return [IO.Path]::GetFullPath($gitResult.Output.Trim())
}

function Normalize-VersionSpec {
    param([string]$Value)
    $versionValue=$Value.Trim()
    if($versionValue.StartsWith('v',[StringComparison]::OrdinalIgnoreCase)){$versionValue=$versionValue.Substring(1)}
    return $versionValue
}

function Find-VersionMatches {
    param([string]$Root,[string]$Spec)
    $logResult=Invoke-Git $Root @('log','--all','--format=%H%x09%s')
    $commitMatches=New-Object System.Collections.Generic.List[object]
    foreach($logLine in @($logResult.Output -split "`r?`n")){
        if(-not $logLine){continue}
        $tabIndex=$logLine.IndexOf("`t")
        if($tabIndex -lt 1){continue}
        $hashValue=$logLine.Substring(0,$tabIndex)
        $subjectValue=$logLine.Substring($tabIndex+1)
        if($subjectValue -match ('^v'+[regex]::Escape($Spec)+'(?:\s|$)')){$commitMatches.Add([pscustomobject]@{Commit=$hashValue;Subject=$subjectValue;Spec=$Spec})}
    }
    return $commitMatches.ToArray()
}

function Resolve-Commit {
    param([string]$Root,[string]$Token)
    $spec=Normalize-VersionSpec $Token
    $commitMatches=@(Find-VersionMatches $Root $spec)
    if($commitMatches.Count -eq 0){
        if(Fetch-ConfiguredHistory $Root $script:CompareWorkOverride){$commitMatches=@(Find-VersionMatches $Root $spec)}
    }
    if($commitMatches.Count -eq 1){return $commitMatches[0]}
    if($commitMatches.Count -gt 1){
        $detail=($commitMatches|ForEach-Object{'  '+$_.Commit.Substring(0,12)+'  '+$_.Subject}) -join "`n"
        throw "Version '$Token' matches more than one commit.`n$detail"
    }
    $refResult=Invoke-Git $Root @('rev-parse','--verify',($Token+'^{commit}')) -AllowFailure
    if($refResult.Rc -eq 0 -and $refResult.Output.Trim()){
        $subject=(Invoke-Git $Root @('show','-s','--format=%s',$refResult.Output.Trim())).Output.Trim()
        return [pscustomobject]@{Commit=$refResult.Output.Trim();Subject=$subject;Spec=$Token}
    }
    throw "Could not resolve '$Token' to a unique vVERSION commit or Git commit/ref."
}

function Get-Sha256Stream {
    param([IO.Stream]$Stream)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($Stream))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}

function Get-Sha256File {
    param([string]$Path)
    $stream=[IO.File]::OpenRead($Path)
    try{return Get-Sha256Stream $stream}finally{$stream.Dispose()}
}

function New-Inventory {
    return [System.Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
}

function Normalize-ArchivePath {
    param([string]$Path)
    $normalized=$Path.Replace('\','/')
    while($normalized.StartsWith('./')){$normalized=$normalized.Substring(2)}
    if($normalized.StartsWith('/')){throw "Unsafe archive path: $Path"}
    $parts=@($normalized.Split('/')|Where-Object{$_ -and $_ -ne '.'})
    if($parts.Count -eq 0 -or $parts -contains '..'){throw "Unsafe archive path: $Path"}
    foreach($partValue in $parts){if($partValue.Contains(':')){throw "Unsafe archive path: $Path"}}
    return ($parts -join '/')
}

function Read-ZipInventory {
    param([string]$ZipPath)
    $zip=[IO.Compression.ZipFile]::OpenRead($ZipPath)
    try{
        $entries=@($zip.Entries|Where-Object{$_.Name})
        $names=New-Object System.Collections.Generic.List[string]
        foreach($entry in $entries){$names.Add((Normalize-ArchivePath $entry.FullName))}
        $prefix=''
        if($names.Count -gt 0){
            $firstPart=$null
            $allNested=$true
            foreach($nameValue in $names.ToArray()){
                $pathParts=$nameValue.Split('/')
                if($pathParts.Count -lt 2){$allNested=$false;break}
                if($null -eq $firstPart){$firstPart=$pathParts[0]}elseif($pathParts[0] -cne $firstPart){$allNested=$false;break}
            }
            if($allNested){$prefix=$firstPart+'/'}
        }
        $inventory=New-Inventory
        for($index=0;$index -lt $entries.Count;$index++){
            $rawName=$names[$index]
            $relative=if($prefix -and $rawName.StartsWith($prefix,[StringComparison]::Ordinal)){$rawName.Substring($prefix.Length)}else{$rawName}
            $relative=Normalize-ArchivePath $relative
            if($inventory.ContainsKey($relative)){throw "Duplicate path after root stripping: $relative"}
            $entryStream=$entries[$index].Open()
            try{$inventory.Add($relative,(Get-Sha256Stream $entryStream))}finally{$entryStream.Dispose()}
        }
        return (,$inventory)
    }finally{$zip.Dispose()}
}

function Read-FolderInventory {
    param([string]$FolderPath)
    $folderFull=[IO.Path]::GetFullPath($FolderPath).TrimEnd('\')
    $inventory=New-Inventory
    foreach($fileItem in Get-ChildItem -LiteralPath $folderFull -Recurse -File){
        $relative=$fileItem.FullName.Substring($folderFull.Length).TrimStart('\').Replace('\','/')
        if($relative.StartsWith('.git/')){continue}
        $inventory.Add($relative,(Get-Sha256File $fileItem.FullName))
    }
    return (,$inventory)
}

function Read-FileInventory {
    param([string]$FilePath)
    $inventory=New-Inventory
    $inventory.Add([IO.Path]::GetFileName($FilePath),(Get-Sha256File $FilePath))
    return (,$inventory)
}

function Read-CurrentInventory {
    param([string]$Root)
    $inventory=New-Inventory
    $listResult=Invoke-Git $Root @('-c','core.quotepath=false','ls-files','-co','--exclude-standard')
    foreach($relativeRaw in @($listResult.Output -split "`r?`n")){
        if(-not $relativeRaw){continue}
        $relative=$relativeRaw.Replace('\','/')
        $full=Join-Path $Root ($relative.Replace('/','\'))
        if(-not(Test-Path -LiteralPath $full -PathType Leaf)){continue}
        if(-not $inventory.ContainsKey($relative)){$inventory.Add($relative,(Get-Sha256File $full))}
    }
    return (,$inventory)
}

function Read-CommitInventory {
    param([string]$Root,[string]$Commit)
    $temp=Join-Path ([IO.Path]::GetTempPath()) ('git_compare_repo_version.'+[Guid]::NewGuid().ToString('N')+'.zip')
    try{
        Invoke-Git $Root @('archive','--format=zip',('--output='+$temp),$Commit)|Out-Null
        return (Read-ZipInventory $temp)
    }finally{
        if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
    }
}

function Get-GitDirectory {
    param([string]$Root)
    $gitResult=Invoke-Git $Root @('rev-parse','--git-dir')
    $gitDir=$gitResult.Output.Trim()
    if(-not[IO.Path]::IsPathRooted($gitDir)){$gitDir=Join-Path $Root $gitDir}
    return [IO.Path]::GetFullPath($gitDir)
}

function Resolve-ImportWorkFolder {
    param([string]$Root,[string]$Override)
    if($Override){return [IO.Path]::GetFullPath($Override)}
    $gitDir=Get-GitDirectory $Root
    $pointer=Join-Path (Join-Path $gitDir 'info') 'git_history_import.work-folder.txt'
    if(Test-Path -LiteralPath $pointer -PathType Leaf){
        $pointerValue=(Get-Content -LiteralPath $pointer -Raw -Encoding UTF8).Trim()
        if($pointerValue){return [IO.Path]::GetFullPath($pointerValue)}
    }
    return [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $Root) 'local_history_import'))
}

function Get-ConfiguredHistoryUrl {
    param([string]$Root,[string]$WorkOverride)
    try{
        $workFolder=Resolve-ImportWorkFolder $Root $WorkOverride
        $statePath=Join-Path $workFolder 'git_history_import.state.json'
        if(-not(Test-Path -LiteralPath $statePath -PathType Leaf)){return $null}
        $state=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if($state.repository -and $state.repository.repo){return ('https://github.com/'+[string]$state.repository.repo+'.git')}
    }catch{}
    return $null
}

function Fetch-ConfiguredHistory {
    param([string]$Root,[string]$WorkOverride)
    $url=Get-ConfiguredHistoryUrl $Root $WorkOverride
    if(-not $url){return $false}
    Write-Host ('Fetching configured published history: '+$url) -ForegroundColor DarkCyan
    $fetch=Invoke-Git $Root @('fetch','--no-tags','--quiet',$url,'+refs/heads/main:refs/remotes/git-history-tools/main') -AllowFailure
    if($fetch.Rc -ne 0){Write-Host ('Configured history fetch failed: '+$fetch.Output) -ForegroundColor Yellow;return $false}
    return $true
}

function Get-LayoutInfo {
    param([string]$Root,[string]$WorkOverride,[bool]$NoLayout)
    if($NoLayout){return [pscustomobject]@{Mode='identity';Label='none (--no-layout)';Moves=@{}}}
    $workFolder=Resolve-ImportWorkFolder $Root $WorkOverride
    $planPath=Join-Path $workFolder 'plan.json'
    if(-not(Test-Path -LiteralPath $planPath -PathType Leaf)){return [pscustomobject]@{Mode='identity';Label='none (no active history-import plan)';Moves=@{}}}
    $plan=Get-Content -LiteralPath $planPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if(-not $plan.layout -or [string]$plan.layout.mode -eq 'identity'){return [pscustomobject]@{Mode='identity';Label='none (active identity layout)';Moves=@{}}}
    $moveMap=@{}
    foreach($moveRec in @($plan.layout.moves)){$moveMap[[string]$moveRec.from]=[string]$moveRec.to}
    $label=[string]$plan.layout.finalArchive
    if(-not $label){$label='active reference layout'}
    return [pscustomobject]@{Mode='reference';Label=$label;Moves=$moveMap}
}

function Apply-Layout {
    param($Inventory,$LayoutInfo)
    if($LayoutInfo.Mode -eq 'identity' -or $LayoutInfo.Moves.Count -eq 0){return $Inventory}
    $mapped=New-Inventory
    foreach($sourcePath in $Inventory.Keys){
        $destination=if($LayoutInfo.Moves.ContainsKey($sourcePath)){[string]$LayoutInfo.Moves[$sourcePath]}else{$sourcePath}
        if($mapped.ContainsKey($destination)){throw "Layout mapping collision: $sourcePath -> $destination"}
        $mapped.Add($destination,[string]$Inventory[$sourcePath])
    }
    return (,$mapped)
}

function Resolve-Target {
    param([string]$Root,[string]$Token,$LayoutInfo)
    if($Token -ieq 'current'){
        return [pscustomobject]@{Token=$Token;Label='current';Kind='repo';Inventory=(Read-CurrentInventory $Root);Detail=$Root}
    }
    if(Test-Path -LiteralPath $Token){
        $full=[IO.Path]::GetFullPath($Token)
        if(Test-Path -LiteralPath $full -PathType Container){
            $raw=Read-FolderInventory $full
            return [pscustomobject]@{Token=$Token;Label=$full;Kind='external';Inventory=(Apply-Layout $raw $LayoutInfo);Detail=$full}
        }
        if([IO.Path]::GetExtension($full) -ieq '.zip'){
            $raw=Read-ZipInventory $full
            return [pscustomobject]@{Token=$Token;Label=$full;Kind='external';Inventory=(Apply-Layout $raw $LayoutInfo);Detail=$full}
        }
        $raw=Read-FileInventory $full
        return [pscustomobject]@{Token=$Token;Label=$full;Kind='external';Inventory=(Apply-Layout $raw $LayoutInfo);Detail=$full}
    }
    $commitInfo=Resolve-Commit $Root $Token
    return [pscustomobject]@{Token=$Token;Label=('v'+(Normalize-VersionSpec $Token));Kind='repo';Inventory=(Read-CommitInventory $Root $commitInfo.Commit);Detail=($commitInfo.Commit.Substring(0,12)+'  '+$commitInfo.Subject)}
}

function Compare-Full {
    param($Left,$Right)
    $same=0
    $modified=New-Object System.Collections.Generic.List[string]
    $onlyLeft=New-Object System.Collections.Generic.List[string]
    $onlyRight=New-Object System.Collections.Generic.List[string]
    foreach($pathValue in $Left.Keys){
        if(-not $Right.ContainsKey($pathValue)){$onlyLeft.Add($pathValue);continue}
        if([string]$Left[$pathValue] -ceq [string]$Right[$pathValue]){$same++}else{$modified.Add($pathValue)}
    }
    foreach($pathValue in $Right.Keys){if(-not $Left.ContainsKey($pathValue)){$onlyRight.Add($pathValue)}}
    return [pscustomobject]@{Mode='full';Same=$same;Modified=$modified;OnlyLeft=$onlyLeft;OnlyRight=$onlyRight;Identical=($modified.Count -eq 0 -and $onlyLeft.Count -eq 0 -and $onlyRight.Count -eq 0)}
}

function Compare-Managed {
    param($ExternalTarget,$RepoTarget)
    $matched=0
    $missing=New-Object System.Collections.Generic.List[string]
    $changed=New-Object System.Collections.Generic.List[string]
    $repoOnly=New-Object System.Collections.Generic.List[string]
    foreach($pathValue in $ExternalTarget.Inventory.Keys){
        if(-not $RepoTarget.Inventory.ContainsKey($pathValue)){$missing.Add($pathValue);continue}
        if([string]$ExternalTarget.Inventory[$pathValue] -ceq [string]$RepoTarget.Inventory[$pathValue]){$matched++}else{$changed.Add($pathValue)}
    }
    foreach($pathValue in $RepoTarget.Inventory.Keys){if(-not $ExternalTarget.Inventory.ContainsKey($pathValue)){$repoOnly.Add($pathValue)}}
    return [pscustomobject]@{Mode='managed';Matched=$matched;Missing=$missing;Changed=$changed;RepoOnly=$repoOnly;ManagedMatch=($missing.Count -eq 0 -and $changed.Count -eq 0)}
}

function Write-PathSamples {
    param([string]$Name,$Items,[ConsoleColor]$Color)
    if($Items.Count -eq 0){return}
    Write-Host ('  '+$Name+':') -ForegroundColor $Color
    foreach($pathValue in @($Items.ToArray()|Select-Object -First 12)){Write-Host ('    '+$pathValue) -ForegroundColor $Color}
    if($Items.Count -gt 12){Write-Host ('    ... '+($Items.Count-12)+' more') -ForegroundColor DarkGray}
}

function Compare-Pair {
    param([int]$Index,[int]$Total,$LeftTarget,$RightTarget,$LayoutInfo)
    Write-Heading ("git_compare_repo_version $ToolVersion - $Index/$Total")
    Write-InfoPair 'Left:' $LeftTarget.Label Cyan
    Write-InfoPair 'Left detail:' $LeftTarget.Detail DarkGray
    Write-InfoPair 'Right:' $RightTarget.Label Cyan
    Write-InfoPair 'Right detail:' $RightTarget.Detail DarkGray
    Write-InfoPair 'Layout:' $LayoutInfo.Label Magenta
    Write-InfoPair 'Left files:' ([string]$LeftTarget.Inventory.Count) Cyan
    Write-InfoPair 'Right files:' ([string]$RightTarget.Inventory.Count) Cyan
    if($LeftTarget.Kind -ne $RightTarget.Kind){
        $externalTarget=if($LeftTarget.Kind -eq 'external'){$LeftTarget}else{$RightTarget}
        $repoTarget=if($LeftTarget.Kind -eq 'repo'){$LeftTarget}else{$RightTarget}
        $comparison=Compare-Managed $externalTarget $repoTarget
        Write-InfoPair 'Managed expected:' ([string]$externalTarget.Inventory.Count) Cyan
        Write-InfoPair 'Matched:' ([string]$comparison.Matched) Green
        Write-InfoPair 'Missing:' ([string]$comparison.Missing.Count) $(if($comparison.Missing.Count){'Red'}else{'Green'})
        Write-InfoPair 'Changed:' ([string]$comparison.Changed.Count) $(if($comparison.Changed.Count){'Red'}else{'Green'})
        Write-InfoPair 'Repo-only extras:' ([string]$comparison.RepoOnly.Count) Yellow
        Write-PathSamples 'missing' $comparison.Missing Red
        Write-PathSamples 'changed' $comparison.Changed Red
        if($comparison.ManagedMatch){Write-Host 'RESULT: MANAGED CONTENT MATCH' -ForegroundColor Green}else{Write-Host 'RESULT: MANAGED CONTENT MISMATCH' -ForegroundColor Red}
        return
    }
    $comparison=Compare-Full $LeftTarget.Inventory $RightTarget.Inventory
    Write-InfoPair 'Unchanged:' ([string]$comparison.Same) Green
    Write-InfoPair 'Modified:' ([string]$comparison.Modified.Count) $(if($comparison.Modified.Count){'Yellow'}else{'Green'})
    Write-InfoPair 'Only left:' ([string]$comparison.OnlyLeft.Count) $(if($comparison.OnlyLeft.Count){'Yellow'}else{'Green'})
    Write-InfoPair 'Only right:' ([string]$comparison.OnlyRight.Count) $(if($comparison.OnlyRight.Count){'Yellow'}else{'Green'})
    Write-PathSamples 'modified' $comparison.Modified Yellow
    Write-PathSamples 'only left' $comparison.OnlyLeft Yellow
    Write-PathSamples 'only right' $comparison.OnlyRight Yellow
    if($comparison.Identical){Write-Host 'RESULT: IDENTICAL' -ForegroundColor Green}else{Write-Host 'RESULT: DIFFERENT' -ForegroundColor Yellow}
}

function Show-Help {
    Write-Host "git_compare_repo_version $ToolVersion" -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Compare Git repository versions, the current working tree, ZIP/files, or folders.'
    Write-Host ''
    Write-Host 'USAGE' -ForegroundColor Cyan
    Write-Host '  tools\git_compare_repo_version TARGET'
    Write-Host '  tools\git_compare_repo_version TARGET TARGET [TARGET ...]'
    Write-Host '  tools\git_compare_repo_version TARGET [TARGET ...] --no-layout'
    Write-Host '  tools\git_compare_repo_version TARGET [TARGET ...] --work-folder FOLDER'
    Write-Host ''
    Write-Host 'TARGETS' -ForegroundColor Cyan
    Write-Host '  VERSION   resolves the unique Git commit whose subject begins with vVERSION'
    Write-Host '  current   current tracked + non-ignored working-tree files'
    Write-Host '  ZIP       external ZIP; common top folder is stripped'
    Write-Host '  FILE      external single file'
    Write-Host '  FOLDER    external folder, recursively'
    Write-Host ''
    Write-Host 'BEHAVIOR' -ForegroundColor Cyan
    Write-Host '  One target is compared with current.'
    Write-Host '  Two or more targets are compared pairwise in the order supplied.'
    Write-Host '  External ZIP/file/folder targets are normalized through the active'
    Write-Host '  git_history_import layout mapping unless --no-layout is specified.'
    Write-Host '  When one side is external and the other is a Git/current snapshot,'
    Write-Host '  external files define the managed comparison set; repo-only framework'
    Write-Host '  files are reported separately.'
    Write-Host ''
    Write-Host 'EXAMPLES' -ForegroundColor Cyan
    Write-Host '  tools\git_compare_repo_version 0.19.3'
    Write-Host '  tools\git_compare_repo_version 0.19.3 current'
    Write-Host '  tools\git_compare_repo_version 0.19.3 0.20.0 0.21.2'
    Write-Host '  tools\git_compare_repo_version 0.19.3 "D:\history\Project-0.19.3.zip"'
    Write-Host '  tools\git_compare_repo_version current "D:\checks\project-folder"'
}

function Main {
    if($CliArgs.Count -eq 0 -or $CliArgs[0] -in @('/?','/h','-?','-h','--help')){Show-Help;return 0}
    $targets=New-Object System.Collections.Generic.List[string]
    $workOverride=$null
    $noLayout=$false
    for($index=0;$index -lt $CliArgs.Count;$index++){
        $argValue=$CliArgs[$index]
        if($argValue -eq '--no-layout'){$noLayout=$true;continue}
        if($argValue -eq '--work-folder'){
            if($index+1 -ge $CliArgs.Count){throw 'Missing value for --work-folder.'}
            $index++;$workOverride=$CliArgs[$index];continue
        }
        if($argValue.StartsWith('--')){throw "Unknown option: $argValue"}
        $targets.Add($argValue)
    }
    if($targets.Count -eq 0){throw 'At least one comparison target is required.'}
    if($targets.Count -eq 1){$targets.Add('current')}
    $root=Get-RepositoryRoot
    $script:CompareWorkOverride=$workOverride
    $layoutInfo=Get-LayoutInfo $root $workOverride $noLayout
    $resolvedTargets=New-Object System.Collections.Generic.List[object]
    foreach($targetValue in $targets.ToArray()){$resolvedTargets.Add((Resolve-Target $root $targetValue $layoutInfo))}
    $pairCount=$resolvedTargets.Count-1
    for($pairIndex=0;$pairIndex -lt $pairCount;$pairIndex++){Compare-Pair ($pairIndex+1) $pairCount $resolvedTargets[$pairIndex] $resolvedTargets[$pairIndex+1] $layoutInfo}
    Write-Host ''
    Write-Host ("COMPARE COMPLETE: $pairCount pair(s)") -ForegroundColor Green
    return 0
}

try{exit [int](Main)}catch{Write-Host '';Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red;exit 1}
:_GitCompareRepoVersion_end
