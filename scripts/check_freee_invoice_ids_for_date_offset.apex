Date targetDate = Date.newInstance(2026, 6, 20);
Integer limitSize = 20;
Integer maxOffsets = 5;
FreeeConfigService.Config config = FreeeConfigService.getConfig();

Set<String> ids = new Set<String>();
for (Integer offsetIndex = 0; offsetIndex < maxOffsets; offsetIndex++) {
    Integer offsetValue = offsetIndex * limitSize;
    HttpRequest req = new HttpRequest();
    req.setEndpoint(
        'callout:Freee_iv/invoices'
        + '?company_id=' + String.valueOf(config.companyId)
        + '&start_billing_date=' + String.valueOf(targetDate)
        + '&end_billing_date=' + String.valueOf(targetDate)
        + '&limit=' + String.valueOf(limitSize)
        + '&offset=' + String.valueOf(offsetValue)
    );
    req.setMethod('GET');
    req.setHeader('Content-Type', 'application/json');
    req.setTimeout(60000);
    HttpResponse response = new Http().send(req);
    System.debug('OFFSET offset=' + offsetValue + ' status=' + response.getStatusCode());
    if (response.getStatusCode() == 429) {
        System.debug('RATE_LIMIT body=' + response.getBody());
        break;
    }
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
        System.debug('ERROR body=' + response.getBody());
        break;
    }
    Object parsed = JSON.deserializeUntyped(response.getBody());
    List<Object> invoices = new List<Object>();
    if (parsed instanceof Map<String, Object>) {
        Object value = ((Map<String, Object>) parsed).get('invoices');
        if (value instanceof List<Object>) {
            invoices = (List<Object>) value;
        }
    }
    System.debug('OFFSET_COUNT offset=' + offsetValue + ' count=' + invoices.size());
    if (invoices.isEmpty()) {
        break;
    }
    for (Object invoiceObject : invoices) {
        Map<String, Object> invoiceMap = (Map<String, Object>) invoiceObject;
        String idValue = String.valueOf(invoiceMap.get('id'));
        String numberValue = String.valueOf(invoiceMap.get('invoice_number'));
        String partnerValue = String.valueOf(invoiceMap.get('partner_name'));
        ids.add(idValue);
        System.debug('OFFSET_LIST id=' + idValue + ' number=' + numberValue + ' partner=' + partnerValue);
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
for (String idValue : ids) {
    if (!existingIds.contains(idValue)) {
        System.debug('MISSING_BY_OFFSET id=' + idValue);
    }
}
System.debug('offsetFreeeCount=' + ids.size() + ' existingWorkCount=' + existingIds.size());
