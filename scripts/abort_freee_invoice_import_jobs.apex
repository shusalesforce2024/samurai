List<CronTrigger> triggers = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime
    FROM CronTrigger
    WHERE CronJobDetail.Name LIKE 'FreeeInvoiceImport%'
      AND State IN ('WAITING', 'ACQUIRED', 'EXECUTING', 'PAUSED')
];
Integer abortedCount = 0;
for (CronTrigger triggerRecord : triggers) {
    System.debug('Aborting ' + triggerRecord.Id + ' ' + triggerRecord.CronJobDetail.Name + ' ' + triggerRecord.State);
    System.abortJob(triggerRecord.Id);
    abortedCount++;
}
System.debug('abortedCount=' + abortedCount);
