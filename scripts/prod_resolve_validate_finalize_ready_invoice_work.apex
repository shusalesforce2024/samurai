Integer readyBefore = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_READY
];
Integer importedBefore = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_IMPORTED
];
Integer reviewBefore = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW
];

Mig_FreeeInvoiceFetchService.runResolversAndValidation();

Integer readyAfterValidation = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_READY
];

Mig_FreeeInvoiceFinalizeService.finalizeAllReady();

Integer readyAfter = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_READY
];
Integer importedAfter = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_IMPORTED
];
Integer reviewAfter = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW
];

System.debug(
    'SUMMARY readyBefore=' + readyBefore +
    ', readyAfterValidation=' + readyAfterValidation +
    ', readyAfter=' + readyAfter +
    ', importedBefore=' + importedBefore +
    ', importedAfter=' + importedAfter +
    ', reviewBefore=' + reviewBefore +
    ', reviewAfter=' + reviewAfter +
    ', finalizedDelta=' + (importedAfter - importedBefore)
);
