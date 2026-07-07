public with sharing class Mig_FreeeInvoiceFinalizeService {
    public static void finalizeAllReady() {
        List<Id> workIds = new List<Id>();
        for (Mig_FreeeInvoiceWork__c workRecord : [
            SELECT Id
            FROM Mig_FreeeInvoiceWork__c
            WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_READY
            ORDER BY BillingDate__c ASC, CreatedDate ASC
            LIMIT 5000
        ]) {
            workIds.add(workRecord.Id);
        }
        finalizeByWorkIds(workIds);
    }

    public static void finalizeByWorkIds(List<Id> workIds) {
        if (workIds == null || workIds.isEmpty()) {
            return;
        }

        List<Mig_FreeeInvoiceWork__c> works = [
            SELECT Id,
                   ExternalKey__c,
                   FreeeInvoiceId__c,
                   FreeeInvoiceNumber__c,
                   FreeePartnerId__c,
                   BillingDate__c,
                   PaymentDate__c,
                   Subject__c,
                   InvoiceAmount__c,
                   TaxAmount__c,
                   PaidAmount__c,
                   UnpaidAmount__c,
                   SendStatus__c,
                   PaymentStatus__c,
                   TargetPeriodStartDate__c,
                   TargetPeriodEndDate__c,
                   ResolvedAccount__c,
                   ResolvedContract__c,
                   ResolvedContractPeriod__c,
                   CreatedInvoice__c,
                   ImportStatus__c,
                   ValidationMessage__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id IN :workIds
        ];
        if (works.isEmpty()) {
            return;
        }

        Set<Id> requestedWorkIds = new Set<Id>();
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            requestedWorkIds.add(workRecord.Id);
        }

        List<Mig_FreeeInvoiceLineWork__c> lineWorks = [
            SELECT Id,
                   InvoiceWork__c,
                   ExternalKey__c,
                   FreeeLineId__c,
                   Description__c,
                   Quantity__c,
                   Unit__c,
                   UnitPrice__c,
                   LineAmount__c,
                   TaxRate__c,
                   TaxAmount__c,
                   ConfirmedProductMaster__c,
                   ConfirmedProductMaster__r.Name,
                   ResolvedContractLineItem__c,
                   CreatedInvoiceLine__c,
                   ImportStatus__c,
                   ResolveMessage__c
            FROM Mig_FreeeInvoiceLineWork__c
            WHERE InvoiceWork__c IN :requestedWorkIds
              AND ImportStatus__c != :Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED
        ];

        Map<Id, List<Mig_FreeeInvoiceLineWork__c>> linesByWork = new Map<Id, List<Mig_FreeeInvoiceLineWork__c>>();
        for (Mig_FreeeInvoiceLineWork__c lineWork : lineWorks) {
            if (!linesByWork.containsKey(lineWork.InvoiceWork__c)) {
                linesByWork.put(lineWork.InvoiceWork__c, new List<Mig_FreeeInvoiceLineWork__c>());
            }
            linesByWork.get(lineWork.InvoiceWork__c).add(lineWork);
        }

        Map<Decimal, List<Invoice__c>> existingInvoicesByFreeeId = findExistingInvoicesByFreeeId(works);
        List<Invoice__c> invoicesToUpsert = new List<Invoice__c>();
        List<Invoice__c> existingInvoicesToLink = new List<Invoice__c>();
        Map<String, Mig_FreeeInvoiceWork__c> workByExternalKey = new Map<String, Mig_FreeeInvoiceWork__c>();
        Map<Id, Id> invoiceIdByWorkId = new Map<Id, Id>();
        Set<Id> newWorkIds = new Set<Id>();
        Set<Id> existingWorkIds = new Set<Id>();
        Set<Id> existingInvoiceIds = new Set<Id>();
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            List<String> errors = validateWork(workRecord, linesByWork.get(workRecord.Id));
            errors.addAll(validateExistingInvoiceMatch(workRecord, existingInvoicesByFreeeId));
            if (!errors.isEmpty()) {
                workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW;
                workRecord.ValidationMessage__c = String.join(errors, '\n');
                continue;
            }
            Invoice__c invoiceRecord = toInvoice(workRecord);
            Invoice__c existingInvoice = getSingleExistingInvoice(workRecord, existingInvoicesByFreeeId);
            if (existingInvoice != null) {
                existingInvoicesToLink.add(new Invoice__c(
                    Id = existingInvoice.Id,
                    Freee_External_Key__c = workRecord.ExternalKey__c,
                    MigrationSourceWork__c = workRecord.Id,
                    MigrationImportedAt__c = System.now()
                ));
                invoiceIdByWorkId.put(workRecord.Id, existingInvoice.Id);
                existingWorkIds.add(workRecord.Id);
                existingInvoiceIds.add(existingInvoice.Id);
            } else {
                invoicesToUpsert.add(invoiceRecord);
                newWorkIds.add(workRecord.Id);
            }
            workByExternalKey.put(workRecord.ExternalKey__c, workRecord);
        }

        if (!existingInvoicesToLink.isEmpty()) {
            update existingInvoicesToLink;
        }
        if (!invoicesToUpsert.isEmpty()) {
            upsert invoicesToUpsert Invoice__c.Freee_External_Key__c;
        }

        Map<String, Invoice__c> invoiceByExternalKey = new Map<String, Invoice__c>();
        if (!workByExternalKey.isEmpty()) {
            for (Invoice__c invoiceRecord : [
                SELECT Id, Freee_External_Key__c
                FROM Invoice__c
                WHERE Freee_External_Key__c IN :workByExternalKey.keySet()
            ]) {
                invoiceByExternalKey.put(invoiceRecord.Freee_External_Key__c, invoiceRecord);
                Mig_FreeeInvoiceWork__c workRecord = workByExternalKey.get(invoiceRecord.Freee_External_Key__c);
                if (workRecord != null) {
                    invoiceIdByWorkId.put(workRecord.Id, invoiceRecord.Id);
                }
            }
        }

        List<InvoiceLine__c> invoiceLinesToUpsert = new List<InvoiceLine__c>();
        Map<String, Mig_FreeeInvoiceLineWork__c> lineWorkByExternalKey = new Map<String, Mig_FreeeInvoiceLineWork__c>();
        List<Mig_FreeeInvoiceLineWork__c> existingLineWorkUpdates = new List<Mig_FreeeInvoiceLineWork__c>();
        Map<String, List<InvoiceLine__c>> existingLinesByMatchKey = getExistingLinesByMatchKey(existingInvoiceIds);
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            Id invoiceId = invoiceIdByWorkId.get(workRecord.Id);
            if (invoiceId == null) {
                continue;
            }
            Boolean allExistingLinesMatched = true;
            for (Mig_FreeeInvoiceLineWork__c lineWork : linesByWork.get(workRecord.Id)) {
                if (existingWorkIds.contains(workRecord.Id)) {
                    InvoiceLine__c existingLine = findExistingLine(invoiceId, lineWork, existingLinesByMatchKey);
                    if (existingLine == null) {
                        allExistingLinesMatched = false;
                    } else {
                        lineWork.CreatedInvoiceLine__c = existingLine.Id;
                        lineWork.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_IMPORTED;
                        existingLineWorkUpdates.add(lineWork);
                    }
                } else {
                    invoiceLinesToUpsert.add(toInvoiceLine(invoiceId, lineWork));
                    lineWorkByExternalKey.put(lineWork.ExternalKey__c, lineWork);
                }
            }
            if (!allExistingLinesMatched) {
                workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW;
                workRecord.ValidationMessage__c = '同じfreee請求書IDのSalesforce請求は存在しますが、すべての請求明細を照合できませんでした。既存の請求明細と移行Workの明細を確認してください。';
                continue;
            }
            workRecord.CreatedInvoice__c = invoiceId;
            workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_IMPORTED;
            workRecord.ValidationMessage__c = null;
        }

        if (!invoiceLinesToUpsert.isEmpty()) {
            upsert invoiceLinesToUpsert InvoiceLine__c.Freee_External_Key__c;
        }

        List<Invoice__c> invoicesToMarkSynced = new List<Invoice__c>();
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            if (!newWorkIds.contains(workRecord.Id)) {
                continue;
            }
            Id invoiceId = invoiceIdByWorkId.get(workRecord.Id);
            if (invoiceId != null) {
                invoicesToMarkSynced.add(new Invoice__c(
                    Id = invoiceId,
                    Sent_To_Freee__c = true,
                    Freee_Sync_Status__c = 'Success'
                ));
            }
        }
        if (!invoicesToMarkSynced.isEmpty()) {
            update invoicesToMarkSynced;
        }

        if (!lineWorkByExternalKey.isEmpty()) {
            for (InvoiceLine__c createdLine : [
                SELECT Id, Freee_External_Key__c
                FROM InvoiceLine__c
                WHERE Freee_External_Key__c IN :lineWorkByExternalKey.keySet()
            ]) {
                Mig_FreeeInvoiceLineWork__c sourceLineWork = lineWorkByExternalKey.get(createdLine.Freee_External_Key__c);
                sourceLineWork.CreatedInvoiceLine__c = createdLine.Id;
                sourceLineWork.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_IMPORTED;
            }
        }

        update works;
        if (!lineWorkByExternalKey.isEmpty()) {
            update lineWorkByExternalKey.values();
        }
        if (!existingLineWorkUpdates.isEmpty()) {
            update existingLineWorkUpdates;
        }
        updateContractLineItems(lineWorks, invoiceIdByWorkId, works);
    }

    private static Invoice__c toInvoice(Mig_FreeeInvoiceWork__c workRecord) {
        return new Invoice__c(
            Account__c = workRecord.ResolvedAccount__c,
            ParentContract__c = workRecord.ResolvedContract__c,
            ContractPeriod__c = workRecord.ResolvedContractPeriod__c,
            Billing_Date__c = workRecord.BillingDate__c,
            Payment_Date__c = workRecord.PaymentDate__c,
            Subject__c = String.isBlank(workRecord.Subject__c) ? workRecord.FreeeInvoiceNumber__c : workRecord.Subject__c,
            InvoiceAmount__c = workRecord.InvoiceAmount__c,
            TaxAmount__c = workRecord.TaxAmount__c,
            AmountWithTax__c = workRecord.InvoiceAmount__c,
            PaidAmount__c = workRecord.PaidAmount__c,
            UnpaidAmount__c = workRecord.UnpaidAmount__c,
            Freee_Invoice_Id__c = Mig_FreeeInvoiceWorkService.toDecimal(workRecord.FreeeInvoiceId__c),
            Freee_Invoice_Number__c = workRecord.FreeeInvoiceNumber__c,
            Freee_Partner_Id__c = Mig_FreeeInvoiceWorkService.toDecimal(workRecord.FreeePartnerId__c),
            Freee_Invoice_Status__c = workRecord.SendStatus__c,
            PaymentStatus__c = workRecord.PaymentStatus__c,
            Freee_Sync_Status__c = 'Success',
            Sent_To_Freee__c = false,
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_External_Key__c = workRecord.ExternalKey__c,
            MigrationSourceWork__c = workRecord.Id,
            MigrationImportedAt__c = System.now(),
            TargetPeriodStartDate__c = workRecord.TargetPeriodStartDate__c,
            TargetPeriodEndDate__c = workRecord.TargetPeriodEndDate__c
        );
    }

    private static InvoiceLine__c toInvoiceLine(Id invoiceId, Mig_FreeeInvoiceLineWork__c lineWork) {
        Decimal quantity = lineWork.Quantity__c == null || lineWork.Quantity__c == 0 ? 1 : lineWork.Quantity__c;
        Decimal unitPrice = lineWork.UnitPrice__c;
        if (unitPrice == null && lineWork.LineAmount__c != null && quantity != 0) {
            unitPrice = lineWork.LineAmount__c / quantity;
        }
        return new InvoiceLine__c(
            Invoice__c = invoiceId,
            ProductMaster__c = lineWork.ConfirmedProductMaster__c,
            Description__c = lineWork.Description__c,
            Quantity__c = quantity,
            Unit__c = lineWork.Unit__c,
            Unit_Price__c = unitPrice,
            Tax_Rate__c = lineWork.TaxRate__c == null ? 10 : lineWork.TaxRate__c,
            TaxAmount__c = lineWork.TaxAmount__c,
            AmountWithTax__c = lineWork.TaxAmount__c == null ? lineWork.LineAmount__c : lineWork.LineAmount__c + lineWork.TaxAmount__c,
            Freee_Line_Id__c = lineWork.FreeeLineId__c,
            Freee_External_Key__c = lineWork.ExternalKey__c,
            MigrationSourceLineWork__c = lineWork.Id
        );
    }

    private static Map<String, List<InvoiceLine__c>> getExistingLinesByMatchKey(Set<Id> invoiceIds) {
        Map<String, List<InvoiceLine__c>> linesByMatchKey = new Map<String, List<InvoiceLine__c>>();
        if (invoiceIds == null || invoiceIds.isEmpty()) {
            return linesByMatchKey;
        }
        for (InvoiceLine__c lineRecord : [
            SELECT Id,
                   Invoice__c,
                   ProductMaster__c,
                   Quantity__c,
                   AmountWithTax__c
            FROM InvoiceLine__c
            WHERE Invoice__c IN :invoiceIds
        ]) {
            String key = matchKey(
                lineRecord.Invoice__c,
                lineRecord.ProductMaster__c,
                lineRecord.Quantity__c,
                lineRecord.AmountWithTax__c
            );
            if (!linesByMatchKey.containsKey(key)) {
                linesByMatchKey.put(key, new List<InvoiceLine__c>());
            }
            linesByMatchKey.get(key).add(lineRecord);
        }
        return linesByMatchKey;
    }

    private static InvoiceLine__c findExistingLine(
        Id invoiceId,
        Mig_FreeeInvoiceLineWork__c lineWork,
        Map<String, List<InvoiceLine__c>> existingLinesByMatchKey
    ) {
        Decimal amountWithTax = lineWork.TaxAmount__c == null
            ? lineWork.LineAmount__c
            : lineWork.LineAmount__c + lineWork.TaxAmount__c;
        String key = matchKey(invoiceId, lineWork.ConfirmedProductMaster__c, lineWork.Quantity__c, amountWithTax);
        List<InvoiceLine__c> candidates = existingLinesByMatchKey.get(key);
        return candidates == null || candidates.size() != 1 ? null : candidates[0];
    }

    private static String matchKey(Id invoiceId, Id productId, Decimal quantity, Decimal amountWithTax) {
        return String.valueOf(invoiceId)
            + ':'
            + String.valueOf(productId)
            + ':'
            + normalizeDecimal(quantity)
            + ':'
            + normalizeDecimal(amountWithTax);
    }

    private static String normalizeDecimal(Decimal value) {
        return value == null ? '' : String.valueOf(value.setScale(2));
    }

    private static List<String> validateWork(Mig_FreeeInvoiceWork__c workRecord, List<Mig_FreeeInvoiceLineWork__c> lineWorks) {
        List<String> errors = new List<String>();
        if (workRecord.ImportStatus__c != Mig_FreeeInvoiceWorkService.STATUS_READY) {
            errors.add('請求書移行Workの取込ステータスが反映可能ではありません。検証を実行し、要確認事項を解消してください。');
        }
        if (Mig_FreeeInvoiceWorkService.toDecimal(workRecord.FreeeInvoiceId__c) == null) {
            errors.add('freee請求書IDが不正です。freee請求書IDに数値が入っているか確認してください。');
        }
        if (workRecord.ResolvedAccount__c == null) {
            errors.add('取引先を特定できません。freee取引先IDまたは取引先名の対応を確認してください。');
        }
        if (workRecord.ResolvedContract__c == null) {
            errors.add('契約管理を特定できません。取引先に有効な契約管理があるか確認してください。');
        }
        if (workRecord.ResolvedContractPeriod__c == null) {
            errors.add('契約期間を特定できません。請求日を含む契約期間があるか確認してください。');
        }
        if (String.isBlank(workRecord.ExternalKey__c)) {
            errors.add('移行用の一意キーが作成できていません。freee請求書IDまたは事業所IDを確認してください。');
        }
        if (lineWorks == null || lineWorks.isEmpty()) {
            errors.add('請求明細Workがありません。freee請求書に明細が存在するか確認してください。');
        } else {
            for (Mig_FreeeInvoiceLineWork__c lineWork : lineWorks) {
                if (lineWork.ConfirmedProductMaster__c == null) {
                    errors.add('商品マスタが未確定の請求明細Workがあります。候補商品を確認し、商品マスタを確定してください。');
                    break;
                }
            }
        }
        if (errors.isEmpty() && lineWorks != null) {
            for (Mig_FreeeInvoiceLineWork__c lineWork : lineWorks) {
                if (isLowSimilarityPriceMatch(lineWork)) {
                    errors.add(
                        '請求明細の件名と商品マスタ名が類似していないため、請求作成を停止しました。'
                        + '金額一致だけで商品が選ばれている可能性があります。'
                        + '明細「' + safeText(lineWork.Description__c) + '」の商品マスタを確認してください。'
                    );
                    break;
                }
            }
        }
        return errors;
    }

    private static Boolean isLowSimilarityPriceMatch(Mig_FreeeInvoiceLineWork__c lineWork) {
        if (lineWork == null || String.isBlank(lineWork.ResolveMessage__c)) {
            return false;
        }
        Boolean priceOnlyMatch = lineWork.ResolveMessage__c == 'Matched by unit price.'
            || lineWork.ResolveMessage__c == 'Matched by single-line amount.';
        if (!priceOnlyMatch || lineWork.ConfirmedProductMaster__r == null) {
            return false;
        }
        return textSimilarity(lineWork.Description__c, lineWork.ConfirmedProductMaster__r.Name) < 0.35;
    }

    private static Decimal textSimilarity(String leftText, String rightText) {
        String left = normalizeForSimilarity(leftText);
        String right = normalizeForSimilarity(rightText);
        if (String.isBlank(left) || String.isBlank(right)) {
            return 0;
        }
        if (left.contains(right) || right.contains(left)) {
            return 1;
        }

        Set<String> leftChars = toCharacterSet(left);
        Set<String> rightChars = toCharacterSet(right);
        Set<String> unionChars = new Set<String>();
        unionChars.addAll(leftChars);
        unionChars.addAll(rightChars);
        if (unionChars.isEmpty()) {
            return 0;
        }

        Integer intersectionCount = 0;
        for (String characterValue : leftChars) {
            if (rightChars.contains(characterValue)) {
                intersectionCount++;
            }
        }
        return Decimal.valueOf(intersectionCount) / Decimal.valueOf(unionChars.size());
    }

    private static Set<String> toCharacterSet(String source) {
        Set<String> values = new Set<String>();
        if (String.isBlank(source)) {
            return values;
        }
        for (Integer i = 0; i < source.length(); i++) {
            values.add(source.substring(i, i + 1));
        }
        return values;
    }

    private static String normalizeForSimilarity(String source) {
        if (String.isBlank(source)) {
            return '';
        }
        String normalized = source.toLowerCase();
        List<String> removableValues = new List<String>{
            ' ', '　', '_', '-', '・', '（', '）', '(', ')', '[', ']', '【', '】',
            '「', '」', '『', '』', ',', '，', '.', '．', '/', '／', ':', '：',
            ';', '；', '+', '＋', '株式会社', '有限会社', '合同会社', '年間利用料',
            '月額', '初期費用'
        };
        for (String value : removableValues) {
            normalized = normalized.replace(value, '');
        }
        return normalized;
    }

    private static String safeText(String source) {
        return String.isBlank(source) ? '(空白)' : source;
    }

    private static Map<Decimal, List<Invoice__c>> findExistingInvoicesByFreeeId(List<Mig_FreeeInvoiceWork__c> works) {
        Set<Decimal> freeeInvoiceIds = new Set<Decimal>();
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            Decimal freeeInvoiceId = Mig_FreeeInvoiceWorkService.toDecimal(workRecord.FreeeInvoiceId__c);
            if (freeeInvoiceId != null) {
                freeeInvoiceIds.add(freeeInvoiceId);
            }
        }

        Map<Decimal, List<Invoice__c>> invoicesByFreeeId = new Map<Decimal, List<Invoice__c>>();
        if (freeeInvoiceIds.isEmpty()) {
            return invoicesByFreeeId;
        }

        for (Invoice__c invoiceRecord : [
            SELECT Id,
                   Freee_Invoice_Id__c,
                   Freee_External_Key__c,
                   MigrationSourceWork__c
            FROM Invoice__c
            WHERE Freee_Invoice_Id__c IN :freeeInvoiceIds
        ]) {
            if (!invoicesByFreeeId.containsKey(invoiceRecord.Freee_Invoice_Id__c)) {
                invoicesByFreeeId.put(invoiceRecord.Freee_Invoice_Id__c, new List<Invoice__c>());
            }
            invoicesByFreeeId.get(invoiceRecord.Freee_Invoice_Id__c).add(invoiceRecord);
        }
        return invoicesByFreeeId;
    }

    private static List<String> validateExistingInvoiceMatch(
        Mig_FreeeInvoiceWork__c workRecord,
        Map<Decimal, List<Invoice__c>> existingInvoicesByFreeeId
    ) {
        List<String> errors = new List<String>();
        Decimal freeeInvoiceId = Mig_FreeeInvoiceWorkService.toDecimal(workRecord.FreeeInvoiceId__c);
        if (freeeInvoiceId == null) {
            return errors;
        }

        List<Invoice__c> existingInvoices = existingInvoicesByFreeeId.get(freeeInvoiceId);
        if (existingInvoices == null || existingInvoices.isEmpty()) {
            return errors;
        }
        if (existingInvoices.size() > 1) {
            errors.add('同じfreee請求書IDを持つSalesforce請求が複数存在します。freee請求書ID=' + String.valueOf(freeeInvoiceId));
            return errors;
        }

        Invoice__c existingInvoice = existingInvoices[0];
        if (!String.isBlank(existingInvoice.Freee_External_Key__c)
            && existingInvoice.Freee_External_Key__c != workRecord.ExternalKey__c
        ) {
            errors.add('既存のSalesforce請求のfreee外部キーが、この請求書移行Workと一致しません。既存請求と移行Workの対応を確認してください。');
        }
        if (existingInvoice.MigrationSourceWork__c != null && existingInvoice.MigrationSourceWork__c != workRecord.Id) {
            errors.add('既存のSalesforce請求は別の請求書移行Workに紐づいています。重複取込または紐づけ誤りがないか確認してください。');
        }
        return errors;
    }

    private static Invoice__c getSingleExistingInvoice(
        Mig_FreeeInvoiceWork__c workRecord,
        Map<Decimal, List<Invoice__c>> existingInvoicesByFreeeId
    ) {
        Decimal freeeInvoiceId = Mig_FreeeInvoiceWorkService.toDecimal(workRecord.FreeeInvoiceId__c);
        if (freeeInvoiceId == null) {
            return null;
        }
        List<Invoice__c> existingInvoices = existingInvoicesByFreeeId.get(freeeInvoiceId);
        return existingInvoices == null || existingInvoices.size() != 1 ? null : existingInvoices[0];
    }

    private static void updateContractLineItems(
        List<Mig_FreeeInvoiceLineWork__c> lineWorks,
        Map<Id, Id> invoiceIdByWorkId,
        List<Mig_FreeeInvoiceWork__c> works
    ) {
        Map<Id, Mig_FreeeInvoiceWork__c> workById = new Map<Id, Mig_FreeeInvoiceWork__c>(works);
        Map<Id, Id> invoiceIdByPeriodId = new Map<Id, Id>();
        Map<Id, Id> invoiceIdByCliId = new Map<Id, Id>();
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            Id invoiceId = invoiceIdByWorkId.get(workRecord.Id);
            if (invoiceId != null && workRecord.ResolvedContractPeriod__c != null) {
                invoiceIdByPeriodId.put(workRecord.ResolvedContractPeriod__c, invoiceId);
            }
        }
        for (Mig_FreeeInvoiceLineWork__c lineWork : lineWorks) {
            if (lineWork.ResolvedContractLineItem__c == null) {
                continue;
            }
            Mig_FreeeInvoiceWork__c workRecord = workById.get(lineWork.InvoiceWork__c);
            Id invoiceId = workRecord == null ? null : invoiceIdByWorkId.get(workRecord.Id);
            if (invoiceId != null) {
                invoiceIdByCliId.put(lineWork.ResolvedContractLineItem__c, invoiceId);
            }
        }
        if (!invoiceIdByPeriodId.isEmpty()) {
            for (ContractLineItem__c lineRecord : [
                SELECT Id,
                       ContractPeriod__c
                FROM ContractLineItem__c
                WHERE ContractPeriod__c IN :invoiceIdByPeriodId.keySet()
            ]) {
                invoiceIdByCliId.put(
                    lineRecord.Id,
                    invoiceIdByPeriodId.get(lineRecord.ContractPeriod__c)
                );
            }
        }
        List<ContractLineItem__c> updates = new List<ContractLineItem__c>();
        for (Id cliId : invoiceIdByCliId.keySet()) {
            updates.add(new ContractLineItem__c(
                Id = cliId,
                RelatedInvoice__c = invoiceIdByCliId.get(cliId)
            ));
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }
}
