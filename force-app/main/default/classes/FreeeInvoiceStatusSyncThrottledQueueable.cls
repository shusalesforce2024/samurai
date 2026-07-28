public with sharing class FreeeInvoiceStatusSyncThrottledQueueable
    implements Queueable, Database.AllowsCallouts {
    @TestVisible static final Integer CHUNK_SIZE = 20;
    @TestVisible static final Integer MAX_INVOICES_PER_NIGHT = 1000;
    @TestVisible static final Integer NEXT_CHUNK_DELAY_MINUTES = 2;
    private static final Integer MIN_RATE_LIMIT_RETRY_MINUTES = 3;
    private static final String PAYMENT_DONE = '決済済み';
    private static final String CANCELLED = '取消済';

    private Date runDate;
    private List<Id> remainingInvoiceIds;
    private Integer processedCount;
    private Boolean dailyCapReached;

    public FreeeInvoiceStatusSyncThrottledQueueable(
        Date runDate,
        List<Id> remainingInvoiceIds,
        Integer processedCount,
        Boolean dailyCapReached
    ) {
        this.runDate = runDate == null ? Date.today() : runDate;
        this.remainingInvoiceIds = remainingInvoiceIds;
        this.processedCount = processedCount == null ? 0 : processedCount;
        this.dailyCapReached = dailyCapReached == true;
    }

    public static Id startSync(Date runDate) {
        if (FreeeInvoiceStatusSyncThrottledScheduler.hasActiveChain()) {
            return null;
        }
        return System.enqueueJob(new FreeeInvoiceStatusSyncThrottledQueueable(
            runDate,
            null,
            0,
            false
        ));
    }

    public void execute(QueueableContext context) {
        List<Id> workIds = remainingInvoiceIds == null
            ? loadCandidateIds()
            : new List<Id>(remainingInvoiceIds);

        if (workIds.isEmpty()) {
            return;
        }

        Boolean capReached = dailyCapReached;
        if (remainingInvoiceIds == null && workIds.size() > MAX_INVOICES_PER_NIGHT) {
            workIds.remove(workIds.size() - 1);
            capReached = true;
        }

        Integer chunkSize = Math.min(CHUNK_SIZE, workIds.size());
        List<Id> chunkIds = new List<Id>();
        for (Integer i = 0; i < chunkSize; i++) {
            chunkIds.add(workIds[i]);
        }

        Map<Id, Invoice__c> invoicesById = new Map<Id, Invoice__c>([
            SELECT Id,
                   Freee_Invoice_Id__c,
                   Freee_Invoice_Status__c,
                   Freee_Account_Item_Picklist__c,
                   InvoiceAmount__c,
                   PaymentStatus__c,
                   CancelStatus__c
            FROM Invoice__c
            WHERE Id IN :chunkIds
        ]);
        List<Invoice__c> orderedInvoices = new List<Invoice__c>();
        for (Id invoiceId : chunkIds) {
            if (invoicesById.containsKey(invoiceId)) {
                orderedInvoices.add(invoicesById.get(invoiceId));
            }
        }

        FreeeInvoiceStatusSyncService.SyncResult syncResult =
            FreeeInvoiceStatusSyncService.syncInvoicesWithResult(orderedInvoices);

        List<Id> nextIds = buildNextIds(workIds, chunkIds, syncResult.rateLimitedInvoiceId);
        Integer completedThisRun = syncResult.isRateLimited()
            ? indexOf(chunkIds, syncResult.rateLimitedInvoiceId)
            : chunkIds.size();
        Integer totalProcessed = processedCount + Math.max(0, completedThisRun);

        if (!nextIds.isEmpty()) {
            Integer delayMinutes = syncResult.isRateLimited()
                ? Math.max(
                    MIN_RATE_LIMIT_RETRY_MINUTES,
                    syncResult.retryAfterMinutes == null
                        ? MIN_RATE_LIMIT_RETRY_MINUTES
                        : syncResult.retryAfterMinutes
                )
                : NEXT_CHUNK_DELAY_MINUTES;
            FreeeInvoiceStatusSyncThrottledScheduler.scheduleNextRun(
                runDate,
                nextIds,
                totalProcessed,
                capReached,
                delayMinutes
            );
        } else if (capReached) {
            saveDailyCapWarning(totalProcessed);
        }
    }

    @TestVisible
    private List<Id> loadCandidateIds() {
        Date syncStartDate = FreeeInvoiceStatusSyncBatch.getSyncStartDate(runDate);
        Date syncEndDate = FreeeInvoiceStatusSyncBatch.getSyncEndDate(runDate);
        Integer queryLimit = MAX_INVOICES_PER_NIGHT + 1;
        List<Id> candidateIds = new List<Id>();
        for (Invoice__c invoiceRecord : [
            SELECT Id
            FROM Invoice__c
            WHERE Freee_Invoice_Id__c != null
              AND Sent_To_Freee__c = true
              AND (CancelStatus__c = null OR CancelStatus__c != :CANCELLED)
              AND (
                  (
                      (PaymentStatus__c = null OR PaymentStatus__c != :PAYMENT_DONE)
                      AND Payment_Date__c >= :syncStartDate
                      AND Payment_Date__c <= :syncEndDate
                  )
                  OR Freee_Sync_Status__c = 'Failed'
              )
            ORDER BY Freee_Last_Synced_At__c ASC NULLS FIRST, Id
            LIMIT :queryLimit
        ]) {
            candidateIds.add(invoiceRecord.Id);
        }
        return candidateIds;
    }

    @TestVisible
    private static List<Id> buildNextIds(
        List<Id> workIds,
        List<Id> chunkIds,
        Id rateLimitedInvoiceId
    ) {
        Integer keepFromIndex = chunkIds.size();
        if (rateLimitedInvoiceId != null) {
            Integer rateLimitedIndex = indexOf(chunkIds, rateLimitedInvoiceId);
            keepFromIndex = rateLimitedIndex < 0 ? 0 : rateLimitedIndex;
        }

        List<Id> nextIds = new List<Id>();
        for (Integer i = keepFromIndex; i < chunkIds.size(); i++) {
            nextIds.add(chunkIds[i]);
        }
        for (Integer i = chunkIds.size(); i < workIds.size(); i++) {
            nextIds.add(workIds[i]);
        }
        return nextIds;
    }

    private static Integer indexOf(List<Id> ids, Id targetId) {
        if (targetId == null) {
            return -1;
        }
        for (Integer i = 0; i < ids.size(); i++) {
            if (ids[i] == targetId) {
                return i;
            }
        }
        return -1;
    }

    private static void saveDailyCapWarning(Integer processedCount) {
        try {
            FreeeSyncLogService.LogRequest logRequest = new FreeeSyncLogService.LogRequest();
            logRequest.result = 'Failed';
            logRequest.errorMessage =
                'freee請求ステータス同期が夜間上限の'
                + MAX_INVOICES_PER_NIGHT
                + '件に達しました。残件は翌日の夜間処理へ繰り越します。処理件数='
                + processedCount;
            FreeeSyncLogService.saveLog(logRequest);
        } catch (Exception e) {
            System.debug('freee請求ステータス同期の上限警告ログ保存に失敗しました: ' + e.getMessage());
        }
    }
}
