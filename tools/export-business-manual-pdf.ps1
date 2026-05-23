param(
    [Parameter(Mandatory = $true)]
    [string]$InputMarkdown,

    [Parameter(Mandatory = $true)]
    [string]$OutputPdf
)

$ErrorActionPreference = "Stop"

$inputPath = (Resolve-Path -LiteralPath $InputMarkdown).Path
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPdf)
$outputDir = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$word = $null
$doc = $null

function Add-Paragraph {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Document,
        [string]$Text,
        [int]$Style = -1,
        [string]$FontName = "Yu Gothic",
        [double]$FontSize = 10.5,
        [bool]$Bold = $false,
        [double]$SpaceAfter = 4,
        [double]$LeftIndent = 0
    )

    $range = $Document.Range($Document.Content.End - 1, $Document.Content.End - 1)
    $range.Text = $Text + "`r"
    $paragraph = $range.Paragraphs.Item(1)
    $paragraph.Style = $Style
    $paragraph.SpaceAfter = $SpaceAfter
    $paragraph.LeftIndent = $LeftIndent
    $paragraph.Range.Font.Name = $FontName
    $paragraph.Range.Font.Size = $FontSize
    $paragraph.Range.Font.Bold = [int]$Bold
}

try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0

    $doc = $word.Documents.Add()
    $doc.PageSetup.TopMargin = 42
    $doc.PageSetup.BottomMargin = 42
    $doc.PageSetup.LeftMargin = 48
    $doc.PageSetup.RightMargin = 48

    $lines = Get-Content -LiteralPath $inputPath -Encoding UTF8
    $inCode = $false

    foreach ($line in $lines) {
        if ($line -match '^```') {
            $inCode = -not $inCode
            continue
        }

        if ($inCode) {
            Add-Paragraph -Document $doc -Text $line -FontName "Consolas" -FontSize 8.5 -SpaceAfter 1 -LeftIndent 18
            continue
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
            Add-Paragraph -Document $doc -Text "" -SpaceAfter 0
            continue
        }

        if ($line -match '^# (.+)$') {
            Add-Paragraph -Document $doc -Text $Matches[1] -Style -2 -FontSize 18 -Bold $true -SpaceAfter 10
        }
        elseif ($line -match '^## (.+)$') {
            Add-Paragraph -Document $doc -Text $Matches[1] -Style -3 -FontSize 14 -Bold $true -SpaceAfter 8
        }
        elseif ($line -match '^### (.+)$') {
            Add-Paragraph -Document $doc -Text $Matches[1] -Style -4 -FontSize 12 -Bold $true -SpaceAfter 6
        }
        elseif ($line -match '^\|') {
            if ($line -notmatch '^\|\s*-') {
                Add-Paragraph -Document $doc -Text $line -FontName "Consolas" -FontSize 8 -SpaceAfter 1
            }
        }
        elseif ($line -match '^\s*[-*]\s+(.+)$') {
            Add-Paragraph -Document $doc -Text ("- " + $Matches[1]) -FontSize 10.5 -SpaceAfter 2 -LeftIndent 12
        }
        elseif ($line -match '^\s*\d+\.\s+(.+)$') {
            Add-Paragraph -Document $doc -Text $line -FontSize 10.5 -SpaceAfter 2 -LeftIndent 12
        }
        else {
            Add-Paragraph -Document $doc -Text $line -FontSize 10.5 -SpaceAfter 4
        }
    }

    $doc.ExportAsFixedFormat($outputPath, 17)
}
finally {
    if ($doc -ne $null) {
        $doc.Close($false)
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($doc) | Out-Null
    }
    if ($word -ne $null) {
        $word.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}

Write-Output $outputPath
