List<Mig_FreeeInvoiceWork__c> targetWorks = [
    SELECT Id, Name, InvoiceAmount__c, TaxAmount__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = '要確認'
];

Set<Id> workIds = new Set<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : targetWorks) {
    workIds.add(workRecord.Id);
}

Map<Id, Decimal> amountWithTaxByWorkId = new Map<Id, Decimal>();
Map<Id, Decimal> taxByWorkId = new Map<Id, Decimal>();
for (Mig_FreeeInvoiceLineWork__c lineWork : [
    SELECT InvoiceWork__c, LineAmount__c, TaxAmount__c, ImportStatus__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__c IN :workIds
      AND ImportStatus__c != '対象外'
]) {
    Decimal lineAmount = lineWork.LineAmount__c == null ? 0 : lineWork.LineAmount__c;
    Decimal taxAmount = lineWork.TaxAmount__c == null ? 0 : lineWork.TaxAmount__c;
    Decimal currentAmount = amountWithTaxByWorkId.containsKey(lineWork.InvoiceWork__c)
        ? amountWithTaxByWorkId.get(lineWork.InvoiceWork__c)
        : 0;
    Decimal currentTax = taxByWorkId.containsKey(lineWork.InvoiceWork__c)
        ? taxByWorkId.get(lineWork.InvoiceWork__c)
        : 0;
    amountWithTaxByWorkId.put(lineWork.InvoiceWork__c, currentAmount + lineAmount + taxAmount);
    taxByWorkId.put(lineWork.InvoiceWork__c, currentTax + taxAmount);
}

List<Mig_FreeeInvoiceWork__c> updates = new List<Mig_FreeeInvoiceWork__c>();
for (Mig_FreeeInvoiceWork__c workRecord : targetWorks) {
    if (!amountWithTaxByWorkId.containsKey(workRecord.Id)) {
        continue;
    }
    updates.add(new Mig_FreeeInvoiceWork__c(
        Id = workRecord.Id,
        InvoiceAmount__c = amountWithTaxByWorkId.get(workRecord.Id),
        TaxAmount__c = taxByWorkId.get(workRecord.Id)
    ));
}

if (!updates.isEmpty()) {
    update updates;
}

Mig_FreeeInvoiceValidator.validateAll();
System.debug('MIG_FREEE_FIXED_AMOUNT_MISMATCH_WORKS=' + updates.size());
