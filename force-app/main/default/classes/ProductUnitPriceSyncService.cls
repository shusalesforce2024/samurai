public with sharing class ProductUnitPriceSyncService {
    public static void syncQuotationLineUnitPrice(
        List<QuotationLine__c> newRecords,
        Map<Id, QuotationLine__c> oldMap
    ) {
        Map<Id, Decimal> unitPriceByProductId = getUnitPriceByProductId(
            collectChangedProductIdsForQuotationLines(newRecords, oldMap)
        );

        for (QuotationLine__c record : newRecords) {
            if (!shouldSyncQuotationLine(record, oldMap)) {
                continue;
            }

            Decimal unitPrice = unitPriceByProductId.get(record.ProductMaster__c);
            if (unitPrice != null) {
                record.Unit_Price__c = unitPrice;
            }
        }
    }

    public static void syncInvoiceLineUnitPrice(
        List<InvoiceLine__c> newRecords,
        Map<Id, InvoiceLine__c> oldMap
    ) {
        Map<Id, Decimal> unitPriceByProductId = getUnitPriceByProductId(
            collectChangedProductIdsForInvoiceLines(newRecords, oldMap)
        );

        for (InvoiceLine__c record : newRecords) {
            if (!shouldSyncInvoiceLine(record, oldMap)) {
                continue;
            }

            Decimal unitPrice = unitPriceByProductId.get(record.ProductMaster__c);
            if (unitPrice != null) {
                record.Unit_Price__c = unitPrice;
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

        if (oldMap == null || !oldMap.containsKey(record.Id)) {
            return true;
        }

        return oldMap.get(record.Id).ProductMaster__c != record.ProductMaster__c;
    }

    private static Map<Id, Decimal> getUnitPriceByProductId(Set<Id> productIds) {
        Map<Id, Decimal> unitPriceByProductId = new Map<Id, Decimal>();
        if (productIds.isEmpty()) {
            return unitPriceByProductId;
        }

        for (ProductMaster__c product : [
            SELECT Id, UnitPrice__c
            FROM ProductMaster__c
            WHERE Id IN :productIds
        ]) {
            unitPriceByProductId.put(product.Id, product.UnitPrice__c);
        }

        return unitPriceByProductId;
    }
}
