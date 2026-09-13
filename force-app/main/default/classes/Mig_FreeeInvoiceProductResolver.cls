public with sharing class Mig_FreeeInvoiceProductResolver {
    public static void resolveAll() {
        resolveProducts();
        resolveContractLineItems();
    }

    public static void resolveProducts() {
        List<Mig_FreeeInvoiceLineWork__c> lines = [
            SELECT Id,
                   InvoiceWork__c,
                   Description__c,
                   UnitPrice__c,
                   Quantity__c,
                   LineAmount__c,
                   TaxAmount__c,
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
        Map<String, Set<Id>> confirmedProductsBySignature =
            loadConfirmedProductHistory();

        for (Mig_FreeeInvoiceLineWork__c line : lines) {
            if (line.ConfirmedProductMaster__c != null || line.ImportStatus__c == Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED) {
                continue;
            }
            if (isInformationalLine(line)) {
                line.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED;
                line.ProductResolveStatus__c =
                    Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_EXCLUDED;
                line.ResolveMessage__c =
                    '金額を持たない注記行のため、請求明細の作成対象外にしました。';
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
            applyConfirmedHistory(line, confirmedProductsBySignature);
        }
        resolveAdjustmentLines(lines);
        update lines;
    }

    private static Map<String, Set<Id>> loadConfirmedProductHistory() {
        Map<String, Set<Id>> confirmedProductsBySignature =
            new Map<String, Set<Id>>();
        for (Mig_FreeeInvoiceLineWork__c historicalLine : [
            SELECT Description__c,
                   UnitPrice__c,
                   Quantity__c,
                   LineAmount__c,
                   ConfirmedProductMaster__c
            FROM Mig_FreeeInvoiceLineWork__c
            WHERE ConfirmedProductMaster__c != null
              AND CreatedDate = LAST_N_DAYS:730
        ]) {
            String signature = productSignature(historicalLine);
            if (!confirmedProductsBySignature.containsKey(signature)) {
                confirmedProductsBySignature.put(signature, new Set<Id>());
            }
            confirmedProductsBySignature.get(signature)
                .add(historicalLine.ConfirmedProductMaster__c);
        }
        return confirmedProductsBySignature;
    }

    private static void applyConfirmedHistory(
        Mig_FreeeInvoiceLineWork__c line,
        Map<String, Set<Id>> confirmedProductsBySignature
    ) {
        if (line.ConfirmedProductMaster__c != null) {
            return;
        }
        Set<Id> historicalProducts =
            confirmedProductsBySignature.get(productSignature(line));
        if (historicalProducts == null || historicalProducts.size() != 1) {
            return;
        }
        Id historicalProductId =
            new List<Id>(historicalProducts)[0];
        if (line.SuggestedProductMaster__c != null
            && line.SuggestedProductMaster__c != historicalProductId) {
            return;
        }
        line.SuggestedProductMaster__c = historicalProductId;
        line.ConfirmedProductMaster__c = historicalProductId;
        line.ProductResolveStatus__c =
            Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED;
        line.ResolveConfidence__c = 0.99;
        line.ResolveMessage__c =
            '過去に確定した同一の明細名・単価・数量・金額から商品を自動確定しました。';
    }

    private static void resolveAdjustmentLines(
        List<Mig_FreeeInvoiceLineWork__c> lines
    ) {
        Map<Id, Set<Id>> primaryProductsByWorkId =
            new Map<Id, Set<Id>>();
        for (Mig_FreeeInvoiceLineWork__c line : lines) {
            if (line.ImportStatus__c == Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED
                || isAdjustmentLine(line)
                || (line.LineAmount__c != null && line.LineAmount__c < 0)
                || line.ConfirmedProductMaster__c == null) {
                continue;
            }
            if (!primaryProductsByWorkId.containsKey(line.InvoiceWork__c)) {
                primaryProductsByWorkId.put(line.InvoiceWork__c, new Set<Id>());
            }
            primaryProductsByWorkId.get(line.InvoiceWork__c)
                .add(line.ConfirmedProductMaster__c);
        }

        for (Mig_FreeeInvoiceLineWork__c line : lines) {
            if (!isAdjustmentLine(line)
                || line.ConfirmedProductMaster__c != null) {
                continue;
            }
            Set<Id> primaryProducts =
                primaryProductsByWorkId.get(line.InvoiceWork__c);
            if (primaryProducts == null || primaryProducts.size() != 1) {
                continue;
            }
            Id productId = new List<Id>(primaryProducts)[0];
            line.SuggestedProductMaster__c = productId;
            line.ConfirmedProductMaster__c = productId;
            line.ProductResolveStatus__c =
                Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED;
            line.ResolveConfidence__c = 0.98;
            line.ResolveMessage__c =
                '同じ請求内の主商品が一意に確定しているため、割引・調整行を同じ商品へ自動紐づけしました。';
        }
    }

    private static Boolean isInformationalLine(
        Mig_FreeeInvoiceLineWork__c line
    ) {
        return isZero(line.UnitPrice__c)
            && isZero(line.LineAmount__c)
            && isZero(line.TaxAmount__c)
            && isZero(line.Quantity__c);
    }

    private static Boolean isAdjustmentLine(
        Mig_FreeeInvoiceLineWork__c line
    ) {
        if (line == null || line.LineAmount__c == null
            || line.LineAmount__c >= 0) {
            return false;
        }
        String normalized =
            Mig_FreeeInvoiceWorkService.normalize(line.Description__c);
        return normalized.contains('割引')
            || normalized.contains('値引')
            || normalized.contains('discount')
            || normalized.contains('調整');
    }

    private static Boolean isZero(Decimal value) {
        return value == null || value == 0;
    }

    private static String productSignature(
        Mig_FreeeInvoiceLineWork__c line
    ) {
        return String.join(new List<String>{
            Mig_FreeeInvoiceWorkService.normalize(line.Description__c),
            decimalKey(line.UnitPrice__c),
            decimalKey(line.Quantity__c),
            decimalKey(line.LineAmount__c)
        }, '|');
    }

    private static String decimalKey(Decimal value) {
        return value == null ? '' : String.valueOf(value);
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
            List<ContractLineItem__c> datedCandidates =
                new List<ContractLineItem__c>();
            for (ContractLineItem__c candidate : candidates) {
                if (targetDate != null
                    && (candidate.PeriodStartDate__c == null || candidate.PeriodStartDate__c <= targetDate)
                    && (candidate.PeriodEndDate__c == null || candidate.PeriodEndDate__c >= targetDate)) {
                    datedCandidates.add(candidate);
                }
            }
            ContractLineItem__c selected =
                datedCandidates.size() == 1 ? datedCandidates[0] : null;
            if (selected == null
                && datedCandidates.isEmpty()
                && candidates.size() == 1) {
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
        ProductMatch calculatedUnitPriceMatch =
            matchUniqueCalculatedUnitPrice(line, products, normalizedDescription);
        if (calculatedUnitPriceMatch != null) {
            return calculatedUnitPriceMatch;
        }
        for (ProductMaster__c product : products) {
            if (line.UnitPrice__c != null
                && hasProductNameSignal(normalizedDescription, product)
                && (
                    (product.UnitPrice__c != null && product.UnitPrice__c == line.UnitPrice__c)
                    || (product.AnnualMonthlyPrice__c != null && product.AnnualMonthlyPrice__c == line.UnitPrice__c)
                )
            ) {
                return new ProductMatch(product.Id, 0.75, 'Matched by unit price and product name.');
            }
        }

        Boolean singleQuantity = line.Quantity__c == null || line.Quantity__c == 1;
        if (singleQuantity) {
            for (ProductMaster__c product : products) {
                if (line.LineAmount__c != null
                    && hasProductNameSignal(normalizedDescription, product)
                    && (
                        (product.UnitPrice__c != null && product.UnitPrice__c == line.LineAmount__c)
                        || (product.AnnualMonthlyPrice__c != null && product.AnnualMonthlyPrice__c == line.LineAmount__c)
                    )
                ) {
                    return new ProductMatch(product.Id, 0.7, 'Matched by single-line amount and product name.');
                }
            }
        }
        return null;
    }

    private static ProductMatch matchUniqueCalculatedUnitPrice(
        Mig_FreeeInvoiceLineWork__c line,
        List<ProductMaster__c> products,
        String normalizedDescription
    ) {
        if (line == null
            || line.LineAmount__c == null
            || line.Quantity__c == null
            || line.Quantity__c == 0) {
            return null;
        }

        Decimal calculatedUnitPrice =
            (line.LineAmount__c / line.Quantity__c).abs();
        Map<Id, ProductMaster__c> matchedProducts =
            new Map<Id, ProductMaster__c>();
        for (ProductMaster__c product : products) {
            if (!hasProductNameSignal(normalizedDescription, product)) {
                continue;
            }
            Boolean priceMatched =
                (product.UnitPrice__c != null
                    && product.UnitPrice__c.abs() == calculatedUnitPrice)
                || (product.AnnualMonthlyPrice__c != null
                    && product.AnnualMonthlyPrice__c.abs() == calculatedUnitPrice);
            if (priceMatched) {
                matchedProducts.put(product.Id, product);
            }
        }
        if (matchedProducts.size() != 1) {
            return null;
        }
        return new ProductMatch(
            new List<Id>(matchedProducts.keySet())[0],
            0.96,
            'Matched uniquely by calculated unit price and product name.'
        );
    }

    private static Boolean hasProductNameSignal(String normalizedDescription, ProductMaster__c product) {
        if (String.isBlank(normalizedDescription) || product == null || String.isBlank(product.Name)) {
            return false;
        }
        String normalizedProductName = Mig_FreeeInvoiceWorkService.normalize(product.Name);
        if (String.isBlank(normalizedProductName)) {
            return false;
        }
        return normalizedDescription.contains(normalizedProductName)
            || normalizedProductName.contains(normalizedDescription)
            || sharesSignificantToken(normalizedDescription, normalizedProductName);
    }

    private static Boolean sharesSignificantToken(String normalizedDescription, String normalizedProductName) {
        for (String token : significantProductTokens(normalizedProductName)) {
            if (normalizedDescription.contains(token)) {
                return true;
            }
        }
        return false;
    }

    private static List<String> significantProductTokens(String normalizedProductName) {
        List<String> tokens = new List<String>();
        if (String.isBlank(normalizedProductName)) {
            return tokens;
        }
        for (String token : new List<String>{'knockknockai', 'knockknock', 'rendery', 'rendary', 'visioal', 'visual', '受託開発', '受託'}) {
            if (normalizedProductName.contains(token)) {
                tokens.add(token);
            }
        }
        return tokens;
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
