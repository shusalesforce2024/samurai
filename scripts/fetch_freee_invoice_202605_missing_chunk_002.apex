List<Decimal> freeeInvoiceIds = new List<Decimal>{
    58573629, 58573631, 58573632, 58573634, 58573635,
    58573637, 58573639, 58573640, 58573642, 58573644,
    58573647, 58573648, 58573650, 58573652, 58573654,
    58573656, 58573658, 58573661, 58573663, 58573666
};

List<String> detailBodies = new List<String>();
for (Decimal freeeInvoiceId : freeeInvoiceIds) {
    HttpResponse response = FreeeInvoiceService.getInvoice(freeeInvoiceId);
    System.debug('GET id=' + freeeInvoiceId + ' status=' + response.getStatusCode());
    if (response.getStatusCode() == 429) {
        System.debug('RATE_LIMIT id=' + freeeInvoiceId + ' body=' + response.getBody());
        break;
    }
    if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
        detailBodies.add(response.getBody());
    } else {
        System.debug('ERROR id=' + freeeInvoiceId + ' body=' + response.getBody());
    }
}

Integer headerCount = 0;
Integer lineCount = 0;
for (String detailBody : detailBodies) {
    Mig_FreeeInvoiceWorkService.ImportResult result = Mig_FreeeInvoiceWorkService.importBody(detailBody);
    headerCount += result.headerCount;
    lineCount += result.lineCount;
}
System.debug('CHUNK=002 imported headers=' + headerCount + ' lines=' + lineCount);
