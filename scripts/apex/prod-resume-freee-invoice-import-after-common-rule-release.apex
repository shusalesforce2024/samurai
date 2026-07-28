List<CronTrigger> existingJobs = [
    SELECT Id, CronJobDetail.Name, State
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'FreeeInvoiceImportScheduler_毎週土曜2時30分'
      AND State IN ('WAITING', 'ACQUIRED', 'PAUSED', 'BLOCKED')
];
System.assertEquals(0, existingJobs.size(), '同名の有効なスケジュールが残っています。');

String jobId = System.schedule(
    'FreeeInvoiceImportScheduler_毎週土曜2時30分',
    '0 30 2 ? * SAT',
    new FreeeInvoiceImportScheduler()
);
System.debug('RESUMED_FREEE_INVOICE_IMPORT jobId=' + jobId);
