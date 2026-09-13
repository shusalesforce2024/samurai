List<Mig_FreeeInvoiceLineWork__c> lineUpdates = new List<Mig_FreeeInvoiceLineWork__c>{
    new Mig_FreeeInvoiceLineWork__c(
        Id = 'a0ERB00000Pk8Qp2AJ',
        ConfirmedProductMaster__c = 'a0CRB0000CcXZ6Q2QW',
        ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED
    ),
    new Mig_FreeeInvoiceLineWork__c(
        Id = 'a0ERB00000Pk8aY2AR',
        ConfirmedProductMaster__c = 'a0CRB0000CcXZ6Q2QW',
        ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED
    ),
    new Mig_FreeeInvoiceLineWork__c(
        Id = 'a0ERB00000Pk8k92AB',
        ConfirmedProductMaster__c = 'a0CRB0000CcXZ6V2QW',
        ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED
    )
};
update lineUpdates;

Mig_FreeeInvoiceValidator.validateAll();

Set<Id> allowedWorkIds = new Set<Id>{
    'a0FRB00000aE0GN2A0',
    'a0FRB00000aCDG82AO',
    'a0FRB00000aDzP82AK'
};
List<Id> readyWorkIds = new List<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id, Name, ImportStatus__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :allowedWorkIds
    ORDER BY Name
]) {
    if (workRecord.ImportStatus__c == Mig_FreeeInvoiceWorkService.STATUS_READY) {
        readyWorkIds.add(workRecord.Id);
    }
}

System.debug(LoggingLevel.ERROR,
    'READY allowed=' + allowedWorkIds.size() + ', ready=' + readyWorkIds.size()
);
if (!readyWorkIds.isEmpty()) {
    Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(readyWorkIds);
}
System.debug(LoggingLevel.ERROR, 'FINALIZE requested=' + readyWorkIds.size());
