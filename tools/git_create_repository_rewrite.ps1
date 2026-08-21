param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Plan", "Apply", "Restore")]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [string]$Root,

    [string]$OldSlug = "",
    [string]$NewSlug = "",

    [ValidateSet("all", "urls", "none")]
    [string]$References = "all",

    [ValidateSet("yes", "no")]
    [string]$RenameName = "yes",

    [string]$Report = "",
    [string]$BackupRoot = ""
)

$ErrorActionPreference = "Stop"

function Get-TextInfo {
    param([byte[]]$Bytes)

    if ($Bytes.Length -eq 0) {
        return [pscustomobject]@{
            IsText = $true
            Encoding = New-Object System.Text.UTF8Encoding($false)
            Text = ""
            Name = "UTF-8 without BOM"
        }
    }

    if ($Bytes.Length -ge 3 -and
        $Bytes[0] -eq 0xEF -and
        $Bytes[1] -eq 0xBB -and
        $Bytes[2] -eq 0xBF) {
        $encoding = New-Object System.Text.UTF8Encoding($true, $true)
        return [pscustomobject]@{
            IsText = $true
            Encoding = $encoding
            Text = $encoding.GetString($Bytes, 3, $Bytes.Length - 3)
            Name = "UTF-8 with BOM"
        }
    }

    if ($Bytes.Length -ge 2 -and
        $Bytes[0] -eq 0xFF -and
        $Bytes[1] -eq 0xFE) {
        $encoding = New-Object System.Text.UnicodeEncoding($false, $true, $true)
        return [pscustomobject]@{
            IsText = $true
            Encoding = $encoding
            Text = $encoding.GetString($Bytes, 2, $Bytes.Length - 2)
            Name = "UTF-16 LE"
        }
    }

    if ($Bytes.Length -ge 2 -and
        $Bytes[0] -eq 0xFE -and
        $Bytes[1] -eq 0xFF) {
        $encoding = New-Object System.Text.UnicodeEncoding($true, $true, $true)
        return [pscustomobject]@{
            IsText = $true
            Encoding = $encoding
            Text = $encoding.GetString($Bytes, 2, $Bytes.Length - 2)
            Name = "UTF-16 BE"
        }
    }

    if ($Bytes -contains 0) {
        return [pscustomobject]@{
            IsText = $false
            Encoding = $null
            Text = $null
            Name = "binary"
        }
    }

    try {
        $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
        $text = $strictUtf8.GetString($Bytes)
        return [pscustomobject]@{
            IsText = $true
            Encoding = New-Object System.Text.UTF8Encoding($false)
            Text = $text
            Name = "UTF-8 without BOM"
        }
    }
    catch {
        $encoding = [System.Text.Encoding]::GetEncoding(
            1252,
            [System.Text.EncoderExceptionFallback]::new(),
            [System.Text.DecoderExceptionFallback]::new()
        )

        try {
            $text = $encoding.GetString($Bytes)
            return [pscustomobject]@{
                IsText = $true
                Encoding = $encoding
                Text = $text
                Name = "Windows-1252"
            }
        }
        catch {
            return [pscustomobject]@{
                IsText = $false
                Encoding = $null
                Text = $null
                Name = "binary or unsupported encoding"
            }
        }
    }
}

function Write-TextPreservingEncoding {
    param(
        [string]$Path,
        [string]$Text,
        [System.Text.Encoding]$Encoding
    )

    [System.IO.File]::WriteAllText($Path, $Text, $Encoding)
}

function Get-CandidateFiles {
    param([string]$ProjectRoot)

    $output = & git.exe -C $ProjectRoot ls-files -co --exclude-standard 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "git ls-files failed."
    }

    # These are disposable root-level build products created by the project
    # framework. Requiring a directory separator after the first path component
    # avoids excluding legitimate files such as build_config.bat.
    $generatedRootPattern = '^(?:build_[^/\\]+|source_[^/\\]+|oldbuilds)[/\\]'

    return @(
        $output |
        Where-Object { $_ -and $_.Trim().Length -gt 0 } |
        Where-Object { $_ -notmatch $generatedRootPattern } |
        Sort-Object -Unique
    )
}

function Get-Replacements {
    param(
        [string]$SourceSlug,
        [string]$TargetSlug,
        [string]$ReferenceMode,
        [string]$RenameRepositoryName
    )

    $sourceParts = $SourceSlug.Split("/", 2)
    $targetParts = $TargetSlug.Split("/", 2)

    if ($sourceParts.Count -ne 2 -or $targetParts.Count -ne 2) {
        throw "OldSlug and NewSlug must use OWNER/REPOSITORY syntax."
    }

    $oldName = $sourceParts[1]
    $newName = $targetParts[1]
    $items = New-Object System.Collections.Generic.List[object]

    if ($ReferenceMode -ne "none") {
        $items.Add([pscustomobject]@{
            Name = "raw GitHub base"
            Old = "https://raw.githubusercontent.com/$SourceSlug/"
            New = "https://raw.githubusercontent.com/$TargetSlug/"
        })
        $items.Add([pscustomobject]@{
            Name = "GitHub HTTPS Git URL"
            Old = "https://github.com/$SourceSlug.git"
            New = "https://github.com/$TargetSlug.git"
        })
        $items.Add([pscustomobject]@{
            Name = "GitHub HTTPS web URL"
            Old = "https://github.com/$SourceSlug"
            New = "https://github.com/$TargetSlug"
        })
        $items.Add([pscustomobject]@{
            Name = "GitHub SSH URL"
            Old = "git@github.com:$SourceSlug.git"
            New = "git@github.com:$TargetSlug.git"
        })
        $items.Add([pscustomobject]@{
            Name = "GitHub SSH scheme URL"
            Old = "ssh://git@github.com/$SourceSlug.git"
            New = "ssh://git@github.com/$TargetSlug.git"
        })
        $items.Add([pscustomobject]@{
            Name = "repository slug"
            Old = $SourceSlug
            New = $TargetSlug
        })
    }

    if ($ReferenceMode -eq "all" -and $RenameRepositoryName -eq "yes") {
        $items.Add([pscustomobject]@{
            Name = "standalone repository name"
            Old = $oldName
            New = $newName
        })
    }

    return @(
        $items.ToArray() |
        Sort-Object { $_.Old.Length } -Descending
    )
}

function Invoke-ReplacementAnalysis {
    param(
        [string]$Text,
        [object[]]$Replacements,
        [switch]$ReturnText
    )

    $working = $Text
    $results = New-Object System.Collections.Generic.List[object]
    $placeholders = New-Object System.Collections.Generic.List[object]
    $index = 0

    foreach ($replacement in $Replacements) {
        if ([string]::IsNullOrEmpty($replacement.Old)) {
            continue
        }

        $regex = New-Object System.Text.RegularExpressions.Regex(
            [regex]::Escape($replacement.Old),
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
        $matches = $regex.Matches($working)

        if ($matches.Count -eq 0) {
            continue
        }

        $results.Add([pscustomobject]@{
            Name = $replacement.Name
            Count = $matches.Count
            Old = $replacement.Old
            New = $replacement.New
        })

        $placeholder = "__GCR_REPLACEMENT_${index}__"
        $working = $regex.Replace(
            $working,
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($match)
                return $placeholder
            }
        )
        $placeholders.Add([pscustomobject]@{
            Placeholder = $placeholder
            Value = $replacement.New
        })
        $index++
    }

    if ($ReturnText) {
        foreach ($item in $placeholders) {
            $working = $working.Replace($item.Placeholder, $item.Value)
        }
    }

    return [pscustomobject]@{
        Matches = $results.ToArray()
        Text = $working
    }
}

function Test-BinaryReference {
    param(
        [byte[]]$Bytes,
        [object[]]$Replacements
    )

    $latin = [System.Text.Encoding]::GetEncoding(28591).GetString($Bytes)

    foreach ($replacement in $Replacements) {
        if ([string]::IsNullOrEmpty($replacement.Old)) {
            continue
        }

        if ($latin.IndexOf(
            $replacement.Old,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -ge 0) {
            return $true
        }
    }

    return $false
}

function Write-Report {
    param(
        [string]$Path,
        [string[]]$Lines
    )

    if ([string]::IsNullOrEmpty($Path)) {
        return
    }

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    [System.IO.File]::WriteAllLines(
        $Path,
        $Lines,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

$rootPath = [System.IO.Path]::GetFullPath($Root)

if ($Mode -eq "Restore") {
    if ([string]::IsNullOrEmpty($BackupRoot)) {
        throw "BackupRoot is required for Restore."
    }

    $manifest = Join-Path $BackupRoot "manifest.txt"
    if (-not (Test-Path -LiteralPath $manifest)) {
        Write-Host "No rewrite backup manifest was found."
        exit 0
    }

    foreach ($relative in [System.IO.File]::ReadAllLines($manifest)) {
        if ([string]::IsNullOrWhiteSpace($relative)) {
            continue
        }

        $source = Join-Path $BackupRoot $relative
        $target = Join-Path $rootPath $relative
        $targetParent = Split-Path -Parent $target

        if (-not (Test-Path -LiteralPath $targetParent)) {
            New-Item -ItemType Directory -Force -Path $targetParent | Out-Null
        }

        Copy-Item -LiteralPath $source -Destination $target -Force
    }

    Write-Host "Restored rewritten files from backup."
    exit 0
}

if ([string]::IsNullOrEmpty($OldSlug) -or
    [string]::IsNullOrEmpty($NewSlug)) {
    throw "OldSlug and NewSlug are required."
}

$replacements = Get-Replacements `
    -SourceSlug $OldSlug `
    -TargetSlug $NewSlug `
    -ReferenceMode $References `
    -RenameRepositoryName $RenameName

$files = Get-CandidateFiles -ProjectRoot $rootPath
$reportLines = New-Object System.Collections.Generic.List[string]
$modifiedFiles = New-Object System.Collections.Generic.List[string]
$binaryFailures = New-Object System.Collections.Generic.List[string]
$totalMatches = 0

$reportLines.Add("Repository reference migration")
$reportLines.Add("==============================")
$reportLines.Add("")
$reportLines.Add("Mode: $Mode")
$reportLines.Add("Root: $rootPath")
$reportLines.Add("Old repository: $OldSlug")
$reportLines.Add("New repository: $NewSlug")
$reportLines.Add("Reference mode: $References")
$reportLines.Add("Rename standalone name: $RenameName")
$reportLines.Add("Candidate files: $($files.Count)")
$reportLines.Add("Excluded generated root folders: build_*, source_*, oldbuilds")
$reportLines.Add("")

foreach ($relative in $files) {
    $fullPath = Join-Path $rootPath $relative

    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    $info = Get-TextInfo -Bytes $bytes

    if (-not $info.IsText) {
        if (Test-BinaryReference -Bytes $bytes -Replacements $replacements) {
            $binaryFailures.Add($relative)
        }
        continue
    }

    $analysis = Invoke-ReplacementAnalysis `
        -Text $info.Text `
        -Replacements $replacements `
        -ReturnText

    if ($analysis.Matches.Count -eq 0) {
        continue
    }

    $fileCount = ($analysis.Matches | Measure-Object -Property Count -Sum).Sum
    $totalMatches += $fileCount
    $reportLines.Add("File: $relative")
    $reportLines.Add("Encoding: $($info.Name)")
    $reportLines.Add("Matches: $fileCount")

    foreach ($match in $analysis.Matches) {
        $reportLines.Add(
            "  $($match.Count) x $($match.Name): $($match.Old) -> $($match.New)"
        )
    }

    $reportLines.Add("")
    $modifiedFiles.Add($relative)

    if ($Mode -eq "Apply") {
        if ([string]::IsNullOrEmpty($BackupRoot)) {
            throw "BackupRoot is required for Apply."
        }

        $backupPath = Join-Path $BackupRoot $relative
        $backupParent = Split-Path -Parent $backupPath

        if (-not (Test-Path -LiteralPath $backupParent)) {
            New-Item -ItemType Directory -Force -Path $backupParent | Out-Null
        }

        [System.IO.File]::WriteAllBytes($backupPath, $bytes)

        Write-TextPreservingEncoding `
            -Path $fullPath `
            -Text $analysis.Text `
            -Encoding $info.Encoding
    }
}

if ($binaryFailures.Count -gt 0) {
    $reportLines.Add("ERROR")
    $reportLines.Add("-----")
    $reportLines.Add(
        "Binary or unsupported files contain repository references and require manual review:"
    )

    foreach ($file in $binaryFailures) {
        $reportLines.Add("  $file")
    }

    Write-Report -Path $Report -Lines ($reportLines.ToArray())
    Write-Host "ERROR: Binary files contain old repository references."
    exit 3
}

if ($Mode -eq "Apply") {
    if (-not (Test-Path -LiteralPath $BackupRoot)) {
        New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
    }

    [System.IO.File]::WriteAllLines(
        (Join-Path $BackupRoot "manifest.txt"),
        $modifiedFiles.ToArray(),
        (New-Object System.Text.UTF8Encoding($false))
    )
}

$reportLines.Add("Summary")
$reportLines.Add("-------")
$reportLines.Add("Files with replacements: $($modifiedFiles.Count)")
$reportLines.Add("Total replacements: $totalMatches")
$reportLines.Add("Binary reference failures: 0")

if ($Mode -eq "Apply") {
    $reportLines.Add("Backup root: $BackupRoot")
}

Write-Report -Path $Report -Lines ($reportLines.ToArray())

Write-Host "Files with repository references: $($modifiedFiles.Count)"
Write-Host "Total repository-reference replacements: $totalMatches"

if ($Mode -eq "Plan") {
    Write-Host "Plan report: $Report"
}
else {
    Write-Host "Applied reference migration."
}

exit 0
