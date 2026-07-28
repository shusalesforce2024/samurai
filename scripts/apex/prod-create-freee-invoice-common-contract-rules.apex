Map<Id, String> productNameById = new Map<Id, String>{
    'a0CRB0000CcXZ6Q2QW' => 'Rendery Proプラン',
    'a0CRB0000CcXZ6T2QW' => '[OLD] Rendery Enterpriseプラン(2025年9月まで)',
    'a0CRB0000CcXZ6V2QW' => 'Rendery Enterpriseプラン',
    'a0CRB0000CcXZ6i2QG' => 'knock knock AI Basicプラン(50クレジット)'
};

Map<Id, ProductMaster__c> productById = new Map<Id, ProductMaster__c>([
    SELECT Id, Name, ProductType__c, BillingTiming__c
    FROM ProductMaster__c
    WHERE Id IN :productNameById.keySet()
]);
System.assertEquals(productNameById.size(), productById.size(), '対象商品が不足しています。');

for (Id productId : productNameById.keySet()) {
    ProductMaster__c productRecord = productById.get(productId);
    System.assertEquals(productNameById.get(productId), productRecord.Name);
    System.assertEquals('継続費用', productRecord.ProductType__c);
    System.assertEquals('毎月', productRecord.BillingTiming__c);
}

List<FreeeInvoiceContractRule__c> existingRules = [
    SELECT Id, ProductMaster__c
    FROM FreeeInvoiceContractRule__c
    WHERE Account__c = null
      AND ProductMaster__c IN :productNameById.keySet()
      AND IsActive__c = true
];
System.assertEquals(0, existingRules.size(), '同じ商品の有効な共通ルールが既に存在します。');

List<FreeeInvoiceContractRule__c> rulesToInsert =
    new List<FreeeInvoiceContractRule__c>();
for (Id productId : productNameById.keySet()) {
    rulesToInsert.add(new FreeeInvoiceContractRule__c(
        Name = productNameById.get(productId) + ' 月額共通ルール',
        ProductMaster__c = productId,
        BillingCycle__c = 'Monthly',
        AutoCreateAllowed__c = true,
        IsActive__c = true
    ));
}
insert rulesToInsert;
System.debug('CREATED_COMMON_RULES count=' + rulesToInsert.size());
