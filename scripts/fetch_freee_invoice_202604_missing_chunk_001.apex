List<Decimal> freeeInvoiceIds = new List<Decimal>{
    56527528, 56527529, 56527531, 56527532, 56527533,
    56527535, 56527536, 56527537, 56527538, 56527539,
    56527540, 56527541, 56527544, 56527545, 56527546,
    56527548, 56527550, 56527551, 56527552, 56527553
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
System.debug('CHUNK=202604-001 imported headers=' + headerCount + ' lines=' + lineCount);
