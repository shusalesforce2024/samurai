List<Date> targetDates = new List<Date>{
    Date.newInstance(2026, 5, 18),
    Date.newInstance(2026, 5, 20)
};

for (Date targetDate : targetDates) {
    Mig_FreeeInvoiceFetchService.FetchPageResult result =
        Mig_FreeeInvoiceFetchService.fetchDate(targetDate, 10);
    System.debug(
        'FETCH targetDate=' + targetDate +
        ', invoiceCount=' + result.invoiceCount +
        ', importedHeaderCount=' + result.importedHeaderCount +
        ', importedLineCount=' + result.importedLineCount
    );
}

Mig_FreeeInvoiceFetchService.runResolversAndValidation();
System.debug('RESOLVE_AND_VALIDATE_DONE');
