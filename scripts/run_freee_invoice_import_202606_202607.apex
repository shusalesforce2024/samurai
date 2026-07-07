FreeeInvoiceImportService.ImportResult result = FreeeInvoiceImportService.enqueueImport(
    Date.newInstance(2026, 6, 1),
    Date.newInstance(2026, 7, 31),
    10
);
System.debug('JOB=' + result.jobId + ' range=' + result.rangeStartDate + '..' + result.rangeEndDate + ' perPage=' + result.perPage);
