List<Mig_FreeeInvoiceWork__c> readyWorks = [
    SELECT Id,
           Name,
           FreeeInvoiceId__c,
           ExternalKey__c,
           ResolvedAccount__c,
           ResolvedContract__c,
           ResolvedContractPeriod__c,
           CreatedInvoice__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_READY
    ORDER BY BillingDate__c, CreatedDate
    LIMIT 5000
];

System.assert(!readyWorks.isEmpty(), '反映可能な請求Workがありません。');

Set<Id> readyWorkIds = new Map<Id, Mig_FreeeInvoiceWork__c>(readyWorks).keySet();
Set<String> freeeInvoiceIds = new Set<String>();
Integer readyWithExistingInvoice = 0;
for (Mig_FreeeInvoiceWork__c workRecord : readyWorks) {
    System.assertNotEquals(null, workRecord.FreeeInvoiceId__c, workRecord.Name + ': freee請求書IDがありません。');
    System.assertNotEquals(null, workRecord.ExternalKey__c, workRecord.Name + ': 外部キーがありません。');
    System.assertNotEquals(null, workRecord.ResolvedAccount__c, workRecord.Name + ': 取引先が未解決です。');
    System.assertNotEquals(null, workRecord.ResolvedContract__c, workRecord.Name + ': 契約管理が未解決です。');
    System.assertNotEquals(null, workRecord.ResolvedContractPeriod__c, workRecord.Name + ': 契約期間が未解決です。');
    System.assert(!freeeInvoiceIds.contains(workRecord.FreeeInvoiceId__c),
        workRecord.Name + ': 反映可能Work内でfreee請求書IDが重複しています。');
    freeeInvoiceIds.add(workRecord.FreeeInvoiceId__c);
    if (workRecord.CreatedInvoice__c != null) {
        readyWithExistingInvoice++;
    }
}

Integer readyLineCount = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__c IN :readyWorkIds
      AND ImportStatus__c != :Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED
];
Integer unresolvedProductLineCount = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__c IN :readyWorkIds
      AND ImportStatus__c != :Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED
      AND ConfirmedProductMaster__c = null
];
System.assertEquals(0, unresolvedProductLineCount, '商品未確定の請求明細Workがあります。');
System.assert(readyLineCount > 0, '反映対象の請求明細Workがありません。');

Integer importedBefore = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_IMPORTED
];
Integer reviewBefore = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW
];

Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(new List<Id>(readyWorkIds));

Integer readyAfter = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :readyWorkIds
      AND ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_READY
];
Integer importedTargetAfter = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :readyWorkIds
      AND ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_IMPORTED
];
Integer reviewTargetAfter = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :readyWorkIds
      AND ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW
];
Integer importedBeforeTarget = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :readyWorkIds
      AND ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_IMPORTED
];

System.assertEquals(0, readyAfter, '処理後も反映可能のまま残るWorkがあります。');
System.assertEquals(readyWorks.size(), importedTargetAfter + reviewTargetAfter,
    '対象Workの処理結果件数が一致しません。');

System.debug(
    'FINALIZE_SUMMARY'
    + ' requested=' + readyWorks.size()
    + ', newInvoiceTargets=' + (readyWorks.size() - readyWithExistingInvoice)
    + ', existingInvoiceTargets=' + readyWithExistingInvoice
    + ', lineTargets=' + readyLineCount
    + ', imported=' + importedTargetAfter
    + ', needsReview=' + reviewTargetAfter
    + ', importedOrgBefore=' + importedBefore
    + ', reviewOrgBefore=' + reviewBefore
);
