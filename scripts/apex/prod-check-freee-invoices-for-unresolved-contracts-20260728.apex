List<Contract__c> unresolvedContracts = [
    SELECT Id, Name, Account__c, Account__r.Name, Account__r.Freee_Partner_Id__c
    FROM Contract__c
    WHERE Status__c = 'Activated'
      AND ProductCategory__c = null
      AND PlanCategory__c = null
      AND AccountCount__c = null
];

Map<String, String> accountNameByPartnerId = new Map<String, String>();
for (Contract__c contractRecord : unresolvedContracts) {
    if (contractRecord.Account__r == null || contractRecord.Account__r.Freee_Partner_Id__c == null) {
        continue;
    }
    String partnerId = String.valueOf(contractRecord.Account__r.Freee_Partner_Id__c.longValue());
    accountNameByPartnerId.put(partnerId, contractRecord.Account__r.Name);
}

Set<String> existingFreeeInvoiceIds = new Set<String>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT FreeeInvoiceId__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c != null
]) {
    existingFreeeInvoiceIds.add(workRecord.FreeeInvoiceId__c);
}

Date startDate = Date.newInstance(2025, 9, 1);
Date endDate = Date.newInstance(2026, 7, 31);
Integer limitSize = 100;
Integer offset = 0;
Integer listCallCount = 0;
Integer totalFreeeRows = 0;
List<Map<String, Object>> matchedInvoices = new List<Map<String, Object>>();
List<Map<String, Object>> missingWorkInvoices = new List<Map<String, Object>>();

while (true) {
    HttpResponse response = FreeeInvoiceService.getInvoicesByOffset(startDate, endDate, offset, limitSize);
    listCallCount++;
    System.debug(LoggingLevel.ERROR,
        'FREEE_RATE_LIMIT offset=' + offset +
        ', status=' + response.getStatusCode() +
        ', hourRemaining=' + response.getHeader('X-RateLimit-Remaining') +
        ', minuteRemaining=' + response.getHeader('X-Ratelimit-Remaining-Minute') +
        ', dayRemaining=' + response.getHeader('X-RateLimit-Remaining-Day') +
        ', dayReset=' + response.getHeader('X-Ratelimit-Reset-Day')
    );
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
        System.debug(LoggingLevel.ERROR, 'FREEE_ERROR body=' + response.getBody());
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

    totalFreeeRows += invoiceObjects.size();
    for (Object invoiceObject : invoiceObjects) {
        if (!(invoiceObject instanceof Map<String, Object>)) {
            continue;
        }
        Map<String, Object> invoiceMap = (Map<String, Object>) invoiceObject;
        String partnerId = Mig_FreeeInvoiceWorkService.firstString(
            invoiceMap,
            new List<String>{'partner_id', 'freee_partner_id'}
        );
        if (!accountNameByPartnerId.containsKey(partnerId)) {
            continue;
        }
        String invoiceId = Mig_FreeeInvoiceWorkService.firstString(
            invoiceMap,
            new List<String>{'id', 'invoice_id'}
        );
        Map<String, Object> resultRow = new Map<String, Object>{
            'invoiceId' => invoiceId,
            'invoiceNumber' => Mig_FreeeInvoiceWorkService.firstString(
                invoiceMap,
                new List<String>{'invoice_number', 'number'}
            ),
            'billingDate' => String.valueOf(Mig_FreeeInvoiceWorkService.firstDate(
                invoiceMap,
                new List<String>{'issue_date', 'invoice_date', 'billing_date', 'date'}
            )),
            'partnerId' => partnerId,
            'accountName' => accountNameByPartnerId.get(partnerId),
            'workExists' => existingFreeeInvoiceIds.contains(invoiceId)
        };
        matchedInvoices.add(resultRow);
        if (!existingFreeeInvoiceIds.contains(invoiceId)) {
            missingWorkInvoices.add(resultRow);
        }
    }

    if (invoiceObjects.size() < limitSize) {
        break;
    }
    offset += limitSize;
}

System.debug(LoggingLevel.ERROR,
    'SUMMARY unresolvedContracts=' + unresolvedContracts.size() +
    ', partnerIds=' + accountNameByPartnerId.size() +
    ', listCalls=' + listCallCount +
    ', totalFreeeRows=' + totalFreeeRows +
    ', matchedInvoices=' + matchedInvoices.size() +
    ', missingWorkInvoices=' + missingWorkInvoices.size()
);
System.debug(LoggingLevel.ERROR, 'MATCHED=' + JSON.serialize(matchedInvoices));
System.debug(LoggingLevel.ERROR, 'MISSING_WORK=' + JSON.serialize(missingWorkInvoices));
