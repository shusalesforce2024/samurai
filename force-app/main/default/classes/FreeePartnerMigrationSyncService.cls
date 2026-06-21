public with sharing class FreeePartnerMigrationSyncService {
    public static final Integer MAX_MIGRATION_SIZE = 2000;
    public static final Integer QUEUEABLE_SCOPE_SIZE = 45;

    public class MigrationSyncException extends Exception {}

    public static List<Id> enqueue(List<Id> accountIds) {
        List<Id> targetIds = normalizeIds(accountIds);
        if (targetIds.isEmpty()) {
            throw new MigrationSyncException('同期対象の取引先を指定してください。');
        }
        if (targetIds.size() > MAX_MIGRATION_SIZE) {
            throw new MigrationSyncException('移行用の一括同期は1回あたり' + MAX_MIGRATION_SIZE + '件までです。');
        }

        List<Id> jobIds = new List<Id>();
        for (Integer startIndex = 0; startIndex < targetIds.size(); startIndex += QUEUEABLE_SCOPE_SIZE) {
            List<Id> chunk = new List<Id>();
            Integer endIndex = Math.min(startIndex + QUEUEABLE_SCOPE_SIZE, targetIds.size());
            for (Integer i = startIndex; i < endIndex; i++) {
                chunk.add(targetIds[i]);
            }
            jobIds.add(System.enqueueJob(new FreeePartnerBulkSyncQueueable(chunk)));
        }
        return jobIds;
    }

    public static List<Id> enqueueTodayUnsynced(Integer maxRecords) {
        Integer limitSize = maxRecords == null ? MAX_MIGRATION_SIZE : maxRecords;
        if (limitSize <= 0 || limitSize > MAX_MIGRATION_SIZE) {
            throw new MigrationSyncException('移行用の一括同期は1回あたり1件以上' + MAX_MIGRATION_SIZE + '件までです。');
        }

        List<Id> accountIds = new List<Id>();
        for (Account accountRecord : [
            SELECT Id
            FROM Account
            WHERE CreatedDate = TODAY
              AND Freee_Partner_Id__c = null
            ORDER BY Name
            LIMIT :limitSize
        ]) {
            accountIds.add(accountRecord.Id);
        }
        return enqueue(accountIds);
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
}
