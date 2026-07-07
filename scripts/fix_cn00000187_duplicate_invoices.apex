Boolean dryRun = true;

Id keepInvoiceId = 'a00RB000024Ux4qYAC'; // INV-0000000045 / paid
Set<Id> duplicateInvoiceIds = new Set<Id>{
    'a00RB000024Ux4pYAC', // INV-0000000044
    'a00RB000024Ux4rYAC'  // INV-0000000046
};
Set<String> duplicateFreeeInvoiceIds = new Set<String>{
    '55195079',
    '55196219'
};

List<ContractLineItem__c> duplicateContractLines = [
    SELECT Id, Name, RelatedInvoice__c
    FROM ContractLineItem__c
    WHERE RelatedInvoice__c IN :duplicateInvoiceIds
];

List<InvoiceLine__c> duplicateInvoiceLines = [
    SELECT Id, Name, Invoice__c
    FROM InvoiceLine__c
    WHERE Invoice__c IN :duplicateInvoiceIds
];

List<Invoice__c> duplicateInvoices = [
    SELECT Id, Name, Freee_Invoice_Id__c, Freee_Invoice_Number__c
    FROM Invoice__c
    WHERE Id IN :duplicateInvoiceIds
];

List<Mig_FreeeInvoiceWork__c> duplicateWorks = [
    SELECT Id,
           Name,
           FreeeInvoiceId__c,
           CreatedInvoice__c,
           ImportStatus__c,
           ValidationMessage__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c IN :duplicateFreeeInvoiceIds
];

Set<Id> duplicateWorkIds = new Set<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : duplicateWorks) {
    duplicateWorkIds.add(workRecord.Id);
}

List<Mig_FreeeInvoiceLineWork__c> duplicateLineWorks = duplicateWorkIds.isEmpty()
    ? new List<Mig_FreeeInvoiceLineWork__c>()
    : [
        SELECT Id,
               Name,
               InvoiceWork__c,
               CreatedInvoiceLine__c,
               ResolvedContractLineItem__c,
               ImportStatus__c
        FROM Mig_FreeeInvoiceLineWork__c
        WHERE InvoiceWork__c IN :duplicateWorkIds
    ];

System.debug('dryRun=' + dryRun);
System.debug('keepInvoiceId=' + keepInvoiceId);
System.debug('duplicateInvoices=' + duplicateInvoices.size());
System.debug('duplicateInvoiceLines=' + duplicateInvoiceLines.size());
System.debug('duplicateContractLines=' + duplicateContractLines.size());
System.debug('duplicateWorks=' + duplicateWorks.size());
System.debug('duplicateLineWorks=' + duplicateLineWorks.size());

if (!dryRun) {
    Savepoint sp = Database.setSavepoint();
    try {
        for (Mig_FreeeInvoiceLineWork__c lineWork : duplicateLineWorks) {
            lineWork.CreatedInvoiceLine__c = null;
            lineWork.ResolvedContractLineItem__c = null;
            lineWork.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW;
        }
        if (!duplicateLineWorks.isEmpty()) {
            update duplicateLineWorks;
        }

        for (Mig_FreeeInvoiceWork__c workRecord : duplicateWorks) {
            workRecord.CreatedInvoice__c = null;
            workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW;
            workRecord.ValidationMessage__c = 'CN-00000187の同一月同額重複請求として整理済み。Salesforce側の重複請求・請求明細・契約月次明細は削除済み。正として保持した請求: INV-0000000045 / freee請求書ID 55195797。';
        }
        if (!duplicateWorks.isEmpty()) {
            update duplicateWorks;
        }

        if (!duplicateContractLines.isEmpty()) {
            delete duplicateContractLines;
        }
        if (!duplicateInvoiceLines.isEmpty()) {
            delete duplicateInvoiceLines;
        }
        if (!duplicateInvoices.isEmpty()) {
            delete duplicateInvoices;
        }

        System.debug('updatedLineWorks=' + duplicateLineWorks.size());
        System.debug('updatedWorks=' + duplicateWorks.size());
        System.debug('deletedContractLines=' + duplicateContractLines.size());
        System.debug('deletedInvoiceLines=' + duplicateInvoiceLines.size());
        System.debug('deletedInvoices=' + duplicateInvoices.size());
    } catch (Exception e) {
        Database.rollback(sp);
        System.debug(LoggingLevel.ERROR, e.getTypeName() + ': ' + e.getMessage() + ' line=' + e.getLineNumber());
        throw e;
    }
}
