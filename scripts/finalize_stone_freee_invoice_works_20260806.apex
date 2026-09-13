Set<String> freeeIds = new Set<String>{
    '46403241', '48320223', '50082828', '50083045', '51933364'
};
List<Id> workIds = new List<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id, ImportStatus__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c IN :freeeIds
]) {
    System.assertEquals(Mig_FreeeInvoiceWorkService.STATUS_READY,
        workRecord.ImportStatus__c, '反映可能でないWorkが含まれています。');
    workIds.add(workRecord.Id);
}
System.assertEquals(5, workIds.size(), '対象Work件数が一致しません。');
Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(workIds);
System.debug('FINALIZED_STONE count=' + workIds.size());
