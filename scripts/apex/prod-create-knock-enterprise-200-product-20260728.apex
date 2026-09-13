String productName =
    '[月払] knock knock AI Enterpriseプラン 200クレジット';
List<ProductMaster__c> existingProducts = [
    SELECT Id, Name, UnitPrice__c
    FROM ProductMaster__c
    WHERE Name = :productName
    LIMIT 1
];

ProductMaster__c productRecord;
if (existingProducts.isEmpty()) {
    productRecord = new ProductMaster__c(
        Name = productName,
        ProductType__c = '継続費用',
        BillingTiming__c = '毎月',
        UnitPrice__c = 24000,
        MRR_Target__c = true,
        ARR_Target__c = true
    );
    insert productRecord;
} else {
    productRecord = existingProducts[0];
    if (productRecord.UnitPrice__c != 24000) {
        throw new IllegalArgumentException(
            '同名商品が24,000円以外で登録されています: '
            + productRecord.UnitPrice__c
        );
    }
}

System.debug(
    LoggingLevel.ERROR,
    'PRODUCT id=' + productRecord.Id
        + ', name=' + productRecord.Name
        + ', unitPrice=' + productRecord.UnitPrice__c
);
