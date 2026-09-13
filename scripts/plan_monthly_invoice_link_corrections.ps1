param([string]$DataDir = 'outputs/data-integrity-postfix-20260806')
$monthly=@(Import-Csv (Join-Path $DataDir 'monthly-links-latest.csv'))
$invoices=@(Import-Csv (Join-Path $DataDir 'invoices.csv')|Where-Object CancelStatus__c -eq '通常')
$byKey=@{}
foreach($invoice in $invoices|Where-Object{-not[string]::IsNullOrWhiteSpace($_.ParentContract__c)-and-not[string]::IsNullOrWhiteSpace($_.Billing_Date__c)}){
    $ym=$invoice.Billing_Date__c.Substring(0,7).Replace('-','/')
    $key="$($invoice.ParentContract__c)|$($invoice.Account__c)|$ym"
    if(-not $byKey.ContainsKey($key)){$byKey[$key]=@()}
    $byKey[$key]+=$invoice
}
$targets=@()
foreach($line in $monthly|Where-Object{$_.'MasterContract__r.ContractUpdate__c'-eq'月'-and-not[string]::IsNullOrWhiteSpace($_.RelatedInvoice__c)}){
    try{
        $start=[datetime]::ParseExact($line.PeriodStartDate__c,'yyyy-MM-dd',$null)
        $billing=[datetime]::ParseExact($line.'RelatedInvoice__r.Billing_Date__c','yyyy-MM-dd',$null)
    }catch{continue}
    $diff=[math]::Abs((($billing.Year-$start.Year)*12)+$billing.Month-$start.Month)
    if($diff-le1){continue}
    $key="$($line.MasterContract__c)|$($line.Account__c)|$($line.Month__c)"
    $matches=@(if($byKey.ContainsKey($key)){$byKey[$key]}else{@()})
    $newInvoice=if($matches.Count-eq1){$matches[0].Id}else{''}
    $targets += [pscustomobject]@{
        Id=$line.Id;Name=$line.Name;Contract=$line.MasterContract__c;Account=$line.Account__c;Month=$line.Month__c
        OldInvoice=$line.RelatedInvoice__c;OldBilling=$line.'RelatedInvoice__r.Billing_Date__c'
        NewInvoice=$newInvoice;CandidateCount=$matches.Count
    }
}
$targets|Export-Csv (Join-Path $DataDir 'monthly-distant-invoice-backup-and-plan.csv') -NoTypeInformation -Encoding UTF8
"targets=$($targets.Count) replace=$(@($targets|Where-Object{-not[string]::IsNullOrWhiteSpace($_.NewInvoice)}).Count) clear=$(@($targets|Where-Object{[string]::IsNullOrWhiteSpace($_.NewInvoice)}).Count) ambiguous=$(@($targets|Where-Object{$_.CandidateCount-gt1}).Count)"
$targets|Group-Object CandidateCount|Sort-Object Name|Format-Table Count,Name
