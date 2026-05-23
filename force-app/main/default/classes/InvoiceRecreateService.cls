public with sharing class InvoiceRecreateService {
    private static final String CANCELLED = '取消済';
    private static final String SEND_WAITING = '送付待ち';
    private static final String PAYMENT_WAITING = '決済待ち';

    public static Id recreateInvoice(Id cancelledInvoiceId) {
        if (cancelledInvoiceId == null) {
            throw new AuraHandledException('請求IDが指定されていません。');
        }

        Invoice__c source = getInvoice(cancelledInvoiceId);
        if (source.CancelStatus__c != CANCELLED) {
            throw new AuraHandledException('取消済みの請求のみ再作成できます。');
        }

        Invoice__c recreated = new Invoice__c(
            Account__c = source.Account__c,
            Billing_Date__c = source.Billing_Date__c,
            ContractPeriod__c = source.ContractPeriod__c,
            Freee_Account_Item_Picklist__c = source.Freee_Account_Item_Picklist__c,
            Freee_Invoice_Status__c = SEND_WAITING,
            Freee_Partner_Id__c = source.Freee_Partner_Id__c,
            Freee_Sync_Status__c = 'Processing',
            Memo__c = source.Memo__c,
            OriginalInvoice__c = source.Id,
            ParentContract__c = source.ParentContract__c,
            ParentOpportunity__c = source.ParentOpportunity__c,
            PaymentStatus__c = PAYMENT_WAITING,
            Payment_Date__c = source.Payment_Date__c,
            Payment_Type__c = source.Payment_Type__c,
            Subject__c = source.Subject__c,
            TargetPeriodEndDate__c = source.TargetPeriodEndDate__c,
            TargetPeriodStartDate__c = source.TargetPeriodStartDate__c
        );
        insert recreated;

        List<InvoiceLine__c> linesToInsert = new List<InvoiceLine__c>();
        for (InvoiceLine__c sourceLine : getInvoiceLines(source.Id)) {
            linesToInsert.add(new InvoiceLine__c(
                Description__c = sourceLine.Description__c,
                DiscountRate__c = sourceLine.DiscountRate__c,
                DiscountedUnitPrice__c = sourceLine.DiscountedUnitPrice__c,
                Freee_Account_Item_Id__c = sourceLine.Freee_Account_Item_Id__c,
                Invoice__c = recreated.Id,
                LineType__c = sourceLine.LineType__c,
                Product2__c = sourceLine.Product2__c,
                Quantity__c = sourceLine.Quantity__c,
                QuotationLine__c = sourceLine.QuotationLine__c,
                Reduced_Tax__c = sourceLine.Reduced_Tax__c,
                Tax_Rate__c = sourceLine.Tax_Rate__c,
                Unit_Price__c = sourceLine.Unit_Price__c,
                Withholding__c = sourceLine.Withholding__c
            ));
        }
        if (!linesToInsert.isEmpty()) {
            insert linesToInsert;
        }

        return recreated.Id;
    }

    private static Invoice__c getInvoice(Id invoiceId) {
        List<Invoice__c> invoices = [
            SELECT Id,
                   Account__c,
                   Billing_Date__c,
                   CancelStatus__c,
                   ContractPeriod__c,
                   Freee_Account_Item_Picklist__c,
                   Freee_Partner_Id__c,
                   Memo__c,
                   ParentContract__c,
                   ParentOpportunity__c,
                   Payment_Date__c,
                   Payment_Type__c,
                   Subject__c,
                   TargetPeriodEndDate__c,
                   TargetPeriodStartDate__c
            FROM Invoice__c
            WHERE Id = :invoiceId
            LIMIT 1
        ];
        if (invoices.isEmpty()) {
            throw new AuraHandledException('対象の請求が見つかりません。');
        }
        return invoices[0];
    }

    private static List<InvoiceLine__c> getInvoiceLines(Id invoiceId) {
        return [
            SELECT Description__c,
                   DiscountRate__c,
                   DiscountedUnitPrice__c,
                   Freee_Account_Item_Id__c,
                   LineType__c,
                   Product2__c,
                   Quantity__c,
                   QuotationLine__c,
                   Reduced_Tax__c,
                   Tax_Rate__c,
                   Unit_Price__c,
                   Withholding__c
            FROM InvoiceLine__c
            WHERE Invoice__c = :invoiceId
            ORDER BY CreatedDate ASC
        ];
    }
}
