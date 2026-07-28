String productName = 'knock knock AI Basicプラン(50クレジット)';
Set<String> approvedDescriptions = new Set<String>{
    'knock knock AI_Basicプラン',
    'KnockKnockAI_Basicプラン(月額)'
};
Set<Id> targetLineIds = new Set<Id>{
    'a0ERB00000OjzO72AJ',
    'a0ERB00000OjzOD2AZ',
    'a0ERB00000OjzOF2AZ',
    'a0ERB00000Ok0Yf2AJ',
    'a0ERB00000Ok0Yk2AJ',
    'a0ERB00000Ok0Ym2AJ',
    'a0ERB00000OjwBn2AJ',
    'a0ERB00000OjwBr2AJ',
    'a0ERB00000OjwBw2AJ',
    'a0ERB00000OjwBy2AJ',
    'a0ERB00000PIXwp2AH',
    'a0ERB00000PIXwr2AH',
    'a0ERB00000PIXww2AH',
    'a0ERB00000PIdKf2AL'
};

List<ProductMaster__c> products = [
    SELECT Id, Name
    FROM ProductMaster__c
    WHERE Name = :productName
];
System.assertEquals(1, products.size(), '対象商品マスタが一意に特定できません。');
Id productId = products[0].Id;

List<Mig_FreeeInvoiceLineWork__c> targetLines = [
    SELECT Id, InvoiceWork__c, Description__c, CreatedInvoiceLine__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE Id IN :targetLineIds
      AND InvoiceWork__r.ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW
];
System.assertEquals(14, targetLines.size(), '指定された追加P01対象明細は14件である必要があります。');

Set<Id> targetWorkIds = new Set<Id>();
for (Mig_FreeeInvoiceLineWork__c lineWork : targetLines) {
    System.assert(approvedDescriptions.contains(lineWork.Description__c), '対象外の明細名が含まれています。');
    System.assertEquals(null, lineWork.CreatedInvoiceLine__c, '作成済み請求明細があるレコードは今回の対象外です。');
    lineWork.SuggestedProductMaster__c = productId;
    lineWork.ConfirmedProductMaster__c = productId;
    lineWork.ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED;
    lineWork.ResolveConfidence__c = 1;
    lineWork.ResolveMessage__c =
        '経理確認済み: knock knock AI Basicプラン(50クレジット)として確定。';
    targetWorkIds.add(lineWork.InvoiceWork__c);
}
System.assertEquals(14, targetWorkIds.size(), '1つのWorkに対象明細が複数存在します。');
update targetLines;

Map<String, Mig_FreeeInvoiceLineProductMap__c> mappingByKeyword =
    new Map<String, Mig_FreeeInvoiceLineProductMap__c>();
for (Mig_FreeeInvoiceLineProductMap__c mapping : [
    SELECT Id, Keyword__c
    FROM Mig_FreeeInvoiceLineProductMap__c
    WHERE Keyword__c IN :approvedDescriptions
      AND MatchType__c = '完全一致'
]) {
    System.assert(
        !mappingByKeyword.containsKey(mapping.Keyword__c),
        '同じ完全一致キーワードの商品マッピングが複数存在します。'
    );
    mappingByKeyword.put(mapping.Keyword__c, mapping);
}
List<Mig_FreeeInvoiceLineProductMap__c> mappingsToUpsert =
    new List<Mig_FreeeInvoiceLineProductMap__c>();
for (String description : approvedDescriptions) {
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
    mapping.Memo__c = '2026-07-24 経理確認済み。50クレジット商品へ変換する。';
    mappingsToUpsert.add(mapping);
}
upsert mappingsToUpsert;

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
        messages.add('契約管理を特定できません。');
    }
    if (workRecord.ResolvedContractPeriod__c == null) {
        messages.add('契約期間を特定できません。');
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
        messages.add('商品マスタが未確定の請求明細Workがあります。');
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
System.assertEquals(14, readyWorkIds.size(), '反映可能なWorkは14件である必要があります。');
update works;
Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(readyWorkIds);

System.debug(
    'ADDITIONAL_P01_CONFIRMED lines=' + targetLines.size()
    + ' works=' + works.size()
    + ' finalized=' + readyWorkIds.size()
    + ' mappings=' + mappingsToUpsert.size()
);
