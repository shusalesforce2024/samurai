param(
    [string]$SourceCsv = "docs/freee/freee請求移行Work_要確認表_Excel取込用_20260724.csv",
    [string]$OutputXlsx = "outputs/freee-review-20260724/freee請求移行Work_要確認表_20260724.xlsx",
    [string]$PreviewPdf = "outputs/freee-review-20260724/freee請求移行Work_要確認表_20260724_preview.pdf"
)

$ErrorActionPreference = "Stop"

function Get-ExcelColor([string]$hex) {
    $value = $hex.TrimStart("#")
    $r = [Convert]::ToInt32($value.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($value.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($value.Substring(4, 2), 16)
    return $r + ($g * 256) + ($b * 65536)
}

function Release-ComObject($object) {
    if ($null -ne $object) {
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($object)
    }
}

$sourcePath = (Resolve-Path $SourceCsv).Path
$outputPath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputXlsx))
$previewPath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $PreviewPdf))
$outputDirectory = Split-Path -Parent $outputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$records = @(Import-Csv -LiteralPath $sourcePath)
if ($records.Count -eq 0) {
    throw "入力CSVに対象レコードがありません。"
}
function Get-QuestionCodeCount([string]$code) {
    return @($records | Where-Object {
        @(($_.確認コード -split ",") | ForEach-Object { $_.Trim() }) -contains $code
    }).Count
}
$recordLastRow = $records.Count + 1

$navy = Get-ExcelColor "#123B63"
$blue = Get-ExcelColor "#2F75B5"
$paleBlue = Get-ExcelColor "#D9EAF7"
$lightGray = Get-ExcelColor "#F3F6F9"
$border = Get-ExcelColor "#CBD5E1"
$red = Get-ExcelColor "#FDE2E2"
$redText = Get-ExcelColor "#9C1C1C"
$yellow = Get-ExcelColor "#FFF2CC"
$yellowText = Get-ExcelColor "#7F6000"
$green = Get-ExcelColor "#E2F0D9"
$greenText = Get-ExcelColor "#2E6B2E"
$white = Get-ExcelColor "#FFFFFF"

$excel = $null
$workbook = $null
try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $excel.ScreenUpdating = $false

    $workbook = $excel.Workbooks.Add()
    while ($workbook.Worksheets.Count -gt 1) {
        $workbook.Worksheets.Item($workbook.Worksheets.Count).Delete()
    }

    $summary = $workbook.Worksheets.Item(1)
    $summary.Name = "サマリー"
    $recordSheet = $workbook.Worksheets.Add()
    $recordSheet.Name = "レコード別確認"
    $questionSheet = $workbook.Worksheets.Add()
    $questionSheet.Name = "共通質問"
    $historySheet = $workbook.Worksheets.Add()
    $historySheet.Name = "対応履歴"

    foreach ($sheet in @($summary, $recordSheet, $questionSheet, $historySheet)) {
        $sheet.Cells.Font.Name = "Yu Gothic"
        $sheet.Cells.Font.Size = 10
        $sheet.Activate()
        $excel.ActiveWindow.DisplayGridlines = $false
    }

    # サマリー
    $summary.Range("A1:H1").Merge()
    $summary.Range("A1").Value2 = "Freee請求移行Work 要確認表"
    $summary.Range("A1:H1").Interior.Color = $navy
    $summary.Range("A1:H1").Font.Color = $white
    $summary.Range("A1:H1").Font.Bold = $true
    $summary.Range("A1:H1").Font.Size = 18
    $summary.Rows.Item(1).RowHeight = 34

    $summary.Range("A2:H2").Merge()
    $summary.Range("A2").Value2 = "prod / 2026-07-24 本反映・追加解消後　経理確認・対応管理用"
    $summary.Range("A2:H2").Interior.Color = $paleBlue
    $summary.Range("A2:H2").Font.Color = $navy

    $summary.Range("A3").Value2 = "対象件数"
    $summary.Range("B3").Formula = "=COUNTA('レコード別確認'!D2:D$recordLastRow)"
    $summary.Range("D3").Value2 = "未確認件数"
    $summary.Range("E3").Formula = "=COUNTIF('レコード別確認'!Q2:Q$recordLastRow,""未確認"")"
    $summary.Range("G3").Value2 = "対応完了率"
    $summary.Range("H3").Formula = "=(COUNTIF('レコード別確認'!Q2:Q$recordLastRow,""対応済み"")+COUNTIF('レコード別確認'!Q2:Q$recordLastRow,""対象外""))/B3"
    $summary.Range("A3:H3").Interior.Color = $lightGray
    $summary.Range("A3:H3").Font.Bold = $true
    $summary.Range("A3:H3").Font.Color = $navy
    $summary.Range("H3").NumberFormat = "0.0%"

    $summary.Range("A5:B5").Value2 = @(
        @("主原因", "件数")
    )
    $categories = @(
        "契約・契約期間未確定",
        "商品未確定",
        "契約・商品未確定",
        "商品名の類似性不足",
        "既存請求明細との照合不一致",
        "金額不一致",
        "契約・商品・金額不一致",
        "商品・金額不一致",
        "その他"
    )
    for ($index = 0; $index -lt $categories.Count; $index++) {
        $row = 6 + $index
        $summary.Cells.Item($row, 1).Value2 = $categories[$index]
        $summary.Cells.Item($row, 2).Formula = "=COUNTIF('レコード別確認'!C2:C$recordLastRow,A$row)"
    }
    $summary.Range("A5:B5").Interior.Color = $blue
    $summary.Range("A5:B5").Font.Color = $white
    $summary.Range("A5:B5").Font.Bold = $true

    $summary.Range("D5:F5").Value2 = @(
        @("対応状況", "件数", "説明")
    )
    $statusData = @(
        @("未確認", "経理による確認前"),
        @("確認中", "内容を確認中"),
        @("対応待ち", "マスタ・契約等の設定待ち"),
        @("対応済み", "再検証・本反映まで完了"),
        @("対象外", "対応不要と判断")
    )
    for ($index = 0; $index -lt $statusData.Count; $index++) {
        $row = 6 + $index
        $summary.Cells.Item($row, 4).Value2 = $statusData[$index][0]
        $summary.Cells.Item($row, 5).Formula = "=COUNTIF('レコード別確認'!Q2:Q$recordLastRow,D$row)"
        $summary.Cells.Item($row, 6).Value2 = $statusData[$index][1]
    }
    $summary.Range("D5:F5").Interior.Color = $blue
    $summary.Range("D5:F5").Font.Color = $white
    $summary.Range("D5:F5").Font.Bold = $true

    $summary.Range("A16:H16").Merge()
    $summary.Range("A16").Value2 = "最新化結果: 反映可能98件のうち77件を本反映後、追加照合で19件を解消。合計96件が反映済みとなり、追加要確認は2件。現在の要確認61件を掲載。"
    $summary.Range("A16:H16").Interior.Color = $green
    $summary.Range("A16:H16").Font.Color = $greenText
    $summary.Range("A16:H16").Font.Bold = $true
    $summary.Range("A16:H16").WrapText = $true
    $summary.Rows.Item(16).RowHeight = 36

    $summary.Columns.Item("A").ColumnWidth = 30
    $summary.Columns.Item("B").ColumnWidth = 12
    $summary.Columns.Item("C").ColumnWidth = 3
    $summary.Columns.Item("D").ColumnWidth = 16
    $summary.Columns.Item("E").ColumnWidth = 12
    $summary.Columns.Item("F").ColumnWidth = 30
    $summary.Columns.Item("G").ColumnWidth = 16
    $summary.Columns.Item("H").ColumnWidth = 14

    # レコード別確認
    $headers = @(
        "No", "優先度", "主原因", "Work名", "Salesforce URL", "Freee請求書ID", "取引先",
        "請求日", "請求金額", "契約管理", "契約期間", "作成済み請求", "確認コード",
        "個別確認対象", "自動反映可否", "主担当", "対応状況", "確認結果", "対応者", "確認日", "備考"
    )
    for ($column = 0; $column -lt $headers.Count; $column++) {
        $recordSheet.Cells.Item(1, $column + 1).Value2 = $headers[$column]
    }

    for ($index = 0; $index -lt $records.Count; $index++) {
        $row = $index + 2
        $record = $records[$index]
        $salesforceUrl = if ($record.SalesforceURL) {
            $record.SalesforceURL
        }
        else {
            $record.'Salesforce URL'
        }
        $values = @(
            [int]$record.No,
            $record.優先度,
            $record.主原因,
            $record.Work名,
            $salesforceUrl,
            $record.Freee請求書ID,
            $record.取引先,
            $record.請求日,
            [decimal]$record.請求金額,
            $record.契約管理,
            $record.契約期間,
            $record.作成済み請求,
            $record.確認コード,
            $record.個別確認対象,
            $record.自動反映可否,
            "経理",
            "未確認",
            "未入力",
            "",
            "",
            ""
        )
        for ($column = 0; $column -lt $values.Count; $column++) {
            $cell = $recordSheet.Cells.Item([int]$row, [int]($column + 1))
            if ($column -eq 0 -or $column -eq 8) {
                $cell.Value2 = [double]$values[$column]
            }
            else {
                $cell.Value2 = [string]$values[$column]
            }
            Release-ComObject $cell
        }
        if ($salesforceUrl) {
            [void]$recordSheet.Hyperlinks.Add(
                $recordSheet.Cells.Item($row, 5),
                $salesforceUrl,
                "",
                "Salesforceレコードを開く",
                $salesforceUrl
            )
        }
    }

    $lastRow = $records.Count + 1
    $recordSheet.Range("A1:U1").Interior.Color = $navy
    $recordSheet.Range("A1:U1").Font.Color = $white
    $recordSheet.Range("A1:U1").Font.Bold = $true
    $recordSheet.Range("A1:U1").WrapText = $true
    $recordSheet.Rows.Item(1).RowHeight = 34
    $recordSheet.Range("H2:H$lastRow").NumberFormat = "yyyy-mm-dd"
    $recordSheet.Range("I2:I$lastRow").NumberFormat = "#,##0"
    $recordSheet.Range("T2:T$lastRow").NumberFormat = "yyyy-mm-dd"
    $recordSheet.Range("N2:N$lastRow").WrapText = $true
    $recordSheet.Range("E2:E$lastRow").WrapText = $true
    $recordSheet.Range("U2:U$lastRow").WrapText = $true
    $recordSheet.Range("A2:U$lastRow").RowHeight = 45

    $listObject = $recordSheet.ListObjects.Add(1, $recordSheet.Range("A1:U$lastRow"), $null, 1)
    $listObject.Name = "FreeeInvoiceReviewTable"
    $listObject.TableStyle = "TableStyleMedium2"

    $recordSheet.Range("P2:P$lastRow").Validation.Delete()
    $recordSheet.Range("P2:P$lastRow").Validation.Add(3, 1, 1, "経理,システム管理者,営業")
    $recordSheet.Range("Q2:Q$lastRow").Validation.Delete()
    $recordSheet.Range("Q2:Q$lastRow").Validation.Add(3, 1, 1, "未確認,確認中,対応待ち,対応済み,対象外")
    $recordSheet.Range("R2:R$lastRow").Validation.Delete()
    $recordSheet.Range("R2:R$lastRow").Validation.Add(3, 1, 1, "未入力,承認,修正必要,保留")

    $priorityHigh = $recordSheet.Range("B2:B$lastRow").FormatConditions.Add(2, 0, '=$B2="高"')
    $priorityHigh.Interior.Color = $red
    $priorityHigh.Font.Color = $redText
    $priorityHigh.Font.Bold = $true
    $priorityMedium = $recordSheet.Range("B2:B$lastRow").FormatConditions.Add(2, 0, '=$B2="中"')
    $priorityMedium.Interior.Color = $yellow
    $priorityMedium.Font.Color = $yellowText
    $statusComplete = $recordSheet.Range("Q2:Q$lastRow").FormatConditions.Add(2, 0, '=$Q2="対応済み"')
    $statusComplete.Interior.Color = $green
    $statusComplete.Font.Color = $greenText
    $statusWaiting = $recordSheet.Range("Q2:Q$lastRow").FormatConditions.Add(2, 0, '=$Q2="対応待ち"')
    $statusWaiting.Interior.Color = $yellow
    $statusWaiting.Font.Color = $yellowText
    $statusProgress = $recordSheet.Range("Q2:Q$lastRow").FormatConditions.Add(2, 0, '=$Q2="確認中"')
    $statusProgress.Interior.Color = $paleBlue
    $statusProgress.Font.Color = $navy

    $widths = @(7, 8, 23, 15, 58, 16, 28, 12, 14, 15, 15, 15, 12, 58, 20, 14, 12, 12, 14, 12, 30)
    for ($column = 0; $column -lt $widths.Count; $column++) {
        $recordSheet.Columns.Item($column + 1).ColumnWidth = $widths[$column]
    }
    $recordSheet.Activate()
    $excel.ActiveWindow.SplitRow = 1
    $excel.ActiveWindow.SplitColumn = 4
    $excel.ActiveWindow.FreezePanes = $true
    $excel.ActiveWindow.Zoom = 80

    # 共通質問
    $questionSheet.Range("A1:D1").Merge()
    $questionSheet.Range("A1").Value2 = "共通確認事項"
    $questionSheet.Range("A1:D1").Interior.Color = $navy
    $questionSheet.Range("A1:D1").Font.Color = $white
    $questionSheet.Range("A1:D1").Font.Bold = $true
    $questionSheet.Range("A1:D1").Font.Size = 16
    $questionSheet.Range("A3:D3").Value2 = @(
        @("コード", "対象件数", "共通して確認すること", "確認後の対応")
    )
    $questions = @(
        @("C01", (Get-QuestionCodeCount "C01"), "請求が月契約・年契約・単発請求のどれか、既存契約へ紐づけるか新規契約を作るか、請求日を含む契約期間を作成してよいか確認する。", "取引先・商品・件名キーワード・請求区分が一意になるFreee請求契約ルールを登録し、有効化する。"),
        @("P01", (Get-QuestionCodeCount "P01"), "Freee明細名・単価・数量と候補商品が一致し、その商品として確定してよいか確認する。", "候補商品を確定商品に設定し、継続利用する名称は商品マッピングへ登録する。"),
        @("P02", (Get-QuestionCodeCount "P02"), "商品候補がない明細について、既存商品、汎用商品、商品マスタ追加のどれで管理するか確認する。", "商品マスタを選択または追加し、確定商品と商品マッピングを設定する。"),
        @("P03", (Get-QuestionCodeCount "P03"), "Freee明細名と確定商品名が類似していないため、単価・数量・契約内容を含めて誤紐づけでないか確認する。", "正しければ正式な別名として商品マッピングへ登録し、誤りなら正しい商品へ変更する。"),
        @("A01", (Get-QuestionCodeCount "A01"), "現在の請求金額と明細合計は一致しているため、古い金額エラーが再検証で消えるか確認する。", "データを変更せず再検証し、残る場合だけRaw JSONの税込・税抜金額と税額を調査する。"),
        @("A02", (Get-QuestionCodeCount "A02"), "現在も請求金額と明細合計が異なるため、税、値引き、源泉税、調整額、明細重複のどれが原因かFreee原本で確認する。", "Freee原本を正としてWorkの税額・請求金額・明細を補正する。"),
        @("I01", (Get-QuestionCodeCount "I01"), "作成済みSalesforce請求とFreee請求の明細を、Freee明細ID・件名・数量・単価・金額単位で比較する。", "既存明細を直接削除せず、差分確定後に不足明細の追加または誤明細の訂正を行う。")
    )
    for ($index = 0; $index -lt $questions.Count; $index++) {
        for ($column = 0; $column -lt 4; $column++) {
            $cell = $questionSheet.Cells.Item([int]($index + 4), [int]($column + 1))
            if ($column -eq 1) {
                $cell.Value2 = [double]$questions[$index][$column]
            }
            else {
                $cell.Value2 = [string]$questions[$index][$column]
            }
            Release-ComObject $cell
        }
    }
    $questionSheet.Range("A3:D3").Interior.Color = $blue
    $questionSheet.Range("A3:D3").Font.Color = $white
    $questionSheet.Range("A3:D3").Font.Bold = $true
    $questionSheet.Range("C4:D10").WrapText = $true
    $questionSheet.Range("A4:D10").RowHeight = 48
    $questionSheet.Columns.Item("A").ColumnWidth = 10
    $questionSheet.Columns.Item("B").ColumnWidth = 12
    $questionSheet.Columns.Item("C").ColumnWidth = 65
    $questionSheet.Columns.Item("D").ColumnWidth = 65
    $questionSheet.Activate()
    $excel.ActiveWindow.SplitRow = 3
    $excel.ActiveWindow.FreezePanes = $true
    $excel.ActiveWindow.Zoom = 85

    # 対応履歴
    $historySheet.Range("A1:E1").Merge()
    $historySheet.Range("A1").Value2 = "対応履歴"
    $historySheet.Range("A1:E1").Interior.Color = $navy
    $historySheet.Range("A1:E1").Font.Color = $white
    $historySheet.Range("A1:E1").Font.Bold = $true
    $historySheet.Range("A1:E1").Font.Size = 16
    $historySheet.Range("A3:E3").Value2 = @(
        @("対応日", "対応内容", "対象", "結果", "残対応")
    )
    $historySheet.Range("A4:E4").Value2 = @(
        @("2026-07-24", "商品変換を確定", "knock knock AI Basicプラン → knock knock AI Basicプラン(50クレジット)", "8件の商品確定、3件の請求反映", "契約・契約期間確認4件、既存請求明細照合1件")
    )
    $historySheet.Range("A5:E5").Value2 = @(
        @("2026-07-24", "商品変換を確定", "knock knock AI_Basicプラン(月額) → knock knock AI Basicプラン(50クレジット)", "24件の商品確定、16件の請求反映", "契約・契約期間確認3件、既存請求明細照合5件")
    )
    $historySheet.Range("A6:E6").Value2 = @(
        @("2026-07-24", "A01再検証・税額補正", "税込入力請求の税額二重計上5件", "既存請求補正2件、重複対象外1件、A01残件0件", "商品確認1件、契約・商品確認1件")
    )
    $historySheet.Range("A7:E7").Value2 = @(
        @("2026-07-24", "年一括商品を確定", "年払い表記のRendery商品9明細", "9明細を年一括商品へ確定、完全一致マッピング9件登録", "年払い割引・SSO・通常Pro商品の商品マスタ確認")
    )
    $historySheet.Range("A8:E8").Value2 = @(
        @("2026-07-24", "商品変換を確定", "knock knock AI Basicプラン(月額) → knock knock AI Basicプラン(50クレジット)", "5件の商品確定、4件の請求反映", "契約・契約期間確認1件")
    )
    $historySheet.Range("A9:E9").Value2 = @(
        @("2026-07-24", "追加P01の商品変換を確定", "knock knock AI_Basicプラン等 → knock knock AI Basicプラン(50クレジット)", "14件の商品確定、14件の請求反映、完全一致マッピング2件登録", "なし")
    )
    $historySheet.Range("A10:E10").Value2 = @(
        @("2026-07-24", "P03の商品誤紐づけ確認を解消", "Rendery エンタープライズプラン表記3種 → [OLD] Rendery Enterpriseプラン(2025年9月まで)", "4件の金額一致を確認して商品確定・反映、完全一致マッピング3件登録", "なし")
    )
    $historySheet.Range("A11:E11").Value2 = @(
        @("2026-07-24", "P03の商品誤紐づけを訂正", "KnockKnockAI_Basicプラン(月額) → knock knock AI Basicプラン(50クレジット)", "5件の金額一致を確認、既存請求明細1件を含めて商品を統一", "なし")
    )
    $historySheet.Range("A12:E12").Value2 = @(
        @("2026-07-24", "反映可能Workを本反映", "反映可能98件・請求明細Work124件", "77件を反映済み、請求76件・請求明細80件を新規作成", "既存請求明細照合13件、商品名類似性確認8件")
    )
    $historySheet.Range("A13:E13").Value2 = @(
        @("2026-07-24", "本反映後の追加照合", "要確認へ移行した21件", "既存請求明細17件を照合確定、新規請求2件を作成、商品補正11件、合計19件を反映済み", "VISIOAL商品判断1件、Rendery Enterprise商品二重候補1件")
    )
    $historySheet.Range("A3:E3").Interior.Color = $blue
    $historySheet.Range("A3:E3").Font.Color = $white
    $historySheet.Range("A3:E3").Font.Bold = $true
    $historySheet.Range("B4:E13").WrapText = $true
    $historySheet.Range("A4:E13").RowHeight = 45
    $historySheet.Columns.Item("A").ColumnWidth = 13
    $historySheet.Columns.Item("B").ColumnWidth = 28
    $historySheet.Columns.Item("C").ColumnWidth = 55
    $historySheet.Columns.Item("D").ColumnWidth = 34
    $historySheet.Columns.Item("E").ColumnWidth = 48

    foreach ($sheet in @($summary, $recordSheet, $questionSheet, $historySheet)) {
        $usedRange = $sheet.UsedRange
        $usedRange.Borders.Color = $border
        $usedRange.VerticalAlignment = -4160
        Release-ComObject $usedRange
    }

    $summary.Activate()
    $excel.ActiveWindow.Zoom = 95
    $workbook.SaveAs($outputPath, 51)
    $workbook.ExportAsFixedFormat(0, $previewPath)

    $sheetCount = $workbook.Worksheets.Count
    $recordCount = $recordSheet.ListObjects.Item("FreeeInvoiceReviewTable").ListRows.Count
    if ($sheetCount -ne 4 -or $recordCount -ne $records.Count) {
        throw "Excel検証に失敗しました。シート数=$sheetCount、レコード数=$recordCount"
    }

    $workbook.Close($true)
    $excel.Quit()
    Write-Output "xlsx=$outputPath"
    Write-Output "preview=$previewPath"
    Write-Output "sheets=$sheetCount records=$recordCount"
}
finally {
    if ($null -ne $workbook) {
        try { $workbook.Close($false) } catch {}
    }
    if ($null -ne $excel) {
        try { $excel.Quit() } catch {}
    }
    foreach ($object in @($historySheet, $questionSheet, $recordSheet, $summary, $workbook, $excel)) {
        Release-ComObject $object
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
