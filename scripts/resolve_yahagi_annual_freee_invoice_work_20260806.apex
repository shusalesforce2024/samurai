String freeeId = '39903347';
Id annualMonthlyProductId = 'a0CRB0000CcXZ6U2QW';

Mig_FreeeInvoiceWork__c workRecord = [
    SELECT Id, ImportStatus__c, ResolvedContract__c, ResolvedContractPeriod__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c = :freeeId
    LIMIT 1
];
System.assertEquals(Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW,
    workRecord.ImportStatus__c, '要確認以外のWorkです。');
System.assertNotEquals(null, workRecord.ResolvedContract__c, '契約が未解決です。');
System.assertNotEquals(null, workRecord.ResolvedContractPeriod__c, '契約期間が未解決です。');

List<Mig_FreeeInvoiceLineWork__c> lines = [
    SELECT Id, Description__c, Quantity__c, UnitPrice__c, LineAmount__c,
           SuggestedProductMaster__c, ConfirmedProductMaster__c,
           ProductResolveStatus__c, ResolveConfidence__c, ResolveMessage__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__c = :workRecord.Id
];
System.assertEquals(3, lines.size(), '請求明細Workは3件である必要があります。');
Integer primaryCount = 0;
for (Mig_FreeeInvoiceLineWork__c line : lines) {
    if (line.LineAmount__c <= 0) {
        continue;
    }
    System.assert(line.Description__c.contains('Enterprise'), '主商品名が想定外です。');
    System.assertEquals(5, line.Quantity__c, 'アカウント数が想定外です。');
    System.assertEquals(132000, line.UnitPrice__c, '値引前の年額単価が想定外です。');
    line.SuggestedProductMaster__c = annualMonthlyProductId;
    line.ConfirmedProductMaster__c = annualMonthlyProductId;
    line.ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED;
    line.ResolveConfidence__c = 1.00;
    line.ResolveMessage__c = '年額132,000円から年払い値引き12,000円を控除した月額換算10,000円が既存年払商品と一致したため確定しました。';
    primaryCount++;
}
System.assertEquals(1, primaryCount, '主商品が一意ではありません。');
update lines;

Mig_FreeeInvoiceProductResolver.resolveProducts();
Mig_FreeeInvoiceValidator.validateAll();
System.debug('RESOLVED_YAHAGI work=' + workRecord.Id);
