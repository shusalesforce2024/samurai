param([string]$DataDir='outputs/data-integrity-progress-20260806')
$periods=@(Import-Csv (Join-Path $DataDir 'periods-missing-end.csv'))
$updates=@()
foreach($period in $periods){
    if([string]::IsNullOrWhiteSpace($period.PeriodStartDate__c)){continue}
    $start=[datetime]::ParseExact($period.PeriodStartDate__c,'yyyy-MM-dd',$null)
    $end=if($period.'Contract__r.ContractUpdate__c'-eq'月'){$start.AddMonths(1).AddDays(-1)}elseif($period.'Contract__r.ContractUpdate__c'-eq'年'){$start.AddYears(1).AddDays(-1)}else{$null}
    if($null-ne$end){$updates += [pscustomobject]@{Id=$period.Id;PeriodEndDate__c=$end.ToString('yyyy-MM-dd')}}
}
$writer=[IO.StreamWriter]::new((Join-Path $DataDir 'period-end-safe-update.csv'),$false,[Text.UTF8Encoding]::new($false))
try{$writer.WriteLine('Id,PeriodEndDate__c');foreach($row in $updates){$writer.WriteLine("$($row.Id),$($row.PeriodEndDate__c)")}}finally{$writer.Dispose()}
$updates|Export-Csv (Join-Path $DataDir 'period-end-update-readable.csv') -NoTypeInformation -Encoding UTF8
"updates=$($updates.Count) monthly=$(@($periods|Where-Object{$_.'Contract__r.ContractUpdate__c'-eq'月'}).Count) annual=$(@($periods|Where-Object{$_.'Contract__r.ContractUpdate__c'-eq'年'}).Count)"
