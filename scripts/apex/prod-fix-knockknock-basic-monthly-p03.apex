Id correctProductId = 'a0CRB0000CcXZ6i2QG';
String description = 'KnockKnockAI_Basicプラン(月額)';

ProductMaster__c correctProduct = [
    SELECT Id, Name, UnitPrice__c
    FROM ProductMaster__c
    WHERE Id = :correctProductId
];
System.assertEquals('knock knock AI Basicプラン(50クレジット)', correctProduct.Name);
System.assertEquals(11000, correctProduct.UnitPrice__c);

List<Mig_FreeeInvoiceLineWork__c> lines = [
    SELECT Id,
           InvoiceWork__c,
           InvoiceWork__r.Name,
           Description__c,
           Quantity__c,
           UnitPrice__c,
           LineAmount__c,
           TaxAmount__c,
           CreatedInvoiceLine__c,
           CreatedInvoiceLine__r.Invoice__c,
           CreatedInvoiceLine__r.Invoice__r.Sent_To_Freee__c,
           CreatedInvoiceLine__r.ProductMaster__c,
           CreatedInvoiceLine__r.Quantity__c,
           CreatedInvoiceLine__r.Unit_Price__c,
           CreatedInvoiceLine__r.TaxAmount__c,
           CreatedInvoiceLine__r.AmountWithTax__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE Description__c = :description
    ORDER BY InvoiceWork__r.Name
];
System.assertEquals(5, lines.size(), '対象明細は5件である必要があります。');

Set<Id> workIds = new Set<Id>();
List<InvoiceLine__c> invoiceLinesToUpdate = new List<InvoiceLine__c>();
Set<Id> protectedInvoiceIds = new Set<Id>();
for (Mig_FreeeInvoiceLineWork__c lineWork : lines) {
    Decimal expectedNet = lineWork.Quantity__c * correctProduct.UnitPrice__c;
    Decimal expectedGross = expectedNet + lineWork.TaxAmount__c;

    System.assertEquals(1, lineWork.Quantity__c, '数量が想定と異なります: ' + lineWork.InvoiceWork__r.Name);
    System.assertEquals(correctProduct.UnitPrice__c, lineWork.UnitPrice__c, '単価が一致しません: ' + lineWork.InvoiceWork__r.Name);
    System.assertEquals(expectedNet, lineWork.LineAmount__c, '税抜金額が一致しません: ' + lineWork.InvoiceWork__r.Name);
    System.assertEquals(1100, lineWork.TaxAmount__c, '税額が一致しません: ' + lineWork.InvoiceWork__r.Name);
    System.assertEquals(12100, expectedGross, '税込金額が一致しません: ' + lineWork.InvoiceWork__r.Name);
    System.assertNotEquals(null, lineWork.CreatedInvoiceLine__c, '作成済み請求明細がありません: ' + lineWork.InvoiceWork__r.Name);
    System.assertEquals(lineWork.Quantity__c, lineWork.CreatedInvoiceLine__r.Quantity__c, '請求明細の数量が一致しません: ' + lineWork.InvoiceWork__r.Name);
    System.assertEquals(lineWork.UnitPrice__c, lineWork.CreatedInvoiceLine__r.Unit_Price__c, '請求明細の単価が一致しません: ' + lineWork.InvoiceWork__r.Name);
    System.assertEquals(lineWork.TaxAmount__c, lineWork.CreatedInvoiceLine__r.TaxAmount__c, '請求明細の税額が一致しません: ' + lineWork.InvoiceWork__r.Name);
    System.assertEquals(expectedGross, lineWork.CreatedInvoiceLine__r.AmountWithTax__c, '請求明細の税込金額が一致しません: ' + lineWork.InvoiceWork__r.Name);

    lineWork.SuggestedProductMaster__c = correctProductId;
    lineWork.ConfirmedProductMaster__c = correctProductId;
    lineWork.ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED;
    lineWork.ResolveConfidence__c = 1;
    lineWork.ResolveMessage__c =
        '経理確認済み: 金額一致によりknock knock AI Basicプラン(50クレジット)として確定。';
    lineWork.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_IMPORTED;

    if (lineWork.CreatedInvoiceLine__r.ProductMaster__c != correctProductId) {
        System.assertEquals(
            true,
            lineWork.CreatedInvoiceLine__r.Invoice__r.Sent_To_Freee__c,
            '商品訂正対象の請求はfreee連携済みである必要があります。'
        );
        invoiceLinesToUpdate.add(new InvoiceLine__c(
            Id = lineWork.CreatedInvoiceLine__c,
            ProductMaster__c = correctProductId
        ));
        protectedInvoiceIds.add(lineWork.CreatedInvoiceLine__r.Invoice__c);
    }
    workIds.add(lineWork.InvoiceWork__c);
}
update lines;
if (!invoiceLinesToUpdate.isEmpty()) {
    List<Invoice__c> protectedInvoices = new List<Invoice__c>();
    for (Id invoiceId : protectedInvoiceIds) {
        protectedInvoices.add(new Invoice__c(
            Id = invoiceId,
            Sent_To_Freee__c = false
        ));
    }
    update protectedInvoices;
    update invoiceLinesToUpdate;
    for (Invoice__c invoiceRecord : protectedInvoices) {
        invoiceRecord.Sent_To_Freee__c = true;
    }
    update protectedInvoices;
}

List<Mig_FreeeInvoiceWork__c> works = [
    SELECT Id, Name, InvoiceAmount__c, CreatedInvoice__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :workIds
];
System.assertEquals(5, works.size(), '対象Workは5件である必要があります。');
for (Mig_FreeeInvoiceWork__c workRecord : works) {
    System.assertEquals(12100, workRecord.InvoiceAmount__c, '請求金額が一致しません: ' + workRecord.Name);
    System.assertNotEquals(null, workRecord.CreatedInvoice__c, '作成済み請求がありません: ' + workRecord.Name);
    workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_IMPORTED;
    workRecord.ValidationMessage__c = null;
}
update works;

List<Mig_FreeeInvoiceLineProductMap__c> mappings = [
    SELECT Id, ProductMaster__c, IsActive__c, Priority__c
    FROM Mig_FreeeInvoiceLineProductMap__c
    WHERE Keyword__c = :description
      AND MatchType__c = '完全一致'
];
System.assertEquals(1, mappings.size(), '完全一致マッピングは1件である必要があります。');
mappings[0].ProductMaster__c = correctProductId;
mappings[0].IsActive__c = true;
mappings[0].Priority__c = 10;
mappings[0].Memo__c =
    '2026-07-24 経理確認済み。金額一致によりknock knock AI Basicプラン(50クレジット)へ確定。';
update mappings;

System.debug(
    'KNOCKKNOCK_BASIC_MONTHLY_P03_FIXED works=' + works.size()
    + ' lines=' + lines.size()
    + ' invoiceLinesCorrected=' + invoiceLinesToUpdate.size()
);
