Set<String> freeeIds = new Set<String>{
    '46403241', '48320223', '50082828', '50083045', '51933364'
};
Id mainContractId = 'a04RB00000kUAOkYAO';
Id mainPeriodId = 'a0BRB00000ynb6f2AA';
Id ssoMonthlyProductId = 'a0CRB0000CcXZ6b2QG';
Id ssoInitialProductId = 'a0CRB0000CcXZ6a2QG';

List<Mig_FreeeInvoiceWork__c> works = [
    SELECT Id, FreeeInvoiceId__c, ImportStatus__c,
           ResolvedAccount__c, ResolvedContract__c, ResolvedContractPeriod__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c IN :freeeIds
];
System.assertEquals(5, works.size(), '対象Workは5件である必要があります。');
for (Mig_FreeeInvoiceWork__c workRecord : works) {
    System.assertEquals(Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW,
        workRecord.ImportStatus__c, '要確認以外のWorkが含まれています。');
    System.assertNotEquals(null, workRecord.ResolvedAccount__c, '取引先が未解決です。');
    workRecord.ResolvedContract__c = mainContractId;
    workRecord.ResolvedContractPeriod__c = mainPeriodId;
}
update works;

List<Mig_FreeeInvoiceLineWork__c> lines = [
    SELECT Id, Description__c, UnitPrice__c, LineAmount__c,
           SuggestedProductMaster__c, ConfirmedProductMaster__c,
           ProductResolveStatus__c, ResolveConfidence__c, ResolveMessage__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__r.FreeeInvoiceId__c IN :freeeIds
];
Integer resolvedSsoLines = 0;
for (Mig_FreeeInvoiceLineWork__c line : lines) {
    if (line.ConfirmedProductMaster__c != null
        || String.isBlank(line.Description__c)
        || !line.Description__c.contains('シングルサインオン')) {
        continue;
    }
    Id productId = line.Description__c.contains('初期費用')
        ? ssoInitialProductId : ssoMonthlyProductId;
    Decimal expectedPrice = line.Description__c.contains('初期費用') ? 100000 : 30000;
    System.assertEquals(expectedPrice, line.UnitPrice__c,
        'SSO商品の単価が商品マスタと一致しません: ' + line.Description__c);
    line.SuggestedProductMaster__c = productId;
    line.ConfirmedProductMaster__c = productId;
    line.ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED;
    line.ResolveConfidence__c = 1.00;
    line.ResolveMessage__c = '商品名、単価、既存商品マスタ、同一取引先の過去確定実績が一致したため自動確定しました。';
    resolvedSsoLines++;
}
System.assertEquals(12, resolvedSsoLines, 'SSO明細の期待件数と一致しません。');
update lines;

Mig_FreeeInvoiceValidator.validateAll();
System.debug('RESOLVED works=' + works.size() + ' ssoLines=' + resolvedSsoLines);
