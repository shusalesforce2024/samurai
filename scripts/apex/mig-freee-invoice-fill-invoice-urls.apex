FreeeConfigService.Config config = FreeeConfigService.getConfig();
String baseUrl = config.invoiceBaseUrl;
if (String.isBlank(baseUrl)) {
    throw new AuraHandledException('Freee invoice base URL is blank.');
}
if (!baseUrl.endsWith('/')) {
    baseUrl += '/';
}

List<Invoice__c> updates = new List<Invoice__c>();
for (Invoice__c invoiceRecord : [
    SELECT Id, Freee_Invoice_Id__c, Freee_Invoice_URL__c
    FROM Invoice__c
    WHERE Freee_Invoice_Id__c != null
      AND Freee_Invoice_URL__c = null
]) {
    updates.add(new Invoice__c(
        Id = invoiceRecord.Id,
        Freee_Invoice_URL__c = baseUrl + String.valueOf(invoiceRecord.Freee_Invoice_Id__c.setScale(0))
    ));
}

if (!updates.isEmpty()) {
    update updates;
}

System.debug('MIG_FREEE_FILLED_INVOICE_URLS=' + updates.size());
System.debug('MIG_FREEE_INVOICE_BASE_URL=' + baseUrl);
