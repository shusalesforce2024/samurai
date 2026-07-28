public with sharing class FreeeInvoiceStatusSyncBatch
    implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {
    @TestVisible private static final Integer MAX_INVOICES_PER_RUN = 20;
    @TestVisible private static final Integer FAILED_RETRY_DELAY_MINUTES = 5;
    private static final String PAYMENT_DONE = '決済済み';
    private static final String CANCELLED = '取消済';
    private Date runDate;

    public FreeeInvoiceStatusSyncBatch() {
        this(Date.today());
    }

    @TestVisible
    private FreeeInvoiceStatusSyncBatch(Date runDate) {
        this.runDate = runDate == null ? Date.today() : runDate;
    }

    public void execute(SchedulableContext context) {
        FreeeInvoiceStatusSyncThrottledQueueable.startSync(Date.today());
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        Date syncStartDate = getSyncStartDate(runDate);
        Date syncEndDate = getSyncEndDate(runDate);
        DateTime failedRetryBefore = System.now().addMinutes(-FAILED_RETRY_DELAY_MINUTES);
        return Database.getQueryLocator([
            SELECT Id,
                   Freee_Invoice_Id__c,
                   Freee_Invoice_Status__c,
                   Freee_Account_Item_Picklist__c,
                   InvoiceAmount__c,
                   PaymentStatus__c,
                   CancelStatus__c
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
                  OR (
                      Freee_Sync_Status__c = 'Failed'
                      AND (
                          Freee_Last_Synced_At__c = null
                          OR Freee_Last_Synced_At__c <= :failedRetryBefore
                      )
                  )
              )
            ORDER BY Freee_Last_Synced_At__c ASC NULLS FIRST, Id
            LIMIT :MAX_INVOICES_PER_RUN
        ]);
    }

    public void execute(Database.BatchableContext context, List<Invoice__c> scope) {
        FreeeInvoiceStatusSyncService.syncInvoices(scope);
    }

    public void finish(Database.BatchableContext context) {
    }

    public static Date getSyncStartDate(Date baseDate) {
        Date effectiveDate = baseDate == null ? Date.today() : baseDate;
        Date currentMonthStart = Date.newInstance(effectiveDate.year(), effectiveDate.month(), 1);
        return currentMonthStart.addMonths(-1);
    }

    public static Date getSyncEndDate(Date baseDate) {
        Date effectiveDate = baseDate == null ? Date.today() : baseDate;
        Date currentMonthStart = Date.newInstance(effectiveDate.year(), effectiveDate.month(), 1);
        return currentMonthStart.addMonths(1).addDays(-1);
    }
}
