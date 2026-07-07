Decimal freeeInvoiceId = 60861151;
HttpResponse response = FreeeInvoiceService.getInvoice(freeeInvoiceId);
System.debug('status=' + response.getStatusCode());
System.debug('body=' + Mig_FreeeInvoiceWorkService.left(response.getBody(), 4000));
if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
    Mig_FreeeInvoiceWorkService.ImportResult result =
        Mig_FreeeInvoiceWorkService.importBody(response.getBody());
    System.debug('imported headers=' + result.headerCount + ' lines=' + result.lineCount);
}
