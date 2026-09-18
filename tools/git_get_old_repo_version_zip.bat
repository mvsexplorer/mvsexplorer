@echo off
:setup
set "app.version=0.7.0"
set "app.name=git_get_old_repo_version_zip"
set "app.self=%~f0"
set "app.rc=0"
:main
set "RunPowerShellFromLabel.function=GitGetOldRepoVersionZip"
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

:_GitGetOldRepoVersionZip_start
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArgs
)

$ErrorActionPreference='Stop'
$ToolVersion='0.7.0'
$Utf8NoBom=[Text.UTF8Encoding]::new($false)

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
    Write-Host ($Name.PadRight(16)) -NoNewline -ForegroundColor DarkCyan
    Write-Host $Value -ForegroundColor $ValueColor
}

function Invoke-Captured {
    param([string]$File,[string[]]$Arguments,[string]$WorkingDirectory)
    $old=Get-Location
    $oldPreference=$ErrorActionPreference
    try{
        if($WorkingDirectory){Set-Location -LiteralPath $WorkingDirectory}
        $ErrorActionPreference='Continue'
        $global:LASTEXITCODE=0
        $output=& $File @Arguments 2>&1 | ForEach-Object{$_.ToString()}
        $rc=$LASTEXITCODE
        if($null -eq $rc){$rc=0}
        return [pscustomobject]@{Rc=[int]$rc;Output=($output -join "`n")}
    }finally{
        $ErrorActionPreference=$oldPreference
        Set-Location -LiteralPath $old
    }
}

function Invoke-Git {
    param([string]$Root,[string[]]$Arguments,[switch]$AllowFailure)
    $r=Invoke-Captured 'git.exe' $Arguments $Root
    if(-not $AllowFailure -and $r.Rc -ne 0){throw "git $($Arguments -join ' ') failed with rc=$($r.Rc).`n$($r.Output)"}
    return $r
}

function Get-RepositoryRoot {
    $cwd=(Get-Location).Path
    $r=Invoke-Captured 'git.exe' @('rev-parse','--show-toplevel') $cwd
    if($r.Rc -ne 0 -or -not $r.Output.Trim()){throw 'Run this tool from inside a Git repository.'}
    return [IO.Path]::GetFullPath($r.Output.Trim())
}

function Normalize-VersionSpec {
    param([string]$Value)
    $v=$Value.Trim()
    if($v.StartsWith('v',[StringComparison]::OrdinalIgnoreCase)){$v=$v.Substring(1)}
    return $v
}

function Get-ConfiguredHistoryUrl {
    param([string]$Root)
    try{
        $gitDir=(Invoke-Git $Root @('rev-parse','--git-dir')).Output.Trim()
        if(-not[IO.Path]::IsPathRooted($gitDir)){$gitDir=Join-Path $Root $gitDir}
        $pointer=Join-Path (Join-Path $gitDir 'info') 'git_history_import.work-folder.txt'
        $workFolder=$null
        if(Test-Path -LiteralPath $pointer -PathType Leaf){$workFolder=(Get-Content -LiteralPath $pointer -Raw -Encoding UTF8).Trim()}
        if(-not $workFolder){$workFolder=[IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $Root) 'local_history_import'))}
        $statePath=Join-Path $workFolder 'git_history_import.state.json'
        if(-not(Test-Path -LiteralPath $statePath -PathType Leaf)){return $null}
        $state=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if($state.repository -and $state.repository.repo){return ('https://github.com/'+[string]$state.repository.repo+'.git')}
    }catch{}
    return $null
}

function Fetch-ConfiguredHistory {
    param([string]$Root)
    $url=Get-ConfiguredHistoryUrl $Root
    if(-not $url){return $false}
    Write-Host ('Fetching configured published history: '+$url) -ForegroundColor DarkCyan
    $fetch=Invoke-Git $Root @('fetch','--no-tags','--quiet',$url,'+refs/heads/main:refs/remotes/git-history-tools/main') -AllowFailure
    if($fetch.Rc -ne 0){Write-Host ('Configured history fetch failed: '+$fetch.Output) -ForegroundColor Yellow;return $false}
    return $true
}

function Find-VersionMatches {
    param([string]$Root,[string]$Spec)
    $log=Invoke-Git $Root @('log','--all','--format=%H%x09%s')
    $commitMatches=New-Object System.Collections.Generic.List[object]
    foreach($line in @($log.Output -split "`r?`n")){
        if(-not $line){continue}
        $tab=$line.IndexOf("`t")
        if($tab -lt 1){continue}
        $hashValue=$line.Substring(0,$tab)
        $subjectValue=$line.Substring($tab+1)
        if($subjectValue -match ('^v'+[regex]::Escape($Spec)+'(?:\s|$)')){$commitMatches.Add([pscustomobject]@{Commit=$hashValue;Subject=$subjectValue;Spec=$Spec})}
    }
    return $commitMatches.ToArray()
}

function Resolve-Commit {
    param([string]$Root,[string]$Token)
    if($Token -ieq 'current'){
        $r=Invoke-Git $Root @('rev-parse','HEAD')
        $s=Invoke-Git $Root @('show','-s','--format=%s',$r.Output.Trim())
        return [pscustomobject]@{Commit=$r.Output.Trim();Subject=$s.Output.Trim();Spec='current'}
    }
    $spec=Normalize-VersionSpec $Token
    $commitMatches=@(Find-VersionMatches $Root $spec)
    if($commitMatches.Count -eq 0){
        if(Fetch-ConfiguredHistory $Root){$commitMatches=@(Find-VersionMatches $Root $spec)}
    }
    if($commitMatches.Count -eq 1){return $commitMatches[0]}
    if($commitMatches.Count -gt 1){
        $detail=($commitMatches.ToArray()|ForEach-Object{'  '+$_.Commit.Substring(0,12)+'  '+$_.Subject}) -join "`n"
        throw "Version '$Token' matches more than one commit.`n$detail"
    }
    $ref=Invoke-Git $Root @('rev-parse','--verify',($Token+'^{commit}')) -AllowFailure
    if($ref.Rc -eq 0 -and $ref.Output.Trim()){
        $subject=(Invoke-Git $Root @('show','-s','--format=%s',$ref.Output.Trim())).Output.Trim()
        return [pscustomobject]@{Commit=$ref.Output.Trim();Subject=$subject;Spec=$Token}
    }
    throw "Could not resolve '$Token' to a unique vVERSION commit or Git commit/ref."
}

function Get-RepositoryName {
    param([string]$Root)
    try{
        $gitDir=(Invoke-Git $Root @('rev-parse','--git-dir')).Output.Trim()
        if(-not[IO.Path]::IsPathRooted($gitDir)){$gitDir=Join-Path $Root $gitDir}
        $pointer=Join-Path (Join-Path $gitDir 'info') 'git_history_import.work-folder.txt'
        $workFolder=$null
        if(Test-Path -LiteralPath $pointer -PathType Leaf){$workFolder=(Get-Content -LiteralPath $pointer -Raw -Encoding UTF8).Trim()}
        if(-not $workFolder){$workFolder=[IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $Root) 'local_history_import'))}
        $statePath=Join-Path $workFolder 'git_history_import.state.json'
        if(Test-Path -LiteralPath $statePath -PathType Leaf){
            $state=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
            if($state.repository -and $state.repository.name){return [string]$state.repository.name}
        }
    }catch{}
    $r=Invoke-Git $Root @('config','--get','remote.origin.url') -AllowFailure
    if($r.Rc -eq 0 -and $r.Output.Trim()){
        $u=$r.Output.Trim().TrimEnd('/')
        $leaf=($u -replace '^.*[/:]','')
        if($leaf.EndsWith('.git',[StringComparison]::OrdinalIgnoreCase)){$leaf=$leaf.Substring(0,$leaf.Length-4)}
        if($leaf){return $leaf}
    }
    return (Split-Path -Leaf $Root)
}

function Get-Sha256File {
    param([string]$Path)
    $h=[Security.Cryptography.SHA256]::Create()
    $stream=[IO.File]::OpenRead($Path)
    try{return ([BitConverter]::ToString($h.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}finally{$stream.Dispose();$h.Dispose()}
}

function Ensure-OutputIgnored {
    param([string]$Root,[string]$Output)
    $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd('\')
    $outFull=[IO.Path]::GetFullPath($Output)
    if(-not $outFull.StartsWith($rootFull+'\',[StringComparison]::OrdinalIgnoreCase)){return}
    $gd=(Invoke-Git $Root @('rev-parse','--git-dir')).Output.Trim()
    if(-not[IO.Path]::IsPathRooted($gd)){$gd=Join-Path $Root $gd}
    $exclude=Join-Path (Join-Path $gd 'info') 'exclude'
    [IO.Directory]::CreateDirectory((Split-Path -Parent $exclude))|Out-Null
    $old=''
    if(Test-Path -LiteralPath $exclude -PathType Leaf){$old=[IO.File]::ReadAllText($exclude)}
    $rel=$outFull.Substring($rootFull.Length+1).Replace('\','/')
    $line='/'+$rel
    if($old -notmatch ('(?m)^'+[regex]::Escape($line)+'$')){
        if($old -and -not $old.EndsWith("`n")){$old+="`r`n"}
        [IO.File]::WriteAllText($exclude,$old+"# git_get_old_repo_version_zip outputs`r`n"+$line+"`r`n",$Utf8NoBom)
    }
}

function Show-Help {
    Write-Host "git_get_old_repo_version_zip $ToolVersion" -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Export a complete historical Git repository tree as a ZIP.'
    Write-Host ''
    Write-Host 'USAGE' -ForegroundColor Cyan
    Write-Host '  tools\git_get_old_repo_version_zip VERSION [--output FILE]'
    Write-Host '  tools\git_get_old_repo_version_zip current [--output FILE]'
    Write-Host ''
    Write-Host 'VERSION' -ForegroundColor Cyan
    Write-Host '  Resolves the unique commit whose subject begins with vVERSION.'
    Write-Host '  A Git commit/ref is also accepted when no version-subject match exists.'
    Write-Host ''
    Write-Host 'EXAMPLE' -ForegroundColor Cyan
    Write-Host '  tools\git_get_old_repo_version_zip 0.19.3'
}

function Main {
    if($CliArgs.Count -eq 0 -or $CliArgs[0] -in @('/?','/h','-?','-h','--help')){Show-Help;return 0}
    $token=$CliArgs[0]
    $output=$null
    for($i=1;$i -lt $CliArgs.Count;$i++){
        $a=$CliArgs[$i]
        if($a -eq '--output'){
            if($i+1 -ge $CliArgs.Count){throw 'Missing value for --output.'}
            $i++;$output=$CliArgs[$i];continue
        }
        throw "Unknown argument: $a"
    }
    $root=Get-RepositoryRoot
    $resolved=Resolve-Commit $root $token
    $repo=Get-RepositoryName $root
    $label=if($resolved.Spec -eq 'current'){'current'}else{'v'+(Normalize-VersionSpec $resolved.Spec)}
    $safe=($repo+'-'+$label) -replace '[^A-Za-z0-9._-]+','_'
    $out=if($output){[IO.Path]::GetFullPath($output)}else{Join-Path (Get-Location).Path ($safe+'.zip')}
    $parent=Split-Path -Parent $out
    if($parent){[IO.Directory]::CreateDirectory($parent)|Out-Null}
    if(Test-Path -LiteralPath $out){Remove-Item -LiteralPath $out -Force}
    Ensure-OutputIgnored $root $out
    $prefix=$safe+'/'
    $r=Invoke-Git $root @('archive','--format=zip',('--prefix='+$prefix),('--output='+$out),$resolved.Commit)
    if(-not(Test-Path -LiteralPath $out -PathType Leaf)){throw "Git archive did not create: $out"}
    Write-Heading "git_get_old_repo_version_zip $ToolVersion"
    Write-InfoPair 'Requested:' $token Cyan
    Write-InfoPair 'Commit:' $resolved.Commit Yellow
    Write-InfoPair 'Subject:' $resolved.Subject White
    Write-InfoPair 'ZIP:' $out Cyan
    Write-InfoPair 'SHA-256:' (Get-Sha256File $out) DarkGray
    Write-Host ''
    Write-Host 'REPO ZIP PASS' -ForegroundColor Green
    return 0
}

try{exit [int](Main)}catch{Write-Host '';Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red;exit 1}
:_GitGetOldRepoVersionZip_end
