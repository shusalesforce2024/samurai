Set<String> targetNames = new Set<String>{
    'MFIW-000021',
    'MFIW-000058',
    'MFIW-000059',
    'MFIW-000154',
    'MFIW-000373'
};
Set<String> importedNames = new Set<String>{'MFIW-000021', 'MFIW-000058'};
Set<String> excludedNames = new Set<String>{'MFIW-000059'};

List<Mig_FreeeInvoiceWork__c> works = [
    SELECT Id,
           Name,
           InvoiceAmount__c,
           CreatedInvoice__c,
           ImportStatus__c,
           ValidationMessage__c,
           ResolvedContract__c,
           ResolvedContractPeriod__c,
           (SELECT Id,
                   FreeeLineId__c,
                   LineAmount__c,
                   TaxRate__c,
                   TaxAmount__c,
                   ConfirmedProductMaster__c,
                   ImportStatus__c,
                   CreatedInvoiceLine__c
            FROM InvoiceLineWorks__r)
    FROM Mig_FreeeInvoiceWork__c
    WHERE Name IN :targetNames
    ORDER BY Name
];
System.assertEquals(5, works.size(), 'A01対象Workは5件である必要があります。');

Set<Id> invoiceIds = new Set<Id>();
Set<String> freeeLineIds = new Set<String>();
for (Mig_FreeeInvoiceWork__c workRecord : works) {
    if (workRecord.CreatedInvoice__c != null) {
        invoiceIds.add(workRecord.CreatedInvoice__c);
    }
    for (Mig_FreeeInvoiceLineWork__c lineWork : workRecord.InvoiceLineWorks__r) {
        if (!String.isBlank(lineWork.FreeeLineId__c)) {
            freeeLineIds.add(lineWork.FreeeLineId__c);
        }
    }
}

Map<Id, Invoice__c> invoiceById = new Map<Id, Invoice__c>([
    SELECT Id, Sent_To_Freee__c
    FROM Invoice__c
    WHERE Id IN :invoiceIds
]);
Map<String, InvoiceLine__c> invoiceLineByFreeeLineId = new Map<String, InvoiceLine__c>();
for (InvoiceLine__c invoiceLine : [
    SELECT Id, Invoice__c, Freee_Line_Id__c
    FROM InvoiceLine__c
    WHERE Invoice__c IN :invoiceIds
      AND Freee_Line_Id__c IN :freeeLineIds
]) {
    invoiceLineByFreeeLineId.put(invoiceLine.Freee_Line_Id__c, invoiceLine);
}

List<Mig_FreeeInvoiceLineWork__c> lineWorkUpdates = new List<Mig_FreeeInvoiceLineWork__c>();
List<InvoiceLine__c> invoiceLineUpdates = new List<InvoiceLine__c>();
List<Invoice__c> invoiceUpdates = new List<Invoice__c>();
Map<Id, Boolean> originalSentToFreeeByInvoiceId = new Map<Id, Boolean>();

for (Mig_FreeeInvoiceWork__c workRecord : works) {
    Decimal invoiceTax = 0;
    for (Mig_FreeeInvoiceLineWork__c lineWork : workRecord.InvoiceLineWorks__r) {
        Decimal amountIncludingTax = lineWork.LineAmount__c == null ? 0 : lineWork.LineAmount__c;
        Decimal taxRate = lineWork.TaxRate__c == null ? 0 : lineWork.TaxRate__c;
        Decimal taxAmount = taxRate == 0
            ? 0
            : (amountIncludingTax * taxRate / (100 + taxRate)).setScale(0, System.RoundingMode.DOWN);
        Decimal amountExcludingTax = amountIncludingTax - taxAmount;
        invoiceTax += taxAmount;

        lineWorkUpdates.add(new Mig_FreeeInvoiceLineWork__c(
            Id = lineWork.Id,
            LineAmount__c = amountExcludingTax,
            TaxAmount__c = taxAmount,
            ImportStatus__c = importedNames.contains(workRecord.Name)
                ? Mig_FreeeInvoiceWorkService.STATUS_IMPORTED
                : (excludedNames.contains(workRecord.Name)
                    ? Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED
                    : lineWork.ImportStatus__c)
        ));

        InvoiceLine__c existingLine = invoiceLineByFreeeLineId.get(lineWork.FreeeLineId__c);
        if (existingLine != null && importedNames.contains(workRecord.Name)) {
            invoiceLineUpdates.add(new InvoiceLine__c(
                Id = existingLine.Id,
                TaxAmount__c = taxAmount,
                AmountWithTax__c = amountIncludingTax
            ));
        }
    }

    workRecord.TaxAmount__c = invoiceTax;
    if (importedNames.contains(workRecord.Name)) {
        System.assertNotEquals(null, workRecord.CreatedInvoice__c, workRecord.Name + 'に作成済み請求が必要です。');
        workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_IMPORTED;
        workRecord.ValidationMessage__c = null;
        invoiceUpdates.add(new Invoice__c(
            Id = workRecord.CreatedInvoice__c,
            InvoiceAmount__c = workRecord.InvoiceAmount__c,
            TaxAmount__c = invoiceTax,
            AmountWithTax__c = workRecord.InvoiceAmount__c
        ));
    } else if (excludedNames.contains(workRecord.Name)) {
        System.assertEquals(null, workRecord.CreatedInvoice__c, '重複候補から請求を新規作成しないでください。');
        workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED;
        workRecord.ValidationMessage__c =
            '同一取引先・同一請求日・同額の反映済み請求が存在するため、重複候補として対象外にしました。';
    } else if (workRecord.Name == 'MFIW-000154') {
        workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW;
        workRecord.ValidationMessage__c =
            '商品マスタが未確定の請求明細Workがあります。候補商品を確認し、商品マスタを確定してください。';
    } else if (workRecord.Name == 'MFIW-000373') {
        workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW;
        workRecord.ValidationMessage__c =
            '契約管理を特定できません。取引先に有効な契約管理があるか確認してください。\n'
            + '契約期間を特定できません。請求日を含む契約期間があるか確認してください。\n'
            + '商品マスタが未確定の請求明細Workがあります。候補商品を確認し、商品マスタを確定してください。';
    }
}

for (Invoice__c invoiceRecord : invoiceById.values()) {
    originalSentToFreeeByInvoiceId.put(invoiceRecord.Id, invoiceRecord.Sent_To_Freee__c);
    if (invoiceRecord.Sent_To_Freee__c) {
        invoiceRecord.Sent_To_Freee__c = false;
    }
}
if (!invoiceById.isEmpty()) {
    update invoiceById.values();
}
update lineWorkUpdates;
if (!invoiceLineUpdates.isEmpty()) {
    update invoiceLineUpdates;
}
if (!invoiceUpdates.isEmpty()) {
    update invoiceUpdates;
}
update works;

List<Invoice__c> restoreInvoices = new List<Invoice__c>();
for (Id invoiceId : originalSentToFreeeByInvoiceId.keySet()) {
    restoreInvoices.add(new Invoice__c(
        Id = invoiceId,
        Sent_To_Freee__c = originalSentToFreeeByInvoiceId.get(invoiceId)
    ));
}
if (!restoreInvoices.isEmpty()) {
    update restoreInvoices;
}

System.debug(
    'A01_RESOLVED works=' + works.size()
    + ' lineWorks=' + lineWorkUpdates.size()
    + ' invoices=' + invoiceUpdates.size()
    + ' invoiceLines=' + invoiceLineUpdates.size()
);
