$ErrorActionPreference = 'Continue'
$auditDir = $PSScriptRoot
$queries = [ordered]@{
 'contracts' = "SELECT Id,Name,ContractName__c,Account__c,Account__r.Name,Status__c,MRR__c,StartDate__c,EndDate__c,ContractUpdate__c,ProductCategory__c,Oppotunity__c,SourceQuotation__c,AutoCreatedFromFreee__c,CreationSource__c,BillingControlSource__c,RenewalStop__c,PreviousContract__c,CreatedDate,LastModifiedDate FROM Contract__c"
 'monthly' = "SELECT Id,Name,Account__c,MasterContract__c,ContractPeriod__c,ContractYearMonth__c,Month__c,PeriodStartDate__c,PeriodEndDate__c,ProductMaster__c,QuotationLine__c,RelatedInvoice__c,RevenueAmount__c,Total__c,MRR_Target__c,InitialFee__c,PeopleNumber__c,CreatedDate,LastModifiedDate FROM ContractLineItem__c"
 'periods' = "SELECT Id,Name,Contract__c,PeriodStartDate__c,PeriodEndDate__c,RelatedInvoice__c,CreatedDate FROM ContractPeriod__c"
 'invoices' = "SELECT Id,Name,Account__c,ParentContract__c,ContractPeriod__c,Billing_Date__c,TargetPeriodStartDate__c,TargetPeriodEndDate__c,TotalAmount__c,AmountWithTax__c,CancelStatus__c,Freee_Invoice_Id__c,CreatedDate FROM Invoice__c"
 'invoice-lines' = "SELECT Id,Name,Invoice__c,ProductMaster__c,Description__c,Quantity__c,Line_Amount__c,Freee_Line_Id__c,CreatedDate FROM InvoiceLine__c"
 'opportunities' = "SELECT Id,Name,Account__c,MRR__c,StageName__c,ContractUpdate__c,ProductCategory__c,StartDate__c,CreatedDate,LastModifiedDate FROM Opportunity__c"
 'quotations' = "SELECT Id,Name,Oppotunity__c,Quotation_Status__c,TotalAmount__c,CreatedDate,LastModifiedDate FROM Quotation__c"
 'quotation-lines' = "SELECT Id,Name,Quotation__c,ProductMaster__c,Quantity__c,Line_Amount__c,Unit_Price__c,CreatedDate,LastModifiedDate FROM QuotationLine__c"
 'products' = "SELECT Id,Name,MRR_Target__c,ProductType__c,BillingTiming__c,AnnualMonthlyPrice__c FROM ProductMaster__c"
 'reports' = "SELECT Id,Name,DeveloperName,FolderName FROM Report"
 'dashboards' = "SELECT Id,Title,DeveloperName,FolderName FROM Dashboard"
}
foreach ($entry in $queries.GetEnumerator()) {
 $queryPath = Join-Path $auditDir ($entry.Key + '.soql')
 [IO.File]::WriteAllText($queryPath, $entry.Value, [Text.UTF8Encoding]::new($false))
 $result = & sf data query --target-org prod --query $entry.Value --json 2> (Join-Path $auditDir ($entry.Key + '.stderr.txt'))
 $code = $LASTEXITCODE
 [IO.File]::WriteAllText((Join-Path $auditDir ($entry.Key + '.json')), ($result -join "`n"), [Text.UTF8Encoding]::new($false))
 if ($code -ne 0) { Write-Output ($entry.Key + ': FAILED'); continue }
 $parsed = ($result -join "`n") | ConvertFrom-Json
 Write-Output ($entry.Key + ': ' + $parsed.result.totalSize + ' records, done=' + $parsed.result.done)
}
$apexQuery = "SELECT Id,Name,Body,LastModifiedDate FROM ApexClass WHERE Name IN ('OpportunityMrrSyncService','OppContractInvoiceService','ContractMonthlyLineBatch','ContractRenewalInvoiceBatch','FreeeInvoiceContractProvisioningService','Mig_FreeeInvoiceFinalizeService','ContractLineItemPeriodService')"
$result = & sf data query --target-org prod --use-tooling-api --query $apexQuery --json 2> (Join-Path $auditDir 'apex.stderr.txt')
[IO.File]::WriteAllText((Join-Path $auditDir 'apex.json'), ($result -join "`n"), [Text.UTF8Encoding]::new($false))
Write-Output ('apex exit=' + $LASTEXITCODE)
$triggerQuery = "SELECT Id,Name,Body,Status FROM ApexTrigger WHERE TableEnumOrId IN ('Quotation__c','QuotationLine__c','Opportunity__c','Contract__c','ContractLineItem__c')"
$result = & sf data query --target-org prod --use-tooling-api --query $triggerQuery --json 2> (Join-Path $auditDir 'triggers.stderr.txt')
[IO.File]::WriteAllText((Join-Path $auditDir 'triggers.json'), ($result -join "`n"), [Text.UTF8Encoding]::new($false))
Write-Output ('triggers exit=' + $LASTEXITCODE)
