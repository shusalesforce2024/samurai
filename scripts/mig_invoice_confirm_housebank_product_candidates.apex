Id contractId = 'a04RB00000kUAPiYAO';

List<Mig_FreeeInvoiceLineWork__c> linesToUpdate = new List<Mig_FreeeInvoiceLineWork__c>();
for (Mig_FreeeInvoiceLineWork__c lineRecord : [
    SELECT Id,
           SuggestedProductMaster__c,
           ConfirmedProductMaster__c,
           ProductResolveStatus__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__r.ResolvedContract__c = :contractId
      AND ConfirmedProductMaster__c = null
      AND SuggestedProductMaster__c != null
      AND ProductResolveStatus__c = '候補あり'
]) {
    linesToUpdate.add(new Mig_FreeeInvoiceLineWork__c(
        Id = lineRecord.Id,
        ConfirmedProductMaster__c = lineRecord.SuggestedProductMaster__c,
        ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED
    ));
}

if (!linesToUpdate.isEmpty()) {
    update linesToUpdate;
}

Mig_FreeeInvoiceValidator.validateAll();
System.debug(LoggingLevel.INFO, 'confirmed product candidates=' + linesToUpdate.size());
