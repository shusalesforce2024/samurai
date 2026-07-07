Mig_FreeeInvoiceFetchService.runResolversAndValidation();

List<Id> readyWorkIds = new List<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c = '60861151'
      AND ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_READY
]) {
    readyWorkIds.add(workRecord.Id);
}

System.debug('readyWorkIds=' + readyWorkIds.size());
Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(readyWorkIds);
System.debug('finalize requested=' + readyWorkIds.size());
