List<Mig_FreeeInvoiceLineWork__c> lines = [
    SELECT Id
    FROM Mig_FreeeInvoiceLineWork__c
];
if (!lines.isEmpty()) {
    delete lines;
}

List<Mig_FreeeInvoiceWork__c> works = [
    SELECT Id
    FROM Mig_FreeeInvoiceWork__c
];
if (!works.isEmpty()) {
    delete works;
}

System.debug('MIG_FREEE_CLEANUP_DELETED_WORKS=' + works.size());
System.debug('MIG_FREEE_CLEANUP_DELETED_LINES=' + lines.size());
