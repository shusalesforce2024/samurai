Mig_FreeeInvoiceFetchService.FetchPageResult result =
    Mig_FreeeInvoiceFetchService.fetchDate(Date.newInstance(2026, 5, 20), 10);
System.debug(
    'FETCH targetDate=2026-05-20' +
    ', invoiceCount=' + result.invoiceCount +
    ', importedHeaderCount=' + result.importedHeaderCount +
    ', importedLineCount=' + result.importedLineCount
);
