Set<String> targetNames = new Set<String>{
    'MFIW-000021',
    'MFIW-000058',
    'MFIW-000059',
    'MFIW-000154',
    'MFIW-000373'
};

List<Mig_FreeeInvoiceWork__c> works = [
    SELECT Id,
           Name,
           RawJson__c,
           TaxAmount__c,
           CreatedInvoice__c,
           (SELECT Id,
                   FreeeLineId__c,
                   LineAmount__c,
                   TaxAmount__c
            FROM InvoiceLineWorks__r
            ORDER BY FreeeLineId__c)
    FROM Mig_FreeeInvoiceWork__c
    WHERE Name IN :targetNames
    ORDER BY Name
];
System.assertEquals(5, works.size(), 'A01対象Workは5件である必要があります。');

Set<Id> invoiceIds = new Set<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : works) {
    if (workRecord.CreatedInvoice__c != null) {
        invoiceIds.add(workRecord.CreatedInvoice__c);
    }
}
Map<String, InvoiceLine__c> invoiceLineByKey = new Map<String, InvoiceLine__c>();
for (InvoiceLine__c invoiceLine : [
    SELECT Id, Invoice__c, Freee_Line_Id__c
    FROM InvoiceLine__c
    WHERE Invoice__c IN :invoiceIds
]) {
    invoiceLineByKey.put(
        String.valueOf(invoiceLine.Invoice__c) + ':' + invoiceLine.Freee_Line_Id__c,
        invoiceLine
    );
}
Map<Id, Invoice__c> invoiceById = new Map<Id, Invoice__c>([
    SELECT Id, Sent_To_Freee__c
    FROM Invoice__c
    WHERE Id IN :invoiceIds
]);
Map<Id, Boolean> originalSentByInvoiceId = new Map<Id, Boolean>();
for (Invoice__c invoiceRecord : invoiceById.values()) {
    originalSentByInvoiceId.put(invoiceRecord.Id, invoiceRecord.Sent_To_Freee__c);
    invoiceRecord.Sent_To_Freee__c = false;
}
if (!invoiceById.isEmpty()) {
    update invoiceById.values();
}

List<Mig_FreeeInvoiceLineWork__c> lineWorkUpdates = new List<Mig_FreeeInvoiceLineWork__c>();
List<InvoiceLine__c> invoiceLineUpdates = new List<InvoiceLine__c>();
List<Invoice__c> invoiceUpdates = new List<Invoice__c>();
for (Mig_FreeeInvoiceWork__c workRecord : works) {
    Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(workRecord.RawJson__c);
    Decimal expectedTax = raw.get('amount_tax') == null
        ? workRecord.TaxAmount__c
        : Decimal.valueOf(String.valueOf(raw.get('amount_tax')));
    Decimal currentTax = 0;
    for (Mig_FreeeInvoiceLineWork__c lineWork : workRecord.InvoiceLineWorks__r) {
        currentTax += lineWork.TaxAmount__c == null ? 0 : lineWork.TaxAmount__c;
    }
    Decimal difference = expectedTax - currentTax;
    if (difference != 0 && !workRecord.InvoiceLineWorks__r.isEmpty()) {
        Mig_FreeeInvoiceLineWork__c lastLine =
            workRecord.InvoiceLineWorks__r[workRecord.InvoiceLineWorks__r.size() - 1];
        Decimal grossAmount =
            (lastLine.LineAmount__c == null ? 0 : lastLine.LineAmount__c)
            + (lastLine.TaxAmount__c == null ? 0 : lastLine.TaxAmount__c);
        lineWorkUpdates.add(new Mig_FreeeInvoiceLineWork__c(
            Id = lastLine.Id,
            LineAmount__c = lastLine.LineAmount__c - difference,
            TaxAmount__c = lastLine.TaxAmount__c + difference
        ));
        InvoiceLine__c existingLine = invoiceLineByKey.get(
            String.valueOf(workRecord.CreatedInvoice__c) + ':' + lastLine.FreeeLineId__c
        );
        if (existingLine != null) {
            invoiceLineUpdates.add(new InvoiceLine__c(
                Id = existingLine.Id,
                TaxAmount__c = lastLine.TaxAmount__c + difference,
                AmountWithTax__c = grossAmount
            ));
        }
    }
    workRecord.TaxAmount__c = expectedTax;
    if (workRecord.CreatedInvoice__c != null) {
        invoiceUpdates.add(new Invoice__c(
            Id = workRecord.CreatedInvoice__c,
            TaxAmount__c = expectedTax
        ));
    }
}

if (!lineWorkUpdates.isEmpty()) {
    update lineWorkUpdates;
}
if (!invoiceLineUpdates.isEmpty()) {
    update invoiceLineUpdates;
}
if (!invoiceUpdates.isEmpty()) {
    update invoiceUpdates;
}
update works;

List<Invoice__c> restoreInvoices = new List<Invoice__c>();
for (Id invoiceId : originalSentByInvoiceId.keySet()) {
    restoreInvoices.add(new Invoice__c(
        Id = invoiceId,
        Sent_To_Freee__c = originalSentByInvoiceId.get(invoiceId)
    ));
}
if (!restoreInvoices.isEmpty()) {
    update restoreInvoices;
}
System.debug(
    'A01_TAX_RECONCILED lineWorks=' + lineWorkUpdates.size()
    + ' invoiceLines=' + invoiceLineUpdates.size()
);
