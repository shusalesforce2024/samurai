Map<String, Id> productIdByName = new Map<String, Id>();
for (ProductMaster__c productRecord : [
    SELECT Id, Name, UnitPrice__c
    FROM ProductMaster__c
    WHERE Name IN (
        '受託開発',
        'knock knock AI Basicプラン(50クレジット)',
        '[OLD] Rendery Enterpriseプラン(2025年9月まで)',
        'Rendery セキュリティオプション+_運用費用',
        'Rendery セキュリティオプション(SSO)_初期費用',
        '[年払] Rendery Enterpriseプラン'
    )
]) {
    if (productRecord.Name == '[年払] Rendery Enterpriseプラン' && productRecord.UnitPrice__c != 168000) {
        continue;
    }
    productIdByName.put(productRecord.Name, productRecord.Id);
}

List<String> requiredNames = new List<String>{
    '受託開発',
    'knock knock AI Basicプラン(50クレジット)',
    '[OLD] Rendery Enterpriseプラン(2025年9月まで)',
    'Rendery セキュリティオプション+_運用費用',
    'Rendery セキュリティオプション(SSO)_初期費用',
    '[年払] Rendery Enterpriseプラン'
};
for (String requiredName : requiredNames) {
    if (!productIdByName.containsKey(requiredName)) {
        throw new AuraHandledException('Required ProductMaster not found: ' + requiredName);
    }
}

List<Mig_FreeeInvoiceLineWork__c> updates = new List<Mig_FreeeInvoiceLineWork__c>();
Map<String, Integer> countByProductName = new Map<String, Integer>();
for (Mig_FreeeInvoiceLineWork__c lineWork : [
    SELECT Id,
           Description__c,
           ConfirmedProductMaster__c,
           ImportStatus__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE ImportStatus__c != '対象外'
      AND ConfirmedProductMaster__c = null
]) {
    String description = lineWork.Description__c == null ? '' : lineWork.Description__c;
    String productName = '受託開発';

    if (description.contains('シングルサインオン') && (description.contains('初期') || description.contains('初期コスト'))) {
        productName = 'Rendery セキュリティオプション(SSO)_初期費用';
    } else if (description.contains('セキュリティオプション+') && (description.contains('運用') || description.contains('月額'))) {
        productName = 'Rendery セキュリティオプション+_運用費用';
    } else if (description.contains('Rendery') && description.contains('Enterprise') && description.contains('年間費用')) {
        productName = '[年払] Rendery Enterpriseプラン';
    } else if (description.contains('knock knock AI_Basic')
        || description.contains('knock knock AI Basic')
        || description.contains('KnockKnockAI_Basic')) {
        productName = 'knock knock AI Basicプラン(50クレジット)';
    } else if ((description.contains('Rendery') && description.contains('Enterprise'))
        || (description.contains('Rendery') && description.contains('エンタープライズ'))) {
        productName = '[OLD] Rendery Enterpriseプラン(2025年9月まで)';
    }

    updates.add(new Mig_FreeeInvoiceLineWork__c(
        Id = lineWork.Id,
        ConfirmedProductMaster__c = productIdByName.get(productName),
        ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED,
        ResolveMessage__c = 'Confirmed by migration rule: ' + productName
    ));
    Integer currentCount = countByProductName.containsKey(productName) ? countByProductName.get(productName) : 0;
    countByProductName.put(productName, currentCount + 1);
}

if (!updates.isEmpty()) {
    update updates;
}

Mig_FreeeInvoiceProductResolver.resolveContractLineItems();
Mig_FreeeInvoiceValidator.validateAll();

System.debug('MIG_FREEE_CONFIRMED_REMAINING_PRODUCT_LINES=' + updates.size());
System.debug('MIG_FREEE_CONFIRMED_REMAINING_PRODUCT_COUNTS=' + JSON.serialize(countByProductName));
