List<Mig_FreeeInvoiceLineWork__c> lineUpdates = new List<Mig_FreeeInvoiceLineWork__c>();
for (Mig_FreeeInvoiceLineWork__c lineWork : [
    SELECT Id,
           SuggestedProductMaster__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__r.FreeeInvoiceId__c = '60861151'
      AND ConfirmedProductMaster__c = null
      AND SuggestedProductMaster__c != null
]) {
    lineUpdates.add(new Mig_FreeeInvoiceLineWork__c(
        Id = lineWork.Id,
        ConfirmedProductMaster__c = lineWork.SuggestedProductMaster__c,
        ProductResolveStatus__c = '確定済み'
    ));
}
System.debug('lineUpdates=' + lineUpdates.size());
if (!lineUpdates.isEmpty()) {
    update lineUpdates;
}

Mig_FreeeInvoiceValidator.validateAll();

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
