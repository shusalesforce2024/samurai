$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path ".").Path
$outDir = Join-Path $root "docs\contract-billing"
$outFile = Join-Path $outDir "stripe-salesforce-wbs-l4.xlsx"
$tmp = Join-Path $env:TEMP ("stripe_wbs_l4_" + [guid]::NewGuid().ToString("N"))

function Xml-Escape([object]$value) {
    if ($null -eq $value) { return "" }
    return [System.Security.SecurityElement]::Escape([string]$value)
}

function ColName([int]$n) {
    $name = ""
    while ($n -gt 0) {
        $n--
        $name = [char](65 + ($n % 26)) + $name
        $n = [math]::Floor($n / 26)
    }
    return $name
}

function Excel-Date([string]$dateText) {
    if ([string]::IsNullOrWhiteSpace($dateText)) { return $null }
    $dt = [datetime]::ParseExact("2026/$dateText", "yyyy/M/d", $null)
    $base = [datetime]"1899-12-30"
    return [int](($dt - $base).TotalDays)
}

function CellXml([int]$row, [int]$col, [object]$value, [int]$style = 0, [string]$kind = "text") {
    $ref = "$(ColName $col)$row"
    if ($null -eq $value -or [string]$value -eq "") {
        if ($style -gt 0) { return "<c r=`"$ref`" s=`"$style`"/>" }
        return "<c r=`"$ref`"/>"
    }
    if ($kind -eq "number") {
        return "<c r=`"$ref`" s=`"$style`"><v>$value</v></c>"
    }
    if ($kind -eq "date") {
        $serial = Excel-Date ([string]$value)
        return "<c r=`"$ref`" s=`"$style`"><v>$serial</v></c>"
    }
    return "<c r=`"$ref`" s=`"$style`" t=`"inlineStr`"><is><t>$(Xml-Escape $value)</t></is></c>"
}

function Add-SheetXml($path, $rows, $freeze = $true, $autoFilter = $true, $widths = $null) {
    $maxCols = ($rows | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum
    $maxRows = $rows.Count
    $lastCol = ColName $maxCols
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.AppendLine('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
    [void]$sb.AppendLine("<dimension ref=`"A1:$lastCol$maxRows`"/>")
    if ($widths) {
        [void]$sb.AppendLine("<cols>")
        for ($i = 1; $i -le $maxCols; $i++) {
            $w = if ($i -le $widths.Count) { $widths[$i - 1] } else { 14 }
            [void]$sb.AppendLine("<col min=`"$i`" max=`"$i`" width=`"$w`" customWidth=`"1`"/>")
        }
        [void]$sb.AppendLine("</cols>")
    }
    if ($freeze) {
        [void]$sb.AppendLine('<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/><selection pane="bottomLeft"/></sheetView></sheetViews>')
    } else {
        [void]$sb.AppendLine('<sheetViews><sheetView workbookViewId="0"/></sheetViews>')
    }
    [void]$sb.AppendLine("<sheetData>")
    for ($r = 1; $r -le $rows.Count; $r++) {
        [void]$sb.AppendLine("<row r=`"$r`">")
        $row = $rows[$r - 1]
        for ($c = 1; $c -le $maxCols; $c++) {
            $value = if ($c -le $row.Count) { $row[$c - 1] } else { "" }
            $style = 0
            $kind = "text"
            if ($r -eq 1) { $style = 1 }
            elseif ($value -is [int] -or $value -is [double] -or $value -is [decimal]) { $style = 3; $kind = "number" }
            if ($r -gt 1 -and ($c -eq 6 -or $c -eq 7) -and [string]$value -match '^\d{1,2}/\d{1,2}$') { $style = 2; $kind = "date" }
            [void]$sb.AppendLine((CellXml $r $c $value $style $kind))
        }
        [void]$sb.AppendLine("</row>")
    }
    [void]$sb.AppendLine("</sheetData>")
    if ($autoFilter) { [void]$sb.AppendLine("<autoFilter ref=`"A1:$lastCol$maxRows`"/>") }
    [void]$sb.AppendLine('</worksheet>')
    [System.IO.File]::WriteAllText($path, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
}

$headers = @("WBS ID","L1 フェーズ","L2 ワークストリーム","L3 成果物","L4 タスク","開始日","終了日","予定工数(h)","担当","クライアント確認者","ステータス","優先度","依存関係","成果物","備考")
$wbs = New-Object System.Collections.Generic.List[object]
function Add-Wbs($id,$l1,$l2,$l3,$l4,$start,$end,$hours,$owner,$reviewer,$priority,$dep,$output,$note="") {
    $wbs.Add(@($id,$l1,$l2,$l3,$l4,$start,$end,[double]$hours,$owner,$reviewer,"未着手",$priority,$dep,$output,$note))
}

Add-Wbs "1.1.1.1" "要件定義" "スコープ整理" "要件確認メモ" "要件一覧の対象・対象外を確認する" "7/14" "7/14" 1.0 "川波" "高山、横溝" "高" "-" "要件確認メモ"
Add-Wbs "1.1.1.2" "要件定義" "スコープ整理" "要件確認メモ" "初期リリース対象と次フェーズ対象を分類する" "7/14" "7/14" 1.0 "川波" "高山、横溝" "高" "1.1.1.1" "スコープ分類表"
Add-Wbs "1.1.1.3" "要件定義" "スコープ整理" "要件確認メモ" "リリース判定に必要な最低要件を定義する" "7/14" "7/14" 1.0 "川波" "高山、加藤" "高" "1.1.1.2" "最低要件一覧"
Add-Wbs "1.2.1.1" "要件定義" "業務フロー" "業務フロー確認表" "営業の決済URL作成・顧客案内フローを整理する" "7/14" "7/15" 1.5 "川波" "玉木、畝山" "高" "1.1.1.2" "営業フロー"
Add-Wbs "1.2.1.2" "要件定義" "業務フロー" "業務フロー確認表" "経理の未入金・決済済み・返金確認フローを整理する" "7/15" "7/15" 1.5 "川波" "中山" "高" "1.2.1.1" "経理フロー"
Add-Wbs "1.2.1.3" "要件定義" "業務フロー" "業務フロー確認表" "CS・経営向け確認範囲を整理する" "7/15" "7/15" 1.0 "川波" "玉木、高山、加藤" "中" "1.2.1.2" "利用範囲メモ"
Add-Wbs "1.3.1.1" "要件定義" "決済方式" "決済方式整理" "Stripe Checkout採用可否を整理する" "7/15" "7/16" 1.5 "川波" "横溝、小室" "高" "1.1.1.2" "決済方式比較"
Add-Wbs "1.3.1.2" "要件定義" "決済方式" "決済方式整理" "Billing/Subscriptionを初期対象外にする条件を整理する" "7/16" "7/16" 1.0 "川波" "横溝、小室" "中" "1.3.1.1" "対象外整理"
Add-Wbs "1.3.1.3" "要件定義" "決済方式" "決済方式整理" "Payment Intent/Checkout Sessionに保持するIDを定義する" "7/16" "7/16" 1.5 "川波" "小室" "高" "1.3.1.1" "ID管理方針"
Add-Wbs "1.4.1.1" "要件定義" "顧客名寄せ" "名寄せルール表" "Stripe Customer ID完全一致ルールを定義する" "7/16" "7/16" 1.0 "川波" "横溝、小室" "高" "1.3.1.3" "名寄せルール"
Add-Wbs "1.4.1.2" "要件定義" "顧客名寄せ" "名寄せルール表" "メール・会社名・電話番号による候補判定を定義する" "7/17" "7/17" 1.5 "川波" "横溝、小室、中山" "高" "1.4.1.1" "候補判定ルール"
Add-Wbs "1.4.1.3" "要件定義" "顧客名寄せ" "名寄せルール表" "複数候補・未解決時の手動確認運用を定義する" "7/17" "7/17" 1.5 "川波" "中山、玉木" "高" "1.4.1.2" "手動確認運用"
Add-Wbs "1.5.1.1" "要件定義" "ステータス" "ステータスマッピング" "Checkout作成済み・決済済み・失敗・期限切れの対応を定義する" "7/17" "7/18" 1.5 "川波" "中山、横溝" "高" "1.3.1.3" "ステータス表"
Add-Wbs "1.5.1.2" "要件定義" "ステータス" "ステータスマッピング" "返金・取消・Disputeの初期運用を定義する" "7/18" "7/18" 1.5 "川波" "中山、横溝" "中" "1.5.1.1" "返金運用"
Add-Wbs "1.5.1.3" "要件定義" "ステータス" "ステータスマッピング" "Salesforce請求項目への反映ルールを定義する" "7/18" "7/18" 1.0 "川波" "中山、小室" "高" "1.5.1.1" "反映項目表"
Add-Wbs "1.6.1.1" "要件定義" "レビュー" "要件確定版" "要件定義レビューを実施する" "7/19" "7/19" 1.5 "川波" "高山、加藤、横溝" "高" "1.5.1.3" "レビュー議事メモ"
Add-Wbs "1.6.1.2" "要件定義" "レビュー" "要件確定版" "指摘を反映し要件を確定する" "7/19" "7/19" 1.5 "川波" "高山、加藤、横溝" "高" "1.6.1.1" "要件確定版"

Add-Wbs "2.1.1.1" "設計" "責務分担" "基本設計" "Salesforce/Stripe/freeeの責務分担を整理する" "7/19" "7/20" 1.5 "川波" "横溝、高山" "高" "1.6.1.2" "責務分担表"
Add-Wbs "2.1.1.2" "設計" "責務分担" "基本設計" "契約・請求・決済の正を定義する" "7/20" "7/20" 1.0 "川波" "横溝、高山" "高" "2.1.1.1" "正管理定義"
Add-Wbs "2.1.1.3" "設計" "責務分担" "基本設計" "障害時の復旧・再取得方針を整理する" "7/20" "7/20" 1.5 "川波" "小室" "中" "2.1.1.2" "復旧方針"
Add-Wbs "2.2.1.1" "設計" "メタデータ" "項目設計表" "Account追加項目を設計する" "7/20" "7/20" 1.0 "川波" "小室" "高" "2.1.1.2" "Account項目設計"
Add-Wbs "2.2.1.2" "設計" "メタデータ" "項目設計表" "Invoice追加項目を設計する" "7/20" "7/20" 1.5 "川波" "小室、中山" "高" "2.2.1.1" "Invoice項目設計"
Add-Wbs "2.2.1.3" "設計" "メタデータ" "項目設計表" "Stripeイベントログ・連携ログを設計する" "7/20" "7/20" 1.5 "川波" "小室" "高" "2.2.1.2" "ログ設計"
Add-Wbs "2.3.1.1" "設計" "名寄せ" "名寄せ詳細設計" "Stripe Customer検索条件を設計する" "7/21" "7/21" 1.5 "川波" "横溝、小室" "高" "1.4.1.3" "検索条件設計"
Add-Wbs "2.3.1.2" "設計" "名寄せ" "名寄せ詳細設計" "自動紐づけ・手動確認ステータスを設計する" "7/21" "7/21" 1.5 "川波" "中山、玉木" "高" "2.3.1.1" "状態遷移設計"
Add-Wbs "2.3.1.3" "設計" "名寄せ" "名寄せ詳細設計" "データ移行時の名寄せ照合観点を設計する" "7/21" "7/21" 1.0 "川波" "横溝、中山" "高" "2.3.1.2" "照合観点"
Add-Wbs "2.4.1.1" "設計" "Checkout" "API設計" "Checkout Session作成APIリクエストを設計する" "7/21" "7/22" 1.5 "川波" "小室" "高" "1.3.1.3" "API仕様"
Add-Wbs "2.4.1.2" "設計" "Checkout" "API設計" "請求明細からLine Itemへの変換を設計する" "7/22" "7/22" 1.5 "川波" "小室" "高" "2.4.1.1" "Line Item設計"
Add-Wbs "2.4.1.3" "設計" "Checkout" "API設計" "決済URL再作成・期限切れ時の扱いを設計する" "7/22" "7/22" 1.0 "川波" "中山、小室" "中" "2.4.1.2" "再作成設計"
Add-Wbs "2.5.1.1" "設計" "Webhook" "Webhook設計" "Webhookエンドポイントを設計する" "7/22" "7/22" 1.0 "川波" "小室" "高" "2.4.1.1" "Webhook仕様"
Add-Wbs "2.5.1.2" "設計" "Webhook" "Webhook設計" "署名検証とSecret管理を設計する" "7/22" "7/22" 1.5 "川波" "横溝、小室" "高" "2.5.1.1" "署名検証設計"
Add-Wbs "2.5.1.3" "設計" "Webhook" "Webhook設計" "Event ID冪等性制御を設計する" "7/22" "7/22" 1.5 "川波" "小室" "高" "2.5.1.2" "冪等性設計"
Add-Wbs "2.6.1.1" "設計" "権限・画面" "権限・画面設計" "営業・経理・管理者権限を設計する" "7/23" "7/23" 1.0 "川波" "玉木、中山" "高" "2.2.1.3" "権限設計"
Add-Wbs "2.6.1.2" "設計" "権限・画面" "権限・画面設計" "リストビュー・レポート最小構成を設計する" "7/23" "7/23" 1.0 "川波" "中山、加藤" "中" "2.6.1.1" "画面設計"
Add-Wbs "2.6.1.3" "設計" "移行設計" "移行設計" "業務移行・システム移行・データ移行の計画を設計に反映する" "7/23" "7/23" 1.0 "川波" "高山、横溝" "高" "2.6.1.2" "移行計画"

Add-Wbs "3.1.1.1" "実装" "メタデータ" "Salesforceメタデータ" "Account Stripe項目を作成する" "7/23" "7/24" 1.5 "川波" "小室" "高" "2.2.1.1" "項目メタデータ"
Add-Wbs "3.1.1.2" "実装" "メタデータ" "Salesforceメタデータ" "Invoice Stripe項目を作成する" "7/24" "7/24" 2.0 "川波" "小室" "高" "2.2.1.2" "項目メタデータ"
Add-Wbs "3.1.1.3" "実装" "メタデータ" "Salesforceメタデータ" "レイアウト・権限の項目表示を調整する" "7/24" "7/24" 1.5 "川波" "玉木、中山" "中" "3.1.1.2" "レイアウト"
Add-Wbs "3.2.1.1" "実装" "ログ" "ログオブジェクト" "StripeEvent__cを作成する" "7/24" "7/24" 1.5 "川波" "小室" "高" "2.2.1.3" "ログオブジェクト"
Add-Wbs "3.2.1.2" "実装" "ログ" "ログオブジェクト" "StripeSyncLog__cを作成する" "7/24" "7/24" 1.5 "川波" "小室" "高" "3.2.1.1" "連携ログ"
Add-Wbs "3.2.1.3" "実装" "ログ" "ログオブジェクト" "ログ参照用リストビューを作成する" "7/24" "7/24" 1.0 "川波" "小室" "中" "3.2.1.2" "ログリストビュー"
Add-Wbs "3.3.1.1" "実装" "接続設定" "接続設定" "Named Credential/外部認証のメタデータを準備する" "7/25" "7/25" 1.5 "川波" "横溝、小室" "高" "2.5.1.2" "接続設定"
Add-Wbs "3.3.1.2" "実装" "接続設定" "接続設定" "Stripe APIキー設定手順を整理する" "7/25" "7/25" 1.0 "川波" "横溝、小室" "高" "3.3.1.1" "設定手順"
Add-Wbs "3.3.1.3" "実装" "接続設定" "接続設定" "接続疎通確認用の処理を準備する" "7/25" "7/25" 1.5 "川波" "小室" "中" "3.3.1.2" "疎通確認"
Add-Wbs "3.4.1.1" "実装" "顧客連携" "Apexサービス" "Stripe Customer検索サービスを実装する" "7/25" "7/26" 3.0 "川波" "小室" "高" "2.3.1.1" "Apex"
Add-Wbs "3.4.1.2" "実装" "顧客連携" "Apexサービス" "Stripe Customer作成サービスを実装する" "7/26" "7/26" 3.0 "川波" "小室" "高" "3.4.1.1" "Apex"
Add-Wbs "3.4.1.3" "実装" "顧客連携" "Apexサービス" "名寄せ結果をAccountに反映する処理を実装する" "7/26" "7/26" 2.0 "川波" "小室、中山" "高" "3.4.1.2" "Apex"
Add-Wbs "3.5.1.1" "実装" "Checkout" "Apexサービス" "Checkout Session作成サービスを実装する" "7/26" "7/27" 3.0 "川波" "小室" "高" "2.4.1.1" "Apex"
Add-Wbs "3.5.1.2" "実装" "Checkout" "Apexサービス" "InvoiceLineからLine Itemを生成する処理を実装する" "7/27" "7/27" 2.0 "川波" "小室" "高" "2.4.1.2" "Apex"
Add-Wbs "3.5.1.3" "実装" "Checkout" "Apexサービス" "Checkout URL/Session IDをInvoiceへ保存する処理を実装する" "7/27" "7/27" 2.0 "川波" "小室" "高" "3.5.1.1" "Apex"
Add-Wbs "3.5.1.4" "実装" "Checkout" "Apexサービス" "APIエラーを日本語メッセージへ変換する" "7/27" "7/27" 1.0 "川波" "玉木、中山" "中" "3.5.1.3" "エラー処理"
Add-Wbs "3.6.1.1" "実装" "画面導線" "ボタン/画面" "請求レコードに決済URL作成ボタンを追加する" "7/27" "7/27" 1.5 "川波" "玉木、中山" "高" "3.5.1.3" "ボタン"
Add-Wbs "3.6.1.2" "実装" "画面導線" "ボタン/画面" "連携失敗時の手動再実行導線を追加する" "7/27" "7/27" 1.5 "川波" "中山" "中" "3.6.1.1" "再実行導線"
Add-Wbs "3.6.1.3" "実装" "画面導線" "ボタン/画面" "営業・経理向けの画面表示を確認する" "7/27" "7/27" 1.0 "川波" "玉木、中山" "中" "3.6.1.2" "画面確認"
Add-Wbs "3.7.1.1" "実装" "Webhook" "Apex REST" "Webhook受信エンドポイントを実装する" "7/28" "7/28" 2.0 "川波" "小室" "高" "2.5.1.1" "Apex REST"
Add-Wbs "3.7.1.2" "実装" "Webhook" "Apex REST" "署名検証処理を実装する" "7/28" "7/29" 2.0 "川波" "小室" "高" "2.5.1.2" "署名検証"
Add-Wbs "3.7.1.3" "実装" "Webhook" "Apex REST" "Webhookイベント種別の振り分けを実装する" "7/29" "7/29" 1.5 "川波" "小室" "高" "3.7.1.1" "イベント分岐"
Add-Wbs "3.7.1.4" "実装" "Webhook" "Apex REST" "Webhook受信失敗時のログ記録を実装する" "7/29" "7/29" 1.5 "川波" "小室" "中" "3.7.1.3" "ログ処理"
Add-Wbs "3.8.1.1" "実装" "冪等性" "イベント処理" "Stripe Event ID重複チェックを実装する" "7/29" "7/29" 1.5 "川波" "小室" "高" "2.5.1.3" "冪等性"
Add-Wbs "3.8.1.2" "実装" "冪等性" "イベント処理" "イベント処理ステータスを管理する" "7/29" "7/29" 1.0 "川波" "小室" "高" "3.8.1.1" "イベント状態"
Add-Wbs "3.8.1.3" "実装" "冪等性" "イベント処理" "処理済みイベントの再処理防止をテスト可能にする" "7/29" "7/29" 1.5 "川波" "小室" "中" "3.8.1.2" "再処理防止"
Add-Wbs "3.9.1.1" "実装" "決済反映" "ステータス更新処理" "決済成功時の請求更新を実装する" "7/30" "7/30" 2.0 "川波" "中山、小室" "高" "3.7.1.3" "成功更新"
Add-Wbs "3.9.1.2" "実装" "決済反映" "ステータス更新処理" "決済失敗時の請求更新を実装する" "7/30" "7/30" 1.5 "川波" "中山、小室" "高" "3.9.1.1" "失敗更新"
Add-Wbs "3.9.1.3" "実装" "決済反映" "ステータス更新処理" "期限切れ時の請求更新を実装する" "7/31" "7/31" 1.5 "川波" "中山、小室" "中" "3.9.1.2" "期限切れ更新"
Add-Wbs "3.9.1.4" "実装" "決済反映" "ステータス更新処理" "返金結果の同期処理を実装する" "7/31" "7/31" 2.0 "川波" "中山、小室" "中" "3.9.1.1" "返金同期"
Add-Wbs "3.10.1.1" "実装" "再取得" "バッチ/Queueable" "決済状態再取得Queueableを実装する" "7/31" "8/1" 2.0 "川波" "小室" "中" "3.9.1.3" "再取得処理"
Add-Wbs "3.10.1.2" "実装" "再取得" "バッチ/Queueable" "再取得対象条件を実装する" "8/1" "8/1" 1.5 "川波" "中山、小室" "中" "3.10.1.1" "対象条件"
Add-Wbs "3.10.1.3" "実装" "再取得" "バッチ/Queueable" "再取得結果を請求へ反映する" "8/1" "8/1" 1.5 "川波" "中山、小室" "中" "3.10.1.2" "結果反映"
Add-Wbs "3.10.1.4" "実装" "再取得" "バッチ/Queueable" "手動再取得ボタンを準備する" "8/1" "8/1" 1.0 "川波" "中山" "低" "3.10.1.3" "手動再取得"
Add-Wbs "3.11.1.1" "実装" "画面・帳票" "経理/CS/経営確認用画面" "未入金リストビューを作成する" "8/1" "8/1" 1.5 "川波" "中山" "高" "3.9.1.2" "リストビュー"
Add-Wbs "3.11.1.2" "実装" "画面・帳票" "経理/CS/経営確認用画面" "決済失敗・期限切れリストビューを作成する" "8/1" "8/2" 1.5 "川波" "中山" "高" "3.11.1.1" "リストビュー"
Add-Wbs "3.11.1.3" "実装" "画面・帳票" "経理/CS/経営確認用画面" "決済状況レポートを作成する" "8/2" "8/2" 1.5 "川波" "中山、加藤" "中" "3.11.1.2" "レポート"
Add-Wbs "3.11.1.4" "実装" "画面・帳票" "経理/CS/経営確認用画面" "管理者向け連携エラービューを作成する" "8/2" "8/2" 1.5 "川波" "小室" "中" "3.2.1.3" "エラービュー"
Add-Wbs "3.12.1.1" "実装" "権限" "権限セット" "営業向け権限を作成・更新する" "8/2" "8/2" 1.5 "川波" "玉木" "高" "2.6.1.1" "権限セット"
Add-Wbs "3.12.1.2" "実装" "権限" "権限セット" "経理向け権限を作成・更新する" "8/2" "8/2" 1.5 "川波" "中山" "高" "3.12.1.1" "権限セット"
Add-Wbs "3.12.1.3" "実装" "権限" "権限セット" "管理者向け権限・タブ・アプリ表示を調整する" "8/2" "8/2" 1.0 "川波" "高山" "中" "3.12.1.2" "権限セット"

Add-Wbs "4.1.1.1" "テスト" "単体テスト" "テストクラス" "Customer検索・作成のApexテストを作成する" "8/3" "8/3" 2.0 "川波" "小室" "高" "3.4.1.3" "テストクラス"
Add-Wbs "4.1.1.2" "テスト" "単体テスト" "テストクラス" "Checkout作成のApexテストを作成する" "8/3" "8/3" 2.0 "川波" "小室" "高" "3.5.1.4" "テストクラス"
Add-Wbs "4.1.1.3" "テスト" "単体テスト" "テストクラス" "Webhook・決済反映のApexテストを作成する" "8/3" "8/3" 2.0 "川波" "小室" "高" "3.9.1.4" "テストクラス"
Add-Wbs "4.2.1.1" "テスト" "シナリオ" "テスト結果" "請求からCheckout URLを作成するシナリオを実施する" "8/3" "8/4" 2.0 "川波" "玉木、畝山" "高" "4.1.1.2" "テスト結果"
Add-Wbs "4.2.1.2" "テスト" "シナリオ" "テスト結果" "請求明細がLine Itemへ正しく変換されることを確認する" "8/4" "8/4" 1.5 "川波" "小室" "高" "4.2.1.1" "テスト結果"
Add-Wbs "4.2.1.3" "テスト" "シナリオ" "テスト結果" "決済URL再作成・エラー表示を確認する" "8/4" "8/4" 1.5 "川波" "玉木、中山" "中" "4.2.1.2" "テスト結果"
Add-Wbs "4.3.1.1" "テスト" "Webhook" "テスト結果" "決済成功Webhookをテストする" "8/4" "8/4" 2.0 "川波" "小室、中山" "高" "4.1.1.3" "テスト結果"
Add-Wbs "4.3.1.2" "テスト" "Webhook" "テスト結果" "決済失敗Webhookをテストする" "8/4" "8/4" 1.5 "川波" "小室、中山" "高" "4.3.1.1" "テスト結果"
Add-Wbs "4.3.1.3" "テスト" "Webhook" "テスト結果" "期限切れWebhookをテストする" "8/4" "8/4" 1.5 "川波" "小室、中山" "中" "4.3.1.2" "テスト結果"
Add-Wbs "4.4.1.1" "テスト" "返金・取消" "テスト結果" "返金イベント同期をテストする" "8/5" "8/5" 2.0 "川波" "中山" "中" "3.9.1.4" "テスト結果"
Add-Wbs "4.4.1.2" "テスト" "返金・取消" "テスト結果" "取消・無効化時の状態を確認する" "8/5" "8/5" 1.0 "川波" "中山" "中" "4.4.1.1" "テスト結果"
Add-Wbs "4.4.1.3" "テスト" "返金・取消" "テスト結果" "返金・取消の運用対象外/対象を再確認する" "8/5" "8/5" 1.0 "川波" "中山、横溝" "中" "4.4.1.2" "確認結果"
Add-Wbs "4.5.1.1" "テスト" "名寄せ" "テスト結果" "Stripe Customer ID完全一致をテストする" "8/5" "8/5" 1.5 "川波" "横溝、小室" "高" "3.4.1.3" "テスト結果"
Add-Wbs "4.5.1.2" "テスト" "名寄せ" "テスト結果" "複数候補時に手動確認となることをテストする" "8/5" "8/5" 1.5 "川波" "横溝、小室" "高" "4.5.1.1" "テスト結果"
Add-Wbs "4.5.1.3" "テスト" "名寄せ" "テスト結果" "未解決時に誤紐づけされないことをテストする" "8/5" "8/5" 1.0 "川波" "中山" "高" "4.5.1.2" "テスト結果"
Add-Wbs "4.6.1.1" "テスト" "権限" "権限テスト結果" "営業権限で決済URL作成が可能か確認する" "8/6" "8/6" 1.5 "川波" "玉木" "高" "3.12.1.1" "権限結果"
Add-Wbs "4.6.1.2" "テスト" "権限" "権限テスト結果" "経理権限で決済状況確認が可能か確認する" "8/6" "8/6" 1.5 "川波" "中山" "高" "3.12.1.2" "権限結果"
Add-Wbs "4.6.1.3" "テスト" "権限" "権限テスト結果" "管理者権限でログ・設定確認が可能か確認する" "8/6" "8/6" 1.0 "川波" "高山" "中" "3.12.1.3" "権限結果"
Add-Wbs "4.7.1.1" "テスト" "技術レビュー" "技術レビュー結果" "Apexガバナ制限観点を確認する" "8/6" "8/6" 1.0 "川波" "小室" "高" "4.1.1.3" "技術レビュー"
Add-Wbs "4.7.1.2" "テスト" "技術レビュー" "技術レビュー結果" "Stripe API制限・リトライ観点を確認する" "8/6" "8/6" 1.0 "川波" "小室" "高" "4.7.1.1" "技術レビュー"
Add-Wbs "4.7.1.3" "テスト" "技術レビュー" "技術レビュー結果" "ログ・監査・障害調査性を確認する" "8/6" "8/6" 1.0 "川波" "小室" "中" "4.7.1.2" "技術レビュー"

Add-Wbs "5.1.1.1" "UAT" "営業UAT" "UAT結果" "営業が請求から決済URLを作成する" "8/6" "8/7" 1.5 "川波" "玉木、畝山" "高" "4.6.1.1" "UAT結果"
Add-Wbs "5.1.1.2" "UAT" "営業UAT" "UAT結果" "営業が顧客案内に必要なURL・状態を確認する" "8/7" "8/7" 1.0 "川波" "玉木、畝山" "高" "5.1.1.1" "UAT結果"
Add-Wbs "5.1.1.3" "UAT" "営業UAT" "UAT結果" "営業インターンへの影響有無を確認する" "8/7" "8/7" 1.5 "川波" "古川・桐谷、玉木" "低" "5.1.1.2" "確認結果"
Add-Wbs "5.2.1.1" "UAT" "経理UAT" "UAT結果" "経理が未入金・決済済みを確認する" "8/7" "8/7" 1.5 "川波" "中山" "高" "4.6.1.2" "UAT結果"
Add-Wbs "5.2.1.2" "UAT" "経理UAT" "UAT結果" "経理が決済失敗・期限切れを確認する" "8/7" "8/7" 1.0 "川波" "中山" "高" "5.2.1.1" "UAT結果"
Add-Wbs "5.2.1.3" "UAT" "経理UAT" "UAT結果" "返金・取消結果確認の運用を確認する" "8/7" "8/7" 1.5 "川波" "中山" "中" "5.2.1.2" "UAT結果"
Add-Wbs "5.3.1.1" "UAT" "CS/経営UAT" "UAT結果" "CS観点の契約更新・決済状況確認を実施する" "8/8" "8/8" 1.5 "川波" "玉木" "中" "5.2.1.3" "UAT結果"
Add-Wbs "5.3.1.2" "UAT" "CS/経営UAT" "UAT結果" "経営観点の収益・予実確認影響を確認する" "8/8" "8/8" 1.0 "川波" "高山、加藤" "中" "5.3.1.1" "UAT結果"
Add-Wbs "5.3.1.3" "UAT" "CS/経営UAT" "UAT結果" "受託案件フローへの影響を確認する" "8/8" "8/8" 1.5 "川波" "畝山" "中" "5.3.1.2" "UAT結果"
Add-Wbs "5.4.1.1" "UAT" "指摘対応" "修正版" "UAT指摘を一覧化する" "8/8" "8/8" 1.0 "川波" "各担当" "高" "5.3.1.3" "指摘一覧"
Add-Wbs "5.4.1.2" "UAT" "指摘対応" "修正版" "優先度高の指摘を修正する" "8/8" "8/9" 3.0 "川波" "各担当" "高" "5.4.1.1" "修正版"
Add-Wbs "5.4.1.3" "UAT" "指摘対応" "修正版" "修正結果を再確認する" "8/9" "8/9" 2.0 "川波" "各担当" "高" "5.4.1.2" "再確認結果"

Add-Wbs "6.1.1.1" "移行準備" "業務移行" "業務移行方針" "現行freee/Stripe/Salesforce運用との差分を整理する" "8/6" "8/7" 1.5 "川波" "中山、玉木、高山" "高" "1.2.1.2" "差分整理"
Add-Wbs "6.1.1.2" "移行準備" "業務移行" "業務移行方針" "新業務の担当者・タイミング・確認画面を定義する" "8/7" "8/7" 1.5 "川波" "中山、玉木" "高" "6.1.1.1" "業務移行方針"
Add-Wbs "6.1.1.3" "移行準備" "業務移行" "業務移行方針" "切替日・周知対象・問い合わせ窓口を整理する" "8/7" "8/7" 1.0 "川波" "高山" "高" "6.1.1.2" "切替計画"
Add-Wbs "6.2.1.1" "移行準備" "業務手順" "業務移行手順" "営業向け運用手順を作成する" "8/7" "8/8" 1.5 "川波" "玉木" "高" "6.1.1.2" "営業手順"
Add-Wbs "6.2.1.2" "移行準備" "業務手順" "業務移行手順" "経理向け運用手順を作成する" "8/8" "8/8" 2.0 "川波" "中山" "高" "6.2.1.1" "経理手順"
Add-Wbs "6.2.1.3" "移行準備" "業務手順" "業務移行手順" "障害時一次対応・問い合わせ導線を作成する" "8/8" "8/8" 1.5 "川波" "中山、玉木" "中" "6.2.1.2" "一次対応手順"
Add-Wbs "6.3.1.1" "移行準備" "システム移行" "システム移行手順" "本番反映対象メタデータを整理する" "8/7" "8/8" 1.5 "川波" "小室" "高" "3.12.1.3" "リリース対象一覧"
Add-Wbs "6.3.1.2" "移行準備" "システム移行" "システム移行手順" "Named Credential/APIキー/Webhook設定手順を整理する" "8/8" "8/8" 2.0 "川波" "横溝、小室" "高" "3.3.1.2" "設定手順"
Add-Wbs "6.3.1.3" "移行準備" "システム移行" "システム移行手順" "権限・タブ・スケジュール確認手順を作成する" "8/8" "8/9" 1.5 "川波" "小室" "中" "6.3.1.1" "設定確認表"
Add-Wbs "6.3.1.4" "移行準備" "システム移行" "システム移行手順" "切り戻し方針を整理する" "8/9" "8/9" 1.0 "川波" "横溝、高山" "中" "6.3.1.3" "切り戻し方針"
Add-Wbs "6.4.1.1" "移行準備" "データ移行" "データ移行方針" "既存Stripe Customer IDの取得形式を確認する" "8/7" "8/7" 1.5 "川波" "横溝、小室" "高" "2.3.1.3" "取得形式"
Add-Wbs "6.4.1.2" "移行準備" "データ移行" "データ移行方針" "Salesforce取引先への紐づけキーを定義する" "8/8" "8/8" 1.5 "川波" "横溝、中山" "高" "6.4.1.1" "紐づけキー"
Add-Wbs "6.4.1.3" "移行準備" "データ移行" "データ移行方針" "既存請求・決済状態の移行対象範囲を整理する" "8/8" "8/8" 1.0 "川波" "中山" "中" "6.4.1.2" "移行対象"
Add-Wbs "6.4.1.4" "移行準備" "データ移行" "データ移行方針" "移行後照合観点を作成する" "8/8" "8/8" 1.0 "川波" "中山、高山" "高" "6.4.1.3" "照合観点"
Add-Wbs "6.5.1.1" "移行準備" "移行リハ" "移行リハ結果" "移行リハーサルを実施する" "8/9" "8/9" 1.5 "川波" "横溝、小室" "高" "6.3.1.4" "リハ結果"
Add-Wbs "6.5.1.2" "移行準備" "移行リハ" "移行リハ結果" "移行後照合を実施する" "8/9" "8/9" 1.0 "川波" "中山、高山" "高" "6.5.1.1" "照合結果"
Add-Wbs "6.5.1.3" "移行準備" "移行リハ" "移行リハ結果" "リリース判定表を更新する" "8/9" "8/9" 1.5 "川波" "高山、加藤、横溝" "高" "6.5.1.2" "判定表"

Add-Wbs "7.1.1.1" "リリース" "リリース準備" "リリース資材" "package.xml/manifestを作成する" "8/9" "8/9" 1.5 "川波" "小室" "高" "6.3.1.1" "manifest"
Add-Wbs "7.1.1.2" "リリース" "リリース準備" "リリース資材" "dry-runを実施する" "8/9" "8/9" 1.5 "川波" "小室" "高" "7.1.1.1" "dry-run結果"
Add-Wbs "7.1.1.3" "リリース" "リリース準備" "リリース資材" "dry-run結果の指摘を修正する" "8/9" "8/9" 1.0 "川波" "小室" "高" "7.1.1.2" "修正版"
Add-Wbs "7.2.1.1" "リリース" "手順書" "手順書" "本番リリース手順を作成する" "8/9" "8/9" 1.5 "川波" "横溝、高山" "高" "7.1.1.2" "手順書"
Add-Wbs "7.2.1.2" "リリース" "手順書" "手順書" "切り戻し手順を作成する" "8/9" "8/9" 1.0 "川波" "横溝、高山" "中" "7.2.1.1" "切り戻し手順"
Add-Wbs "7.2.1.3" "リリース" "手順書" "手順書" "リリース後確認チェックリストを作成する" "8/9" "8/9" 0.5 "川波" "小室" "中" "7.2.1.2" "確認チェックリスト"
Add-Wbs "7.3.1.1" "リリース" "本番反映" "リリース結果" "本番リリースを実施する" "8/10" "8/10" 1.0 "川波" "横溝、小室" "高" "7.2.1.3" "リリース結果"
Add-Wbs "7.3.1.2" "リリース" "本番反映" "リリース結果" "リリース後疎通確認を実施する" "8/10" "8/10" 1.0 "川波" "横溝、小室" "高" "7.3.1.1" "疎通結果"
Add-Wbs "7.4.1.1" "リリース" "完了報告" "完了報告" "残課題を整理する" "8/10" "8/10" 0.5 "川波" "高山、加藤" "高" "7.3.1.2" "残課題一覧"
Add-Wbs "7.4.1.2" "リリース" "完了報告" "完了報告" "完了報告を作成する" "8/10" "8/10" 0.5 "川波" "高山、加藤" "高" "7.4.1.1" "完了報告"
Add-Wbs "8.1.1.1" "予備" "調整" "調整対応" "要件調整・障害対応に充当する" "7/14" "8/10" 8.0 "川波" "必要に応じて" "中" "-" "調整対応"

$summary = @(
    @("項目","値"),
    @("対象期間","2026/07/14〜2026/08/10"),
    @("総稼働可能時間",140),
    @("L4タスク件数",$wbs.Count),
    @("計画工数合計(h)",($wbs | ForEach-Object { $_[7] } | Measure-Object -Sum).Sum),
    @("開始日","7/14"),
    @("終了日","8/10"),
    @("管理単位","L4")
)

$phaseRows = New-Object System.Collections.Generic.List[object]
$phaseRows.Add(@("フェーズ","タスク件数","計画工数(h)"))
$wbs | Group-Object { $_[1] } | ForEach-Object {
    $phaseRows.Add(@($_.Name, $_.Count, ($_.Group | ForEach-Object { $_[7] } | Measure-Object -Sum).Sum))
}

$milestones = @(
    @("日付","マイルストーン","判定基準","主な確認者"),
    @("7/19","要件・方式確定","スコープ、対象外、名寄せ、決済方式が確定している","横溝、高山、中山"),
    @("7/23","設計確定","オブジェクト、項目、API、Webhook、権限設計が確定している","横溝、小室"),
    @("8/02","主要実装完了","Checkout作成、Webhook受信、ログ、権限の実装が完了している","小室"),
    @("8/06","結合テスト完了","決済成功・失敗・期限切れの主要シナリオが通っている","小室、中山"),
    @("8/08","移行準備完了","業務移行、システム移行、データ移行の手順と照合観点が揃っている","中山、玉木、横溝"),
    @("8/09","UAT・移行リハ・リリース判定","営業・経理の主要UATと移行リハが完了し、重大障害がない","高山、加藤、横溝"),
    @("8/10","リリース完了","本番反映、権限確認、疎通確認、完了報告が完了している","高山、加藤")
)

$migration = @(
    @("区分","L4タスク","主担当","確認者","完了条件"),
    @("業務移行","現行freee/Stripe/Salesforce運用との差分整理","川波","中山、玉木、高山","決済URL作成、顧客案内、入金確認、返金確認の担当が明確"),
    @("業務移行","営業・経理向け運用手順作成","川波","中山、玉木","誰が、いつ、どの画面で、どのステータスを確認するか明記"),
    @("業務移行","切替日、周知対象、問い合わせ窓口整理","川波","高山","運用開始日、旧運用停止範囲、問い合わせ先が決定"),
    @("システム移行","本番反映対象メタデータ整理","川波","小室","オブジェクト、項目、Apex、権限、タブ、リストビュー、レポートが整理済み"),
    @("システム移行","Stripe接続設定確認","川波","横溝、小室","Named Credential、APIキー、Webhook URL、Webhook署名シークレット手順が確定"),
    @("システム移行","リリース前dry-runと移行リハーサル","川波","小室","dry-run成功、主要シナリオ疎通、ロールバック方針確認済み"),
    @("データ移行","既存Stripe Customer ID取得方針整理","川波","横溝、小室","Stripe Customer IDをSalesforce取引先へ紐づける方法が決定"),
    @("データ移行","名寄せ・照合ルール確定","川波","横溝、中山","完全一致、自動候補、手動確認の基準が決定"),
    @("データ移行","移行後照合","川波","中山、高山","件数、未紐づけ、重複候補、決済状態反映の確認観点が揃う")
)

$roles = @(
    @("メンバー","役割","WBS上の主な関与"),
    @("横溝（CTO）","Stripe等の決済や自社サービスのシステム構築全体","アーキテクチャ確認、Stripe方針確認、技術判断"),
    @("小室","アプリケーションエンジニア、自社サービス実装担当","Stripe API仕様確認、Webhook仕様確認、技術レビュー"),
    @("中山（総務）","経理担当、freee仕様・請求・解約手続き担当","決済ステータス、未入金、返金・取消、経理UAT確認"),
    @("玉木","CS担当、商談管理・見積・契約情報入力、CSダッシュボード利用","契約・請求フロー、CS観点のUAT、ダッシュボード確認"),
    @("高山","CSO、全社システム構成・ストラクチャ把握","全体方針確認、業務影響確認、リリース判断"),
    @("加藤","代表、商談管理・予実管理・収益チェック利用","収益管理観点、経営ダッシュボード観点、最終承認"),
    @("畝山","受託PM、受託案件の商談管理・見積・契約手続き","受託案件フローのUAT、例外パターン確認"),
    @("古川・桐谷","営業インターン、リード管理・商談化・初回商談担当","必要に応じて営業入力フロー確認")
)

$risks = @(
    @("No","リスク","影響","対策","関連フェーズ"),
    @(1,"Stripe Customerの名寄せ誤り","別顧客への決済紐づけ","完全一致以外は手動確認にする","要件定義/設計/データ移行"),
    @(2,"Webhook未着・重複","決済状態不整合","Event ID冪等性、再取得バッチを用意","実装/テスト"),
    @(3,"Stripe API仕様・認証設定の確認遅延","実装遅延","横溝・小室に早期確認依頼","設計/システム移行"),
    @(4,"経理運用がfreeeとStripeで混在","入金確認漏れ","freee請求管理とStripe決済管理の役割を明文化","業務移行"),
    @(5,"期間内にフルスコープが収まらない","リリース遅延","初期スコープをCheckout/決済結果反映に絞る","全体"),
    @(6,"返金・取消要件が膨らむ","工数超過","初期はStripe画面手動、Salesforceは結果同期に限定","要件定義"),
    @(7,"業務移行の周知不足","旧運用継続による二重管理","業務移行手順と切替日を明文化し、営業・経理へ周知","業務移行"),
    @(8,"システム移行の設定漏れ","Webhook未着、決済URL作成不可","本番設定チェックリストと移行リハーサルを実施","システム移行"),
    @(9,"データ移行の名寄せ不備","Stripe Customerの誤紐づけ","完全一致のみ自動反映し、曖昧一致は手動確認","データ移行")
)

New-Item -ItemType Directory -Path $tmp | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmp "_rels") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmp "xl\worksheets") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmp "xl\_rels") -Force | Out-Null

$contentTypes = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/worksheets/sheet4.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/worksheets/sheet5.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/worksheets/sheet6.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>
'@
[System.IO.File]::WriteAllText((Join-Path $tmp "[Content_Types].xml"), $contentTypes, [System.Text.UTF8Encoding]::new($false))

$rels = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>
'@
[System.IO.File]::WriteAllText((Join-Path $tmp "_rels\.rels"), $rels, [System.Text.UTF8Encoding]::new($false))

$workbook = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>
<sheet name="サマリ" sheetId="1" r:id="rId1"/>
<sheet name="WBS_L4" sheetId="2" r:id="rId2"/>
<sheet name="移行準備" sheetId="3" r:id="rId3"/>
<sheet name="マイルストーン" sheetId="4" r:id="rId4"/>
<sheet name="体制" sheetId="5" r:id="rId5"/>
<sheet name="リスク" sheetId="6" r:id="rId6"/>
</sheets>
</workbook>
'@
[System.IO.File]::WriteAllText((Join-Path $tmp "xl\workbook.xml"), $workbook, [System.Text.UTF8Encoding]::new($false))

$workbookRels = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/>
<Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet4.xml"/>
<Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet5.xml"/>
<Relationship Id="rId6" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet6.xml"/>
<Relationship Id="rId7" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
'@
[System.IO.File]::WriteAllText((Join-Path $tmp "xl\_rels\workbook.xml.rels"), $workbookRels, [System.Text.UTF8Encoding]::new($false))

$styles = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<numFmts count="1"><numFmt numFmtId="164" formatCode="yyyy-mm-dd"/></numFmts>
<fonts count="3"><font><sz val="10"/><name val="Meiryo UI"/></font><font><b/><color rgb="FFFFFFFF"/><sz val="10"/><name val="Meiryo UI"/></font><font><b/><sz val="12"/><name val="Meiryo UI"/></font></fonts>
<fills count="4"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF1F4E78"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFEAF2F8"/><bgColor indexed="64"/></patternFill></fill></fills>
<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border><left style="thin"><color rgb="FFD9E2EC"/></left><right style="thin"><color rgb="FFD9E2EC"/></right><top style="thin"><color rgb="FFD9E2EC"/></top><bottom style="thin"><color rgb="FFD9E2EC"/></bottom><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="4"><xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/><xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf><xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/><xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/></cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>
'@
[System.IO.File]::WriteAllText((Join-Path $tmp "xl\styles.xml"), $styles, [System.Text.UTF8Encoding]::new($false))

Add-SheetXml (Join-Path $tmp "xl\worksheets\sheet1.xml") $summary $true $true @(24,38)
Add-SheetXml (Join-Path $tmp "xl\worksheets\sheet2.xml") (@($headers) + $wbs.ToArray()) $true $true @(14,16,18,22,48,12,12,12,14,24,12,10,24,24,42)
Add-SheetXml (Join-Path $tmp "xl\worksheets\sheet3.xml") $migration $true $true @(18,52,14,26,72)
Add-SheetXml (Join-Path $tmp "xl\worksheets\sheet4.xml") $milestones $true $true @(14,34,72,28)
Add-SheetXml (Join-Path $tmp "xl\worksheets\sheet5.xml") $roles $true $true @(20,52,72)
Add-SheetXml (Join-Path $tmp "xl\worksheets\sheet6.xml") $risks $true $true @(8,38,38,58,24)

if (Test-Path $outFile) { Remove-Item -LiteralPath $outFile -Force }
$fs = [System.IO.File]::Open($outFile, [System.IO.FileMode]::CreateNew)
$zip = [System.IO.Compression.ZipArchive]::new($fs, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    Push-Location $tmp
    Get-ChildItem -Path . -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring((Get-Location).Path.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}
finally {
    Pop-Location
    $zip.Dispose()
    $fs.Dispose()
}
Remove-Item -LiteralPath $tmp -Recurse -Force
Write-Host "created=$outFile"
Write-Host "tasks=$($wbs.Count)"
Write-Host "hours=$(($wbs | ForEach-Object { $_[7] } | Measure-Object -Sum).Sum)"
