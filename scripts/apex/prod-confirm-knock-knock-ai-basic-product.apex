String description = 'knock knock AI Basicプラン';
String productName = 'knock knock AI Basicプラン(50クレジット)';

List<ProductMaster__c> products = [
    SELECT Id, Name
    FROM ProductMaster__c
    WHERE Name = :productName
];
System.assertEquals(1, products.size(), '対象商品マスタが一意に特定できません。');
Id productId = products[0].Id;

List<Mig_FreeeInvoiceLineWork__c> targetLines = [
    SELECT Id,
           InvoiceWork__c,
           ConfirmedProductMaster__c,
           CreatedInvoiceLine__c,
           InvoiceWork__r.ImportStatus__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE Description__c = :description
      AND InvoiceWork__r.ImportStatus__c = '要確認'
];
System.assertEquals(8, targetLines.size(), '事前確認時から対象明細件数が変わっています。');

Set<Id> targetWorkIds = new Set<Id>();
Integer protectedInvoiceLineCount = 0;
for (Mig_FreeeInvoiceLineWork__c line : targetLines) {
    targetWorkIds.add(line.InvoiceWork__c);
    line.SuggestedProductMaster__c = productId;
    line.ConfirmedProductMaster__c = productId;
    line.ProductResolveStatus__c = '確定済み';
    line.ResolveConfidence__c = 1;
    line.ResolveMessage__c =
        '経理確認済み: knock knock AI Basicプラン(50クレジット)として確定。';
    if (line.CreatedInvoiceLine__c != null) {
        protectedInvoiceLineCount++;
    }
}
update targetLines;

List<Mig_FreeeInvoiceLineProductMap__c> mappings = [
    SELECT Id,
           Name,
           ProductMaster__c,
           MatchType__c,
           Priority__c,
           IsActive__c,
           Memo__c
    FROM Mig_FreeeInvoiceLineProductMap__c
    WHERE Keyword__c = :description
];
System.assert(mappings.size() <= 1, '同じキーワードの商品マッピングが複数存在します。');
Mig_FreeeInvoiceLineProductMap__c mapping;
if (mappings.isEmpty()) {
    mapping = new Mig_FreeeInvoiceLineProductMap__c(
        Name = 'knock knock AI Basicプラン',
        Keyword__c = description
    );
} else {
    mapping = mappings[0];
}
mapping.ProductMaster__c = productId;
mapping.MatchType__c = '部分一致';
mapping.Priority__c = 10;
mapping.IsActive__c = true;
mapping.Memo__c = '2026-07-24 経理確認済み。50クレジット商品へ変換する。';
upsert mapping;

Mig_FreeeInvoiceValidator.validateAll();

List<Id> readyTargetWorkIds = new List<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id, ImportStatus__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :targetWorkIds
]) {
    if (workRecord.ImportStatus__c == '反映可能') {
        readyTargetWorkIds.add(workRecord.Id);
    }
}
Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(readyTargetWorkIds);

System.debug(LoggingLevel.ERROR,
    'confirmedLines=' + targetLines.size()
    + ', protectedInvoiceLines=' + protectedInvoiceLineCount
    + ', targetWorks=' + targetWorkIds.size()
    + ', finalizedWorks=' + readyTargetWorkIds.size()
    + ', mappingId=' + mapping.Id
);
