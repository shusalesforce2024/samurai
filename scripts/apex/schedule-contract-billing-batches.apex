System.schedule(
    'ContractRenewalInvoiceBatch',
    '0 0 2 * * ?',
    new ContractRenewalInvoiceBatch()
);

System.schedule(
    'FreeeInvoiceStatusSyncBatch',
    '0 0 3 * * ?',
    new FreeeInvoiceStatusSyncBatch()
);
