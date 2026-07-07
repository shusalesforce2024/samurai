Date startDate = Date.newInstance(2026, 6, 1);
Date endDate = Date.newInstance(2026, 7, 31);
Integer limitSize = 100;
Integer maxOffsets = 10;
FreeeConfigService.Config config = FreeeConfigService.getConfig();

Map<String, String> freeeIdToBillingDate = new Map<String, String>();
Map<String, String> freeeIdToNumber = new Map<String, String>();
Map<String, String> freeeIdToPartner = new Map<String, String>();
for (Integer offsetIndex = 0; offsetIndex < maxOffsets; offsetIndex++) {
    Integer offsetValue = offsetIndex * limitSize;
    HttpRequest req = new HttpRequest();
    req.setEndpoint(
        'callout:Freee_iv/invoices'
        + '?company_id=' + String.valueOf(config.companyId)
        + '&start_billing_date=' + String.valueOf(startDate)
        + '&end_billing_date=' + String.valueOf(endDate)
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
        freeeIdToBillingDate.put(idValue, String.valueOf(invoiceMap.get('billing_date')));
        freeeIdToNumber.put(idValue, String.valueOf(invoiceMap.get('invoice_number')));
        freeeIdToPartner.put(idValue, String.valueOf(invoiceMap.get('partner_name')));
    }
    if (invoices.size() < limitSize) {
        break;
    }
}

Set<String> existingWorkIds = new Set<String>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT FreeeInvoiceId__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE BillingDate__c >= :startDate
      AND BillingDate__c <= :endDate
]) {
    existingWorkIds.add(workRecord.FreeeInvoiceId__c);
}

Set<String> existingInvoiceIds = new Set<String>();
for (Invoice__c invoiceRecord : [
    SELECT Freee_Invoice_Id__c
    FROM Invoice__c
    WHERE Billing_Date__c >= :startDate
      AND Billing_Date__c <= :endDate
      AND Freee_Invoice_Id__c != null
]) {
    existingInvoiceIds.add(String.valueOf(invoiceRecord.Freee_Invoice_Id__c.setScale(0)));
}

Integer missingWorkCount = 0;
Integer missingInvoiceCount = 0;
for (String idValue : freeeIdToBillingDate.keySet()) {
    if (!existingWorkIds.contains(idValue)) {
        missingWorkCount++;
        System.debug(
            'MISSING_WORK id=' + idValue
            + ' date=' + freeeIdToBillingDate.get(idValue)
            + ' number=' + freeeIdToNumber.get(idValue)
            + ' partner=' + freeeIdToPartner.get(idValue)
        );
    }
    if (!existingInvoiceIds.contains(idValue)) {
        missingInvoiceCount++;
    }
}
System.debug('freeeCount=' + freeeIdToBillingDate.size());
System.debug('existingWorkCount=' + existingWorkIds.size());
System.debug('existingInvoiceCount=' + existingInvoiceIds.size());
System.debug('missingWorkCount=' + missingWorkCount);
System.debug('missingInvoiceCount=' + missingInvoiceCount);
