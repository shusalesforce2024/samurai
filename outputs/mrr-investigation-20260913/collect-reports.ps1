$ErrorActionPreference = 'Continue'
$auditDir=$PSScriptRoot
$reports=(Get-Content (Join-Path $auditDir 'reports.json') -Raw -Encoding UTF8 | ConvertFrom-Json).result.records
foreach($r in $reports | Where-Object {$_.Name -match 'MRR' -or $_.DeveloperName -eq 'ActiveContract'}) {
 $path=Join-Path $auditDir ('report-'+$r.DeveloperName+'.json')
 & sf api request rest ('/services/data/v67.0/analytics/reports/'+$r.Id+'/describe') --target-org prod --method GET --stream-to-file $path 2> (Join-Path $auditDir 'report-api.stderr.txt')
 Write-Output ($r.DeveloperName + ' exit=' + $LASTEXITCODE)
}
& sf api request rest '/services/data/v67.0/analytics/dashboards/01ZRB000005CEAo2AO' --target-org prod --method GET --stream-to-file (Join-Path $auditDir 'dashboard-live.json')
& sf api request rest '/services/data/v67.0/sobjects/ContractLineItem__c/describe' --target-org prod --method GET --stream-to-file (Join-Path $auditDir 'monthly-schema.json')
$query="SELECT Id,Name,Account__c,ProductMaster__c,AutoCreateAllowed__c,IsActive__c,Contract__c,BillingCycle__c,StartDate__c,EndDate__c FROM FreeeInvoiceContractRule__c"
$result=& sf data query --target-org prod --query $query --json
[IO.File]::WriteAllText((Join-Path $auditDir 'freee-rules.json'),($result -join "`n"),[Text.UTF8Encoding]::new($false))
