public with sharing class Mig_FreeeInvoiceValidator {
    public static void validateAll() {
        Mig_FreeeInvoiceReferenceResolver.resolveAll();
        Mig_FreeeInvoiceProductResolver.resolveProducts();
        FreeeInvoiceContractProvisioningService.provisionAll();
        Mig_FreeeInvoiceReferenceResolver.resolveAll();
        Mig_FreeeInvoiceProductResolver.resolveContractLineItems();

        List<Mig_FreeeInvoiceWork__c> works = [
            SELECT Id,
                   FreeeInvoiceId__c,
                   ExternalKey__c,
                   InvoiceAmount__c,
                   ResolvedAccount__c,
                   ResolvedContract__c,
                   ResolvedContractPeriod__c,
                   ImportStatus__c,
                   ValidationMessage__c,
                   (SELECT Id,
                           ConfirmedProductMaster__c,
                           ImportStatus__c,
                           LineAmount__c,
                           TaxAmount__c,
                           ProductResolveStatus__c
                    FROM InvoiceLineWorks__r)
            FROM Mig_FreeeInvoiceWork__c
            WHERE ImportStatus__c IN :new List<String>{
                Mig_FreeeInvoiceWorkService.STATUS_FETCHED,
                Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW,
                Mig_FreeeInvoiceWorkService.STATUS_READY
            }
        ];
        if (works.isEmpty()) {
            return;
        }

        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            List<String> messages = new List<String>();
            if (String.isBlank(workRecord.FreeeInvoiceId__c)) {
                messages.add('freee請求書IDが取得できていません。freee請求データを確認してください。');
            }
            if (String.isBlank(workRecord.ExternalKey__c)) {
                messages.add('移行用の一意キーが作成できていません。freee請求書IDまたは事業所IDを確認してください。');
            }
            if (workRecord.ResolvedAccount__c == null) {
                messages.add('取引先を特定できません。freee取引先IDまたは取引先名の対応を確認してください。');
            }
            if (workRecord.ResolvedContract__c == null) {
                messages.add('契約管理を特定できません。取引先に有効な契約管理があるか確認してください。');
            }
            if (workRecord.ResolvedContractPeriod__c == null) {
                messages.add('契約期間を特定できません。請求日を含む契約期間があるか確認してください。');
            }
            if (workRecord.InvoiceLineWorks__r == null || workRecord.InvoiceLineWorks__r.isEmpty()) {
                messages.add('請求明細Workがありません。freee請求書に明細が存在するか確認してください。');
            } else {
                Decimal lineTotal = 0;
                Boolean hasUnconfirmedProduct = false;
                for (Mig_FreeeInvoiceLineWork__c line : workRecord.InvoiceLineWorks__r) {
                    if (line.ImportStatus__c == Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED) {
                        continue;
                    }
                    Decimal lineAmountWithTax = line.LineAmount__c == null ? 0 : line.LineAmount__c;
                    if (line.TaxAmount__c != null) {
                        lineAmountWithTax += line.TaxAmount__c;
                    }
                    lineTotal += lineAmountWithTax;
                    if (line.ConfirmedProductMaster__c == null) {
                        hasUnconfirmedProduct = true;
                    }
                }
                if (hasUnconfirmedProduct) {
                    messages.add('商品マスタが未確定の請求明細Workがあります。候補商品を確認し、商品マスタを確定してください。');
                }
                if (workRecord.InvoiceAmount__c != null && Math.abs(workRecord.InvoiceAmount__c - lineTotal) > 1) {
                    messages.add('請求金額と明細合計が一致していません。請求金額=' + workRecord.InvoiceAmount__c + '、明細合計=' + lineTotal);
                }
            }

            if (messages.isEmpty()) {
                workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_READY;
                workRecord.ValidationMessage__c = null;
            } else {
                workRecord.ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW;
                workRecord.ValidationMessage__c = String.join(messages, '\n');
            }
        }
        update works;
    }
}
