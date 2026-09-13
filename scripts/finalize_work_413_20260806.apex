Id workId = 'a0FRB00000YqK412AF';
Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(new List<Id>{ workId });
Mig_FreeeInvoiceWork__c result = [
    SELECT ImportStatus__c, CreatedInvoice__c, ValidationMessage__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id = :workId
];
System.debug(LoggingLevel.ERROR, 'WORK_413_RESULT=' + JSON.serialize(result));
