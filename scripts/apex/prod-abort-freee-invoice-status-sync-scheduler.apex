for (CronTrigger triggerRecord : [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'FreeeInvoiceStatusSyncBatch'
      AND State IN ('WAITING', 'ACQUIRED', 'PAUSED')
]) {
    System.abortJob(triggerRecord.Id);
    System.debug('abortedFreeeInvoiceStatusSyncBatch=' + triggerRecord.Id);
}
