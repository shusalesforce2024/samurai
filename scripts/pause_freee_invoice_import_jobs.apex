List<CronTrigger> importJobs = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime
    FROM CronTrigger
    WHERE State != 'DELETED'
      AND CronJobDetail.Name LIKE 'FreeeInvoiceImport%'
];

System.debug('targetJobs=' + importJobs.size());
for (CronTrigger job : importJobs) {
    System.debug('aborting=' + job.Id + ' name=' + job.CronJobDetail.Name + ' state=' + job.State + ' next=' + job.NextFireTime);
    System.abortJob(job.Id);
}
