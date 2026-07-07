List<CronTrigger> jobs = [
    SELECT Id, CronJobDetail.Name
    FROM CronTrigger
    WHERE Id IN ('08eRB00001YtExeYAF', '08eRB00001YtLfgYAF')
];
for (CronTrigger job : jobs) {
    System.debug('Aborting scheduled job: ' + job.CronJobDetail.Name + ' / ' + job.Id);
    System.abortJob(job.Id);
}
System.debug('Aborted job count=' + jobs.size());
