public without sharing class Mig_FreeeInvoiceWorkRetentionBatch
    implements Database.Batchable<SObject>, Schedulable {

    @TestVisible private static final Integer RETENTION_MONTHS = 2;
    @TestVisible private static final Integer BATCH_SIZE = 200;
    @TestVisible private static final String SCHEDULE_NAME = 'Mig_FreeeInvoiceWorkRetentionMonthly';
    @TestVisible private static final String MONTHLY_CRON = '0 0 3 1 * ?';

    public void execute(SchedulableContext context) {
        Database.executeBatch(new Mig_FreeeInvoiceWorkRetentionBatch(), BATCH_SIZE);
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Mig_FreeeInvoiceWork__c
            WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_IMPORTED
              AND CreatedInvoice__c != null
              AND CreatedDate < :retentionCutoff()
        ]);
    }

    public void execute(
        Database.BatchableContext context,
        List<Mig_FreeeInvoiceWork__c> scope
    ) {
        if (!scope.isEmpty()) {
            // Child line Work records are deleted by the master-detail relationship.
            delete scope;
        }
    }

    public void finish(Database.BatchableContext context) {
    }

    public static Id scheduleMonthly() {
        abortExistingSchedules();
        return System.schedule(SCHEDULE_NAME, MONTHLY_CRON, new Mig_FreeeInvoiceWorkRetentionBatch());
    }

    @TestVisible
    private static DateTime retentionCutoff() {
        return System.now().addMonths(-RETENTION_MONTHS);
    }

    @TestVisible
    private static Integer abortExistingSchedules() {
        Integer abortedCount = 0;
        for (CronTrigger triggerRecord : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :SCHEDULE_NAME
              AND State IN ('WAITING', 'PAUSED')
        ]) {
            System.abortJob(triggerRecord.Id);
            abortedCount++;
        }
        return abortedCount;
    }
}
