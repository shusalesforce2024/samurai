List<CronTrigger> triggers = [
    SELECT Id,
           CronJobDetail.Name,
           State
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'Contract Monthly Line Batch - Monthly 11th'
       OR CronJobDetail.Name LIKE 'ContractMonthlyLineBatch%'
];

Integer aborted = 0;
for (CronTrigger triggerRecord : triggers) {
    if (triggerRecord.State == 'WAITING'
        || triggerRecord.State == 'ACQUIRED'
        || triggerRecord.State == 'PAUSED'
    ) {
        System.abortJob(triggerRecord.Id);
        aborted++;
    }
}

System.debug('ABORTED_CONTRACT_MONTHLY_LINE_SCHEDULES=' + aborted);
