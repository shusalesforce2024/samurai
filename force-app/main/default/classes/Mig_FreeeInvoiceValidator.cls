public with sharing class Mig_FreeeInvoiceValidator {
    public static void validateAll() {
        Mig_FreeeInvoiceReferenceResolver.resolveAll();
        Mig_FreeeInvoiceProductResolver.resolveAll();

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
                messages.add('FreeeInvoiceId__c is required.');
            }
            if (String.isBlank(workRecord.ExternalKey__c)) {
                messages.add('ExternalKey__c is required.');
            }
            if (workRecord.ResolvedAccount__c == null) {
                messages.add('ResolvedAccount__c is required.');
            }
            if (workRecord.ResolvedContract__c == null) {
                messages.add('ResolvedContract__c is required.');
            }
            if (workRecord.ResolvedContractPeriod__c == null) {
                messages.add('ResolvedContractPeriod__c is required.');
            }
            if (workRecord.InvoiceLineWorks__r == null || workRecord.InvoiceLineWorks__r.isEmpty()) {
                messages.add('At least one invoice line work record is required.');
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
                    messages.add('All non-excluded line works must have ConfirmedProductMaster__c.');
                }
                if (workRecord.InvoiceAmount__c != null && Math.abs(workRecord.InvoiceAmount__c - lineTotal) > 1) {
                    messages.add('InvoiceAmount__c does not match line total. invoice=' + workRecord.InvoiceAmount__c + ', lines=' + lineTotal);
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
