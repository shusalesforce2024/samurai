List<CronTrigger> existing = [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'FreeeInvoiceStatusSyncBatch'
      AND State IN ('WAITING', 'ACQUIRED', 'PAUSED')
];

if (existing.isEmpty()) {
    String jobId = System.schedule(
        'FreeeInvoiceStatusSyncBatch',
        '0 10 0 * * ?',
        new FreeeInvoiceStatusSyncBatch()
    );
    System.debug('scheduledFreeeInvoiceStatusSyncBatch=' + jobId);
} else {
    System.debug('scheduledFreeeInvoiceStatusSyncBatch=already_exists');
}
