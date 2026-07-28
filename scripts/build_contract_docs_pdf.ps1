param(
    [string]$Root = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

function HtmlEncode([string]$s) {
    return [System.Net.WebUtility]::HtmlEncode($s)
}

function Convert-InlineMarkdown([string]$s) {
    $encoded = HtmlEncode $s
    $encoded = [regex]::Replace($encoded, '`([^`]+)`', '<code>$1</code>')
    return $encoded
}

function Get-ChromePath {
    $candidates = @(
        'C:\Program Files\Google\Chrome\Application\chrome.exe',
        'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
    )
    $chrome = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $chrome) { throw 'Chrome/Edge executable was not found.' }
    return $chrome
}

function Get-MermaidBlocks([string]$markdown) {
    $matches = [regex]::Matches($markdown, '```mermaid\s*([\s\S]*?)```')
    $blocks = New-Object System.Collections.Generic.List[string]
    foreach ($m in $matches) { $blocks.Add($m.Groups[1].Value.Trim()) }
    return $blocks
}

function Get-SummaryHtml([string]$baseName) {
    if ($baseName -eq 'requirements') {
        return 'Salesforce / freee &#22865;&#32004;&#12539;&#35531;&#27714;&#36899;&#25658;&#12398;&#25552;&#20986;&#29992;&#36039;&#26009;&#12391;&#12377;&#12290;'
    }
    return 'Salesforce / freee &#26989;&#21209;&#12510;&#12491;&#12517;&#12450;&#12523;&#12398;&#25552;&#20986;&#29992;&#36039;&#26009;&#12391;&#12377;&#12290;'
}

function Build-CoverHtml([string]$title, [string]$baseName) {
    $date = Get-Date -Format 'yyyy/MM/dd'
    $safeTitle = HtmlEncode $title
    $summary = Get-SummaryHtml $baseName
    return @"
<section class="cover page-break-after">
  <div class="cover-kicker">SAMURAI Salesforce Project</div>
  <h1>$safeTitle</h1>
  <p class="cover-summary">$summary</p>
  <div class="cover-meta">
    <div><span>&#29256;</span><strong>&#25552;&#20986;&#29992;</strong></div>
    <div><span>&#20316;&#25104;&#26085;</span><strong>$date</strong></div>
  </div>
</section>
"@
}

function Build-TocHtml([string]$markdown) {
    $matches = [regex]::Matches($markdown, '^##\s+(.+)$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if ($matches.Count -eq 0) { return '' }
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<section class="toc page-break-after">')
    [void]$sb.AppendLine('<h1>&#30446;&#27425;</h1>')
    [void]$sb.AppendLine('<ol>')
    foreach ($m in $matches) {
        [void]$sb.AppendLine("<li>$(Convert-InlineMarkdown $m.Groups[1].Value.Trim())</li>")
    }
    [void]$sb.AppendLine('</ol>')
    [void]$sb.AppendLine('</section>')
    return $sb.ToString()
}

function Build-MermaidHtml([string]$mermaid, [string]$title) {
    $safeTitle = HtmlEncode $title
    $safeMermaid = HtmlEncode $mermaid
    return @"
<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<title>$safeTitle</title>
<style>
html, body { margin: 0; padding: 0; background: #fff; font-family: "Meiryo", "Yu Gothic", "YuGothic", sans-serif; }
.wrap { display: inline-block; padding: 28px; background: #fff; min-width: 1200px; }
.mermaid { display: inline-block; background: #fff; }
svg { max-width: none !important; font-family: "Meiryo", "Yu Gothic", "YuGothic", sans-serif !important; }
</style>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10.9.3/dist/mermaid.min.js"></script>
</head>
<body>
<div class="wrap"><pre class="mermaid">
$safeMermaid
</pre></div>
<script>
mermaid.initialize({
  startOnLoad: true,
  securityLevel: 'loose',
  theme: 'default',
  flowchart: { htmlLabels: true, curve: 'basis' },
  sequence: { useMaxWidth: false },
  er: { useMaxWidth: false }
});
</script>
</body>
</html>
"@
}

function Crop-PngToContent([string]$pngPath) {
    Add-Type -AssemblyName System.Drawing
    $bitmap = [System.Drawing.Bitmap]::FromFile($pngPath)
    try {
        $minX = $bitmap.Width; $minY = $bitmap.Height; $maxX = 0; $maxY = 0; $found = $false
        for ($y = 0; $y -lt $bitmap.Height; $y += 2) {
            for ($x = 0; $x -lt $bitmap.Width; $x += 2) {
                $c = $bitmap.GetPixel($x, $y)
                if (-not ($c.R -gt 248 -and $c.G -gt 248 -and $c.B -gt 248)) {
                    $found = $true
                    if ($x -lt $minX) { $minX = $x }
                    if ($y -lt $minY) { $minY = $y }
                    if ($x -gt $maxX) { $maxX = $x }
                    if ($y -gt $maxY) { $maxY = $y }
                }
            }
        }
        if (-not $found) { return }
        $pad = 24
        $left = [Math]::Max(0, $minX - $pad)
        $top = [Math]::Max(0, $minY - $pad)
        $right = [Math]::Min($bitmap.Width - 1, $maxX + $pad)
        $bottom = [Math]::Min($bitmap.Height - 1, $maxY + $pad)
        $width = $right - $left + 1
        $height = $bottom - $top + 1
        if ($width -le 0 -or $height -le 0) { return }
        $clone = $bitmap.Clone([System.Drawing.Rectangle]::new($left, $top, $width, $height), $bitmap.PixelFormat)
        $bitmap.Dispose(); $bitmap = $null
        $tmp = "$pngPath.tmp.png"
        $clone.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
        $clone.Dispose()
        Move-Item -LiteralPath $tmp -Destination $pngPath -Force
    } finally {
        if ($bitmap) { $bitmap.Dispose() }
    }
}

function Export-MermaidImages([string]$markdown, [string]$baseName, [string]$outDir) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $blocks = Get-MermaidBlocks $markdown
    $chrome = Get-ChromePath
    $images = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $blocks.Count; $i++) {
        $num = '{0:D2}' -f ($i + 1)
        $htmlPath = Join-Path $outDir "$baseName-diagram-$num.html"
        $pngPath = Join-Path $outDir "$baseName-diagram-$num.png"
        if ((Test-Path $pngPath) -and ((Get-Item $pngPath).Length -gt 0)) {
            $images.Add([System.IO.Path]::GetFullPath($pngPath))
            continue
        }
        Set-Content -LiteralPath $htmlPath -Value (Build-MermaidHtml $blocks[$i] "$baseName $num") -Encoding UTF8
        if (Test-Path $pngPath) { Remove-Item -LiteralPath $pngPath -Force }
        $fullHtml = [System.IO.Path]::GetFullPath($htmlPath).Replace('\', '/')
        $fullPng = [System.IO.Path]::GetFullPath($pngPath)
        & $chrome --headless --disable-gpu --no-sandbox --allow-file-access-from-files --force-device-scale-factor=2 --virtual-time-budget=7000 --window-size=2600,1900 --screenshot="$fullPng" "file:///$fullHtml" | Out-Null
        if (-not (Test-Path $fullPng)) { throw "Mermaid image was not created: $fullPng" }
        Crop-PngToContent $fullPng
        Remove-Item -LiteralPath $htmlPath -Force -ErrorAction SilentlyContinue
        $images.Add([System.IO.Path]::GetFullPath($pngPath))
    }
    return $images
}

function Flush-Table([System.Text.StringBuilder]$sb, [System.Collections.Generic.List[string]]$tableLines) {
    if ($tableLines.Count -lt 2) { return }
    $rows = @()
    foreach ($line in $tableLines) {
        if ($line -match '^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$') { continue }
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith('|')) { $trimmed = $trimmed.Substring(1) }
        if ($trimmed.EndsWith('|')) { $trimmed = $trimmed.Substring(0, $trimmed.Length - 1) }
        $rows += ,($trimmed -split '\|')
    }
    if ($rows.Count -eq 0) { $tableLines.Clear(); return }
    [void]$sb.AppendLine('<table>')
    for ($i = 0; $i -lt $rows.Count; $i++) {
        [void]$sb.AppendLine('<tr>')
        foreach ($cell in $rows[$i]) {
            $tag = if ($i -eq 0) { 'th' } else { 'td' }
            [void]$sb.AppendLine("<$tag>$(Convert-InlineMarkdown $cell.Trim())</$tag>")
        }
        [void]$sb.AppendLine('</tr>')
    }
    [void]$sb.AppendLine('</table>')
    $tableLines.Clear()
}

function Convert-MarkdownToHtml([string]$markdown, [string]$title, [string]$baseName, [System.Collections.Generic.List[string]]$diagramImages) {
    $lines = $markdown -split "`r?`n"
    $sb = [System.Text.StringBuilder]::new()
    $inFence = $false; $fenceType = ''; $fenceLines = [System.Collections.Generic.List[string]]::new()
    $tableLines = [System.Collections.Generic.List[string]]::new()
    $diagramIndex = 0
    foreach ($line in $lines) {
        if ($line -match '^```(\w+)?\s*$') {
            if (-not $inFence) {
                Flush-Table $sb $tableLines
                $inFence = $true; $fenceType = $Matches[1]; $fenceLines.Clear()
            } else {
                $content = ($fenceLines -join "`n")
                if ($fenceType -eq 'mermaid') {
                    $imgPath = $diagramImages[$diagramIndex]; $diagramIndex++
                    $uri = (New-Object System.Uri($imgPath)).AbsoluteUri
                    [void]$sb.AppendLine("<div class=""diagram-block""><img class=""diagram-img"" src=""$uri"" alt=""diagram $diagramIndex""></div>")
                } else {
                    [void]$sb.AppendLine('<pre class="code-block"><code>')
                    [void]$sb.AppendLine((HtmlEncode $content))
                    [void]$sb.AppendLine('</code></pre>')
                }
                $inFence = $false; $fenceType = ''
            }
            continue
        }
        if ($inFence) { $fenceLines.Add($line); continue }
        if ($line -match '^\s*\|.*\|\s*$') { $tableLines.Add($line); continue } else { Flush-Table $sb $tableLines }
        if ($line -match '^# (.+)$') { [void]$sb.AppendLine("<h1>$(Convert-InlineMarkdown $Matches[1])</h1>") }
        elseif ($line -match '^## (.+)$') { [void]$sb.AppendLine("<h2>$(Convert-InlineMarkdown $Matches[1])</h2>") }
        elseif ($line -match '^### (.+)$') { [void]$sb.AppendLine("<h3>$(Convert-InlineMarkdown $Matches[1])</h3>") }
        elseif ($line -match '^#### (.+)$') { [void]$sb.AppendLine("<h4>$(Convert-InlineMarkdown $Matches[1])</h4>") }
        elseif ($line -match '^\s*[-*]\s+(.+)$') { [void]$sb.AppendLine("<p class='bullet'>- $(Convert-InlineMarkdown $Matches[1])</p>") }
        elseif ($line -match '^\s*(\d+)\.\s+(.+)$') { [void]$sb.AppendLine("<p class='numbered'>$($Matches[1]). $(Convert-InlineMarkdown $Matches[2])</p>") }
        elseif ([string]::IsNullOrWhiteSpace($line)) { [void]$sb.AppendLine('<div class="blank"></div>') }
        else { [void]$sb.AppendLine("<p>$(Convert-InlineMarkdown $line)</p>") }
    }
    Flush-Table $sb $tableLines
    $safeTitle = HtmlEncode $title
    $cover = Build-CoverHtml $title $baseName
    $toc = Build-TocHtml $markdown
    $body = $sb.ToString()
    return @"
<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<title>$safeTitle</title>
<style>
@page { size: A4; margin: 14mm 12mm; }
body { font-family: "Meiryo", "Yu Gothic", "YuGothic", "MS Gothic", sans-serif; color: #172033; font-size: 10.5pt; line-height: 1.55; }
h1 { font-size: 21pt; margin: 0 0 14px; padding-bottom: 8px; border-bottom: 2px solid #1f4e79; color: #17365d; break-after: avoid; }
h2 { font-size: 15pt; margin: 22px 0 8px; padding-left: 8px; border-left: 4px solid #1f4e79; color: #17365d; break-after: avoid; }
h3 { font-size: 12.5pt; margin: 16px 0 6px; color: #244766; break-after: avoid; }
h4 { font-size: 11pt; margin: 12px 0 4px; color: #244766; break-after: avoid; }
p { margin: 3px 0 6px; }
.bullet, .numbered { margin-left: 12px; }
.blank { height: 4px; }
code { font-family: Consolas, "Yu Gothic", monospace; background: #f2f5f8; padding: 1px 4px; border-radius: 3px; }
.code-block { white-space: pre-wrap; background: #f6f8fa; border: 1px solid #d8dee6; border-radius: 6px; padding: 8px; font-size: 8.5pt; }
table { border-collapse: collapse; width: 100%; margin: 8px 0 12px; page-break-inside: avoid; }
th, td { border: 1px solid #c9d3df; padding: 5px 6px; vertical-align: top; }
th { background: #eaf1f8; color: #17365d; font-weight: 700; }
.diagram-block { margin: 10px 0 16px; page-break-inside: avoid; text-align: center; }
.diagram-img { width: 100%; max-width: 100%; height: auto; border: 1px solid #d5dde7; border-radius: 8px; background: #fff; }
.page-break-after { break-after: page; page-break-after: always; }
.cover { min-height: 235mm; display: flex; flex-direction: column; justify-content: center; }
.cover-kicker { color: #5f6f82; font-size: 11pt; letter-spacing: .06em; text-transform: uppercase; margin-bottom: 12px; }
.cover h1 { font-size: 28pt; line-height: 1.25; border-bottom: 3px solid #1f4e79; padding-bottom: 14px; margin-bottom: 18px; }
.cover-summary { font-size: 12pt; max-width: 150mm; color: #26384a; margin-bottom: 28px; }
.cover-meta { display: grid; grid-template-columns: 40mm 40mm; gap: 10mm; color: #26384a; }
.cover-meta span { display: block; color: #6a7888; font-size: 9pt; margin-bottom: 3px; }
.cover-meta strong { font-size: 12pt; }
.toc h1 { font-size: 20pt; }
.toc ol { columns: 2; column-gap: 12mm; margin: 10px 0 0; padding-left: 20px; }
.toc li { break-inside: avoid; margin: 0 0 5px; }
</style>
</head>
<body>
$cover
$toc
$body
</body>
</html>
"@
}

function Build-Pdf([string]$mdPath, [string]$pdfPath, [string]$baseName) {
    $markdown = Get-Content -LiteralPath $mdPath -Raw -Encoding UTF8
    $titleMatch = [regex]::Match($markdown, '^#\s+(.+)$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    $title = if ($titleMatch.Success) { $titleMatch.Groups[1].Value.Trim() } else { $baseName }
    $contractFolder = Split-Path (Split-Path $pdfPath -Parent) -Parent
    $diagramDir = Join-Path (Join-Path $contractFolder 'diagrams') 'mermaid-images'
    $images = Export-MermaidImages -markdown $markdown -baseName $baseName -outDir $diagramDir
    $html = Convert-MarkdownToHtml -markdown $markdown -title $title -baseName $baseName -diagramImages $images
    $htmlPath = [System.IO.Path]::ChangeExtension($pdfPath, '.html')
    Set-Content -LiteralPath $htmlPath -Value $html -Encoding UTF8
    $chrome = Get-ChromePath
    $fullHtml = [System.IO.Path]::GetFullPath($htmlPath).Replace('\', '/')
    $fullPdf = [System.IO.Path]::GetFullPath($pdfPath)
    if (Test-Path $fullPdf) { Remove-Item -LiteralPath $fullPdf -Force }
    & $chrome --headless --disable-gpu --no-sandbox --allow-file-access-from-files --virtual-time-budget=5000 --print-to-pdf-no-header --print-to-pdf="$fullPdf" "file:///$fullHtml" | Out-Null
    if (-not (Test-Path $fullPdf)) { throw "PDF was not created: $fullPdf" }
    Remove-Item -LiteralPath $htmlPath -Force -ErrorAction SilentlyContinue
    return [pscustomobject]@{ Pdf = $fullPdf; Images = $images.Count; Size = (Get-Item $fullPdf).Length }
}

$docs = Join-Path $Root 'docs'
$contractDocs = Join-Path $docs 'contract-billing'
$contractPdf = Join-Path $contractDocs 'pdf'
New-Item -ItemType Directory -Force -Path $contractPdf | Out-Null

$results = @()
$results += Build-Pdf (Join-Path $contractDocs 'contract-billing-requirements.md') (Join-Path $contractPdf 'contract-billing-requirements.pdf') 'requirements'
$results += Build-Pdf (Join-Path $contractDocs 'contract-billing-business-manual.md') (Join-Path $contractPdf 'contract-billing-business-manual.pdf') 'manual'
$results | Format-Table -AutoSize
