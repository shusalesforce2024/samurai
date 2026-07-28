List<CronTrigger> monthlyLineJobs = [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'ContractMonthlyLineBatch_毎月11日1時30分'
      AND State IN ('WAITING', 'ACQUIRED', 'PAUSED')
];
if (monthlyLineJobs.isEmpty()) {
    System.debug('scheduledContractMonthlyLineBatch=' + System.schedule(
        'ContractMonthlyLineBatch_毎月11日1時30分',
        '0 30 1 11 * ?',
        new ContractMonthlyLineBatch()
    ));
}

List<CronTrigger> importJobs = [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'FreeeInvoiceImportScheduler_毎週土曜2時30分'
      AND State IN ('WAITING', 'ACQUIRED', 'PAUSED')
];
if (importJobs.isEmpty()) {
    System.debug('scheduledFreeeInvoiceImportScheduler=' + System.schedule(
        'FreeeInvoiceImportScheduler_毎週土曜2時30分',
        '0 30 2 ? * SAT',
        new FreeeInvoiceImportScheduler()
    ));
}

List<CronTrigger> statusJobs = [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'FreeeInvoiceStatusSyncBatch'
      AND State IN ('WAITING', 'ACQUIRED', 'PAUSED')
];
if (statusJobs.isEmpty()) {
    System.debug('scheduledFreeeInvoiceStatusSyncBatch=' + System.schedule(
        'FreeeInvoiceStatusSyncBatch',
        '0 10 0 * * ?',
        new FreeeInvoiceStatusSyncBatch()
    ));
}
