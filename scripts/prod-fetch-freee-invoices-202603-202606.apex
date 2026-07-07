FreeeInvoiceImportService.ImportResult result = FreeeInvoiceImportService.enqueueImport(
    Date.newInstance(2026, 3, 1),
    Date.newInstance(2026, 6, 30),
    200
);
System.debug('jobId=' + result.jobId + ', range=' + result.rangeStartDate + '..' + result.rangeEndDate + ', perPage=' + result.perPage);
