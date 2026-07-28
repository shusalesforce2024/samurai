$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path ".").Path
$xlsx = Join-Path $root "docs\contract-billing\stripe-salesforce-wbs-l4.xlsx"
$tmp = Join-Path $env:TEMP ("stripe_wbs_extract_" + [guid]::NewGuid().ToString("N"))

function ColIndexFromRef([string]$ref) {
    $letters = ([regex]::Match($ref, '^[A-Z]+')).Value
    $n = 0
    foreach ($ch in $letters.ToCharArray()) {
        $n = $n * 26 + ([int][char]$ch - [int][char]'A' + 1)
    }
    return $n
}

function ExcelSerialToDate([double]$serial) {
    return ([datetime]"1899-12-30").AddDays($serial)
}

if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
New-Item -ItemType Directory -Path $tmp | Out-Null
[System.IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path $xlsx), $tmp)

[xml]$wbXml = Get-Content -Path (Join-Path $tmp "xl\workbook.xml") -Raw -Encoding UTF8
$ns = New-Object System.Xml.XmlNamespaceManager($wbXml.NameTable)
$ns.AddNamespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
$sheets = $wbXml.SelectNodes("//x:sheet", $ns)

$excel = New-Object -ComObject Excel.Application
$excel.DisplayAlerts = $false
$wb = $excel.Workbooks.Add()

try {
    while ($wb.Worksheets.Count -lt $sheets.Count) { $wb.Worksheets.Add() | Out-Null }
    while ($wb.Worksheets.Count -gt $sheets.Count) { $wb.Worksheets.Item($wb.Worksheets.Count).Delete() }

    for ($i = 0; $i -lt $sheets.Count; $i++) {
        $sheetName = $sheets[$i].name
        $ws = $wb.Worksheets.Item($i + 1)
        $ws.Name = $sheetName
        [xml]$sheetXml = Get-Content -Path (Join-Path $tmp ("xl\worksheets\sheet" + ($i + 1) + ".xml")) -Raw -Encoding UTF8
        $sns = New-Object System.Xml.XmlNamespaceManager($sheetXml.NameTable)
        $sns.AddNamespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
        $rowNodes = $sheetXml.SelectNodes("//x:sheetData/x:row", $sns)
        $maxRow = 0
        $maxCol = 0
        foreach ($row in $rowNodes) {
            $r = [int]$row.r
            if ($r -gt $maxRow) { $maxRow = $r }
            foreach ($cell in $row.SelectNodes("x:c", $sns)) {
                $c = ColIndexFromRef $cell.r
                if ($c -gt $maxCol) { $maxCol = $c }
                $value = $null
                if ($cell.t -eq "inlineStr") {
                    $tNode = $cell.SelectSingleNode("x:is/x:t", $sns)
                    if ($tNode) { $value = $tNode.InnerText }
                } else {
                    $vNode = $cell.SelectSingleNode("x:v", $sns)
                    if ($vNode) {
                        $raw = $vNode.InnerText
                        if (($c -eq 6 -or $c -eq 7) -and $sheetName -eq "WBS_L4") {
                            $value = ExcelSerialToDate ([double]$raw)
                        } elseif ($c -eq 1 -and $sheetName -eq "マイルストーン") {
                            $value = ExcelSerialToDate ([double]$raw)
                        } elseif ($raw -match '^\d+(\.\d+)?$') {
                            $value = [double]$raw
                        } else {
                            $value = $raw
                        }
                    }
                }
                if ($null -ne $value) {
                    if ($value -is [datetime]) {
                        $ws.Cells.Item($r, $c).Value2 = $value.ToString("yyyy-MM-dd")
                    } else {
                        $ws.Cells.Item($r, $c).Value2 = [string]$value
                    }
                }
            }
        }

        $used = $ws.Range($ws.Cells.Item(1,1), $ws.Cells.Item([Math]::Max(1,$maxRow), [Math]::Max(1,$maxCol)))
        $used.Font.Name = "Meiryo UI"
        $used.Font.Size = 10
        $used.Borders.LineStyle = 1
        $used.Borders.Color = 14277081
        $used.VerticalAlignment = -4108
        $used.WrapText = $true

        $header = $ws.Range($ws.Cells.Item(1,1), $ws.Cells.Item(1, [Math]::Max(1,$maxCol)))
        $header.Interior.Color = 7879740
        $header.Font.Color = 16777215
        $header.Font.Bold = $true
        $header.HorizontalAlignment = -4108

        if ($maxRow -gt 1 -and $maxCol -gt 1) {
            $used.AutoFilter() | Out-Null
        }
        $ws.Application.ActiveWindow.SplitRow = 1
        $ws.Application.ActiveWindow.FreezePanes = $true

        if ($sheetName -eq "WBS_L4") {
            $ws.Columns.Item(1).ColumnWidth = 14
            $ws.Columns.Item(2).ColumnWidth = 16
            $ws.Columns.Item(3).ColumnWidth = 18
            $ws.Columns.Item(4).ColumnWidth = 22
            $ws.Columns.Item(5).ColumnWidth = 50
            $ws.Columns.Item(6).ColumnWidth = 12
            $ws.Columns.Item(7).ColumnWidth = 12
            $ws.Columns.Item(8).ColumnWidth = 12
            $ws.Columns.Item(9).ColumnWidth = 14
            $ws.Columns.Item(10).ColumnWidth = 24
            $ws.Columns.Item(11).ColumnWidth = 12
            $ws.Columns.Item(12).ColumnWidth = 10
            $ws.Columns.Item(13).ColumnWidth = 24
            $ws.Columns.Item(14).ColumnWidth = 24
            $ws.Columns.Item(15).ColumnWidth = 42
            $ws.Range("F:G").NumberFormat = "yyyy-mm-dd"
            $ws.Range("H:H").NumberFormat = "0.0"
        } else {
            $ws.Columns.AutoFit() | Out-Null
            for ($c = 1; $c -le $maxCol; $c++) {
                if ($ws.Columns.Item($c).ColumnWidth -gt 60) { $ws.Columns.Item($c).ColumnWidth = 60 }
            }
        }
    }

    $wb.Worksheets.Item("サマリ").Activate() | Out-Null
    $tmpOut = Join-Path $env:TEMP "stripe-salesforce-wbs-l4-valid.xlsx"
    if (Test-Path $tmpOut) { Remove-Item -LiteralPath $tmpOut -Force }
    $wb.SaveAs($tmpOut, 51)
    $wb.Close($true)
    Copy-Item -LiteralPath $tmpOut -Destination $xlsx -Force
    Remove-Item -LiteralPath $tmpOut -Force
}
finally {
    try { $excel.Quit() } catch {}
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
    Remove-Item -LiteralPath $tmp -Recurse -Force
}

Write-Host "saved=$xlsx"
