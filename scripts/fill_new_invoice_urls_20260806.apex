Set<Id> targetIds = new Set<Id>{
    'a00RB00002DFRNdYAP','a00RB00002DFRNeYAP','a00RB00002DFRNfYAP','a00RB00002DFRNgYAP',
    'a00RB00002DFRNhYAP','a00RB00002DFRNiYAP','a00RB00002DFRNjYAP','a00RB00002DHAs5YAH'
};
List<Invoice__c> updates = new List<Invoice__c>();
for (Invoice__c invoiceRecord : [
    SELECT Id, Freee_Invoice_Id__c, Freee_Invoice_URL__c
    FROM Invoice__c
    WHERE Id IN :targetIds
]) {
    if (invoiceRecord.Freee_Invoice_Id__c != null && String.isBlank(invoiceRecord.Freee_Invoice_URL__c)) {
        invoiceRecord.Freee_Invoice_URL__c = 'https://invoice.secure.freee.co.jp/reports/invoices/' +
            String.valueOf(invoiceRecord.Freee_Invoice_Id__c).substringBefore('.');
        updates.add(invoiceRecord);
    }
}
System.assertEquals(8, updates.size(), 'URL補完対象件数が変わりました');
update updates;
System.debug(LoggingLevel.ERROR, 'UPDATED_URLS=' + updates.size());
