public with sharing class FreeePartnerBulkSyncService {
    public static final Integer MAX_SYNC_SIZE = 50;
    private static final String DEFAULT_CONFIG_NAME = 'Default';

    public class BulkSyncException extends Exception {}

    public class ItemResult {
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String freeePartnerId { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    public class Summary {
        @AuraEnabled public Integer totalCount { get; set; }
        @AuraEnabled public Integer successCount { get; set; }
        @AuraEnabled public Integer skippedCount { get; set; }
        @AuraEnabled public Integer failedCount { get; set; }
        @AuraEnabled public List<ItemResult> results { get; set; }

        public Summary() {
            totalCount = 0;
            successCount = 0;
            skippedCount = 0;
            failedCount = 0;
            results = new List<ItemResult>();
        }
    }

    private class PendingUpdate {
        Account accountRecord;
        ItemResult result;

        PendingUpdate(Account accountRecord, ItemResult result) {
            this.accountRecord = accountRecord;
            this.result = result;
        }
    }

    public static Summary syncPartners(List<Id> accountIds) {
        List<Id> targetIds = normalizeIds(accountIds);
        if (targetIds.isEmpty()) {
            throw new BulkSyncException('同期対象の取引先を選択してください。');
        }
        if (targetIds.size() > MAX_SYNC_SIZE) {
            throw new BulkSyncException('一度に同期できる取引先は' + MAX_SYNC_SIZE + '件までです。選択件数を減らして再実行してください。');
        }

        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new BulkSyncException('取引先の参照権限がありません。');
        }
        if (!Schema.sObjectType.Account.isUpdateable()) {
            throw new BulkSyncException('取引先の更新権限がありません。');
        }

        Freee_Configs__c config = getConfig();
        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id,
                   Name,
                   Freee_Partner_Id__c
            FROM Account
            WHERE Id IN :targetIds
        ]);

        Summary summary = new Summary();
        summary.totalCount = targetIds.size();
        List<PendingUpdate> pendingUpdates = new List<PendingUpdate>();

        for (Id accountId : targetIds) {
            Account accountRecord = accountsById.get(accountId);
            ItemResult result = buildBaseResult(accountId, accountRecord);

            if (accountRecord == null) {
                markFailed(summary, result, '対象の取引先が見つかりません。');
                continue;
            }

            if (!String.isBlank(String.valueOf(accountRecord.Freee_Partner_Id__c))) {
                result.status = 'スキップ';
                result.success = true;
                result.freeePartnerId = String.valueOf(accountRecord.Freee_Partner_Id__c);
                result.message = 'すでにfreee取引先IDが設定されているためスキップしました。';
                summary.skippedCount++;
                summary.results.add(result);
                continue;
            }

            try {
                String partnerId = resolvePartnerId(accountRecord, config);
                accountRecord.Freee_Partner_Id__c = Decimal.valueOf(partnerId);
                result.status = '成功';
                result.success = true;
                result.freeePartnerId = partnerId;
                result.message = 'freee取引先を同期し、取引先IDをSalesforceへ保存しました。';
                pendingUpdates.add(new PendingUpdate(accountRecord, result));
            } catch (Exception e) {
                markFailed(summary, result, e.getMessage());
            }
        }

        applyUpdates(summary, pendingUpdates);
        return summary;
    }

    private static List<Id> normalizeIds(List<Id> accountIds) {
        List<Id> normalized = new List<Id>();
        Set<Id> seen = new Set<Id>();
        if (accountIds == null) {
            return normalized;
        }

        for (Id accountId : accountIds) {
            if (accountId != null && !seen.contains(accountId)) {
                seen.add(accountId);
                normalized.add(accountId);
            }
        }
        return normalized;
    }

    private static ItemResult buildBaseResult(Id accountId, Account accountRecord) {
        ItemResult result = new ItemResult();
        result.accountId = accountId;
        result.accountName = accountRecord == null ? null : accountRecord.Name;
        result.success = false;
        return result;
    }

    private static Freee_Configs__c getConfig() {
        if (!Schema.sObjectType.Freee_Configs__c.isAccessible()) {
            throw new BulkSyncException('Freee設定の参照権限がありません。');
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
            throw new BulkSyncException('Freee設定が見つかりません。Freee_Configs__c のレコードを作成してください。');
        }
        if (String.isBlank(String.valueOf(configs[0].Company_Id__c))) {
            throw new BulkSyncException('Freee設定の Company_Id__c が未設定です。');
        }

        return configs[0];
    }

    private static String resolvePartnerId(Account accountRecord, Freee_Configs__c config) {
        String companyId = String.valueOf(config.Company_Id__c);
        String existingPartnerId = findExistingPartnerId(accountRecord, companyId);
        if (!String.isBlank(existingPartnerId)) {
            return existingPartnerId;
        }

        HttpResponse response = FreeePartnerService.createPartner(buildRequestBody(accountRecord, config));
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new BulkSyncException('freee取引先作成に失敗しました: ' + response.getBody());
        }

        return extractPartnerId(response.getBody());
    }

    private static String findExistingPartnerId(Account accountRecord, String companyId) {
        HttpResponse response = FreeePartnerService.searchPartners(companyId, accountRecord.Name);
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new BulkSyncException('freee取引先検索に失敗しました: ' + response.getBody());
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        List<Object> partners = (List<Object>) responseMap.get('partners');
        if (partners == null || partners.isEmpty()) {
            return null;
        }

        for (Object partnerObject : partners) {
            Map<String, Object> partner = (Map<String, Object>) partnerObject;
            if (String.valueOf(partner.get('name')) == accountRecord.Name && partner.get('id') != null) {
                return String.valueOf(partner.get('id'));
            }
        }
        return null;
    }

    private static String buildRequestBody(Account accountRecord, Freee_Configs__c config) {
        Map<String, Object> body = new Map<String, Object>();
        body.put('company_id', Long.valueOf(String.valueOf(config.Company_Id__c)));
        body.put('name', accountRecord.Name);
        return JSON.serialize(body);
    }

    private static String extractPartnerId(String responseBody) {
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        Map<String, Object> partner = (Map<String, Object>) responseMap.get('partner');
        if (partner == null || partner.get('id') == null) {
            throw new BulkSyncException('freee取引先IDをレスポンスから取得できませんでした。');
        }
        return String.valueOf(partner.get('id'));
    }

    private static void applyUpdates(Summary summary, List<PendingUpdate> pendingUpdates) {
        if (pendingUpdates.isEmpty()) {
            return;
        }

        List<Account> accountsToUpdate = new List<Account>();
        for (PendingUpdate pendingUpdate : pendingUpdates) {
            accountsToUpdate.add(pendingUpdate.accountRecord);
        }

        Database.SaveResult[] saveResults = Database.update(accountsToUpdate, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            ItemResult result = pendingUpdates[i].result;
            if (saveResults[i].isSuccess()) {
                summary.successCount++;
            } else {
                result.status = '失敗';
                result.success = false;
                result.message = saveResults[i].getErrors()[0].getMessage();
                summary.failedCount++;
            }
            summary.results.add(result);
        }
    }

    private static void markFailed(Summary summary, ItemResult result, String message) {
        result.status = '失敗';
        result.success = false;
        result.message = message;
        summary.failedCount++;
        summary.results.add(result);
    }
}
