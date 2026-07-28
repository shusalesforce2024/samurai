String description = 'knock knock AI Basicプラン(月額)';
String productName = 'knock knock AI Basicプラン(50クレジット)';
Set<Id> targetLineIds = new Set<Id>{
    'a0ERB00000OjzOA2AZ',
    'a0ERB00000Ok2E22AJ',
    'a0ERB00000Ok10A2AR',
    'a0ERB00000OjwQS2AZ',
    'a0ERB00000PJ1AA2A1'
};

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
           Description__c,
           CreatedInvoiceLine__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE Id IN :targetLineIds
      AND InvoiceWork__r.ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW
];
System.assertEquals(5, targetLines.size(), '指定されたP01対象明細は5件である必要があります。');

Set<Id> targetWorkIds = new Set<Id>();
for (Mig_FreeeInvoiceLineWork__c lineWork : targetLines) {
    System.assertEquals(description, lineWork.Description__c, '対象外の明細名が含まれています。');
    System.assertEquals(null, lineWork.CreatedInvoiceLine__c, '作成済み請求明細があるレコードは今回の対象外です。');
    lineWork.SuggestedProductMaster__c = productId;
    lineWork.ConfirmedProductMaster__c = productId;
    lineWork.ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED;
    lineWork.ResolveConfidence__c = 1;
    lineWork.ResolveMessage__c =
        '経理確認済み: knock knock AI Basicプラン(50クレジット)として確定。';
    targetWorkIds.add(lineWork.InvoiceWork__c);
}
System.assertEquals(5, targetWorkIds.size(), '1つのWorkに対象明細が複数存在します。');
update targetLines;

List<Mig_FreeeInvoiceLineProductMap__c> mappings = [
    SELECT Id
    FROM Mig_FreeeInvoiceLineProductMap__c
    WHERE Keyword__c = :description
      AND MatchType__c = '完全一致'
];
System.assert(mappings.size() <= 1, '同じ完全一致キーワードの商品マッピングが複数存在します。');
Mig_FreeeInvoiceLineProductMap__c mapping = mappings.isEmpty()
    ? new Mig_FreeeInvoiceLineProductMap__c(
        Name = description,
        Keyword__c = description,
        MatchType__c = '完全一致'
    )
    : mappings[0];
mapping.ProductMaster__c = productId;
mapping.Priority__c = 10;
mapping.IsActive__c = true;
mapping.Memo__c = '2026-07-24 経理確認済み。50クレジット商品へ変換する。';
upsert mapping;

List<Mig_FreeeInvoiceWork__c> works = [
    SELECT Id,
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
    WHERE Id IN :targetWorkIds
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
    'BASIC_SPACE_MONTHLY_CONFIRMED lines=' + targetLines.size()
    + ' works=' + works.size()
    + ' readyOrFinalized=' + readyWorkIds.size()
    + ' mappingId=' + mapping.Id
);
