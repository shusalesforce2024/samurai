Mig_FreeeInvoiceFetchService.runResolversAndValidation();

List<Id> readyWorkIds = new List<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id
    FROM Mig_FreeeInvoiceWork__c
    WHERE BillingDate__c >= 2026-06-01
      AND BillingDate__c <= 2026-07-31
      AND ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_READY
    ORDER BY BillingDate__c ASC, CreatedDate ASC
    LIMIT 5000
]) {
    readyWorkIds.add(workRecord.Id);
}

System.debug('readyWorkIds=' + readyWorkIds.size());
Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(readyWorkIds);
System.debug('finalize requested=' + readyWorkIds.size());
