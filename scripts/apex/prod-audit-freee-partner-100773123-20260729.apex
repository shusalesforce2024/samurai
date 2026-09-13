String targetPartnerId = '100773123';
Date startDate = Date.newInstance(2025, 1, 1);
Date endDate = Date.today();
Integer limitSize = 100;
Integer offset = 0;
Integer listCallCount = 0;
Integer totalFreeeRows = 0;
List<Map<String, Object>> matchedInvoices = new List<Map<String, Object>>();

Set<String> existingWorkIds = new Set<String>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT FreeeInvoiceId__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeePartnerId__c = :targetPartnerId
]) {
    existingWorkIds.add(workRecord.FreeeInvoiceId__c);
}

Set<String> existingInvoiceIds = new Set<String>();
for (Invoice__c invoiceRecord : [
    SELECT Freee_Invoice_Id__c
    FROM Invoice__c
    WHERE Freee_Partner_Id__c = 100773123
]) {
    if (invoiceRecord.Freee_Invoice_Id__c != null) {
        existingInvoiceIds.add(String.valueOf(invoiceRecord.Freee_Invoice_Id__c.longValue()));
    }
}

while (true) {
    HttpResponse response = FreeeInvoiceService.getInvoicesByOffset(
        startDate,
        endDate,
        offset,
        limitSize
    );
    listCallCount++;
    System.debug(LoggingLevel.ERROR,
        'FREEE_PAGE offset=' + offset +
        ', status=' + response.getStatusCode() +
        ', minuteRemaining=' + response.getHeader('X-Ratelimit-Remaining-Minute') +
        ', dayRemaining=' + response.getHeader('X-RateLimit-Remaining-Day')
    );
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
        if (partnerId != targetPartnerId) {
            continue;
        }

        String invoiceId = Mig_FreeeInvoiceWorkService.firstString(
            invoiceMap,
            new List<String>{'id', 'invoice_id'}
        );
        matchedInvoices.add(new Map<String, Object>{
            'invoiceId' => invoiceId,
            'invoiceNumber' => Mig_FreeeInvoiceWorkService.firstString(
                invoiceMap,
                new List<String>{'invoice_number', 'number'}
            ),
            'billingDate' => String.valueOf(Mig_FreeeInvoiceWorkService.firstDate(
                invoiceMap,
                new List<String>{'issue_date', 'invoice_date', 'billing_date', 'date'}
            )),
            'totalAmount' => Mig_FreeeInvoiceWorkService.firstDecimal(
                invoiceMap,
                new List<String>{'total_amount', 'total', 'amount'}
            ),
            'workExists' => existingWorkIds.contains(invoiceId),
            'invoiceExists' => existingInvoiceIds.contains(invoiceId)
        });
    }

    if (invoiceObjects.size() < limitSize) {
        break;
    }
    offset += limitSize;
}

System.debug(LoggingLevel.ERROR,
    'SUMMARY targetPartnerId=' + targetPartnerId +
    ', startDate=' + startDate +
    ', endDate=' + endDate +
    ', listCalls=' + listCallCount +
    ', totalFreeeRows=' + totalFreeeRows +
    ', matchedInvoices=' + matchedInvoices.size() +
    ', existingWork=' + existingWorkIds.size() +
    ', existingInvoices=' + existingInvoiceIds.size()
);
System.debug(LoggingLevel.ERROR, 'MATCHED=' + JSON.serialize(matchedInvoices));
