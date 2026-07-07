List<Decimal> freeeInvoiceIds = new List<Decimal>{
    58549482, 58549485, 58549487, 58573596, 58573600,
    58573601, 58573604, 58573606, 58573608, 58573609,
    58573611, 58573613, 58573614, 58573616, 58573618,
    58573620, 58573621, 58573624, 58573626, 58573627
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
System.debug('CHUNK=001 imported headers=' + headerCount + ' lines=' + lineCount);
