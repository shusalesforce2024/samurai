Mig_FreeeInvoiceWork__c workRecord = [
    SELECT Id, ImportStatus__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c = '64761112'
    LIMIT 1
];
System.assertEquals(Mig_FreeeInvoiceWorkService.STATUS_READY,
    workRecord.ImportStatus__c, '反映可能ではありません。');
Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(new List<Id>{ workRecord.Id });
System.debug('FINALIZED_COSMOS work=' + workRecord.Id);
