Set<String> directWorkNames = new Set<String>{
    'MFIW-000022',
    'MFIW-000056',
    'MFIW-000087',
    'MFIW-000090',
    'MFIW-000116',
    'MFIW-000158',
    'MFIW-000166',
    'MFIW-000170',
    'MFIW-000171',
    'MFIW-000175',
    'MFIW-000176',
    'MFIW-000177',
    'MFIW-000193',
    'MFIW-000194',
    'MFIW-000195',
    'MFIW-000202',
    'MFIW-000213'
};
Set<String> newInvoiceWorkNames = new Set<String>{
    'MFIW-000173',
    'MFIW-000189'
};
Set<String> basicWorkNames = new Set<String>{
    'MFIW-000158',
    'MFIW-000166',
    'MFIW-000170',
    'MFIW-000171',
    'MFIW-000173',
    'MFIW-000175',
    'MFIW-000176',
    'MFIW-000177',
    'MFIW-000193',
    'MFIW-000194',
    'MFIW-000195'
};

List<ProductMaster__c> basicProducts = [
    SELECT Id, Name
    FROM ProductMaster__c
    WHERE Name = 'knock knock AI Basicプラン(50クレジット)'
    LIMIT 2
];
System.assertEquals(1, basicProducts.size(), 'Basicプランの商品マスタを一意に特定できません。');
Id basicProductId = basicProducts[0].Id;

Set<String> allTargetNames = new Set<String>();
allTargetNames.addAll(directWorkNames);
allTargetNames.addAll(newInvoiceWorkNames);
List<Mig_FreeeInvoiceWork__c> targetWorks = [
    SELECT Id,
           Name,
           FreeeInvoiceId__c,
           CreatedInvoice__c,
           ImportStatus__c,
           ValidationMessage__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE Name IN :allTargetNames
    FOR UPDATE
];
System.assertEquals(allTargetNames.size(), targetWorks.size(), '対象Workをすべて取得できません。');

Map<Id, Mig_FreeeInvoiceWork__c> workById = new Map<Id, Mig_FreeeInvoiceWork__c>(targetWorks);
Map<String, Mig_FreeeInvoiceWork__c> workByName = new Map<String, Mig_FreeeInvoiceWork__c>();
Set<Id> targetWorkIds = new Set<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : targetWorks) {
    System.assertEquals(Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW, workRecord.ImportStatus__c,
        workRecord.Name + ': 現在のステータスが要確認ではありません。');
    workByName.put(workRecord.Name, workRecord);
    targetWorkIds.add(workRecord.Id);
    if (directWorkNames.contains(workRecord.Name)) {
        System.assertNotEquals(null, workRecord.CreatedInvoice__c,
            workRecord.Name + ': 既存請求が紐づいていません。');
    }
}

List<Mig_FreeeInvoiceLineWork__c> targetLineWorks = [
    SELECT Id,
           InvoiceWork__c,
           Description__c,
           Quantity__c,
           LineAmount__c,
           TaxAmount__c,
           SuggestedProductMaster__c,
           ConfirmedProductMaster__c,
           CreatedInvoiceLine__c,
           ImportStatus__c,
           ResolveMessage__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__c IN :targetWorkIds
      AND ImportStatus__c != :Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED
    FOR UPDATE
];
System.assert(!targetLineWorks.isEmpty(), '対象の請求明細Workがありません。');

Set<Id> existingInvoiceLineIds = new Set<Id>();
for (Mig_FreeeInvoiceLineWork__c lineWork : targetLineWorks) {
    Mig_FreeeInvoiceWork__c workRecord = workById.get(lineWork.InvoiceWork__c);
    if (directWorkNames.contains(workRecord.Name)) {
        System.assertNotEquals(null, lineWork.CreatedInvoiceLine__c,
            workRecord.Name + ': 既存請求明細へのリンクがありません。');
        existingInvoiceLineIds.add(lineWork.CreatedInvoiceLine__c);
    }
}

Map<Id, InvoiceLine__c> invoiceLineById = new Map<Id, InvoiceLine__c>([
    SELECT Id,
           Invoice__c,
           ProductMaster__c,
           Quantity__c,
           AmountWithTax__c
    FROM InvoiceLine__c
    WHERE Id IN :existingInvoiceLineIds
    FOR UPDATE
]);
System.assertEquals(existingInvoiceLineIds.size(), invoiceLineById.size(),
    'リンク済みの既存請求明細をすべて取得できません。');

Map<Id, InvoiceLine__c> invoiceLineUpdatesById = new Map<Id, InvoiceLine__c>();
for (Mig_FreeeInvoiceLineWork__c lineWork : targetLineWorks) {
    Mig_FreeeInvoiceWork__c workRecord = workById.get(lineWork.InvoiceWork__c);

    if (basicWorkNames.contains(workRecord.Name)) {
        lineWork.SuggestedProductMaster__c = basicProductId;
        lineWork.ConfirmedProductMaster__c = basicProductId;
        lineWork.ResolveMessage__c = '経理確認済み: knock knock AI Basicプラン(50クレジット)として確定。';
        if (lineWork.CreatedInvoiceLine__c != null) {
            InvoiceLine__c linkedLine = invoiceLineById.get(lineWork.CreatedInvoiceLine__c);
            linkedLine.ProductMaster__c = basicProductId;
            invoiceLineUpdatesById.put(linkedLine.Id, linkedLine);
        }
    } else if (workRecord.Name == 'MFIW-000189') {
        lineWork.ResolveMessage__c = '経理確認済み: Rendery Enterprise旧プラン商品として確定。';
    } else if (workRecord.Name == 'MFIW-000202') {
        lineWork.ResolveMessage__c = '既存請求明細と商品・数量・税込金額が一致したため確定。';
    } else if (workRecord.Name == 'MFIW-000213' && lineWork.CreatedInvoiceLine__c != null) {
        InvoiceLine__c linkedLine = invoiceLineById.get(lineWork.CreatedInvoiceLine__c);
        linkedLine.ProductMaster__c = lineWork.ConfirmedProductMaster__c;
        invoiceLineUpdatesById.put(linkedLine.Id, linkedLine);
    }
}

Map<Id, Boolean> originalSentToFreeeByInvoiceId = new Map<Id, Boolean>();
List<Invoice__c> invoicesToUnlock = new List<Invoice__c>();
if (!invoiceLineUpdatesById.isEmpty()) {
    Set<Id> invoiceIdsToUnlock = new Set<Id>();
    for (InvoiceLine__c lineRecord : invoiceLineUpdatesById.values()) {
        invoiceIdsToUnlock.add(lineRecord.Invoice__c);
    }
    for (Invoice__c invoiceRecord : [
        SELECT Id, Sent_To_Freee__c
        FROM Invoice__c
        WHERE Id IN :invoiceIdsToUnlock
        FOR UPDATE
    ]) {
        originalSentToFreeeByInvoiceId.put(invoiceRecord.Id, invoiceRecord.Sent_To_Freee__c);
        if (invoiceRecord.Sent_To_Freee__c == true) {
            invoiceRecord.Sent_To_Freee__c = false;
            invoicesToUnlock.add(invoiceRecord);
        }
    }
    if (!invoicesToUnlock.isEmpty()) {
        update invoicesToUnlock;
    }
    update invoiceLineUpdatesById.values();

    List<Invoice__c> invoicesToRestore = new List<Invoice__c>();
    for (Id invoiceId : originalSentToFreeeByInvoiceId.keySet()) {
        if (originalSentToFreeeByInvoiceId.get(invoiceId) == true) {
            invoicesToRestore.add(new Invoice__c(
                Id = invoiceId,
                Sent_To_Freee__c = true
            ));
        }
    }
    if (!invoicesToRestore.isEmpty()) {
        update invoicesToRestore;
    }
}
update targetLineWorks;

List<Mig_FreeeInvoiceLineWork__c> directLineWorkUpdates = new List<Mig_FreeeInvoiceLineWork__c>();
List<Mig_FreeeInvoiceWork__c> directWorkUpdates = new List<Mig_FreeeInvoiceWork__c>();
for (Mig_FreeeInvoiceLineWork__c lineWork : targetLineWorks) {
    Mig_FreeeInvoiceWork__c workRecord = workById.get(lineWork.InvoiceWork__c);
    if (!directWorkNames.contains(workRecord.Name)) {
        continue;
    }

    InvoiceLine__c linkedLine = invoiceLineById.get(lineWork.CreatedInvoiceLine__c);
    Decimal expectedQuantity = lineWork.Quantity__c == null || lineWork.Quantity__c == 0
        ? 1
        : lineWork.Quantity__c;
    Decimal expectedAmountWithTax = lineWork.LineAmount__c == null
        ? null
        : lineWork.LineAmount__c + (lineWork.TaxAmount__c == null ? 0 : lineWork.TaxAmount__c);

    System.assertEquals(workRecord.CreatedInvoice__c, linkedLine.Invoice__c,
        workRecord.Name + ': 既存請求明細が別の請求に紐づいています。');
    System.assertEquals(lineWork.ConfirmedProductMaster__c, linkedLine.ProductMaster__c,
        workRecord.Name + ': 商品マスタが一致しません。');
    System.assertEquals(expectedQuantity.setScale(2), linkedLine.Quantity__c.setScale(2),
        workRecord.Name + ': 数量が一致しません。');
    if (expectedAmountWithTax == null) {
        System.assertEquals(null, linkedLine.AmountWithTax__c,
            workRecord.Name + ': 税込金額が一致しません。');
    } else {
        System.assertNotEquals(null, linkedLine.AmountWithTax__c,
            workRecord.Name + ': 既存請求明細の税込金額がありません。');
        System.assertEquals(expectedAmountWithTax.setScale(2), linkedLine.AmountWithTax__c.setScale(2),
            workRecord.Name + ': 税込金額が一致しません。');
    }

    lineWork.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_IMPORTED;
    directLineWorkUpdates.add(lineWork);
}
for (String workName : directWorkNames) {
    Mig_FreeeInvoiceWork__c workRecord = workByName.get(workName);
    workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_IMPORTED;
    workRecord.ValidationMessage__c = null;
    directWorkUpdates.add(workRecord);
}
update directLineWorkUpdates;
update directWorkUpdates;

List<Id> newInvoiceWorkIds = new List<Id>();
Set<Decimal> newInvoiceFreeeIds = new Set<Decimal>();
for (String workName : newInvoiceWorkNames) {
    Mig_FreeeInvoiceWork__c workRecord = workByName.get(workName);
    newInvoiceWorkIds.add(workRecord.Id);
    newInvoiceFreeeIds.add(Mig_FreeeInvoiceWorkService.toDecimal(workRecord.FreeeInvoiceId__c));
    workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_READY;
    workRecord.ValidationMessage__c = null;
}
System.assertEquals(0, [
    SELECT COUNT()
    FROM Invoice__c
    WHERE Freee_Invoice_Id__c IN :newInvoiceFreeeIds
], '新規作成対象と同じfreee請求書IDの請求が既に存在します。');
update new List<Mig_FreeeInvoiceWork__c>{
    workByName.get('MFIW-000173'),
    workByName.get('MFIW-000189')
};

Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(newInvoiceWorkIds);

List<Mig_FreeeInvoiceWork__c> results = [
    SELECT Id, Name, ImportStatus__c, CreatedInvoice__c, ValidationMessage__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :targetWorkIds
];
Integer importedCount = 0;
for (Mig_FreeeInvoiceWork__c result : results) {
    System.assertEquals(Mig_FreeeInvoiceWorkService.STATUS_IMPORTED, result.ImportStatus__c,
        result.Name + ': 反映済みになりませんでした。' + result.ValidationMessage__c);
    System.assertNotEquals(null, result.CreatedInvoice__c,
        result.Name + ': 請求が紐づいていません。');
    importedCount++;
}

System.debug(
    'FOLLOWUP_SUMMARY'
    + ' imported=' + importedCount
    + ', directExisting=' + directWorkNames.size()
    + ', newInvoices=' + newInvoiceWorkNames.size()
    + ', correctedInvoiceLines=' + invoiceLineUpdatesById.size()
);
