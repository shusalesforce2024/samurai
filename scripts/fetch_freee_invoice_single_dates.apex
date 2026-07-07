Date targetDate = Date.newInstance(2026, 6, 29);
Mig_FreeeInvoiceFetchService.FetchPageResult result =
    Mig_FreeeInvoiceFetchService.fetchDate(targetDate, 90);
System.debug(
    'FETCH date=' + result.targetDate
    + ' invoices=' + result.invoiceCount
    + ' importedHeaders=' + result.importedHeaderCount
    + ' importedLines=' + result.importedLineCount
);
