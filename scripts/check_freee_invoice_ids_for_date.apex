Date targetDate = Date.newInstance(2026, 6, 20);
Integer perPage = 100;
Integer maxPages = 5;

Set<String> freeeIds = new Set<String>();
for (Integer page = 1; page <= maxPages; page++) {
    HttpResponse response = FreeeInvoiceService.getInvoices(targetDate, targetDate, page, perPage);
    if (response.getStatusCode() == 429) {
        System.debug('RATE_LIMIT page=' + page + ' body=' + response.getBody());
        break;
    }
    System.debug('PAGE page=' + page + ' status=' + response.getStatusCode());
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
        System.debug('ERROR body=' + response.getBody());
        break;
    }
    Object parsed = JSON.deserializeUntyped(response.getBody());
    List<Object> invoices = new List<Object>();
    if (parsed instanceof Map<String, Object>) {
        Map<String, Object> root = (Map<String, Object>) parsed;
        Object value = root.get('invoices');
        if (value instanceof List<Object>) {
            invoices = (List<Object>) value;
        }
    } else if (parsed instanceof List<Object>) {
        invoices = (List<Object>) parsed;
    }
    System.debug('PAGE_COUNT page=' + page + ' count=' + invoices.size());
    if (invoices.isEmpty()) {
        break;
    }
    for (Object invoiceObject : invoices) {
        Map<String, Object> invoiceMap = (Map<String, Object>) invoiceObject;
        String idValue = String.valueOf(invoiceMap.get('id'));
        String numberValue = String.valueOf(invoiceMap.get('invoice_number'));
        String partnerValue = String.valueOf(invoiceMap.get('partner_name'));
        freeeIds.add(idValue);
        System.debug('FREEE_LIST id=' + idValue + ' number=' + numberValue + ' partner=' + partnerValue);
    }
}

Set<String> existingIds = new Set<String>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT FreeeInvoiceId__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE BillingDate__c = :targetDate
]) {
    existingIds.add(workRecord.FreeeInvoiceId__c);
}

for (String freeeId : freeeIds) {
    if (!existingIds.contains(freeeId)) {
        System.debug('MISSING_WORK id=' + freeeId);
    }
}
System.debug('freeeCount=' + freeeIds.size() + ' existingWorkCount=' + existingIds.size());
