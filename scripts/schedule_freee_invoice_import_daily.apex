String jobName = 'FreeeInvoiceImportScheduler_毎週土曜2時30分';
for (CronTrigger triggerRecord : [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = :jobName
      AND State IN ('WAITING', 'ACQUIRED', 'EXECUTING', 'PAUSED')
]) {
    System.abortJob(triggerRecord.Id);
}
Id jobId = System.schedule(jobName, '0 30 2 ? * SAT', new FreeeInvoiceImportScheduler());
System.debug('scheduledJobId=' + jobId);
