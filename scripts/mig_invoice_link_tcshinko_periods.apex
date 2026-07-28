Map<String, Id> periodIdByInvoiceId = new Map<String, Id>{
    '58573600' => 'a0BRB0000124lpt2AA',
    '60861151' => 'a0BRB0000124lpu2AA'
};

List<Mig_FreeeInvoiceWork__c> worksToUpdate = new List<Mig_FreeeInvoiceWork__c>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id, FreeeInvoiceId__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c IN :periodIdByInvoiceId.keySet()
]) {
    worksToUpdate.add(new Mig_FreeeInvoiceWork__c(
        Id = workRecord.Id,
        ResolvedContractPeriod__c = periodIdByInvoiceId.get(workRecord.FreeeInvoiceId__c)
    ));
}
if (!worksToUpdate.isEmpty()) {
    update worksToUpdate;
}

List<Mig_FreeeInvoiceLineWork__c> linesToUpdate = new List<Mig_FreeeInvoiceLineWork__c>();
for (Mig_FreeeInvoiceLineWork__c lineRecord : [
    SELECT Id, ConfirmedProductMaster__c, ProductResolveStatus__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__r.FreeeInvoiceId__c IN :periodIdByInvoiceId.keySet()
      AND ConfirmedProductMaster__c != null
      AND ProductResolveStatus__c != :Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED
]) {
    linesToUpdate.add(new Mig_FreeeInvoiceLineWork__c(
        Id = lineRecord.Id,
        ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED
    ));
}
if (!linesToUpdate.isEmpty()) {
    update linesToUpdate;
}

Mig_FreeeInvoiceValidator.validateAll();
System.debug(LoggingLevel.INFO, 'linked works=' + worksToUpdate.size() + ', fixed lines=' + linesToUpdate.size());
