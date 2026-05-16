public with sharing class FreeeQuotationMapper {
    private static final String DEFAULT_PARTNER_TITLE = '御中';
    private static final String DEFAULT_WITHHOLDING_TAX_ENTRY_METHOD = 'out';

    public static String toRequestBody(
        Quotation__c quotation,
        List<QuotationLine__c> lines,
        FreeeConfigService.Config config
    ) {
        Map<String, Object> body = new Map<String, Object>();
        body.put('company_id', config.companyId);

        if (config.quotationTemplateId != null) {
            body.put('template_id', config.quotationTemplateId);
        }

        body.put(
            'partner_id',
            Long.valueOf(String.valueOf(quotation.Account__r.Freee_Partner_Id__c))
        );
        body.put('quotation_date', String.valueOf(quotation.Issue_Date__c));
        body.put('tax_entry_method', config.taxEntryMethod);
        body.put('tax_fraction', config.taxFraction);
        body.put(
            'withholding_tax_entry_method',
            resolveWithholdingTaxEntryMethod(config.withholdingTaxEntryMethod)
        );
        body.put('partner_title', DEFAULT_PARTNER_TITLE);

        if (String.isNotBlank(quotation.Subject__c)) {
            body.put('subject', quotation.Subject__c);
        }
        if (String.isNotBlank(quotation.Memo__c)) {
            body.put('memo', quotation.Memo__c);
        }
        if (quotation.Expiration_Date__c != null) {
            body.put('expiration_date', String.valueOf(quotation.Expiration_Date__c));
        }

        List<Object> freeeLines = new List<Object>();
        for (QuotationLine__c line : lines) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('type', 'item');
            row.put('description', line.Description__c);
            row.put('quantity', line.Quantity__c);
            row.put('unit_price', String.valueOf(line.Unit_Price__c.setScale(0)));
            row.put('tax_rate', Integer.valueOf(line.Tax_Rate__c));

            if (line.Withholding__c != null) {
                row.put('withholding', line.Withholding__c);
            }

            freeeLines.add(row);
        }

        body.put('lines', freeeLines);
        return JSON.serialize(body);
    }

    private static String resolveWithholdingTaxEntryMethod(String value) {
        if (String.isBlank(value)) {
            return DEFAULT_WITHHOLDING_TAX_ENTRY_METHOD;
        }

        return value.trim().toLowerCase();
    }
}
