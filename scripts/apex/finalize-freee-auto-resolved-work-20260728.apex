List<Id> targetWorkIds = new List<Id>{
    'a0FRB00000WihDQ2AZ',
    'a0FRB00000WihDV2AZ',
    'a0FRB00000WjSKT2A3',
    'a0FRB00000Wjfvr2AB',
    'a0FRB00000YqSO82AN'
};

Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(targetWorkIds);

List<Mig_FreeeInvoiceWork__c> results = [
    SELECT Id,
           Name,
           FreeeInvoiceId__c,
           InvoiceAmount__c,
           ImportStatus__c,
           CreatedInvoice__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :targetWorkIds
    ORDER BY Name
];
System.debug(LoggingLevel.ERROR, 'FREEE_FINALIZE_RESULTS=' + JSON.serialize(results));
