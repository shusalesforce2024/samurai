String description = 'knock knock AI_Basicプラン(月額)';
Set<Id> targetWorkIds = new Set<Id>();
for (Mig_FreeeInvoiceLineWork__c line : [
    SELECT InvoiceWork__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE Description__c = :description
      AND InvoiceWork__r.ImportStatus__c = '要確認'
]) {
    targetWorkIds.add(line.InvoiceWork__c);
}
System.assertEquals(24, targetWorkIds.size(), '事前確認時から対象Work件数が変わっています。');

List<Mig_FreeeInvoiceWork__c> works = [
    SELECT Id,
           FreeeInvoiceId__c,
           ExternalKey__c,
           InvoiceAmount__c,
           ResolvedAccount__c,
           ResolvedContract__c,
           ResolvedContractPeriod__c,
           ImportStatus__c,
           ValidationMessage__c,
           (SELECT Id,
                   ConfirmedProductMaster__c,
                   ImportStatus__c,
                   LineAmount__c,
                   TaxAmount__c
            FROM InvoiceLineWorks__r)
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :targetWorkIds
];

List<Mig_FreeeInvoiceWork__c> readyWorks = new List<Mig_FreeeInvoiceWork__c>();
for (Mig_FreeeInvoiceWork__c workRecord : works) {
    Boolean valid = !String.isBlank(workRecord.FreeeInvoiceId__c)
        && !String.isBlank(workRecord.ExternalKey__c)
        && workRecord.ResolvedAccount__c != null
        && workRecord.ResolvedContract__c != null
        && workRecord.ResolvedContractPeriod__c != null
        && workRecord.InvoiceLineWorks__r != null
        && !workRecord.InvoiceLineWorks__r.isEmpty();
    Decimal lineTotal = 0;
    if (valid) {
        for (Mig_FreeeInvoiceLineWork__c line : workRecord.InvoiceLineWorks__r) {
            if (line.ImportStatus__c == '対象外') {
                continue;
            }
            if (line.ConfirmedProductMaster__c == null) {
                valid = false;
                break;
            }
            lineTotal += line.LineAmount__c == null ? 0 : line.LineAmount__c;
            lineTotal += line.TaxAmount__c == null ? 0 : line.TaxAmount__c;
        }
    }
    if (valid
        && workRecord.InvoiceAmount__c != null
        && Math.abs(workRecord.InvoiceAmount__c - lineTotal) > 1
    ) {
        valid = false;
    }
    if (valid) {
        workRecord.ImportStatus__c = '反映可能';
        workRecord.ValidationMessage__c = null;
        readyWorks.add(workRecord);
    }
}
System.assertEquals(21, readyWorks.size(), '反映可能と判定された対象件数が想定と異なります。');
update readyWorks;

Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(
    new List<Id>(new Map<Id, Mig_FreeeInvoiceWork__c>(readyWorks).keySet())
);

System.debug(LoggingLevel.ERROR,
    'targetWorks=' + works.size() + ', readyWorks=' + readyWorks.size()
);
