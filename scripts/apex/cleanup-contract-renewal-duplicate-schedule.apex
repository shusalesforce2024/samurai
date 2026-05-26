for (CronTrigger job : [
    SELECT Id, CronJobDetail.Name
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'ContractRenewalInvoiceBatch'
]) {
    System.abortJob(job.Id);
    System.debug('Aborted duplicate schedule: ' + job.CronJobDetail.Name + ' / ' + job.Id);
}
