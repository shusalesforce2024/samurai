List<String> jobNames = new List<String>{
    'ContractMonthlyLineBatch_毎月11日1時30分',
    'FreeeInvoiceImportScheduler_毎週土曜2時30分',
    'FreeeInvoiceStatusSyncBatch'
};

for (CronTrigger triggerRecord : [
    SELECT Id, CronJobDetail.Name
    FROM CronTrigger
    WHERE CronJobDetail.Name IN :jobNames
      AND State IN ('WAITING', 'ACQUIRED', 'PAUSED')
]) {
    System.abortJob(triggerRecord.Id);
    System.debug('aborted=' + triggerRecord.CronJobDetail.Name + ':' + triggerRecord.Id);
}
