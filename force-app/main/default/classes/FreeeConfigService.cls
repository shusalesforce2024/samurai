public with sharing class FreeeConfigService {
    public class Config {
        public Long companyId;
        public Long templateId;
        public Long quotationTemplateId;
        public String paymentType;
        public String taxEntryMethod;
        public String taxFraction;
        public String withholding;
        public String withholdingTaxEntryMethod;
        public String invoiceBaseUrl;
    }

    public static Config getConfig() {
        if (!Schema.sObjectType.Freee_Configs__c.isAccessible()) {
            throw new AuraHandledException('設定オブジェクト Freee_Configs__c の参照権限がありません。');
        }

        List<Freee_Configs__c> configRecords = [
            SELECT Company_Id__c,
                   Invoice_Base_Url__c,
                   Payment_Type__c,
                   Quotation_Template_Id__c,
                   Tax_Entry_Method__c,
                   Tax_Fraction__c,
                   Template_Id__c,
                   Withholding__c,
                   Withholding_Tax_Entry_Method__c
            FROM Freee_Configs__c
            LIMIT 1
        ];

        if (configRecords.isEmpty()) {
            throw new AuraHandledException(
                '設定オブジェクト Freee_Configs__c の設定レコードが見つかりません。'
            );
        }

        Freee_Configs__c configRecord = configRecords[0];

        Config config = new Config();
        config.companyId = requireLongValue(configRecord.Company_Id__c, 'Company_Id__c');
        config.templateId = requireLongValue(configRecord.Template_Id__c, 'Template_Id__c');
        config.quotationTemplateId = optionalLongValue(
            configRecord.Quotation_Template_Id__c,
            'Quotation_Template_Id__c'
        );
        config.paymentType = configRecord.Payment_Type__c;
        config.taxEntryMethod = requireTextValue(
            configRecord.Tax_Entry_Method__c,
            'Tax_Entry_Method__c'
        );
        config.taxFraction = requireTextValue(
            configRecord.Tax_Fraction__c,
            'Tax_Fraction__c'
        );
        config.withholding = configRecord.Withholding__c;
        config.withholdingTaxEntryMethod = configRecord.Withholding_Tax_Entry_Method__c;
        config.invoiceBaseUrl = requireTextValue(
            configRecord.Invoice_Base_Url__c,
            'Invoice_Base_Url__c'
        );
        return config;
    }

    public static Long requireQuotationTemplateId(Config config) {
        if (config == null || config.quotationTemplateId == null) {
            throw new AuraHandledException(
                '設定項目 Quotation_Template_Id__c（見積テンプレートID）が設定されていません。'
            );
        }

        return config.quotationTemplateId;
    }

    private static Long requireLongValue(Object rawValue, String fieldName) {
        String value = String.valueOf(rawValue);
        if (String.isBlank(value)) {
            throw new AuraHandledException(
                '設定オブジェクト Freee_Configs__c の必須項目が未設定です。対象項目: '
                + fieldName
            );
        }

        try {
            return Long.valueOf(value);
        } catch (Exception e) {
            throw new AuraHandledException(
                '設定オブジェクト Freee_Configs__c の数値設定が不正です。'
                + fieldName
                + ' = '
                + value
            );
        }
    }

    private static Long optionalLongValue(Object rawValue, String fieldName) {
        String value = String.valueOf(rawValue);
        if (String.isBlank(value)) {
            return null;
        }

        try {
            return Long.valueOf(value);
        } catch (Exception e) {
            throw new AuraHandledException(
                '設定オブジェクト Freee_Configs__c の数値設定が不正です。'
                + fieldName
                + ' = '
                + value
            );
        }
    }

    private static String requireTextValue(String value, String fieldName) {
        if (String.isBlank(value)) {
            throw new AuraHandledException(
                '設定オブジェクト Freee_Configs__c の必須項目が未設定です。対象項目: '
                + fieldName
            );
        }

        return value;
    }
}