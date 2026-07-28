Set<String> workNames = new Set<String>{
    'MFIW-000126', 'MFIW-000174', 'MFIW-000206', 'MFIW-000211',
    'MFIW-000230', 'MFIW-000259', 'MFIW-000260', 'MFIW-000264',
    'MFIW-000268', 'MFIW-000275', 'MFIW-000277', 'MFIW-000280',
    'MFIW-000292', 'MFIW-000296', 'MFIW-000327', 'MFIW-000329',
    'MFIW-000330', 'MFIW-000359', 'MFIW-000388', 'MFIW-000410',
    'MFIW-000414', 'MFIW-000422'
};
List<Id> workIds = new List<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id, Name, ImportStatus__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE Name IN :workNames
]) {
    System.assertEquals('反映可能', workRecord.ImportStatus__c,
        workRecord.Name + ' は反映可能ではありません。');
    workIds.add(workRecord.Id);
}
System.assertEquals(22, workIds.size(), '反映対象Workが22件揃っていません。');

Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(workIds);

Integer importedCount = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :workIds
      AND ImportStatus__c = '反映済み'
      AND CreatedInvoice__c != null
];
System.assertEquals(22, importedCount, '22件すべてを反映済みにできませんでした。');
System.debug(LoggingLevel.ERROR, 'GOOGLE_SHEET_NOTES_FINALIZED imported=' + importedCount);
