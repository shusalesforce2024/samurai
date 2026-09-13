$ErrorActionPreference='Continue'
foreach($entry in @(@('rendery-current','00ORB000015Wx6P2AS'),@('rendery-total','00ORB00000zE2tM2AS'),@('active-contracts','00ORB000014wi2f2AA'))) {
 & sf api request rest ('/services/data/v67.0/analytics/reports/'+$entry[1]+'?includeDetails=true') --target-org prod --method GET --stream-to-file (Join-Path $PSScriptRoot ('run-'+$entry[0]+'.json'))
}
$queries=[ordered]@{
 'schedule'="SELECT Id,CronJobDetail.Name,CronExpression,State,PreviousFireTime,NextFireTime FROM CronTrigger"
 'batch-jobs'="SELECT Id,ApexClass.Name,JobType,Status,CreatedDate,CompletedDate,NumberOfErrors,ExtendedStatus FROM AsyncApexJob WHERE ApexClass.Name IN ('ContractMonthlyLineBatch','ContractRenewalInvoiceBatch') AND CreatedDate = LAST_N_DAYS:45 ORDER BY CreatedDate DESC"
}
foreach($entry in $queries.GetEnumerator()) {
 $result=& sf data query --target-org prod --query $entry.Value --json
 [IO.File]::WriteAllText((Join-Path $PSScriptRoot ($entry.Key+'.json')),($result -join "`n"),[Text.UTF8Encoding]::new($false))
}
