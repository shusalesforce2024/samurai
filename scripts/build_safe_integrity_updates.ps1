param([string]$DataDir = "outputs/data-integrity-fix-20260806")

$contracts = @(Import-Csv (Join-Path $DataDir "contracts-current.csv"))
$periods = @(Import-Csv (Join-Path $DataDir "periods-current.csv"))
$monthly = @(Import-Csv (Join-Path $DataDir "monthly-current.csv"))
$invoices = @(Import-Csv (Join-Path $DataDir "invoices-current.csv"))

function IsEmpty($v) { [string]::IsNullOrWhiteSpace([string]$v) }
function AsDate($v) { if (IsEmpty $v) { return $null }; [datetime]::ParseExact($v.Substring(0,10), "yyyy-MM-dd", $null) }
function Write-NoBomCsv($path, $headers, $rows) {
    $enc = [System.Text.UTF8Encoding]::new($false)
    $writer = [System.IO.StreamWriter]::new($path, $false, $enc)
    try {
        $writer.WriteLine(($headers -join ","))
        foreach ($row in $rows) {
            $values = foreach ($h in $headers) {
                $v = [string]$row.$h
                if ($v.Contains('"')) { $v = $v.Replace('"','""') }
                if ($v.Contains(',') -or $v.Contains('"') -or $v.Contains("`n")) { '"' + $v + '"' } else { $v }
            }
            $writer.WriteLine(($values -join ","))
        }
    } finally { $writer.Dispose() }
}

$contractById=@{}; foreach($r in $contracts){$contractById[$r.Id]=$r}
$invoiceById=@{}; foreach($r in $invoices){$invoiceById[$r.Id]=$r}
$periodsByContract=@{}; foreach($p in $periods){if(-not $periodsByContract.ContainsKey($p.Contract__c)){$periodsByContract[$p.Contract__c]=@()};$periodsByContract[$p.Contract__c]+=$p}
$invoicesByContract=@{}; foreach($i in $invoices){if(-not (IsEmpty $i.ParentContract__c)){if(-not $invoicesByContract.ContainsKey($i.ParentContract__c)){$invoicesByContract[$i.ParentContract__c]=@()};$invoicesByContract[$i.ParentContract__c]+=$i}}

$invoiceUpdates=[System.Collections.Generic.List[object]]::new()
$invoiceRollback=[System.Collections.Generic.List[object]]::new()
foreach($i in $invoices){
    $newUrl=$i.Freee_Invoice_URL__c
    if((-not (IsEmpty $i.Freee_Invoice_Id__c)) -and (IsEmpty $newUrl)){$newUrl="https://invoice.secure.freee.co.jp/reports/invoices/$($i.Freee_Invoice_Id__c)"}
    $newPeriod=$i.ContractPeriod__c
    if(-not (IsEmpty $i.ParentContract__c)){
        $periodMismatch=(-not (IsEmpty $newPeriod)) -and $i.'ContractPeriod__r.Contract__c' -ne $i.ParentContract__c
        if((IsEmpty $newPeriod) -or $periodMismatch){
            $basis=if(-not (IsEmpty $i.TargetPeriodStartDate__c)){AsDate $i.TargetPeriodStartDate__c}else{AsDate $i.Billing_Date__c}
            if($null -ne $basis -and $periodsByContract.ContainsKey($i.ParentContract__c)){
                $matches=@($periodsByContract[$i.ParentContract__c]|Where-Object{$s=AsDate $_.PeriodStartDate__c;$e=AsDate $_.PeriodEndDate__c;$null -ne $s -and $basis -ge $s -and ($null -eq $e -or $basis -le $e)})
                if($matches.Count -eq 1){$newPeriod=$matches[0].Id}
            }
        }
    }
    if($newUrl -ne $i.Freee_Invoice_URL__c -or $newPeriod -ne $i.ContractPeriod__c){
        $invoiceUpdates.Add([pscustomobject]@{Id=$i.Id;Freee_Invoice_URL__c=$newUrl;ContractPeriod__c=$newPeriod})
        $invoiceRollback.Add([pscustomobject]@{Id=$i.Id;Freee_Invoice_URL__c=$i.Freee_Invoice_URL__c;ContractPeriod__c=$i.ContractPeriod__c})
    }
}

$monthlyUpdates=[System.Collections.Generic.List[object]]::new()
$monthlyRollback=[System.Collections.Generic.List[object]]::new()
foreach($m in $monthly){
    $newAccount=$m.Account__c; $newPeriod=$m.ContractPeriod__c; $newCYM=$m.ContractYearMonth__c; $newMonth=$m.Month__c
    $newStart=$m.PeriodStartDate__c; $newEnd=$m.PeriodEndDate__c; $newRevenue=$m.RevenueAmount__c; $newInvoice=$m.RelatedInvoice__c
    $c=$contractById[$m.MasterContract__c]
    if($null -ne $c -and -not (IsEmpty $c.Account__c) -and $newAccount -ne $c.Account__c){$newAccount=$c.Account__c}
    $start=AsDate $newStart
    if($null -ne $start){
        $ym=$start.ToString('yyyy/MM');$monthEnd=$start.AddMonths(1).AddDays(-1).ToString('yyyy-MM-dd')
        if($newCYM -ne $ym){$newCYM=$ym};if($newMonth -ne $ym){$newMonth=$ym};if($newEnd -ne $monthEnd){$newEnd=$monthEnd}
    }
    $periodMismatch=(-not (IsEmpty $newPeriod)) -and $m.'ContractPeriod__r.Contract__c' -ne $m.MasterContract__c
    if((IsEmpty $newPeriod) -or $periodMismatch){
        if($null -ne $start -and $periodsByContract.ContainsKey($m.MasterContract__c)){
            $matches=@($periodsByContract[$m.MasterContract__c]|Where-Object{$s=AsDate $_.PeriodStartDate__c;$e=AsDate $_.PeriodEndDate__c;$null -ne $s -and $start -ge $s -and ($null -eq $e -or $start -le $e)})
            if($matches.Count -eq 1){$newPeriod=$matches[0].Id}
        }
    }
    if((IsEmpty $newRevenue) -and -not (IsEmpty $m.Total__c) -and ($m.MRR_Target__c -eq 'true' -or $m.'ProductMaster__r.MRR_Target__c' -eq 'true')){$newRevenue=$m.Total__c}
    if(-not (IsEmpty $newInvoice)){
        $inv=$invoiceById[$newInvoice]
        $invalid=$null -eq $inv -or $inv.ParentContract__c -ne $m.MasterContract__c -or $inv.Account__c -ne $newAccount
        if($invalid -and $invoicesByContract.ContainsKey($m.MasterContract__c) -and $null -ne $start){
            $matches=@($invoicesByContract[$m.MasterContract__c]|Where-Object{$_.Account__c -eq $newAccount -and (AsDate $_.Billing_Date__c).ToString('yyyy/MM') -eq $start.ToString('yyyy/MM') -and $_.CancelStatus__c -eq '通常'})
            if($matches.Count -eq 1){$newInvoice=$matches[0].Id}
        }
    }
    if($newAccount -ne $m.Account__c -or $newPeriod -ne $m.ContractPeriod__c -or $newCYM -ne $m.ContractYearMonth__c -or $newMonth -ne $m.Month__c -or $newEnd -ne $m.PeriodEndDate__c -or $newRevenue -ne $m.RevenueAmount__c -or $newInvoice -ne $m.RelatedInvoice__c){
        $monthlyUpdates.Add([pscustomobject]@{Id=$m.Id;Account__c=$newAccount;ContractPeriod__c=$newPeriod;ContractYearMonth__c=$newCYM;Month__c=$newMonth;PeriodEndDate__c=$newEnd;RevenueAmount__c=$newRevenue;RelatedInvoice__c=$newInvoice})
        $monthlyRollback.Add([pscustomobject]@{Id=$m.Id;Account__c=$m.Account__c;ContractPeriod__c=$m.ContractPeriod__c;ContractYearMonth__c=$m.ContractYearMonth__c;Month__c=$m.Month__c;PeriodEndDate__c=$m.PeriodEndDate__c;RevenueAmount__c=$m.RevenueAmount__c;RelatedInvoice__c=$m.RelatedInvoice__c})
    }
}

$invoiceHeaders=@('Id','Freee_Invoice_URL__c','ContractPeriod__c')
$monthlyHeaders=@('Id','Account__c','ContractPeriod__c','ContractYearMonth__c','Month__c','PeriodEndDate__c','RevenueAmount__c','RelatedInvoice__c')
Write-NoBomCsv (Join-Path $DataDir 'invoice-safe-update.csv') $invoiceHeaders $invoiceUpdates
Write-NoBomCsv (Join-Path $DataDir 'invoice-rollback.csv') $invoiceHeaders $invoiceRollback
Write-NoBomCsv (Join-Path $DataDir 'monthly-safe-update.csv') $monthlyHeaders $monthlyUpdates
Write-NoBomCsv (Join-Path $DataDir 'monthly-rollback.csv') $monthlyHeaders $monthlyRollback
$invoiceUpdates|Export-Csv (Join-Path $DataDir 'invoice-safe-update-readable.csv') -NoTypeInformation -Encoding UTF8
$monthlyUpdates|Export-Csv (Join-Path $DataDir 'monthly-safe-update-readable.csv') -NoTypeInformation -Encoding UTF8
"invoice_updates=$($invoiceUpdates.Count) monthly_updates=$($monthlyUpdates.Count)"
"invoice_url_updates=$(@($invoiceUpdates|Where-Object{-not (IsEmpty $_.Freee_Invoice_URL__c)}).Count)"
"monthly_revenue_updates=$(@($monthlyUpdates|Where-Object{-not (IsEmpty $_.RevenueAmount__c)}).Count)"
