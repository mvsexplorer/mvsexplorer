$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

function Write-Line {
    param([AllowEmptyString()][string]$Text)
    [Console]::Out.WriteLine($Text)
}

function Write-Err {
    param([string]$Text)
    [Console]::Error.WriteLine($Text)
}

function Normalize-Scalar {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    return ([regex]::Replace($Value, '[\t\r\n]+', ' ')).Trim()
}

function Normalize-Title {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    $decoded = [System.Net.WebUtility]::HtmlDecode($Value)
    return ([regex]::Replace($decoded, '\s+', ' ')).Trim()
}

function Convert-NoteHtmlToText {
    param([AllowNull()][AllowEmptyString()][string]$Html)
    if ([string]::IsNullOrEmpty($Html)) { return '' }
    $text = [regex]::Replace($Html, '(?is)<br\s*/?>', ' ')
    $text = [regex]::Replace($text, '(?is)</p\s*>', ' ')
    $text = [regex]::Replace($text, '(?is)</li\s*>', ' ')
    $text = [regex]::Replace($text, '(?is)</div\s*>', ' ')
    $text = [regex]::Replace($text, '(?is)<[^>]+>', ' ')
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    $text = $text.Replace([char]0x00A0, ' ')
    return ([regex]::Replace($text, '\s+', ' ')).Trim()
}

function Resolve-DumpFolder {
    param([string]$Name, [string]$Root)
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        $candidates += $Name
        $candidates += (Join-Path (Get-Location).Path $Name)
        if (-not [string]::IsNullOrWhiteSpace($env:MVS_DUMPS_ROOT)) {
            $candidates += (Join-Path $env:MVS_DUMPS_ROOT $Name)
        }
        if (-not [string]::IsNullOrWhiteSpace($Root)) {
            $candidates += (Join-Path $Root $Name)
            $candidates += (Join-Path (Join-Path $Root 'mvs_dumps_archive') $Name)
            $parent = Split-Path -Parent $Root
            if (-not [string]::IsNullOrWhiteSpace($parent)) {
                $candidates += (Join-Path (Join-Path $parent 'mvs_dumps_archive') $Name)
            }
        }
        $candidates += (Join-Path (Join-Path (Get-Location).Path 'mvs_dumps_archive') $Name)
    }
    foreach ($candidate in $candidates) {
        try {
            if (Test-Path -LiteralPath $candidate -PathType Container) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        } catch {
        }
    }
    return $null
}

function Get-NaturalKey {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '' }
    $text = $Value.ToLowerInvariant()
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator]{
        param($Match)
        $digits = $Match.Value
        if ($digits.Length -lt 32) { return $digits.PadLeft(32, '0') }
        return ('~' + $digits.Length.ToString('D6') + ':' + $digits)
    }
    return [regex]::Replace($text, '\d+', $evaluator)
}

function Get-DateTicks {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return [Int64]::MaxValue }
    $dto = [DateTimeOffset]::MinValue
    $styles = [Globalization.DateTimeStyles]::AllowWhiteSpaces -bor [Globalization.DateTimeStyles]::AssumeUniversal
    if ([DateTimeOffset]::TryParse($Value, [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$dto)) {
        return $dto.UtcDateTime.Ticks
    }
    return [Int64]::MaxValue
}

function Sort-Products {
    param([object[]]$Products, [string]$Key)
    switch ($Key) {
        ''      { return @($Products) }
        'id'    { return @($Products | Sort-Object @{Expression={ [int]$_.id }; Ascending=$true}) }
        'title' { return @($Products | Sort-Object @{Expression={ Get-NaturalKey $_.title }; Ascending=$true}, @{Expression={ [int]$_.id }; Ascending=$true}) }
        'date'  { return @($Products | Sort-Object @{Expression={ Get-DateTicks $_.date }; Ascending=$true}, @{Expression={ $_.date }; Ascending=$true}, @{Expression={ [int]$_.id }; Ascending=$true}) }
        default { throw ('Unsupported sort key: ' + $Key) }
    }
}

function New-StarWildcardRegex {
    param([AllowNull()][AllowEmptyString()][string]$Pattern)
    if ($null -eq $Pattern) { $Pattern = '' }
    $escaped = [regex]::Escape($Pattern)
    $escaped = $escaped.Replace('\*', '.*')
    return New-Object System.Text.RegularExpressions.Regex(('^' + $escaped + '$'), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function Read-Products {
    param([string]$DumpFolder)
    $idsPath = Join-Path $DumpFolder 'mvs_ids.txt'
    $datesPath = Join-Path $DumpFolder 'mvs_dates.txt'
    $notesPath = Join-Path $DumpFolder 'mvs_notes.html'

    if (-not (Test-Path -LiteralPath $idsPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new(('Missing required file: ' + $idsPath))
    }
    if (-not (Test-Path -LiteralPath $datesPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new(('Missing required file: ' + $datesPath))
    }

    $datesById = @{}
    foreach ($line in Get-Content -LiteralPath $datesPath -Encoding UTF8) {
        if ($line -match '^(?<date>.*?)\s+-\s+.*?\[ID:\s*(?<id>\d+)\]\s*$') {
            $datesById[[int]$Matches.id] = $Matches.date.Trim()
        }
    }

    $notesByTitle = @{}
    if (Test-Path -LiteralPath $notesPath -PathType Leaf) {
        $html = Get-Content -LiteralPath $notesPath -Raw -Encoding UTF8
        $noteMatches = [regex]::Matches($html, '(?is)<h1>(.*?)</h1>(.*?)(?=<h1>|\z)')
        foreach ($match in $noteMatches) {
            $heading = Normalize-Title ([regex]::Replace($match.Groups[1].Value, '(?is)<[^>]+>', ' '))
            $note = Convert-NoteHtmlToText $match.Groups[2].Value
            if ([string]::IsNullOrWhiteSpace($heading) -or [string]::IsNullOrWhiteSpace($note)) { continue }
            if (-not $notesByTitle.ContainsKey($heading)) {
                $notesByTitle[$heading] = New-Object System.Collections.ArrayList
            }
            if (-not $notesByTitle[$heading].Contains($note)) {
                [void]$notesByTitle[$heading].Add($note)
            }
        }
    }

    $products = New-Object System.Collections.ArrayList
    foreach ($line in Get-Content -LiteralPath $idsPath -Encoding UTF8) {
        if ($line -notmatch '^(?<title>.*?)\s*\[ID:\s*(?<id>\d+)\]\s*$') { continue }
        $id = [int]$Matches.id
        $title = Normalize-Title $Matches.title
        $date = ''
        if ($datesById.ContainsKey($id)) { $date = [string]$datesById[$id] }
        $note = ''
        if ($notesByTitle.ContainsKey($title)) {
            $note = (($notesByTitle[$title] | ForEach-Object { [string]$_ }) -join ' || ')
        }
        [void]$products.Add([pscustomobject]@{
            id = [string]$id
            title = $title
            date = $date
            note = $note
        })
    }
    return @($products)
}
