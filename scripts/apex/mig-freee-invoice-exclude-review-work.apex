List<Mig_FreeeInvoiceWork__c> reviewWorks = [
    SELECT Id
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW
];

Set<Id> reviewWorkIds = new Set<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : reviewWorks) {
    reviewWorkIds.add(workRecord.Id);
    workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED;
}

List<Mig_FreeeInvoiceLineWork__c> reviewLines = new List<Mig_FreeeInvoiceLineWork__c>();
if (!reviewWorkIds.isEmpty()) {
    for (Mig_FreeeInvoiceLineWork__c lineWork : [
        SELECT Id
        FROM Mig_FreeeInvoiceLineWork__c
        WHERE InvoiceWork__c IN :reviewWorkIds
    ]) {
        lineWork.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED;
        lineWork.ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_EXCLUDED;
        reviewLines.add(lineWork);
    }
}

Set<Id> excludedWorkIds = new Set<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED
]) {
    excludedWorkIds.add(workRecord.Id);
}
if (!excludedWorkIds.isEmpty()) {
    for (Mig_FreeeInvoiceLineWork__c lineWork : [
        SELECT Id
        FROM Mig_FreeeInvoiceLineWork__c
        WHERE InvoiceWork__c IN :excludedWorkIds
          AND (
              ImportStatus__c != :Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED
              OR ProductResolveStatus__c != :Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_EXCLUDED
          )
    ]) {
        lineWork.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED;
        lineWork.ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_EXCLUDED;
        reviewLines.add(lineWork);
    }
}

if (!reviewLines.isEmpty()) {
    update reviewLines;
}
if (!reviewWorks.isEmpty()) {
    update reviewWorks;
}

System.debug('MIG_FREEE_EXCLUDED_REVIEW_WORKS=' + reviewWorks.size());
System.debug('MIG_FREEE_EXCLUDED_REVIEW_LINES=' + reviewLines.size());
