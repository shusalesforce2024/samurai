$ErrorActionPreference = 'Stop'

$root = (Resolve-Path ".").Path
$sourceScript = Join-Path $root "scripts\build_stripe_wbs_l4_xlsx.ps1"
$outFile = Join-Path $root "docs\contract-billing\stripe-salesforce-wbs-l4.xlsx"

function Parse-AddWbsLine([string]$line) {
    $matches = [regex]::Matches($line, '"([^"]*)"|(?<=\s)(\d+(?:\.\d+)?)(?=\s)')
    $items = @()
    foreach ($m in $matches) {
        if ($m.Groups[1].Success) { $items += $m.Groups[1].Value }
        elseif ($m.Groups[2].Success) { $items += [double]$m.Groups[2].Value }
    }
    return $items
}

function To-Date([string]$md) {
    return [datetime]::ParseExact("2026/$md", "yyyy/M/d", $null)
}

$lines = Get-Content -LiteralPath $sourceScript -Encoding UTF8
$wbs = New-Object System.Collections.Generic.List[object]
foreach ($line in $lines) {
    if ($line -match '^Add-Wbs\s+') {
        $items = Parse-AddWbsLine $line
        if ($items.Count -ge 13) {
            $note = if ($items.Count -ge 14) { $items[13] } else { "" }
            $wbs.Add([pscustomobject]@{
                Id = $items[0]
                L1 = $items[1]
                L2 = $items[2]
                L3 = $items[3]
                L4 = $items[4]
                Start = To-Date $items[5]
                End = To-Date $items[6]
                Hours = [double]$items[7]
                Owner = $items[8]
                Reviewer = $items[9]
                Status = "未着手"
                Priority = $items[10]
                Dependency = $items[11]
                Output = $items[12]
                Note = $note
            })
        }
    }
}

$excel = New-Object -ComObject Excel.Application
$excel.DisplayAlerts = $false
$excel.Visible = $false

if (Test-Path $outFile) { Remove-Item -LiteralPath $outFile -Force }

$wb = $excel.Workbooks.Add()
try {
    while ($wb.Worksheets.Count -lt 6) { $wb.Worksheets.Add() | Out-Null }
    while ($wb.Worksheets.Count -gt 6) { $wb.Worksheets.Item($wb.Worksheets.Count).Delete() }

    $summary = $wb.Worksheets.Item(1)
    $summary.Name = "サマリ"
    $wbsSheet = $wb.Worksheets.Item(2)
    $wbsSheet.Name = "WBS_L4"
    $migration = $wb.Worksheets.Item(3)
    $migration.Name = "移行準備"
    $milestone = $wb.Worksheets.Item(4)
    $milestone.Name = "マイルストーン"
    $roles = $wb.Worksheets.Item(5)
    $roles.Name = "体制"
    $risks = $wb.Worksheets.Item(6)
    $risks.Name = "リスク"

    $summaryRows = @(
        @("項目","値"),
        @("対象期間","2026/07/14〜2026/08/10"),
        @("総稼働可能時間",140),
        @("L4タスク件数",$wbs.Count),
        @("計画工数合計(h)",($wbs | Measure-Object -Property Hours -Sum).Sum),
        @("開始日","2026-07-14"),
        @("終了日","2026-08-10"),
        @("管理単位","L4"),
        @("SPI基準日",[datetime]"2026-07-14"),
        @("SPI算出方法","SPI = EV / PV。PV=予定工数×計画進捗率、EV=予定工数×実績進捗率")
    )
    for ($r = 0; $r -lt $summaryRows.Count; $r++) {
        for ($c = 0; $c -lt $summaryRows[$r].Count; $c++) {
            $summary.Cells.Item($r + 1, $c + 1).Value2 = [string]$summaryRows[$r][$c]
        }
    }
    $summary.Range("B9").NumberFormat = "yyyy-mm-dd"

    $headers = @(
        "WBS ID","L1 フェーズ","L2 ワークストリーム","L3 成果物","L4 タスク",
        "開始日","終了日","予定工数(h)","担当","クライアント確認者","ステータス",
        "優先度","依存関係","成果物","備考","計画進捗率","実績進捗率",
        "PV(h)","EV(h)","SPI","SPI判定"
    )
    for ($c = 0; $c -lt $headers.Count; $c++) {
        $wbsSheet.Cells.Item(1, $c + 1).Value2 = $headers[$c]
    }
    $row = 2
    foreach ($task in $wbs) {
        $wbsSheet.Cells.Item($row,1).Value2 = $task.Id
        $wbsSheet.Cells.Item($row,2).Value2 = $task.L1
        $wbsSheet.Cells.Item($row,3).Value2 = $task.L2
        $wbsSheet.Cells.Item($row,4).Value2 = $task.L3
        $wbsSheet.Cells.Item($row,5).Value2 = $task.L4
        $wbsSheet.Cells.Item($row,6).Value = $task.Start
        $wbsSheet.Cells.Item($row,7).Value = $task.End
        $wbsSheet.Cells.Item($row,8).Value2 = [string]$task.Hours
        $wbsSheet.Cells.Item($row,9).Value2 = $task.Owner
        $wbsSheet.Cells.Item($row,10).Value2 = $task.Reviewer
        $wbsSheet.Cells.Item($row,11).Value2 = $task.Status
        $wbsSheet.Cells.Item($row,12).Value2 = $task.Priority
        $wbsSheet.Cells.Item($row,13).Value2 = $task.Dependency
        $wbsSheet.Cells.Item($row,14).Value2 = $task.Output
        $wbsSheet.Cells.Item($row,15).Value2 = $task.Note
        $wbsSheet.Cells.Item($row,16).Formula = "=IF(OR(F$row="""",G$row=""""),0,MAX(0,MIN(1,('サマリ'!`$B`$9-F$row+1)/(G$row-F$row+1))))"
        $wbsSheet.Cells.Item($row,17).Formula = "=IF(K$row=""完了"",1,IF(K$row=""進行中"",0.5,IF(K$row=""保留"",0,0)))"
        $wbsSheet.Cells.Item($row,18).Formula = "=H$row*P$row"
        $wbsSheet.Cells.Item($row,19).Formula = "=H$row*Q$row"
        $wbsSheet.Cells.Item($row,20).Formula = "=IF(R$row=0,"""",S$row/R$row)"
        $wbsSheet.Cells.Item($row,21).Formula = "=IF(T$row="""",""未計測"",IF(T$row>=1,""予定通り/前倒し"",IF(T$row>=0.9,""要注意"",""遅延"")))"
        $row++
    }

    $lastRow = $row - 1
    $used = $wbsSheet.Range($wbsSheet.Cells.Item(1,1), $wbsSheet.Cells.Item($lastRow,$headers.Count))
    $used.Font.Name = "Meiryo UI"
    $used.Font.Size = 10
    $used.WrapText = $true
    $used.Borders.LineStyle = 1
    $used.Borders.Color = 14277081
    $header = $wbsSheet.Range($wbsSheet.Cells.Item(1,1), $wbsSheet.Cells.Item(1,$headers.Count))
    $header.Interior.Color = 7879740
    $header.Font.Color = 16777215
    $header.Font.Bold = $true
    $header.HorizontalAlignment = -4108
    $used.AutoFilter() | Out-Null
    $wbsSheet.Activate() | Out-Null
    $excel.ActiveWindow.SplitRow = 1
    $excel.ActiveWindow.FreezePanes = $true
    $wbsSheet.Range("F:G").NumberFormat = "yyyy-mm-dd"
    $wbsSheet.Range("H:H").NumberFormat = "0.0"
    $wbsSheet.Range("P:Q").NumberFormat = "0%"
    $wbsSheet.Range("R:S").NumberFormat = "0.0"
    $wbsSheet.Range("T:T").NumberFormat = "0.00"
    $widths = @(14,16,20,22,52,12,12,12,14,24,12,10,24,24,42,12,12,10,10,10,18)
    for ($i = 0; $i -lt $widths.Count; $i++) { $wbsSheet.Columns.Item($i + 1).ColumnWidth = $widths[$i] }

    $statusRange = $wbsSheet.Range("K2:K$lastRow")
    $statusRange.Validation.Delete()
    $statusRange.Validation.Add(3,1,1,"未着手,進行中,完了,保留")
    $priorityRange = $wbsSheet.Range("L2:L$lastRow")
    $priorityRange.Validation.Delete()
    $priorityRange.Validation.Add(3,1,1,"高,中,低")

    $sheetsData = @{
        "移行準備" = @(
            @("区分","L4タスク","主担当","確認者","完了条件"),
            @("業務移行","現行freee/Stripe/Salesforce運用との差分整理","川波","中山、玉木、高山","担当・タイミング・確認画面が明確"),
            @("業務移行","営業・経理向け運用手順作成","川波","中山、玉木","操作手順と一次対応が明記"),
            @("システム移行","本番反映対象メタデータ整理","川波","小室","リリース対象が明確"),
            @("システム移行","Stripe接続設定確認","川波","横溝、小室","APIキー、Webhook、署名シークレット手順が確定"),
            @("データ移行","既存Stripe Customer ID取得方針整理","川波","横溝、小室","Salesforce取引先への紐づけ方法が決定"),
            @("データ移行","名寄せ・照合ルール確定","川波","横溝、中山","完全一致・手動確認基準が決定"),
            @("データ移行","移行後照合","川波","中山、高山","件数・未紐づけ・重複候補の確認観点が揃う")
        )
        "マイルストーン" = @(
            @("日付","マイルストーン","判定基準","主な確認者"),
            @("2026-07-19","要件・方式確定","スコープ、対象外、名寄せ、決済方式が確定","横溝、高山、中山"),
            @("2026-07-23","設計確定","オブジェクト、項目、API、Webhook、権限設計が確定","横溝、小室"),
            @("2026-08-02","主要実装完了","Checkout作成、Webhook受信、ログ、権限の実装が完了","小室"),
            @("2026-08-06","結合テスト完了","決済成功・失敗・期限切れの主要シナリオが通過","小室、中山"),
            @("2026-08-08","移行準備完了","業務移行、システム移行、データ移行の手順が揃う","中山、玉木、横溝"),
            @("2026-08-09","UAT・移行リハ・リリース判定","主要UATと移行リハが完了し重大障害なし","高山、加藤、横溝"),
            @("2026-08-10","リリース完了","本番反映、権限確認、疎通確認、完了報告が完了","高山、加藤")
        )
        "体制" = @(
            @("メンバー","役割","WBS上の主な関与"),
            @("横溝（CTO）","決済・自社サービスシステム構築全体","アーキテクチャ確認、Stripe方針確認、技術判断"),
            @("小室","アプリケーションエンジニア","Stripe API仕様確認、Webhook仕様確認、技術レビュー"),
            @("中山（総務）","経理担当","決済ステータス、未入金、返金・取消、経理UAT確認"),
            @("玉木","CS担当","契約・請求フロー、CS観点のUAT、ダッシュボード確認"),
            @("高山","CSO","全体方針確認、業務影響確認、リリース判断"),
            @("加藤","代表","収益管理観点、経営ダッシュボード観点、最終承認"),
            @("畝山","受託PM","受託案件フローのUAT、例外パターン確認"),
            @("古川・桐谷","営業インターン","必要に応じて営業入力フロー確認")
        )
        "リスク" = @(
            @("No","リスク","影響","対策","関連フェーズ"),
            @(1,"Stripe Customerの名寄せ誤り","別顧客への決済紐づけ","完全一致以外は手動確認","要件定義/データ移行"),
            @(2,"Webhook未着・重複","決済状態不整合","Event ID冪等性、再取得バッチ","実装/テスト"),
            @(3,"Stripe API仕様・認証設定の確認遅延","実装遅延","横溝・小室に早期確認依頼","設計/システム移行"),
            @(4,"経理運用がfreeeとStripeで混在","入金確認漏れ","役割分担を明文化","業務移行"),
            @(5,"期間内にフルスコープが収まらない","リリース遅延","初期スコープを絞る","全体"),
            @(6,"業務移行の周知不足","旧運用継続による二重管理","切替日と問い合わせ先を周知","業務移行")
        )
    }

    foreach ($name in $sheetsData.Keys) {
        $ws = $wb.Worksheets.Item($name)
        $data = $sheetsData[$name]
        for ($r = 0; $r -lt $data.Count; $r++) {
            for ($c = 0; $c -lt $data[$r].Count; $c++) { $ws.Cells.Item($r + 1, $c + 1).Value2 = [string]$data[$r][$c] }
        }
        $ur = $ws.UsedRange
        $ur.Font.Name = "Meiryo UI"
        $ur.Font.Size = 10
        $ur.WrapText = $true
        $ur.Borders.LineStyle = 1
        $ur.Borders.Color = 14277081
        $h = $ws.Range($ws.Cells.Item(1,1), $ws.Cells.Item(1,$ur.Columns.Count))
        $h.Interior.Color = 7879740
        $h.Font.Color = 16777215
        $h.Font.Bold = $true
        $ur.AutoFilter() | Out-Null
        $ws.Columns.AutoFit() | Out-Null
        for ($c = 1; $c -le $ur.Columns.Count; $c++) { if ($ws.Columns.Item($c).ColumnWidth -gt 60) { $ws.Columns.Item($c).ColumnWidth = 60 } }
    }

    $sumUsed = $summary.UsedRange
    $sumUsed.Font.Name = "Meiryo UI"
    $sumUsed.Font.Size = 10
    $sumUsed.Borders.LineStyle = 1
    $sumUsed.Borders.Color = 14277081
    $summary.Range("A1:B1").Interior.Color = 7879740
    $summary.Range("A1:B1").Font.Color = 16777215
    $summary.Range("A1:B1").Font.Bold = $true
    $summary.Columns.AutoFit() | Out-Null

    $summary.Activate() | Out-Null
    $wb.SaveAs($outFile, 51)
}
finally {
    try { $wb.Close($true) } catch {}
    try { $excel.Quit() } catch {}
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
}

Write-Host "saved=$outFile"
Write-Host "tasks=$($wbs.Count)"
Write-Host "hours=$(($wbs | Measure-Object -Property Hours -Sum).Sum)"
