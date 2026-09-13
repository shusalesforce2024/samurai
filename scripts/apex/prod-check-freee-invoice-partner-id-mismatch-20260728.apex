List<Contract__c> unresolvedContracts = [
    SELECT Id, Name, Account__c, Account__r.Name, Account__r.Freee_Partner_Id__c
    FROM Contract__c
    WHERE Status__c = 'Activated'
      AND ProductCategory__c = null
      AND PlanCategory__c = null
      AND AccountCount__c = null
];

Map<String, Account> accountByNormalizedName = new Map<String, Account>();
for (Contract__c contractRecord : unresolvedContracts) {
    if (contractRecord.Account__r == null) {
        continue;
    }
    String normalizedName = contractRecord.Account__r.Name
        .toLowerCase()
        .replace(' ', '')
        .replace('　', '')
        .replace('&', '＆');
    accountByNormalizedName.put(normalizedName, contractRecord.Account__r);
}

Set<String> existingFreeeInvoiceIds = new Set<String>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT FreeeInvoiceId__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c != null
]) {
    existingFreeeInvoiceIds.add(workRecord.FreeeInvoiceId__c);
}

Date startDate = Date.newInstance(2026, 3, 1);
Date endDate = Date.newInstance(2026, 7, 31);
Integer limitSize = 100;
Integer offset = 0;
List<Map<String, Object>> nameMatches = new List<Map<String, Object>>();

while (true) {
    HttpResponse response = FreeeInvoiceService.getInvoicesByOffset(startDate, endDate, offset, limitSize);
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
        System.debug(LoggingLevel.ERROR, 'FREEE_ERROR status=' + response.getStatusCode() + ', body=' + response.getBody());
        break;
    }

    Object parsed = JSON.deserializeUntyped(response.getBody());
    List<Object> invoiceObjects = new List<Object>();
    if (parsed instanceof Map<String, Object>) {
        Map<String, Object> root = (Map<String, Object>) parsed;
        for (String key : new List<String>{'invoices', 'data', 'records'}) {
            if (root.get(key) instanceof List<Object>) {
                invoiceObjects = (List<Object>) root.get(key);
                break;
            }
        }
    } else if (parsed instanceof List<Object>) {
        invoiceObjects = (List<Object>) parsed;
    }

    for (Object invoiceObject : invoiceObjects) {
        if (!(invoiceObject instanceof Map<String, Object>)) {
            continue;
        }
        Map<String, Object> invoiceMap = (Map<String, Object>) invoiceObject;
        String partnerName = Mig_FreeeInvoiceWorkService.firstString(
            invoiceMap,
            new List<String>{'partner_name', 'partner_display_name'}
        );
        if (String.isBlank(partnerName) && invoiceMap.get('partner') instanceof Map<String, Object>) {
            partnerName = Mig_FreeeInvoiceWorkService.firstString(
                (Map<String, Object>) invoiceMap.get('partner'),
                new List<String>{'name', 'display_name'}
            );
        }
        if (String.isBlank(partnerName)) {
            continue;
        }
        String normalizedName = partnerName
            .toLowerCase()
            .replace(' ', '')
            .replace('　', '')
            .replace('&', '＆');
        if (!accountByNormalizedName.containsKey(normalizedName)) {
            continue;
        }

        Account accountRecord = accountByNormalizedName.get(normalizedName);
        String freeePartnerId = Mig_FreeeInvoiceWorkService.firstString(
            invoiceMap,
            new List<String>{'partner_id', 'freee_partner_id'}
        );
        String salesforcePartnerId = accountRecord.Freee_Partner_Id__c == null
            ? null
            : String.valueOf(accountRecord.Freee_Partner_Id__c.longValue());
        String invoiceId = Mig_FreeeInvoiceWorkService.firstString(
            invoiceMap,
            new List<String>{'id', 'invoice_id'}
        );
        nameMatches.add(new Map<String, Object>{
            'invoiceId' => invoiceId,
            'billingDate' => String.valueOf(Mig_FreeeInvoiceWorkService.firstDate(
                invoiceMap,
                new List<String>{'issue_date', 'invoice_date', 'billing_date', 'date'}
            )),
            'freeePartnerName' => partnerName,
            'freeePartnerId' => freeePartnerId,
            'salesforceAccountName' => accountRecord.Name,
            'salesforcePartnerId' => salesforcePartnerId,
            'partnerIdMatches' => freeePartnerId == salesforcePartnerId,
            'workExists' => existingFreeeInvoiceIds.contains(invoiceId)
        });
    }

    if (invoiceObjects.size() < limitSize) {
        break;
    }
    offset += limitSize;
}

Integer mismatchCount = 0;
for (Map<String, Object> row : nameMatches) {
    if (row.get('partnerIdMatches') == false) {
        mismatchCount++;
    }
}
System.debug(LoggingLevel.ERROR,
    'SUMMARY nameMatches=' + nameMatches.size() + ', partnerIdMismatches=' + mismatchCount
);
System.debug(LoggingLevel.ERROR, 'NAME_MATCHES=' + JSON.serialize(nameMatches));
