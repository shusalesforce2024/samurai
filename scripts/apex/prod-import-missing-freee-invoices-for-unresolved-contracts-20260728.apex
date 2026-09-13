List<Decimal> freeeInvoiceIds = new List<Decimal>{
    52182829, 52556987
};

Integer importedHeaders = 0;
Integer importedLines = 0;
List<String> errors = new List<String>();
Map<Decimal, String> detailBodyByInvoiceId = new Map<Decimal, String>();

for (Decimal freeeInvoiceId : freeeInvoiceIds) {
    try {
        HttpResponse response = FreeeInvoiceService.getInvoice(freeeInvoiceId);
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            errors.add(
                String.valueOf(freeeInvoiceId.longValue()) +
                ': status=' + response.getStatusCode() +
                ', body=' + Mig_FreeeInvoiceWorkService.left(response.getBody(), 1000)
            );
            continue;
        }
        detailBodyByInvoiceId.put(freeeInvoiceId, response.getBody());
    } catch (Exception e) {
        errors.add(String.valueOf(freeeInvoiceId.longValue()) + ': ' + e.getMessage());
    }
}

for (Decimal freeeInvoiceId : freeeInvoiceIds) {
    if (!detailBodyByInvoiceId.containsKey(freeeInvoiceId)) {
        continue;
    }
    try {
        Mig_FreeeInvoiceWorkService.ImportResult result = Mig_FreeeInvoiceWorkService.importBody(
            detailBodyByInvoiceId.get(freeeInvoiceId)
        );
        importedHeaders += result.headerCount;
        importedLines += result.lineCount;
    } catch (Exception e) {
        errors.add(String.valueOf(freeeInvoiceId.longValue()) + ': ' + e.getMessage());
    }
}

System.debug(LoggingLevel.ERROR,
    'SUMMARY requested=' + freeeInvoiceIds.size() +
    ', importedHeaders=' + importedHeaders +
    ', importedLines=' + importedLines +
    ', errors=' + errors.size()
);
System.debug(LoggingLevel.ERROR, 'ERRORS=' + JSON.serialize(errors));
