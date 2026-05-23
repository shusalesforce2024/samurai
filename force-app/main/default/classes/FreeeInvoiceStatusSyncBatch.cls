public with sharing class FreeeInvoiceStatusSyncBatch
    implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {
    private static final String PAYMENT_DONE = '決済済み';
    private static final String CANCELLED = '取消済';

    public void execute(SchedulableContext context) {
        Database.executeBatch(new FreeeInvoiceStatusSyncBatch(), 50);
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id,
                   Freee_Invoice_Id__c,
                   Freee_Invoice_Status__c,
                   PaymentStatus__c,
                   CancelStatus__c
            FROM Invoice__c
            WHERE Freee_Invoice_Id__c != null
              AND Sent_To_Freee__c = true
              AND (CancelStatus__c = null OR CancelStatus__c != :CANCELLED)
              AND (PaymentStatus__c = null OR PaymentStatus__c != :PAYMENT_DONE)
        ]);
    }

    public void execute(Database.BatchableContext context, List<Invoice__c> scope) {
        FreeeInvoiceStatusSyncService.syncInvoices(scope);
    }

    public void finish(Database.BatchableContext context) {
    }
}
