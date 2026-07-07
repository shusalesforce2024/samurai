List<Decimal> freeeInvoiceIds = new List<Decimal>{
    60861193, 60899966, 60900081, 60901483, 60904124,
    60905395, 60905677, 60906771, 60907136, 60907570,
    60946048, 60946173, 60952602, 60952846, 60953208,
    60953422, 60953721
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
    Mig_FreeeInvoiceWorkService.ImportResult result =
        Mig_FreeeInvoiceWorkService.importBody(detailBody);
    headerCount += result.headerCount;
    lineCount += result.lineCount;
}
System.debug('imported headers=' + headerCount + ' lines=' + lineCount);
