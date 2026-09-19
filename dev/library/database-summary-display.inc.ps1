$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
$Version = [string]$env:mvsdisp_version
$ProjectVersion = [string]$env:mvsdisp_project_version
$Invocation = [IO.Path]::GetFullPath([string]$env:mvsdisp_invocation_dir)
$KnownSources = @('mvs.txt','mvs_ids.txt','mvs_dates.txt','mvs_names.txt','mvs_notes.html','mvs.sha1','mvs.sha256')
$Pattern = '^mvs_\d{4}-\d{2}-\d{2}(?:-\d{4})?(?:_\d+)?$'

function Write-ColoredLine {
    param([string]$Text,[ConsoleColor]$Color=[ConsoleColor]::Gray)
    $old = [Console]::ForegroundColor
    try {
        if (  -not   [Console]::IsOutputRedirected) { [Console]::ForegroundColor = $Color }
        [Console]::Out.WriteLine($Text)
    } finally {
        if (  -not   [Console]::IsOutputRedirected) { [Console]::ForegroundColor = $old }
    }
}
function Get-FileSha256 {
    param([string]$Path)
    return ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant())
}
function Get-TextSha256 {
    param([string]$Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($Text)))).Replace('-','').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}
function Resolve-SnapshotDataPath {
    param([string]$SnapshotPath)
    foreach ($name in $KnownSources) {
        if (Test-Path -LiteralPath (Join-Path $SnapshotPath $name) -PathType Leaf) { return $SnapshotPath }
    }
    $nested = Join-Path $SnapshotPath 'mvs_dmp'
    if (Test-Path -LiteralPath $nested -PathType Container) {
        foreach ($name in $KnownSources) {
            if (Test-Path -LiteralPath (Join-Path $nested $name) -PathType Leaf) { return $nested }
        }
    }
    return $SnapshotPath
}
function Get-SnapshotFingerprint {
    param([string]$SnapshotPath)
    $data = Resolve-SnapshotDataPath $SnapshotPath
    $parts = New-Object System.Collections.ArrayList
    foreach ($name in $KnownSources) {
        $path = Join-Path $data $name
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            [void]$parts.Add(($name + '=' + (Get-FileSha256 $path)))
        } else {
            [void]$parts.Add(($name + '=MISSING'))
        }
    }
    return Get-TextSha256 (($parts -join "`n") + "`n")
}

$roots = New-Object System.Collections.ArrayList
[void]$roots.Add($Invocation)
$parent = Split-Path -Parent $Invocation
if ($parent   -and     -not   [StringComparer]::OrdinalIgnoreCase.Equals($parent,$Invocation)) {
    [void]$roots.Add($parent)
}

$candidates = New-Object System.Collections.ArrayList
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($root in $roots) {
    foreach ($dir in @(Get-ChildItem -LiteralPath $root -Directory -Filter 'mvs_databases*' -ErrorAction SilentlyContinue)) {
        if ($seen.Add($dir.FullName)) { [void]$candidates.Add($dir) }
    }
}
if ($candidates.Count   -eq   0) {
    Write-ColoredLine 'No mvs_databases* folder found in current or parent folder.' Red
    [Environment]::Exit(3)
}
function Get-DatabaseRootUpdatedUtc {
    param([object]$Directory)
    $summaryPath = Join-Path $Directory.FullName 'database-summary.json'
    if (Test-Path -LiteralPath $summaryPath -PathType Leaf) {
        try {
            $meta = ConvertFrom-Json ([IO.File]::ReadAllText($summaryPath))
            if ([string]$meta.updated) { return ([DateTimeOffset]::Parse([string]$meta.updated)).UtcDateTime }
        } catch {}
    }
    return $Directory.LastWriteTimeUtc
}

$db = @($candidates | Sort-Object @{Expression={Get-DatabaseRootUpdatedUtc $_};Descending=$true}, @{Expression={$_.FullName};Descending=$false})[0]
$lastUpdated = $db.LastWriteTime
$databaseSummaryPath = Join-Path $db.FullName 'database-summary.json'
if (Test-Path -LiteralPath $databaseSummaryPath -PathType Leaf) {
    try {
        $databaseSummaryMeta = ConvertFrom-Json ([IO.File]::ReadAllText($databaseSummaryPath))
        if ([string]$databaseSummaryMeta.updated) {
            $lastUpdated = ([DateTimeOffset]::Parse([string]$databaseSummaryMeta.updated)).LocalDateTime
        }
    } catch {}
}
Write-ColoredLine ('MVS database summary ' + $Version) Cyan
Write-ColoredLine ('Project version: ' + $ProjectVersion) Cyan
Write-ColoredLine ('Database root: ' + $db.FullName) Cyan
Write-ColoredLine ('Last updated: ' + $lastUpdated.ToString('yyyy-MM-dd HH:mm:ss'))

$slots = @(Get-ChildItem -LiteralPath $db.FullName -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'database-state.json') -PathType Leaf } |
    Sort-Object Name)
if ($slots.Count   -eq   0) {
    Write-ColoredLine 'No database slots with database-state.json were found.' Red
    [Environment]::Exit(4)
}

$overall = 'PASS'
foreach ($slot in $slots) {
    $state = ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $slot.FullName 'database-state.json')))
    Write-ColoredLine ''
    Write-ColoredLine ('=== ' + $slot.Name + ' ===') Cyan

    $archive = Join-Path $slot.FullName 'archive-analysis'
    $full = Join-Path $slot.FullName 'family-index'
    $compact = Join-Path $slot.FullName 'compact-index'
    $health = 'PASS'
    $problems = New-Object System.Collections.ArrayList
    if ([string]$state.status -ne 'PASS') {
        [void]$problems.Add(('last create/update status=' + [string]$state.status))
        $health = 'FAIL'
    }

    foreach ($pair in @(@('archive',$archive),@('family',$full),@('compact',$compact))) {
        if (  -not   (Test-Path -LiteralPath $pair[1] -PathType Container)) {
            [void]$problems.Add(('missing ' + $pair[0] + ' database'))
            $health = 'FAIL'
        }
    }

    $validation = ''
    $validationPath = Join-Path $slot.FullName 'validation-status.txt'
    if (Test-Path -LiteralPath $validationPath -PathType Leaf) {
        $validation = (Get-Content -LiteralPath $validationPath -First 1).Trim()
    }
    if ($validation   -ne   'PASS') {
        [void]$problems.Add('database validation not PASS')
        $health = 'FAIL'
    }

    $source = [string]$state.archive_path
    if (  -not   (Test-Path -LiteralPath $source -PathType Container)) {
        foreach ($root in $roots) {
            $candidate = Join-Path $root ([string]$state.archive_name)
            if (Test-Path -LiteralPath $candidate -PathType Container) {
                $source = (Resolve-Path -LiteralPath $candidate).Path
                break
            }
        }
    }

    $sourceNames = @()
    $databaseNames = @()
    $changed = New-Object System.Collections.ArrayList
    if (Test-Path -LiteralPath $source -PathType Container) {
        $sourceNames = @(Get-ChildItem -LiteralPath $source -Directory |
            Where-Object { $_.Name   -match   $Pattern } |
            Sort-Object Name |
            Select-Object -ExpandProperty Name)
    } else {
        [void]$problems.Add('source archive unavailable')
        if ($health   -eq   'PASS') { $health = 'WARN' }
    }

    $snapshotsPath = Join-Path $archive 'snapshots.tsv'
    if (Test-Path -LiteralPath $snapshotsPath -PathType Leaf) {
        $databaseNames = @(Import-Csv -LiteralPath $snapshotsPath -Delimiter "`t" |
            ForEach-Object { [string]$_.snapshot })
    }

    $sourceSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $sourceNames) { [void]$sourceSet.Add($name) }
    $databaseSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $databaseNames) { [void]$databaseSet.Add($name) }

    $missing = @($sourceNames | Where-Object {   -not   $databaseSet.Contains($_) })
    $extra = @($databaseNames | Where-Object {   -not   $sourceSet.Contains($_) })
    if ($missing.Count   -gt   0) {
        [void]$problems.Add(($missing.Count.ToString() + ' source dump(s) not processed'))
        if ($health   -eq   'PASS') { $health = 'WARN' }
    }
    if ($extra.Count   -gt   0) {
        [void]$problems.Add(($extra.Count.ToString() + ' database dump(s) no longer present in source'))
        if ($health   -eq   'PASS') { $health = 'WARN' }
    }

    $fingerprintsPath = Join-Path $archive 'source-fingerprints.tsv'
    if ((Test-Path -LiteralPath $source -PathType Container)   -and  
        (Test-Path -LiteralPath $fingerprintsPath -PathType Leaf)) {
        $oldFingerprints = @{}
        foreach ($row in @(Import-Csv -LiteralPath $fingerprintsPath -Delimiter "`t")) {
            $oldFingerprints[[string]$row.snapshot] = [string]$row.fingerprint
        }
        foreach ($name in @($sourceNames | Where-Object { $databaseSet.Contains($_) })) {
            if ($oldFingerprints.ContainsKey($name)) {
                $snapshotPath = Join-Path $source $name
                if ((Get-SnapshotFingerprint $snapshotPath)   -ne   $oldFingerprints[$name]) {
                    [void]$changed.Add($name)
                }
            } else {
                [void]$changed.Add($name)
            }
        }
        if ($changed.Count   -gt   0) {
            [void]$problems.Add(($changed.Count.ToString() + ' processed dump(s) changed on disk'))
            if ($health   -eq   'PASS') { $health = 'WARN' }
        }
    }

    $planned = 0
    $completed = 0
    $fail = 0
    $planPath = Join-Path $archive 'plan.tsv'
    $runsPath = Join-Path $archive 'runs.tsv'
    if (Test-Path -LiteralPath $planPath -PathType Leaf) {
        $planned = @(Import-Csv -LiteralPath $planPath -Delimiter "`t").Count
    }
    if (Test-Path -LiteralPath $runsPath -PathType Leaf) {
        $runs = @(Import-Csv -LiteralPath $runsPath -Delimiter "`t")
        $completed = $runs.Count
        $fail = @($runs | Where-Object { $_.status   -eq   'FAIL' }).Count
    }
    if ($planned   -ne   $completed   -or   $fail   -gt   0) {
        [void]$problems.Add(('archive checks incomplete/failing: ' + $completed + '/' + $planned + ' FAIL=' + $fail))
        $health = 'FAIL'
    }

    $qualityWarnings = '?'
    $qualityErrors = '?'
    $qualityPath = Join-Path $archive 'quality-check\summary.txt'
    if (Test-Path -LiteralPath $qualityPath -PathType Leaf) {
        $qualityLines = @(Get-Content -LiteralPath $qualityPath)
        for ($i=0; $i   -lt   ($qualityLines.Count - 1); $i++) {
            $label = $qualityLines[$i].Trim()
            $candidate = $qualityLines[$i+1].Trim()
            if ($label   -eq   'Warnings:'   -and   $qualityWarnings   -eq   '?'   -and   $candidate   -match   '^\d+$') { $qualityWarnings = $candidate }
            if ($label   -eq   'Errors:'   -and   $qualityErrors   -eq   '?'   -and   $candidate   -match   '^\d+$') { $qualityErrors = $candidate }
        }
        $qualityErrorCount = 0
        if ([int]::TryParse($qualityErrors,[ref]$qualityErrorCount)   -and   $qualityErrorCount   -gt   0) {
            [void]$problems.Add(('quality errors=' + $qualityErrors))
            $health = 'FAIL'
        }
    }

    if ($health   -eq   'FAIL') {
        $overall = 'FAIL'
    } elseif ($health   -eq   'WARN'   -and   $overall   -eq   'PASS') {
        $overall = 'WARN'
    }

    $healthColor = if ($health   -eq   'PASS') { 'Green' } elseif ($health   -eq   'WARN') { 'Yellow' } else { 'Red' }
    Write-ColoredLine ('Health: ' + $health) $healthColor
    Write-ColoredLine ('Source archive: ' + $source)
    Write-ColoredLine ('Completeness: source snapshots=' + $sourceNames.Count +
        ' database snapshots=' + $databaseNames.Count +
        ' missing=' + $missing.Count +
        ' changed=' + $changed.Count)
    Write-ColoredLine ('Archive checks: ' + $completed + '/' + $planned + ' FAIL=' + $fail)
    $validationColor = if ($validation   -eq   'PASS') { 'Green' } else { 'Red' }
    Write-ColoredLine ('Validation: ' + $(if ($validation) { $validation } else { 'UNKNOWN' })) $validationColor

    $qualityColor = 'Green'
    $qualityWarningCount = 0
    $qualityErrorCount = 0
    if ([int]::TryParse($qualityErrors,[ref]$qualityErrorCount)   -and   $qualityErrorCount   -gt   0) {
        $qualityColor = 'Red'
    } elseif ([int]::TryParse($qualityWarnings,[ref]$qualityWarningCount)   -and   $qualityWarningCount   -gt   0) {
        $qualityColor = 'Yellow'
    }
    Write-ColoredLine ('Quality: warnings=' + $qualityWarnings + ' (advisory) errors=' + $qualityErrors) $qualityColor
    if ([string]$state.latest_html) { Write-ColoredLine ('Latest HTML: ' + [string]$state.latest_html) }

    foreach ($problem in $problems) {
        $problemColor = if ($health   -eq   'FAIL') { 'Red' } else { 'Yellow' }
        Write-ColoredLine ('  - ' + $problem) $problemColor
    }
}
Write-ColoredLine ''
$overallColor = if ($overall   -eq   'PASS') { 'Green' } elseif ($overall   -eq   'WARN') { 'Yellow' } else { 'Red' }
Write-ColoredLine ('OVERALL HEALTH: ' + $overall) $overallColor
if ($overall   -eq   'FAIL') { [Environment]::Exit(1) }
[Environment]::Exit(0)
