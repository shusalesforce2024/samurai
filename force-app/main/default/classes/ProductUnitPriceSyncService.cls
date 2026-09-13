public with sharing class ProductUnitPriceSyncService {
    public static void syncQuotationLineUnitPrice(
        List<QuotationLine__c> newRecords,
        Map<Id, QuotationLine__c> oldMap
    ) {
        Map<Id, ProductMaster__c> productById = getProductById(
            collectChangedProductIdsForQuotationLines(newRecords, oldMap)
        );

        for (QuotationLine__c record : newRecords) {
            if (!shouldSyncQuotationLine(record, oldMap)) {
                continue;
            }

            ProductMaster__c product = productById.get(record.ProductMaster__c);
            if (product == null) {
                continue;
            }
            if (product.UnitPrice__c != null) {
                record.Unit_Price__c = product.UnitPrice__c;
            }
            if (!String.isBlank(product.Unit__c)) {
                record.Unit__c = product.Unit__c;
            }
        }
    }

    public static void syncInvoiceLineUnitPrice(
        List<InvoiceLine__c> newRecords,
        Map<Id, InvoiceLine__c> oldMap
    ) {
        Map<Id, ProductMaster__c> productById = getProductById(
            collectChangedProductIdsForInvoiceLines(newRecords, oldMap)
        );

        for (InvoiceLine__c record : newRecords) {
            if (!shouldSyncInvoiceLine(record, oldMap)) {
                continue;
            }

            ProductMaster__c product = productById.get(record.ProductMaster__c);
            if (product == null) {
                continue;
            }
            if (product.UnitPrice__c != null) {
                record.Unit_Price__c = product.UnitPrice__c;
            }
            if (!String.isBlank(product.Unit__c)) {
                record.Unit__c = product.Unit__c;
            }
        }
    }

    private static Set<Id> collectChangedProductIdsForQuotationLines(
        List<QuotationLine__c> newRecords,
        Map<Id, QuotationLine__c> oldMap
    ) {
        Set<Id> productIds = new Set<Id>();

        for (QuotationLine__c record : newRecords) {
            if (shouldSyncQuotationLine(record, oldMap)) {
                productIds.add(record.ProductMaster__c);
            }
        }

        return productIds;
    }

    private static Set<Id> collectChangedProductIdsForInvoiceLines(
        List<InvoiceLine__c> newRecords,
        Map<Id, InvoiceLine__c> oldMap
    ) {
        Set<Id> productIds = new Set<Id>();

        for (InvoiceLine__c record : newRecords) {
            if (shouldSyncInvoiceLine(record, oldMap)) {
                productIds.add(record.ProductMaster__c);
            }
        }

        return productIds;
    }

    private static Boolean shouldSyncQuotationLine(
        QuotationLine__c record,
        Map<Id, QuotationLine__c> oldMap
    ) {
        if (record.ProductMaster__c == null) {
            return false;
        }

        if (oldMap == null || !oldMap.containsKey(record.Id)) {
            return true;
        }

        return oldMap.get(record.Id).ProductMaster__c != record.ProductMaster__c;
    }

    private static Boolean shouldSyncInvoiceLine(
        InvoiceLine__c record,
        Map<Id, InvoiceLine__c> oldMap
    ) {
        if (record.ProductMaster__c == null) {
            return false;
        }
        if (record.MigrationSourceLineWork__c != null
            && record.Unit_Price__c != null) {
            return false;
        }

        if (oldMap == null || !oldMap.containsKey(record.Id)) {
            return true;
        }

        return oldMap.get(record.Id).ProductMaster__c != record.ProductMaster__c;
    }

    private static Map<Id, ProductMaster__c> getProductById(Set<Id> productIds) {
        Map<Id, ProductMaster__c> productById = new Map<Id, ProductMaster__c>();
        if (productIds.isEmpty()) {
            return productById;
        }

        for (ProductMaster__c product : [
            SELECT Id, UnitPrice__c, Unit__c
            FROM ProductMaster__c
            WHERE Id IN :productIds
        ]) {
            productById.put(product.Id, product);
        }

        return productById;
    }
}
