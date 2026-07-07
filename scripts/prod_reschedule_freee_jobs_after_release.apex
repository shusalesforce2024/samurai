String statusJobId = System.schedule(
    'FreeeInvoiceStatusSyncBatch',
    '0 0 3 * * ?',
    new FreeeInvoiceStatusSyncBatch()
);
System.debug('Scheduled FreeeInvoiceStatusSyncBatch=' + statusJobId);

String importJobId = System.schedule(
    'FreeeInvoiceImportScheduler_毎週土曜2時30分',
    '0 30 2 ? * SAT',
    new FreeeInvoiceImportScheduler()
);
System.debug('Scheduled FreeeInvoiceImportScheduler=' + importJobId);
