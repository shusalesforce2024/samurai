Map<Decimal, List<ProductMaster__c>> productsByUnitPrice = new Map<Decimal, List<ProductMaster__c>>();
for (ProductMaster__c productRecord : [
    SELECT Id, UnitPrice__c, AnnualMonthlyPrice__c
    FROM ProductMaster__c
]) {
    for (Decimal price : new List<Decimal>{ productRecord.UnitPrice__c, productRecord.AnnualMonthlyPrice__c }) {
        if (price == null) {
            continue;
        }
        if (!productsByUnitPrice.containsKey(price)) {
            productsByUnitPrice.put(price, new List<ProductMaster__c>());
        }
        Boolean alreadyAdded = false;
        for (ProductMaster__c existing : productsByUnitPrice.get(price)) {
            if (existing.Id == productRecord.Id) {
                alreadyAdded = true;
                break;
            }
        }
        if (!alreadyAdded) {
            productsByUnitPrice.get(price).add(productRecord);
        }
    }
}

List<Mig_FreeeInvoiceLineWork__c> updates = new List<Mig_FreeeInvoiceLineWork__c>();
for (Mig_FreeeInvoiceLineWork__c lineWork : [
    SELECT Id,
           UnitPrice__c,
           SuggestedProductMaster__c,
           ConfirmedProductMaster__c,
           ProductResolveStatus__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE ConfirmedProductMaster__c = null
      AND SuggestedProductMaster__c != null
]) {
    List<ProductMaster__c> unitPriceMatches = productsByUnitPrice.get(lineWork.UnitPrice__c);
    if (unitPriceMatches != null
        && unitPriceMatches.size() == 1
        && unitPriceMatches[0].Id == lineWork.SuggestedProductMaster__c
    ) {
        updates.add(new Mig_FreeeInvoiceLineWork__c(
            Id = lineWork.Id,
            ConfirmedProductMaster__c = lineWork.SuggestedProductMaster__c,
            ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED
        ));
    }
}

if (!updates.isEmpty()) {
    update updates;
}

Mig_FreeeInvoiceProductResolver.resolveContractLineItems();
Mig_FreeeInvoiceValidator.validateAll();
System.debug('MIG_FREEE_CONFIRMED_UNIQUE_PRODUCT_CANDIDATES=' + updates.size());
