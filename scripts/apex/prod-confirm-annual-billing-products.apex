Id enterpriseAnnualProductId = 'a0CRB0000CcXZ6Z2QW';
Id resellerProAnnualProductId = 'a0CRB0000CcXZ6S2QW';

Map<Id, Id> productByLineId = new Map<Id, Id>{
    'a0ERB00000Ok1g22AB' => enterpriseAnnualProductId,
    'a0ERB00000Ok1gJ2AR' => enterpriseAnnualProductId,
    'a0ERB00000Ok1gN2AR' => enterpriseAnnualProductId,
    'a0ERB00000Ok1gP2AR' => enterpriseAnnualProductId,
    'a0ERB00000OjwWm2AJ' => enterpriseAnnualProductId,
    'a0ERB00000Ojni12AB' => enterpriseAnnualProductId,
    'a0ERB00000Ojni72AB' => enterpriseAnnualProductId,
    'a0ERB00000PISaq2AH' => enterpriseAnnualProductId,
    'a0ERB00000OjniA2AR' => resellerProAnnualProductId
};

Map<Id, ProductMaster__c> products = new Map<Id, ProductMaster__c>([
    SELECT Id, Name, BillingTiming__c
    FROM ProductMaster__c
    WHERE Id IN :new Set<Id>{enterpriseAnnualProductId, resellerProAnnualProductId}
]);
System.assertEquals(2, products.size(), '年一括の商品マスタ2件が必要です。');
for (ProductMaster__c productRecord : products.values()) {
    System.assertEquals(
        '年一括',
        productRecord.BillingTiming__c,
        productRecord.Name + 'の請求タイミングは年一括である必要があります。'
    );
}

List<Mig_FreeeInvoiceLineWork__c> targetLines = [
    SELECT Id,
           InvoiceWork__c,
           Description__c,
           SuggestedProductMaster__c,
           ConfirmedProductMaster__c,
           ProductResolveStatus__c,
           ImportStatus__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE Id IN :productByLineId.keySet()
];
System.assertEquals(9, targetLines.size(), '年一括商品へ確定する明細は9件です。');

Set<Id> workIds = new Set<Id>();
Set<String> descriptions = new Set<String>();
for (Mig_FreeeInvoiceLineWork__c lineWork : targetLines) {
    Id productId = productByLineId.get(lineWork.Id);
    lineWork.SuggestedProductMaster__c = productId;
    lineWork.ConfirmedProductMaster__c = productId;
    lineWork.ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED;
    lineWork.ResolveMessage__c =
        '年払い明細のため、請求タイミングが「年一括」の商品マスタへ確定しました。';
    workIds.add(lineWork.InvoiceWork__c);
    descriptions.add(lineWork.Description__c);
}
update targetLines;

Map<String, Mig_FreeeInvoiceLineProductMap__c> mappingByKeyword =
    new Map<String, Mig_FreeeInvoiceLineProductMap__c>();
for (Mig_FreeeInvoiceLineProductMap__c mapping : [
    SELECT Id, Keyword__c, ProductMaster__c
    FROM Mig_FreeeInvoiceLineProductMap__c
    WHERE Keyword__c IN :descriptions
      AND MatchType__c = '完全一致'
]) {
    System.assert(
        !mappingByKeyword.containsKey(mapping.Keyword__c),
        '完全一致の商品マッピングが重複しています: ' + mapping.Keyword__c
    );
    mappingByKeyword.put(mapping.Keyword__c, mapping);
}

List<Mig_FreeeInvoiceLineProductMap__c> mappingsToUpsert =
    new List<Mig_FreeeInvoiceLineProductMap__c>();
for (Mig_FreeeInvoiceLineWork__c lineWork : targetLines) {
    Mig_FreeeInvoiceLineProductMap__c mapping = mappingByKeyword.get(lineWork.Description__c);
    if (mapping == null) {
        mapping = new Mig_FreeeInvoiceLineProductMap__c(
            Keyword__c = lineWork.Description__c,
            MatchType__c = '完全一致'
        );
    }
    mapping.ProductMaster__c = productByLineId.get(lineWork.Id);
    mapping.IsActive__c = true;
    mapping.Priority__c = 10;
    mapping.Memo__c = '年払い明細を請求タイミング「年一括」の商品へ割り当て';
    mappingsToUpsert.add(mapping);
}
upsert mappingsToUpsert;

List<Mig_FreeeInvoiceWork__c> works = [
    SELECT Id,
           Name,
           FreeeInvoiceId__c,
           ExternalKey__c,
           InvoiceAmount__c,
           ResolvedAccount__c,
           ResolvedContract__c,
           ResolvedContractPeriod__c,
           ImportStatus__c,
           ValidationMessage__c,
           (SELECT Id,
                   ConfirmedProductMaster__c,
                   ImportStatus__c,
                   LineAmount__c,
                   TaxAmount__c
            FROM InvoiceLineWorks__r)
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :workIds
];

List<Id> readyWorkIds = new List<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : works) {
    List<String> messages = new List<String>();
    if (String.isBlank(workRecord.FreeeInvoiceId__c)) {
        messages.add('freee請求書IDが取得できていません。');
    }
    if (String.isBlank(workRecord.ExternalKey__c)) {
        messages.add('移行用の一意キーが作成できていません。');
    }
    if (workRecord.ResolvedAccount__c == null) {
        messages.add('取引先を特定できません。');
    }
    if (workRecord.ResolvedContract__c == null) {
        messages.add('契約管理を特定できません。取引先に有効な契約管理があるか確認してください。');
    }
    if (workRecord.ResolvedContractPeriod__c == null) {
        messages.add('契約期間を特定できません。請求日を含む契約期間があるか確認してください。');
    }
    Decimal lineTotal = 0;
    Boolean hasUnconfirmedProduct = false;
    for (Mig_FreeeInvoiceLineWork__c lineWork : workRecord.InvoiceLineWorks__r) {
        if (lineWork.ImportStatus__c == Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED) {
            continue;
        }
        lineTotal += (lineWork.LineAmount__c == null ? 0 : lineWork.LineAmount__c)
            + (lineWork.TaxAmount__c == null ? 0 : lineWork.TaxAmount__c);
        if (lineWork.ConfirmedProductMaster__c == null) {
            hasUnconfirmedProduct = true;
        }
    }
    if (hasUnconfirmedProduct) {
        messages.add('商品マスタが未確定の請求明細Workがあります。候補商品を確認し、商品マスタを確定してください。');
    }
    if (workRecord.InvoiceAmount__c != null
        && Math.abs(workRecord.InvoiceAmount__c - lineTotal) > 1) {
        messages.add(
            '請求金額と明細合計が一致していません。請求金額='
            + workRecord.InvoiceAmount__c
            + '、明細合計='
            + lineTotal
        );
    }
    if (messages.isEmpty()) {
        workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_READY;
        workRecord.ValidationMessage__c = null;
        readyWorkIds.add(workRecord.Id);
    } else {
        workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW;
        workRecord.ValidationMessage__c = String.join(messages, '\n');
    }
}
update works;

if (!readyWorkIds.isEmpty()) {
    Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(readyWorkIds);
}

System.debug(
    'ANNUAL_PRODUCTS_CONFIRMED lines=' + targetLines.size()
    + ' works=' + works.size()
    + ' readyOrFinalized=' + readyWorkIds.size()
    + ' mappings=' + mappingsToUpsert.size()
);
