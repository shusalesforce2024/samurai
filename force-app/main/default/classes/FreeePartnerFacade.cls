public with sharing class FreeePartnerFacade {
    private static final String DEFAULT_CONFIG_NAME = 'Default';

    public class Result {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String freeePartnerId;
    }

    public static Result syncPartner(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('取引先IDが指定されていません。');
        }

        Account acc = getAccount(accountId);

        if (!String.isBlank(String.valueOf(acc.Freee_Partner_Id__c))) {
            throw new AuraHandledException('この取引先はすでにfreee取引先IDが設定されています。');
        }

        Freee_Configs__c config = getConfig();
        String existingPartnerId = findExistingPartnerId(acc, config);

        if (!String.isBlank(existingPartnerId)) {
            savePartnerId(acc, existingPartnerId);
            return buildResult(
                '既存のfreee取引先を取得し、取引先IDをSalesforceへ保存しました。',
                existingPartnerId
            );
        }

        String requestBody = buildRequestBody(acc, config);
        HttpResponse res = FreeePartnerService.createPartner(requestBody);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new AuraHandledException('freee取引先作成に失敗しました: ' + res.getBody());
        }

        String partnerId = extractPartnerId(res.getBody());
        savePartnerId(acc, partnerId);

        return buildResult(
            'freee取引先を作成し、取引先IDをSalesforceへ保存しました。',
            partnerId
        );
    }

    private static Account getAccount(Id accountId) {
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new AuraHandledException('取引先の参照権限がありません。');
        }

        List<Account> accounts = [
            SELECT Id,
                   Name,
                   Freee_Partner_Id__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        if (accounts.isEmpty()) {
            throw new AuraHandledException('対象の取引先が見つかりません。');
        }

        return accounts[0];
    }

    private static Freee_Configs__c getConfig() {
        if (!Schema.sObjectType.Freee_Configs__c.isAccessible()) {
            throw new AuraHandledException('Freee設定の参照権限がありません。');
        }

        List<Freee_Configs__c> configs = [
            SELECT Id,
                   Name,
                   Company_Id__c
            FROM Freee_Configs__c
            WHERE Name = :DEFAULT_CONFIG_NAME
            LIMIT 1
        ];

        if (configs.isEmpty()) {
            configs = [
                SELECT Id,
                       Name,
                       Company_Id__c
                FROM Freee_Configs__c
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
        }

        if (configs.isEmpty()) {
            throw new AuraHandledException('Freee設定が見つかりません。Freee_Configs__c のレコードを作成してください。');
        }

        return configs[0];
    }

    private static String findExistingPartnerId(Account acc, Freee_Configs__c config) {
        String companyId = String.valueOf(config.Company_Id__c);
        if (String.isBlank(companyId)) {
            throw new AuraHandledException('Freee設定の Company_Id__c が未設定です。');
        }

        HttpResponse res = FreeePartnerService.searchPartners(companyId, acc.Name);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new AuraHandledException('freee取引先検索に失敗しました: ' + res.getBody());
        }

        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> partners = (List<Object>) responseMap.get('partners');

        if (partners == null || partners.isEmpty()) {
            return null;
        }

        for (Object partnerObject : partners) {
            Map<String, Object> partner = (Map<String, Object>) partnerObject;
            if (String.valueOf(partner.get('name')) == acc.Name && partner.get('id') != null) {
                return String.valueOf(partner.get('id'));
            }
        }

        return null;
    }

    private static String buildRequestBody(Account acc, Freee_Configs__c config) {
        if (String.isBlank(String.valueOf(config.Company_Id__c))) {
            throw new AuraHandledException('Freee設定の Company_Id__c が未設定です。');
        }

        Map<String, Object> body = new Map<String, Object>();
        body.put('company_id', Long.valueOf(String.valueOf(config.Company_Id__c)));
        body.put('name', acc.Name);

        return JSON.serialize(body);
    }

    private static String extractPartnerId(String responseBody) {
        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        Map<String, Object> partner =
            (Map<String, Object>) responseMap.get('partner');

        if (partner == null || partner.get('id') == null) {
            throw new AuraHandledException('freee取引先IDをレスポンスから取得できませんでした。');
        }

        return String.valueOf(partner.get('id'));
    }

    private static void savePartnerId(Account acc, String partnerId) {
        if (!Schema.sObjectType.Account.isUpdateable()) {
            throw new AuraHandledException('取引先の更新権限がありません。');
        }

        acc.Freee_Partner_Id__c = Decimal.valueOf(partnerId);
        update acc;
    }

    private static Result buildResult(String message, String partnerId) {
        Result result = new Result();
        result.success = true;
        result.message = message;
        result.freeePartnerId = partnerId;
        return result;
    }
}
