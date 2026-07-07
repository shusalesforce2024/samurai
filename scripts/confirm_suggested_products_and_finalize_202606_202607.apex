List<Mig_FreeeInvoiceLineWork__c> lineUpdates = new List<Mig_FreeeInvoiceLineWork__c>();
for (Mig_FreeeInvoiceLineWork__c lineWork : [
    SELECT Id,
           SuggestedProductMaster__c,
           ConfirmedProductMaster__c,
           ProductResolveStatus__c,
           InvoiceWork__r.BillingDate__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__r.BillingDate__c >= 2026-06-01
      AND InvoiceWork__r.BillingDate__c <= 2026-07-31
      AND ConfirmedProductMaster__c = null
      AND SuggestedProductMaster__c != null
      AND ProductResolveStatus__c = '候補あり'
]) {
    lineUpdates.add(new Mig_FreeeInvoiceLineWork__c(
        Id = lineWork.Id,
        ConfirmedProductMaster__c = lineWork.SuggestedProductMaster__c,
        ProductResolveStatus__c = '確定済み'
    ));
}

System.debug('confirm line count=' + lineUpdates.size());
if (!lineUpdates.isEmpty()) {
    update lineUpdates;
}

Mig_FreeeInvoiceValidator.validateAll();

List<Id> readyWorkIds = new List<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id
    FROM Mig_FreeeInvoiceWork__c
    WHERE BillingDate__c >= 2026-06-01
      AND BillingDate__c <= 2026-07-31
      AND ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_READY
    ORDER BY BillingDate__c ASC, CreatedDate ASC
]) {
    readyWorkIds.add(workRecord.Id);
}

System.debug('ready after confirm=' + readyWorkIds.size());
Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(readyWorkIds);
System.debug('finalize requested=' + readyWorkIds.size());
