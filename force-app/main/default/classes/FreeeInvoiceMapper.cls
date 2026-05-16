public with sharing class FreeeInvoiceMapper {
    private static final String DEFAULT_PARTNER_TITLE = '御中';
    private static final String PAYMENT_TYPE_TRANSFER = 'transfer';
    private static final String PAYMENT_TYPE_DIRECT_DEBIT = 'direct_debit';
    private static final String DEFAULT_WITHHOLDING_TAX_ENTRY_METHOD = 'out';

    public static String toRequestBody(
        Invoice__c invoice,
        List<InvoiceLine__c> lines,
        FreeeConfigService.Config config
    ) {
        Long accountItemId = resolveAccountItemId(invoice);

        Map<String, Object> body = new Map<String, Object>();
        body.put('company_id', config.companyId);
        body.put('billing_date', String.valueOf(invoice.Billing_Date__c));
        body.put('tax_entry_method', config.taxEntryMethod);
        body.put('tax_fraction', config.taxFraction);
        body.put(
            'withholding_tax_entry_method',
            resolveWithholdingTaxEntryMethod(config.withholdingTaxEntryMethod)
        );
        body.put('partner_title', DEFAULT_PARTNER_TITLE);
        body.put(
            'partner_id',
            Long.valueOf(String.valueOf(invoice.Account__r.Freee_Partner_Id__c))
        );

        if (config.templateId != null) {
            body.put('template_id', config.templateId);
        }
        if (invoice.Payment_Date__c != null) {
            body.put('payment_date', String.valueOf(invoice.Payment_Date__c));
        }

        String paymentType = resolvePaymentType(invoice, config.paymentType);
        if (String.isNotBlank(paymentType)) {
            body.put('payment_type', paymentType);
        }
        if (String.isNotBlank(invoice.Subject__c)) {
            body.put('subject', invoice.Subject__c);
        }
        if (String.isNotBlank(invoice.Memo__c)) {
            body.put('memo', invoice.Memo__c);
        }

        List<Object> freeeLines = new List<Object>();
        for (InvoiceLine__c line : lines) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('type', 'item');
            row.put('description', line.Description__c);
            row.put('quantity', line.Quantity__c);
            row.put('unit_price', String.valueOf(line.Unit_Price__c.setScale(0)));
            row.put('tax_rate', Integer.valueOf(line.Tax_Rate__c));
            row.put('account_item_id', accountItemId);

            if (line.Reduced_Tax__c != null) {
                row.put('reduced_tax_rate', line.Reduced_Tax__c);
            }
            if (line.Withholding__c != null) {
                row.put('withholding', line.Withholding__c);
            }

            freeeLines.add(row);
        }

        body.put('lines', freeeLines);
        return JSON.serialize(body);
    }

    private static Long resolveAccountItemId(Invoice__c invoice) {
        String accountItemKey = invoice.Freee_Account_Item_Picklist__c;
        if (String.isBlank(accountItemKey)) {
            throw new AuraHandledException('Freee計上科目が設定されていません。');
        }

        List<Freee_Account_Item_Mappings__c> mappings = [
            SELECT Key__c,
                   Freee_Account_Item_Id__c,
                   Is_Active__c
            FROM Freee_Account_Item_Mappings__c
            WHERE Key__c = :accountItemKey
            AND Is_Active__c = true
            LIMIT 1
        ];

        if (mappings.isEmpty()) {
            throw new AuraHandledException(
                'Freee勘定科目マッピングが見つかりません。キー: ' + accountItemKey
            );
        }

        String freeeAccountItemId = mappings[0].Freee_Account_Item_Id__c;
        if (String.isBlank(freeeAccountItemId)) {
            throw new AuraHandledException(
                'Freee勘定科目マッピングに freee勘定科目ID が設定されていません。キー: '
                + accountItemKey
            );
        }

        return Long.valueOf(freeeAccountItemId);
    }

    private static String resolvePaymentType(Invoice__c invoice, String defaultPaymentType) {
        String value = String.isBlank(invoice.Payment_Type__c)
            ? defaultPaymentType
            : invoice.Payment_Type__c;

        if (String.isBlank(value)) {
            return PAYMENT_TYPE_TRANSFER;
        }

        String normalized = value.trim().toLowerCase();
        if (normalized == PAYMENT_TYPE_TRANSFER || normalized == PAYMENT_TYPE_DIRECT_DEBIT) {
            return normalized;
        }

        throw new AuraHandledException(
            'payment_type は transfer または direct_debit を指定してください。現在値: ' + value
        );
    }

    private static String resolveWithholdingTaxEntryMethod(String value) {
        if (String.isBlank(value)) {
            return DEFAULT_WITHHOLDING_TAX_ENTRY_METHOD;
        }

        return value.trim().toLowerCase();
    }
}
