Id productId = 'a0CRB0000CcXZ6T2QW';
Set<String> workNames = new Set<String>{
    'MFIW-000186',
    'MFIW-000191',
    'MFIW-000192',
    'MFIW-000201'
};

ProductMaster__c productRecord = [
    SELECT Id, Name, UnitPrice__c
    FROM ProductMaster__c
    WHERE Id = :productId
];
System.assertEquals('[OLD] Rendery Enterpriseプラン(2025年9月まで)', productRecord.Name);
System.assertEquals(11000, productRecord.UnitPrice__c);

List<Mig_FreeeInvoiceLineWork__c> lines = [
    SELECT Id,
           InvoiceWork__c,
           Description__c,
           Quantity__c,
           UnitPrice__c,
           LineAmount__c,
           TaxAmount__c,
           ConfirmedProductMaster__c,
           CreatedInvoiceLine__c,
           CreatedInvoiceLine__r.ProductMaster__c,
           CreatedInvoiceLine__r.Quantity__c,
           CreatedInvoiceLine__r.Unit_Price__c,
           CreatedInvoiceLine__r.TaxAmount__c,
           CreatedInvoiceLine__r.AmountWithTax__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__r.Name IN :workNames
];
System.assertEquals(4, lines.size(), '対象明細は4件である必要があります。');

Set<Id> workIds = new Set<Id>();
Set<String> descriptions = new Set<String>();
for (Mig_FreeeInvoiceLineWork__c lineWork : lines) {
    Decimal expectedAmountWithTax =
        (lineWork.LineAmount__c == null ? 0 : lineWork.LineAmount__c)
        + (lineWork.TaxAmount__c == null ? 0 : lineWork.TaxAmount__c);
    System.assertEquals(productRecord.UnitPrice__c, lineWork.UnitPrice__c, '商品単価が一致しません。');
    System.assertNotEquals(null, lineWork.CreatedInvoiceLine__c, '作成済み請求明細がありません。');
    System.assertEquals(productId, lineWork.CreatedInvoiceLine__r.ProductMaster__c, '既存請求明細の商品が一致しません。');
    System.assertEquals(lineWork.Quantity__c, lineWork.CreatedInvoiceLine__r.Quantity__c, '数量が一致しません。');
    System.assertEquals(lineWork.UnitPrice__c, lineWork.CreatedInvoiceLine__r.Unit_Price__c, '請求明細単価が一致しません。');
    System.assertEquals(lineWork.TaxAmount__c, lineWork.CreatedInvoiceLine__r.TaxAmount__c, '税額が一致しません。');
    System.assertEquals(expectedAmountWithTax, lineWork.CreatedInvoiceLine__r.AmountWithTax__c, '税込金額が一致しません。');

    lineWork.SuggestedProductMaster__c = productId;
    lineWork.ConfirmedProductMaster__c = productId;
    lineWork.ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED;
    lineWork.ResolveConfidence__c = 1;
    lineWork.ResolveMessage__c =
        '経理確認済み: 単価・数量・税額・税込金額が一致するためOLD Rendery Enterprise商品として確定。';
    lineWork.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_IMPORTED;
    workIds.add(lineWork.InvoiceWork__c);
    descriptions.add(lineWork.Description__c);
}
update lines;

List<Mig_FreeeInvoiceWork__c> works = [
    SELECT Id, InvoiceAmount__c, CreatedInvoice__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :workIds
];
System.assertEquals(4, works.size(), '対象Workは4件である必要があります。');
for (Mig_FreeeInvoiceWork__c workRecord : works) {
    System.assertNotEquals(null, workRecord.CreatedInvoice__c, '作成済み請求がありません。');
    workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_IMPORTED;
    workRecord.ValidationMessage__c = null;
}
update works;

Map<String, Mig_FreeeInvoiceLineProductMap__c> mappingByKeyword =
    new Map<String, Mig_FreeeInvoiceLineProductMap__c>();
for (Mig_FreeeInvoiceLineProductMap__c mapping : [
    SELECT Id, Keyword__c
    FROM Mig_FreeeInvoiceLineProductMap__c
    WHERE Keyword__c IN :descriptions
      AND MatchType__c = '完全一致'
]) {
    System.assert(!mappingByKeyword.containsKey(mapping.Keyword__c), '完全一致マッピングが重複しています。');
    mappingByKeyword.put(mapping.Keyword__c, mapping);
}
List<Mig_FreeeInvoiceLineProductMap__c> mappingsToUpsert =
    new List<Mig_FreeeInvoiceLineProductMap__c>();
for (String description : descriptions) {
    Mig_FreeeInvoiceLineProductMap__c mapping = mappingByKeyword.get(description);
    if (mapping == null) {
        mapping = new Mig_FreeeInvoiceLineProductMap__c(
            Name = description,
            Keyword__c = description,
            MatchType__c = '完全一致'
        );
    }
    mapping.ProductMaster__c = productId;
    mapping.Priority__c = 10;
    mapping.IsActive__c = true;
    mapping.Memo__c = '2026-07-24 経理確認済み。金額一致によりOLD Rendery Enterprise商品へ確定。';
    mappingsToUpsert.add(mapping);
}
upsert mappingsToUpsert;

System.debug(
    'RENDERY_OLD_P03_CONFIRMED works=' + works.size()
    + ' lines=' + lines.size()
    + ' mappings=' + mappingsToUpsert.size()
);
