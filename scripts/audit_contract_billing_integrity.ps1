param(
    [string]$DataDir = "outputs/data-integrity-20260805",
    [datetime]$AsOfDate = "2026-08-05"
)

$ErrorActionPreference = "Stop"
$contracts = @(Import-Csv (Join-Path $DataDir "contracts.csv"))
$periods = @(Import-Csv (Join-Path $DataDir "periods.csv"))
$monthly = @(Import-Csv (Join-Path $DataDir "monthly.csv"))
$invoices = @(Import-Csv (Join-Path $DataDir "invoices.csv"))
$lines = @(Import-Csv (Join-Path $DataDir "invoice-lines.csv"))
$findings = [System.Collections.Generic.List[object]]::new()

function Empty($value) { return [string]::IsNullOrWhiteSpace([string]$value) }
function Dec($value) { if (Empty $value) { return $null }; return [decimal]$value }
function DateValue($value) { if (Empty $value) { return $null }; return [datetime]::ParseExact($value.Substring(0,10), "yyyy-MM-dd", $null) }
function MonthValue($date) { if ($null -eq $date) { return $null }; return $date.ToString("yyyy/MM") }
function AddFinding($severity, $category, $objectName, $record, $issue, $evidence, $action) {
    $findings.Add([pscustomobject]@{
        Severity=$severity; Category=$category; Object=$objectName; RecordId=$record.Id; RecordName=$record.Name
        Issue=$issue; Evidence=$evidence; RecommendedAction=$action
    })
}

$contractById = @{}; foreach ($r in $contracts) { $contractById[$r.Id] = $r }
$periodById = @{}; foreach ($r in $periods) { $periodById[$r.Id] = $r }
$invoiceById = @{}; foreach ($r in $invoices) { $invoiceById[$r.Id] = $r }
$periodsByContract = $periods | Group-Object Contract__c -AsHashTable -AsString
$monthlyByContract = $monthly | Group-Object MasterContract__c -AsHashTable -AsString
$invoicesByContract = $invoices | Group-Object ParentContract__c -AsHashTable -AsString
$linesByInvoice = $lines | Group-Object Invoice__c -AsHashTable -AsString
$monthlyByInvoice = @($monthly | Where-Object { -not (Empty $_.RelatedInvoice__c) }) | Group-Object RelatedInvoice__c -AsHashTable -AsString
$annualAllocationInvoices = @{}
foreach ($invoiceId in $monthlyByInvoice.Keys) {
    if (-not $invoiceById.ContainsKey($invoiceId) -or -not $linesByInvoice.ContainsKey($invoiceId)) { continue }
    $linkedMonthly = @($monthlyByInvoice[$invoiceId])
    $uniqueMonths = @($linkedMonthly.Month__c | Where-Object { -not (Empty $_) } | Sort-Object -Unique)
    $monthlyTotal = [decimal](($linkedMonthly | ForEach-Object { if (Empty $_.Total__c) { 0 } else { [decimal]$_.Total__c } } | Measure-Object -Sum).Sum)
    $invoiceTotal = Dec $invoiceById[$invoiceId].TotalAmount__c
    $annualDescription = (@($linesByInvoice[$invoiceId].Description__c) -join ' ') -match '年払|年間|年額'
    if ($uniqueMonths.Count -ge 10 -and $null -ne $invoiceTotal -and [math]::Abs($monthlyTotal - $invoiceTotal) -le 1 -and $annualDescription) {
        $annualAllocationInvoices[$invoiceId] = $true
    }
}
$currentMonth = $AsOfDate.ToString("yyyy/MM")

# Contract checks
foreach ($c in $contracts) {
    $start = DateValue ($c.StartDate__c); $end = DateValue ($c.EndDate__c)
    if ($c.Status__c -eq "Activated") {
        if (Empty $c.Account__c) { AddFinding "High" "契約必須情報" "Contract__c" $c "有効契約に取引先がない" "Status=Activated" "取引先を設定する" }
        if ($null -eq $start -or ($c.ContractUpdate__c -eq '年' -and $null -eq $end)) { AddFinding "High" "契約必須情報" "Contract__c" $c "有効契約の開始日、または年更新契約の終了日がない" "Start=$($c.StartDate__c), End=$($c.EndDate__c), Update=$($c.ContractUpdate__c)" "契約期間を確認して日付を補完する" }
        if (Empty $c.MRR__c) { AddFinding "High" "MRR" "Contract__c" $c "有効契約のMRRが空" "Status=Activated" "請求明細または契約内容を根拠にMRRを設定する" }
        if (-not $periodsByContract.ContainsKey($c.Id)) { AddFinding "High" "関連不足" "Contract__c" $c "有効契約に契約期間がない" "Period count=0" "契約開始日・終了日から契約期間を作成する" }
        if (-not $monthlyByContract.ContainsKey($c.Id)) { AddFinding "High" "関連不足" "Contract__c" $c "有効契約に契約月次明細が1件もない" "Monthly count=0" "契約期間と商品を確認して月次明細を生成する" }
        elseif (@($monthlyByContract[$c.Id] | Where-Object { $_.Month__c -eq $currentMonth }).Count -eq 0) { AddFinding "High" "月次不足" "Contract__c" $c "有効契約に当月の契約月次明細がない" "Expected month=$currentMonth" "当月の契約対象を確認し月次明細を生成する" }
        if (-not $invoicesByContract.ContainsKey($c.Id)) { AddFinding "High" "関連不足" "Contract__c" $c "有効契約に請求がない" "Invoice count=0" "freee請求の未取込または契約紐付けを確認する" }
    }
    if ($null -ne $start -and $null -ne $end -and $start -gt $end) { AddFinding "High" "日付矛盾" "Contract__c" $c "契約開始日が終了日より後" "Start=$($c.StartDate__c), End=$($c.EndDate__c)" "契約日付を修正する" }
    if ($c.Status__c -eq "Activated" -and $null -ne $end -and $end -lt $AsOfDate.Date) { AddFinding "High" "ステータス矛盾" "Contract__c" $c "終了済み日付だが有効契約" "End=$($c.EndDate__c)" "更新契約の有無を確認し、終了・更新予定・有効のいずれかへ整理する" }
}

# Contract period checks
foreach ($p in $periods) {
    $ps = DateValue ($p.PeriodStartDate__c); $pe = DateValue ($p.PeriodEndDate__c)
    if ($null -eq $ps -or $null -eq $pe) { AddFinding "High" "契約期間必須情報" "ContractPeriod__c" $p "契約期間の開始日または終了日がない" "Start=$($p.PeriodStartDate__c), End=$($p.PeriodEndDate__c)" "親契約の日付と更新回数から補完する" }
    elseif ($ps -gt $pe) { AddFinding "High" "日付矛盾" "ContractPeriod__c" $p "期間開始日が期間終了日より後" "Start=$($p.PeriodStartDate__c), End=$($p.PeriodEndDate__c)" "期間日付を修正する" }
    $c = $contractById[$p.Contract__c]
    if ($null -ne $c) {
        $cs = DateValue ($c.StartDate__c); $ce = DateValue ($c.EndDate__c)
        if ($null -ne $ps -and $null -ne $cs -and $ps -lt $cs) { AddFinding "Medium" "親子日付不一致" "ContractPeriod__c" $p "契約期間開始日が親契約開始日より前" "Period=$($p.PeriodStartDate__c), Contract=$($c.StartDate__c)" "契約更新履歴を確認する" }
        $normalCancelMonth = $null -ne $pe -and $null -ne $ce -and
            $c.Status__c -eq '解約' -and $c.ContractUpdate__c -eq '月' -and
            $pe.Year -eq $ce.Year -and $pe.Month -eq $ce.Month
        if ($null -ne $pe -and $null -ne $ce -and $pe -gt $ce -and -not $normalCancelMonth) { AddFinding "Medium" "親子日付不一致" "ContractPeriod__c" $p "契約期間終了日が親契約終了日より後" "Period=$($p.PeriodEndDate__c), Contract=$($c.EndDate__c)" "契約更新履歴を確認する" }
    }
    if ((-not (Empty $p.RelatedInvoice__c)) -and $invoiceById.ContainsKey($p.RelatedInvoice__c) -and $invoiceById[$p.RelatedInvoice__c].ParentContract__c -ne $p.Contract__c) {
        AddFinding "High" "参照不一致" "ContractPeriod__c" $p "代表請求の親契約が契約期間の親契約と異なる" "Invoice=$($p.RelatedInvoice__c)" "正しい請求参照へ付け替える"
    }
}
foreach ($g in @($periods | Group-Object Contract__c)) {
    $ordered = @($g.Group | Sort-Object PeriodStartDate__c, PeriodEndDate__c)
    for ($n=1; $n -lt $ordered.Count; $n++) {
        $prevEnd=DateValue ($ordered[$n-1].PeriodEndDate__c); $curStart=DateValue ($ordered[$n].PeriodStartDate__c)
        if ($null -ne $prevEnd -and $null -ne $curStart -and $curStart -le $prevEnd) { AddFinding "High" "期間重複" "ContractPeriod__c" $ordered[$n] "同一契約の契約期間が重複" "Previous=$($ordered[$n-1].Name), previous end=$($ordered[$n-1].PeriodEndDate__c), current start=$($ordered[$n].PeriodStartDate__c)" "更新期間の境界を修正または重複期間を統合する" }
    }
}

# Monthly detail checks
foreach ($m in $monthly) {
    $ms=DateValue ($m.PeriodStartDate__c); $me=DateValue ($m.PeriodEndDate__c)
    if (Empty $m.ContractPeriod__c) { AddFinding "High" "参照不足" "ContractLineItem__c" $m "契約期間が未設定" "MasterContract=$($m.MasterContract__c)" "対象年月を含む契約期間を設定する" }
    elseif ($m.'ContractPeriod__r.Contract__c' -ne $m.MasterContract__c) { AddFinding "High" "参照不一致" "ContractLineItem__c" $m "契約期間の親契約と契約管理が異なる" "PeriodContract=$($m.'ContractPeriod__r.Contract__c'), Master=$($m.MasterContract__c)" "正しい契約期間へ付け替える" }
    if ($m.Account__c -ne $m.'MasterContract__r.Account__c') { AddFinding "High" "取引先不一致" "ContractLineItem__c" $m "月次明細と契約管理の取引先が異なる" "Monthly=$($m.Account__c), Contract=$($m.'MasterContract__r.Account__c')" "契約管理の取引先に統一する" }
    if (Empty $m.ProductMaster__c) { AddFinding "Medium" "商品不足" "ContractLineItem__c" $m "商品マスタが未設定" "Month=$($m.Month__c), Amount=$($m.Total__c)" "請求明細の商品・名称・金額から商品を確定する" }
    if ((Empty $m.RevenueAmount__c) -and ($m.MRR_Target__c -eq "true" -or $m.'ProductMaster__r.MRR_Target__c' -eq "true")) { AddFinding "High" "MRR" "ContractLineItem__c" $m "MRR対象だが売上予定額が空" "Month=$($m.Month__c), Total=$($m.Total__c)" "商品単価または請求明細から売上予定額を補完する" }
    if ($null -eq $ms -or $null -eq $me) { AddFinding "High" "月次必須情報" "ContractLineItem__c" $m "対象期間開始日または終了日がない" "Start=$($m.PeriodStartDate__c), End=$($m.PeriodEndDate__c)" "対象年月から月初・月末を補完する" }
    else {
        $expectedMonth=MonthValue $ms; $expectedEnd=$ms.AddMonths(1).AddDays(-1)
        if ($m.Month__c -ne $expectedMonth -or $m.ContractYearMonth__c -ne $expectedMonth) { AddFinding "High" "年月不一致" "ContractLineItem__c" $m "年月表示と対象期間開始月が異なる" "ContractYM=$($m.ContractYearMonth__c), Month=$($m.Month__c), Start=$($m.PeriodStartDate__c)" "年月を対象期間開始日のyyyy/MMへ統一する" }
        if ($me.Date -ne $expectedEnd.Date) { AddFinding "Medium" "月末不一致" "ContractLineItem__c" $m "対象期間終了日が対象月末ではない" "Start=$($m.PeriodStartDate__c), End=$($m.PeriodEndDate__c), Expected=$($expectedEnd.ToString('yyyy-MM-dd'))" "対象期間終了日を月末へ修正する" }
    }
    if (-not (Empty $m.RelatedInvoice__c)) {
        if ($m.'RelatedInvoice__r.ParentContract__c' -ne $m.MasterContract__c) { AddFinding "High" "請求参照不一致" "ContractLineItem__c" $m "関連請求の親契約が月次明細の契約と異なる" "InvoiceContract=$($m.'RelatedInvoice__r.ParentContract__c'), MonthlyContract=$($m.MasterContract__c)" "正しい請求へ付け替える" }
        if ($m.'RelatedInvoice__r.Account__c' -ne $m.Account__c) { AddFinding "High" "請求参照不一致" "ContractLineItem__c" $m "関連請求の取引先が月次明細と異なる" "InvoiceAccount=$($m.'RelatedInvoice__r.Account__c'), MonthlyAccount=$($m.Account__c)" "正しい請求へ付け替える" }
        $bill=DateValue ($m.'RelatedInvoice__r.Billing_Date__c')
        if ($null -ne $ms -and $null -ne $bill -and -not $annualAllocationInvoices.ContainsKey($m.RelatedInvoice__c) -and [math]::Abs((($bill.Year-$ms.Year)*12)+$bill.Month-$ms.Month) -gt 1) { AddFinding "High" "請求月不一致" "ContractLineItem__c" $m "関連請求の請求月が月次明細から2か月以上離れている" "Monthly=$($m.Month__c), Billing=$($m.'RelatedInvoice__r.Billing_Date__c'), Invoice=$($m.RelatedInvoice__c)" "一括付替え等の誤紐付けを確認する" }
    }
}
foreach ($g in @($monthly | Group-Object { "$($_.MasterContract__c)|$($_.Month__c)|$($_.ProductMaster__c)" })) {
    if ($g.Count -gt 1 -and -not ($g.Name -match '\|$')) { foreach ($r in $g.Group) { AddFinding "High" "重複" "ContractLineItem__c" $r "同一契約・対象月・商品で月次明細が重複" "Key=$($g.Name), Count=$($g.Count)" "請求・作成元を確認し重複を統合する" } }
}

# Invoice and line checks
foreach ($i in $invoices) {
    if (Empty $i.ParentContract__c) { AddFinding "High" "参照不足" "Invoice__c" $i "親契約が未設定" "Account=$($i.Account__c), Billing=$($i.Billing_Date__c)" "取引先・請求明細・請求月から契約を特定する" }
    elseif ($i.Account__c -ne $i.'ParentContract__r.Account__c') { AddFinding "High" "取引先不一致" "Invoice__c" $i "請求と契約管理の取引先が異なる" "Invoice=$($i.Account__c), Contract=$($i.'ParentContract__r.Account__c')" "正しい契約または取引先へ付け替える" }
    if ((-not (Empty $i.ContractPeriod__c)) -and $i.'ContractPeriod__r.Contract__c' -ne $i.ParentContract__c) { AddFinding "High" "参照不一致" "Invoice__c" $i "契約期間の親契約と請求の親契約が異なる" "PeriodContract=$($i.'ContractPeriod__r.Contract__c'), InvoiceContract=$($i.ParentContract__c)" "正しい契約期間へ付け替える" }
    if ((-not (Empty $i.ParentContract__c)) -and (Empty $i.ContractPeriod__c)) { AddFinding "Medium" "参照不足" "Invoice__c" $i "契約はあるが契約期間が未設定" "Contract=$($i.ParentContract__c)" "請求対象月を含む契約期間を設定する" }
    if (-not $linesByInvoice.ContainsKey($i.Id)) { AddFinding "High" "明細不足" "Invoice__c" $i "請求明細がない" "InvoiceAmount=$($i.InvoiceAmount__c)" "freee明細を再取得するか請求明細を作成する" }
    else {
        $lineSum=[decimal](($linesByInvoice[$i.Id] | ForEach-Object { if (Empty $_.Line_Amount__c) {0} else {[decimal]$_.Line_Amount__c} } | Measure-Object -Sum).Sum)
        $total=Dec $i.TotalAmount__c
        if ($null -ne $total -and [math]::Abs($lineSum-$total) -gt 1) { AddFinding "High" "金額不一致" "Invoice__c" $i "請求明細小計と請求合計金額が一致しない" "LineSum=$lineSum, TotalAmount=$total" "明細欠落・商品誤紐付け・金額項目定義を確認する" }
    }
    $amount=Dec $i.InvoiceAmount__c; $paid=Dec $i.PaidAmount__c; $unpaid=Dec $i.UnpaidAmount__c
    if ($null -ne $amount -and $null -ne $paid -and $null -ne $unpaid -and [math]::Abs(($paid+$unpaid)-$amount) -gt 1) { AddFinding "High" "入金金額不一致" "Invoice__c" $i "入金額と未入金額の合計が請求金額と一致しない" "Paid=$paid, Unpaid=$unpaid, Invoice=$amount" "freee決済情報を再同期する" }
    if ($i.PaymentStatus__c -eq "決済済み" -and (($null -ne $unpaid -and $unpaid -gt 1) -or ($null -ne $amount -and $null -ne $paid -and [math]::Abs($paid-$amount) -gt 1))) { AddFinding "High" "決済ステータス矛盾" "Invoice__c" $i "決済済みだが金額が完済状態ではない" "Paid=$paid, Unpaid=$unpaid, Invoice=$amount" "freeeから決済ステータスと金額を再同期する" }
    if ($i.PaymentStatus__c -eq "決済待ち" -and $null -ne $amount -and $null -ne $unpaid -and $amount -gt 0 -and $unpaid -eq 0) { AddFinding "High" "決済ステータス矛盾" "Invoice__c" $i "決済待ちだが未入金額が0" "Invoice=$amount, Unpaid=$unpaid" "freeeから決済ステータスと金額を再同期する" }
    if ($i.Freee_Sync_Status__c -eq "Success" -and (Empty $i.Freee_Invoice_Id__c)) { AddFinding "High" "Freee連携矛盾" "Invoice__c" $i "Freee連携成功だがfreee請求書IDがない" "SyncStatus=Success" "freee IDを再取得する" }
    if ((-not (Empty $i.Freee_Invoice_Id__c)) -and (Empty $i.Freee_Invoice_URL__c)) { AddFinding "Medium" "Freee情報不足" "Invoice__c" $i "freee請求書IDはあるがURLがない" "FreeeId=$($i.Freee_Invoice_Id__c)" "IDから請求書URLを補完する" }
}
foreach ($g in @($invoices | Where-Object {-not (Empty $_.Freee_Invoice_Id__c)} | Group-Object Freee_Invoice_Id__c)) {
    if ($g.Count -gt 1) { foreach ($r in $g.Group) { AddFinding "High" "重複" "Invoice__c" $r "同じfreee請求書IDを持つ請求が複数ある" "FreeeId=$($g.Name), Count=$($g.Count)" "正レコードを確定し重複請求を取消または統合する" } }
}
foreach ($l in $lines) {
    if (Empty $l.ProductMaster__c) { AddFinding "Medium" "商品不足" "InvoiceLine__c" $l "請求明細の商品マスタが未設定" "Description=$($l.Description__c), Amount=$($l.Line_Amount__c)" "商品名・金額・請求タイミングで商品を特定する" }
    $qty=Dec $l.Quantity__c; $unit=Dec $l.Unit_Price__c; $discount=Dec $l.DiscountRate__c; $lineAmount=Dec $l.Line_Amount__c
    if ($null -ne $qty -and $null -ne $unit -and $null -ne $lineAmount -and ($null -eq $discount -or $discount -eq 0) -and [math]::Abs(($qty*$unit)-$lineAmount) -gt 1) { AddFinding "Medium" "明細金額不一致" "InvoiceLine__c" $l "数量×単価と小計金額が一致しない" "Qty=$qty, Unit=$unit, Line=$lineAmount" "値引・単価・数量の移行値を確認する" }
}

$detailPath=Join-Path $DataDir "integrity-findings.csv"
$findings | Sort-Object @{Expression={switch($_.Severity){"High"{1};"Medium"{2};default{3}}}},Category,Object,RecordName | Export-Csv -LiteralPath $detailPath -NoTypeInformation -Encoding UTF8
$summary = @($findings | Group-Object Severity,Category,Object | Sort-Object Count -Descending | ForEach-Object {
    [pscustomobject]@{ Severity=$_.Group[0].Severity; Category=$_.Group[0].Category; Object=$_.Group[0].Object; Count=$_.Count }
})
$summary | Export-Csv -LiteralPath (Join-Path $DataDir "integrity-summary.csv") -NoTypeInformation -Encoding UTF8
"findings=$($findings.Count) high=$(@($findings | Where-Object Severity -eq 'High').Count) medium=$(@($findings | Where-Object Severity -eq 'Medium').Count)"
$summary | Format-Table -AutoSize | Out-String -Width 220

