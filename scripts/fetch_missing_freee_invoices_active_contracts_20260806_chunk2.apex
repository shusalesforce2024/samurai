List<Decimal> invoiceIds = new List<Decimal>{
    39800926, 39800958, 39859160, 39903347, 46403241, 48320223,
    50082828, 50083045, 51206325, 51933364, 51933366, 64761112
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
