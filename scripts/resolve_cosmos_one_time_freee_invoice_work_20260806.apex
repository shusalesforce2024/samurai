String freeeId = '64761112';
Id accountId = '001RB00001VTqgBYAT';
String productName = '二次審査資料作成業務';
String subjectKeyword = 'グッドデザイン賞応募にあたる審査資料作成業務（二次審査分）';

List<ProductMaster__c> existingProducts = [
    SELECT Id FROM ProductMaster__c WHERE Name = :productName
];
System.assert(existingProducts.size() <= 1, '同名商品が複数存在します。');
ProductMaster__c productRecord;
if (existingProducts.isEmpty()) {
    productRecord = new ProductMaster__c(
        Name = productName,
        UnitPrice__c = 500000,
        BillingTiming__c = '初回のみ',
        ProductType__c = '初期費用',
        MRR_Target__c = false,
        ARR_Target__c = false
    );
    insert productRecord;
} else {
    productRecord = existingProducts[0];
}

List<FreeeInvoiceContractRule__c> existingRules = [
    SELECT Id
    FROM FreeeInvoiceContractRule__c
    WHERE Account__c = :accountId
      AND SubjectKeyword__c = :subjectKeyword
];
System.assert(existingRules.size() <= 1, '同じ単発請求ルールが複数存在します。');
if (existingRules.isEmpty()) {
    insert new FreeeInvoiceContractRule__c(
        Account__c = accountId,
        AutoCreateAllowed__c = true,
        BillingCycle__c = 'OneTime',
        ContractName__c = '株式会社コスモスイニシア 二次審査資料作成業務 単発契約',
        IsActive__c = true,
        ProductMaster__c = productRecord.Id,
        SubjectKeyword__c = subjectKeyword
    );
}

Mig_FreeeInvoiceWork__c workRecord = [
    SELECT Id, ImportStatus__c, ResolvedAccount__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c = :freeeId
    LIMIT 1
];
System.assertEquals(Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW,
    workRecord.ImportStatus__c, '要確認以外のWorkです。');
System.assertEquals(accountId, workRecord.ResolvedAccount__c, '取引先が一致しません。');

List<Mig_FreeeInvoiceLineWork__c> lines = [
    SELECT Id, Description__c, Quantity__c, UnitPrice__c, LineAmount__c,
           SuggestedProductMaster__c, ConfirmedProductMaster__c,
           ProductResolveStatus__c, ResolveConfidence__c, ResolveMessage__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__c = :workRecord.Id
];
System.assertEquals(1, lines.size(), '請求明細Workは1件である必要があります。');
Mig_FreeeInvoiceLineWork__c line = lines[0];
System.assert(line.Description__c.contains('二次審査資料'), '明細名が想定外です。');
System.assertEquals(1, line.Quantity__c, '数量が想定外です。');
System.assertEquals(500000, line.UnitPrice__c, '単価が想定外です。');
System.assertEquals(500000, line.LineAmount__c, '明細金額が想定外です。');
line.SuggestedProductMaster__c = productRecord.Id;
line.ConfirmedProductMaster__c = productRecord.Id;
line.ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED;
line.ResolveConfidence__c = 1.00;
line.ResolveMessage__c = '請求件名、明細名、単価が一致するMRR/ARR対象外の単発商品として確定しました。';
update line;

Mig_FreeeInvoiceValidator.validateAll();
System.debug('RESOLVED_COSMOS work=' + workRecord.Id + ' product=' + productRecord.Id);
