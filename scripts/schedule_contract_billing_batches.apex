List<String> jobNames = new List<String>{
    'ContractRenewalInvoiceBatch_毎月11日2時',
    'FreeeInvoiceStatusSyncBatch_毎日2時'
};

for (CronTrigger existingJob : [
    SELECT Id,
           CronJobDetail.Name
    FROM CronTrigger
    WHERE CronJobDetail.Name IN :jobNames
]) {
    System.abortJob(existingJob.Id);
}

System.schedule(
    'ContractRenewalInvoiceBatch_毎月11日2時',
    '0 0 2 11 * ?',
    new ContractRenewalInvoiceBatch()
);

System.schedule(
    'FreeeInvoiceStatusSyncBatch_毎日2時',
    '0 0 2 * * ?',
    new FreeeInvoiceStatusSyncBatch()
);
