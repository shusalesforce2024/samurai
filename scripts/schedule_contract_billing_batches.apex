List<String> managedJobNames = new List<String>{
    'ContractMonthlyLineBatch_毎月11日1時30分',
    'FreeeInvoiceImportScheduler_毎日2時30分',
    'FreeeInvoiceStatusSyncBatch'
};

for (CronTrigger existingJob : [
    SELECT Id,
           CronJobDetail.Name
    FROM CronTrigger
    WHERE CronJobDetail.Name IN :managedJobNames
       OR CronJobDetail.Name LIKE 'ContractRenewalInvoiceBatch%'
]) {
    System.abortJob(existingJob.Id);
}

System.schedule(
    'ContractMonthlyLineBatch_毎月11日1時30分',
    '0 30 1 11 * ?',
    new ContractMonthlyLineBatch()
);

System.schedule(
    'FreeeInvoiceImportScheduler_毎日2時30分',
    '0 30 2 * * ?',
    new FreeeInvoiceImportScheduler()
);

System.schedule(
    'FreeeInvoiceStatusSyncBatch',
    '0 0 3 * * ?',
    new FreeeInvoiceStatusSyncBatch()
);

System.debug('SCHEDULE_CONTRACT_BILLING_BATCHES completed. ContractRenewalInvoiceBatch schedules were removed.');
