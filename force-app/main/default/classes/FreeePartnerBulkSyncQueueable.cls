public with sharing class FreeePartnerBulkSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> accountIds;

    public FreeePartnerBulkSyncQueueable(List<Id> accountIds) {
        this.accountIds = accountIds == null ? new List<Id>() : new List<Id>(accountIds);
    }

    public void execute(QueueableContext context) {
        FreeePartnerBulkSyncService.syncPartners(accountIds);
    }
}
