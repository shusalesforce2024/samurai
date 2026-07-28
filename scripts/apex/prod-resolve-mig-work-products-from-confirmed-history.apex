List<Mig_FreeeInvoiceLineWork__c> allLines = [
    SELECT Id,
           InvoiceWork__c,
           InvoiceWork__r.ImportStatus__c,
           Description__c,
           UnitPrice__c,
           Quantity__c,
           LineAmount__c,
           SuggestedProductMaster__c,
           ConfirmedProductMaster__c,
           ProductResolveStatus__c,
           ResolveMessage__c
    FROM Mig_FreeeInvoiceLineWork__c
];

Map<String, Set<Id>> confirmedProductsByKey = new Map<String, Set<Id>>();
for (Mig_FreeeInvoiceLineWork__c lineRecord : allLines) {
    if (lineRecord.ConfirmedProductMaster__c == null) {
        continue;
    }
    String key = String.join(new List<String>{
        Mig_FreeeInvoiceWorkService.normalize(lineRecord.Description__c),
        String.valueOf(lineRecord.UnitPrice__c),
        String.valueOf(lineRecord.Quantity__c),
        String.valueOf(lineRecord.LineAmount__c)
    }, '|');
    if (!confirmedProductsByKey.containsKey(key)) {
        confirmedProductsByKey.put(key, new Set<Id>());
    }
    confirmedProductsByKey.get(key).add(lineRecord.ConfirmedProductMaster__c);
}

List<Mig_FreeeInvoiceLineWork__c> updates = new List<Mig_FreeeInvoiceLineWork__c>();
Set<Id> affectedWorkIds = new Set<Id>();
for (Mig_FreeeInvoiceLineWork__c lineRecord : allLines) {
    if (lineRecord.InvoiceWork__r.ImportStatus__c != Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW
        || lineRecord.SuggestedProductMaster__c == null
        || lineRecord.ConfirmedProductMaster__c != null) {
        continue;
    }

    String key = String.join(new List<String>{
        Mig_FreeeInvoiceWorkService.normalize(lineRecord.Description__c),
        String.valueOf(lineRecord.UnitPrice__c),
        String.valueOf(lineRecord.Quantity__c),
        String.valueOf(lineRecord.LineAmount__c)
    }, '|');
    Set<Id> confirmedProducts = confirmedProductsByKey.get(key);
    if (confirmedProducts == null
        || confirmedProducts.size() != 1
        || !confirmedProducts.contains(lineRecord.SuggestedProductMaster__c)) {
        continue;
    }

    updates.add(new Mig_FreeeInvoiceLineWork__c(
        Id = lineRecord.Id,
        ConfirmedProductMaster__c = lineRecord.SuggestedProductMaster__c,
        ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED,
        ResolveMessage__c = '過去の確定済み明細と、明細名・単価・数量・金額・商品候補が完全一致したため自動確定しました。'
    ));
    affectedWorkIds.add(lineRecord.InvoiceWork__c);
}

System.assertEquals(137, updates.size(), '事前確認件数と異なるため更新を中止しました。');
System.assertEquals(135, affectedWorkIds.size(), '事前確認Work件数と異なるため更新を中止しました。');

update updates;
Mig_FreeeInvoiceValidator.validateAll();

System.debug('updatedLineCount=' + updates.size());
System.debug('affectedWorkCount=' + affectedWorkIds.size());
