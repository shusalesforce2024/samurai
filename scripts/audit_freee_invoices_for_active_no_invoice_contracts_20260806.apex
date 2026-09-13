List<Contract__c> contracts = [
    SELECT Id, Name, StartDate__c, MRR__c, Account__c,
           Account__r.Name, Account__r.Freee_Partner_Id__c
    FROM Contract__c
    WHERE Status__c = 'Activated'
      AND Id NOT IN (
          SELECT ParentContract__c
          FROM Invoice__c
          WHERE ParentContract__c != null
      )
];

Map<String, List<Contract__c>> contractsByPartnerId = new Map<String, List<Contract__c>>();
Set<Id> accountsWithoutPartnerId = new Set<Id>();
Date startDate = Date.newInstance(2024, 1, 1);
for (Contract__c contractRecord : contracts) {
    if (contractRecord.Account__r == null || contractRecord.Account__r.Freee_Partner_Id__c == null) {
        accountsWithoutPartnerId.add(contractRecord.Account__c);
        continue;
    }
    String partnerId = String.valueOf(contractRecord.Account__r.Freee_Partner_Id__c.longValue());
    if (!contractsByPartnerId.containsKey(partnerId)) {
        contractsByPartnerId.put(partnerId, new List<Contract__c>());
    }
    contractsByPartnerId.get(partnerId).add(contractRecord);
}

Set<String> existingWorkIds = new Set<String>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT FreeeInvoiceId__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c != null
]) {
    existingWorkIds.add(workRecord.FreeeInvoiceId__c);
}

Set<String> existingInvoiceIds = new Set<String>();
for (Invoice__c invoiceRecord : [
    SELECT Freee_Invoice_Id__c
    FROM Invoice__c
    WHERE Freee_Invoice_Id__c != null
]) {
    existingInvoiceIds.add(String.valueOf(invoiceRecord.Freee_Invoice_Id__c.longValue()));
}

Date endDate = Date.newInstance(2026, 8, 31);
Integer limitSize = 100;
Integer offset = 0;
Integer callCount = 0;
Integer totalRows = 0;
List<Map<String, Object>> matches = new List<Map<String, Object>>();
List<Map<String, Object>> missingWorks = new List<Map<String, Object>>();

while (true) {
    HttpResponse response = FreeeInvoiceService.getInvoicesByOffset(startDate, endDate, offset, limitSize);
    callCount++;
    System.debug(LoggingLevel.ERROR,
        'RATE offset=' + offset +
        ' status=' + response.getStatusCode() +
        ' minuteRemaining=' + response.getHeader('X-Ratelimit-Remaining-Minute') +
        ' dayRemaining=' + response.getHeader('X-RateLimit-Remaining-Day'));
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
        System.debug(LoggingLevel.ERROR, 'FREEE_ERROR=' + response.getBody());
        break;
    }

    Object parsed = JSON.deserializeUntyped(response.getBody());
    List<Object> invoiceObjects = new List<Object>();
    if (parsed instanceof List<Object>) {
        invoiceObjects = (List<Object>) parsed;
    } else if (parsed instanceof Map<String, Object>) {
        Map<String, Object> root = (Map<String, Object>) parsed;
        for (String key : new List<String>{'invoices', 'data', 'records'}) {
            if (root.get(key) instanceof List<Object>) {
                invoiceObjects = (List<Object>) root.get(key);
                break;
            }
        }
    }
    totalRows += invoiceObjects.size();

    for (Object invoiceObject : invoiceObjects) {
        if (!(invoiceObject instanceof Map<String, Object>)) { continue; }
        Map<String, Object> invoiceMap = (Map<String, Object>) invoiceObject;
        String partnerId = Mig_FreeeInvoiceWorkService.firstString(
            invoiceMap, new List<String>{'partner_id', 'freee_partner_id'});
        if (!contractsByPartnerId.containsKey(partnerId)) { continue; }

        String invoiceId = Mig_FreeeInvoiceWorkService.firstString(
            invoiceMap, new List<String>{'id', 'invoice_id'});
        Date billingDate = Mig_FreeeInvoiceWorkService.firstDate(
            invoiceMap, new List<String>{'issue_date', 'invoice_date', 'billing_date', 'date'});
        Decimal amount = Mig_FreeeInvoiceWorkService.firstDecimal(
            invoiceMap, new List<String>{'total_amount', 'amount', 'invoice_amount'});
        List<String> contractNames = new List<String>();
        for (Contract__c contractRecord : contractsByPartnerId.get(partnerId)) {
            contractNames.add(contractRecord.Name);
        }
        Map<String, Object> row = new Map<String, Object>{
            'invoiceId' => invoiceId,
            'billingDate' => String.valueOf(billingDate),
            'amount' => amount,
            'partnerId' => partnerId,
            'accountName' => contractsByPartnerId.get(partnerId)[0].Account__r.Name,
            'contracts' => contractNames,
            'workExists' => existingWorkIds.contains(invoiceId),
            'invoiceExists' => existingInvoiceIds.contains(invoiceId)
        };
        matches.add(row);
        if (!existingWorkIds.contains(invoiceId)) {
            missingWorks.add(row);
        }
    }

    if (invoiceObjects.size() < limitSize) { break; }
    offset += limitSize;
}

System.debug(LoggingLevel.ERROR,
    'SUMMARY contracts=' + contracts.size() +
    ' partnerIds=' + contractsByPartnerId.size() +
    ' accountsWithoutPartnerId=' + accountsWithoutPartnerId.size() +
    ' calls=' + callCount +
    ' freeeRows=' + totalRows +
    ' matches=' + matches.size() +
    ' missingWorks=' + missingWorks.size());
System.debug(LoggingLevel.ERROR, 'MATCHES=' + JSON.serialize(matches));
System.debug(LoggingLevel.ERROR, 'MISSING_WORKS=' + JSON.serialize(missingWorks));
