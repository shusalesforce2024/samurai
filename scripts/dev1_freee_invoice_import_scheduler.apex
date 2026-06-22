Integer aborted = FreeeInvoiceImportService.abortContractRenewalInvoiceSchedules();
System.debug('abortedContractRenewalInvoiceSchedules=' + aborted);

List<CronTrigger> existingImports = [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'FreeeInvoiceImportScheduler_毎日2時30分'
    AND State IN ('WAITING', 'ACQUIRED', 'PAUSED')
];

if (existingImports.isEmpty()) {
    String jobId = System.schedule(
        'FreeeInvoiceImportScheduler_毎日2時30分',
        '0 30 2 * * ?',
        new FreeeInvoiceImportScheduler()
    );
    System.debug('scheduledFreeeInvoiceImportScheduler=' + jobId);
} else {
    System.debug('scheduledFreeeInvoiceImportScheduler=already_exists');
}
