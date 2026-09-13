Map<String, ProductMaster__c> existingByName = new Map<String, ProductMaster__c>();
for (ProductMaster__c productRecord : [
    SELECT Id, Name
    FROM ProductMaster__c
    WHERE Name IN (
        '[月払] knock knock AI Enterpriseプラン 2000クレジット',
        '[年払] knock knock AI Enterpriseプラン 2000クレジット'
    )
]) {
    existingByName.put(productRecord.Name, productRecord);
}

List<ProductMaster__c> productsToInsert = new List<ProductMaster__c>();
if (!existingByName.containsKey('[月払] knock knock AI Enterpriseプラン 2000クレジット')) {
    productsToInsert.add(new ProductMaster__c(
        Name = '[月払] knock knock AI Enterpriseプラン 2000クレジット',
        ProductType__c = '継続費用',
        BillingTiming__c = '毎月',
        UnitPrice__c = 290000,
        MRR_Target__c = true,
        ARR_Target__c = true
    ));
}
if (!existingByName.containsKey('[年払] knock knock AI Enterpriseプラン 2000クレジット')) {
    productsToInsert.add(new ProductMaster__c(
        Name = '[年払] knock knock AI Enterpriseプラン 2000クレジット',
        ProductType__c = '継続費用',
        BillingTiming__c = '年一括',
        UnitPrice__c = 261000,
        MRR_Target__c = true,
        ARR_Target__c = true
    ));
}

if (!productsToInsert.isEmpty()) {
    insert productsToInsert;
}
System.debug(LoggingLevel.ERROR,
    'SUMMARY existing=' + existingByName.size() + ', inserted=' + productsToInsert.size()
);
