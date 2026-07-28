List<CronTrigger> jobs = [
    SELECT Id, CronExpression, CronJobDetail.Name, State
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'FreeeInvoiceImportScheduler_毎週土曜2時30分'
      AND State = 'WAITING'
];
System.assertEquals(1, jobs.size(), '対象のfreee請求取込スケジュールは1件である必要があります。');
System.assertEquals('0 30 2 ? * SAT', jobs[0].CronExpression);
System.abortJob(jobs[0].Id);
System.debug('PAUSED_FREEE_INVOICE_IMPORT jobId=' + jobs[0].Id);
