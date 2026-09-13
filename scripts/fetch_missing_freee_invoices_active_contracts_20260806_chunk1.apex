List<Decimal> invoiceIds = new List<Decimal>{
    32399726, 34243674, 34244031, 34244651, 34244944, 36227949,
    36228085, 36233282, 36235097, 38258922, 38259355, 39572257
};

Integer headers = 0;
Integer lines = 0;
List<String> bodies = new List<String>();
for (Decimal invoiceId : invoiceIds) {
    HttpResponse response = FreeeInvoiceService.getInvoice(invoiceId);
    System.debug('FETCH id=' + invoiceId + ' status=' + response.getStatusCode());
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
        System.debug('FETCH_ERROR id=' + invoiceId + ' body=' + response.getBody());
        continue;
    }
    bodies.add(response.getBody());
}
for (String body : bodies) {
    Mig_FreeeInvoiceWorkService.ImportResult result =
        Mig_FreeeInvoiceWorkService.importBody(body);
    headers += result.headerCount;
    lines += result.lineCount;
}
System.debug('RESULT requested=' + invoiceIds.size() + ' headers=' + headers + ' lines=' + lines);
