List<CronTrigger> existingMonthlyLineJobs = [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'ContractMonthlyLineBatch_毎月11日1時30分'
    AND State IN ('WAITING', 'ACQUIRED', 'PAUSED')
];

if (existingMonthlyLineJobs.isEmpty()) {
    String jobId = System.schedule(
        'ContractMonthlyLineBatch_毎月11日1時30分',
        '0 30 1 11 * ?',
        new ContractMonthlyLineBatch()
    );
    System.debug('scheduledContractMonthlyLineBatch=' + jobId);
} else {
    System.debug('scheduledContractMonthlyLineBatch=already_exists');
}
