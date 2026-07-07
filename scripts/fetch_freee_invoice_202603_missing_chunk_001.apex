List<Decimal> freeeInvoiceIds = new List<Decimal>{
    54153830, 54153831, 54153832, 54153833, 54153834,
    54153835, 54153836, 54153837, 54153838, 54153839,
    54153841, 54153843, 54153844, 54153845, 54153846,
    54153848, 54153849, 54153851, 54153853, 54153854
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
System.debug('CHUNK=202603-001 imported headers=' + headerCount + ' lines=' + lineCount);
