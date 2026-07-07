for (CronTrigger triggerRecord : [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name LIKE 'FreeeInvoiceImportScheduler_%'
      AND State IN ('WAITING', 'ACQUIRED', 'PAUSED')
]) {
    System.abortJob(triggerRecord.Id);
    System.debug('abortedFreeeInvoiceImportScheduler=' + triggerRecord.Id);
}
