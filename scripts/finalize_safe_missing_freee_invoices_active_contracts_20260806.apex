Set<String> freeeIds = new Set<String>{
    '32399726', '34243674', '34244031', '34244651', '34244944',
    '36227949', '36228085', '36233282', '36235097', '38258922',
    '38259355', '39572257', '39800926', '39800958', '39859160',
    '51206325', '51933366'
};
List<Id> workIds = new List<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id, ImportStatus__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c IN :freeeIds
]) {
    System.assertEquals(
        Mig_FreeeInvoiceWorkService.STATUS_READY,
        workRecord.ImportStatus__c,
        '反映可能でないWorkが含まれています: ' + workRecord.Id
    );
    workIds.add(workRecord.Id);
}
System.assertEquals(freeeIds.size(), workIds.size(), '対象Work件数が一致しません。');
Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(workIds);
System.debug('FINALIZED count=' + workIds.size());
