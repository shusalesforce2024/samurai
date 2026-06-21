public with sharing class Mig_FreeeInvoiceProductResolver {
    public static void resolveAll() {
        resolveProducts();
        resolveContractLineItems();
    }

    public static void resolveProducts() {
        List<Mig_FreeeInvoiceLineWork__c> lines = [
            SELECT Id,
                   Description__c,
                   UnitPrice__c,
                   Quantity__c,
                   LineAmount__c,
                   SuggestedProductMaster__c,
                   ConfirmedProductMaster__c,
                   ProductResolveStatus__c,
                   ResolveConfidence__c,
                   ResolveMessage__c,
                   ImportStatus__c
            FROM Mig_FreeeInvoiceLineWork__c
            WHERE ImportStatus__c IN :new List<String>{
                Mig_FreeeInvoiceWorkService.STATUS_FETCHED,
                Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW,
                Mig_FreeeInvoiceWorkService.STATUS_READY
            }
        ];
        if (lines.isEmpty()) {
            return;
        }

        List<ProductMaster__c> products = [
            SELECT Id, Name, UnitPrice__c, AnnualMonthlyPrice__c
            FROM ProductMaster__c
        ];
        List<Mig_FreeeInvoiceLineProductMap__c> mappings = [
            SELECT Id, Keyword__c, ProductMaster__c, MatchType__c, Priority__c, IsActive__c
            FROM Mig_FreeeInvoiceLineProductMap__c
            WHERE IsActive__c = true
            ORDER BY Priority__c ASC, CreatedDate ASC
        ];

        for (Mig_FreeeInvoiceLineWork__c line : lines) {
            if (line.ConfirmedProductMaster__c != null || line.ImportStatus__c == Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED) {
                continue;
            }
            ProductMatch match = matchProduct(line, products, mappings);
            if (match != null) {
                line.SuggestedProductMaster__c = match.productId;
                line.ResolveConfidence__c = match.confidence;
                line.ResolveMessage__c = match.reason;
                if (match.confidence >= 0.95) {
                    line.ConfirmedProductMaster__c = match.productId;
                    line.ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED;
                } else {
                    line.ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CANDIDATE;
                }
            } else {
                line.ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_NEEDS_REVIEW;
                line.ResolveMessage__c = 'No ProductMaster candidate found.';
            }
        }
        update lines;
    }

    public static void resolveContractLineItems() {
        List<Mig_FreeeInvoiceLineWork__c> lines = [
            SELECT Id,
                   ConfirmedProductMaster__c,
                   ResolvedContractLineItem__c,
                   InvoiceWork__r.ResolvedContractPeriod__c,
                   InvoiceWork__r.TargetPeriodStartDate__c,
                   InvoiceWork__r.BillingDate__c
            FROM Mig_FreeeInvoiceLineWork__c
            WHERE ResolvedContractLineItem__c = null
              AND ConfirmedProductMaster__c != null
              AND InvoiceWork__r.ResolvedContractPeriod__c != null
        ];
        if (lines.isEmpty()) {
            return;
        }

        Set<Id> periodIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        for (Mig_FreeeInvoiceLineWork__c line : lines) {
            periodIds.add(line.InvoiceWork__r.ResolvedContractPeriod__c);
            productIds.add(line.ConfirmedProductMaster__c);
        }

        Map<String, List<ContractLineItem__c>> cliByKey = new Map<String, List<ContractLineItem__c>>();
        for (ContractLineItem__c cli : [
            SELECT Id, ContractPeriod__c, ProductMaster__c, PeriodStartDate__c, PeriodEndDate__c
            FROM ContractLineItem__c
            WHERE ContractPeriod__c IN :periodIds
              AND ProductMaster__c IN :productIds
        ]) {
            String key = cli.ContractPeriod__c + ':' + cli.ProductMaster__c;
            if (!cliByKey.containsKey(key)) {
                cliByKey.put(key, new List<ContractLineItem__c>());
            }
            cliByKey.get(key).add(cli);
        }

        for (Mig_FreeeInvoiceLineWork__c line : lines) {
            String key = line.InvoiceWork__r.ResolvedContractPeriod__c + ':' + line.ConfirmedProductMaster__c;
            List<ContractLineItem__c> candidates = cliByKey.get(key);
            if (candidates == null || candidates.isEmpty()) {
                continue;
            }
            Date targetDate = line.InvoiceWork__r.TargetPeriodStartDate__c == null
                ? line.InvoiceWork__r.BillingDate__c
                : line.InvoiceWork__r.TargetPeriodStartDate__c;
            ContractLineItem__c selected = null;
            for (ContractLineItem__c candidate : candidates) {
                if (targetDate != null
                    && (candidate.PeriodStartDate__c == null || candidate.PeriodStartDate__c <= targetDate)
                    && (candidate.PeriodEndDate__c == null || candidate.PeriodEndDate__c >= targetDate)) {
                    selected = candidate;
                    break;
                }
            }
            if (selected == null && candidates.size() == 1) {
                selected = candidates[0];
            }
            if (selected != null) {
                line.ResolvedContractLineItem__c = selected.Id;
            }
        }
        update lines;
    }

    private static ProductMatch matchProduct(
        Mig_FreeeInvoiceLineWork__c line,
        List<ProductMaster__c> products,
        List<Mig_FreeeInvoiceLineProductMap__c> mappings
    ) {
        String description = line.Description__c;
        String normalizedDescription = Mig_FreeeInvoiceWorkService.normalize(description);

        for (ProductMaster__c product : products) {
            if (!String.isBlank(description) && description == product.Name) {
                return new ProductMatch(product.Id, 1, 'Exact ProductMaster.Name match.');
            }
        }
        for (ProductMaster__c product : products) {
            if (!String.isBlank(normalizedDescription)
                && normalizedDescription == Mig_FreeeInvoiceWorkService.normalize(product.Name)) {
                return new ProductMatch(product.Id, 0.95, 'Normalized ProductMaster.Name match.');
            }
        }
        for (Mig_FreeeInvoiceLineProductMap__c mapping : mappings) {
            if (mapping.ProductMaster__c == null || String.isBlank(mapping.Keyword__c)) {
                continue;
            }
            String keyword = mapping.Keyword__c;
            String matchType = mapping.MatchType__c;
            Boolean matched = false;
            if (matchType == '完全一致') {
                matched = description == keyword;
            } else if (matchType == '正規化一致') {
                matched = normalizedDescription == Mig_FreeeInvoiceWorkService.normalize(keyword);
            } else {
                matched = !String.isBlank(description) && description.contains(keyword);
            }
            if (matched) {
                return new ProductMatch(mapping.ProductMaster__c, 0.9, 'Matched by migration product map.');
            }
        }
        for (ProductMaster__c product : products) {
            if (line.UnitPrice__c != null
                && (
                    (product.UnitPrice__c != null && product.UnitPrice__c == line.UnitPrice__c)
                    || (product.AnnualMonthlyPrice__c != null && product.AnnualMonthlyPrice__c == line.UnitPrice__c)
                )
            ) {
                return new ProductMatch(product.Id, 0.65, 'Matched by unit price.');
            }
        }

        Boolean singleQuantity = line.Quantity__c == null || line.Quantity__c == 1;
        if (singleQuantity) {
            for (ProductMaster__c product : products) {
                if (line.LineAmount__c != null
                    && (
                        (product.UnitPrice__c != null && product.UnitPrice__c == line.LineAmount__c)
                        || (product.AnnualMonthlyPrice__c != null && product.AnnualMonthlyPrice__c == line.LineAmount__c)
                    )
                ) {
                    return new ProductMatch(product.Id, 0.6, 'Matched by single-line amount.');
                }
            }
        }
        return null;
    }

    private class ProductMatch {
        Id productId;
        Decimal confidence;
        String reason;

        ProductMatch(Id productId, Decimal confidence, String reason) {
            this.productId = productId;
            this.confidence = confidence;
            this.reason = reason;
        }
    }
}
