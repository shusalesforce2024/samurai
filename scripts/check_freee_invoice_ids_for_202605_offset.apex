Date startDate = Date.newInstance(2026, 5, 1);
Date endDate = Date.newInstance(2026, 5, 31);
Integer limitSize = 100;
Integer offset = 0;

Set<String> freeeIds = new Set<String>();
Map<String, Date> billingDateById = new Map<String, Date>();

while (true) {
    HttpResponse res = FreeeInvoiceService.getInvoicesByOffset(startDate, endDate, offset, limitSize);
    System.debug('LIST offset=' + offset + ' status=' + res.getStatusCode());
    if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
        System.debug('LIST_ERROR body=' + res.getBody());
        break;
    }

    Object parsed = JSON.deserializeUntyped(res.getBody());
    List<Object> rows = new List<Object>();
    if (parsed instanceof Map<String, Object>) {
        Map<String, Object> root = (Map<String, Object>) parsed;
        for (String key : new List<String>{'invoices', 'items', 'data'}) {
            if (root.containsKey(key) && root.get(key) instanceof List<Object>) {
                rows = (List<Object>) root.get(key);
                break;
            }
        }
    } else if (parsed instanceof List<Object>) {
        rows = (List<Object>) parsed;
    }

    for (Object rowObj : rows) {
        if (!(rowObj instanceof Map<String, Object>)) {
            continue;
        }
        Map<String, Object> row = (Map<String, Object>) rowObj;
        String idValue = row.containsKey('id') && row.get('id') != null ? String.valueOf(row.get('id')) : null;
        if (String.isBlank(idValue)) {
            idValue = row.containsKey('invoice_id') && row.get('invoice_id') != null ? String.valueOf(row.get('invoice_id')) : null;
        }
        Date billingDate;
        for (String dateKey : new List<String>{'issue_date', 'invoice_date', 'billing_date', 'date'}) {
            if (billingDate == null && row.containsKey(dateKey) && row.get(dateKey) != null) {
                billingDate = Date.valueOf(String.valueOf(row.get(dateKey)));
            }
        }
        if (!String.isBlank(idValue)) {
            freeeIds.add(idValue);
            billingDateById.put(idValue, billingDate);
        }
    }

    if (rows.size() < limitSize) {
        break;
    }
    offset += limitSize;
}

Set<String> workIds = new Set<String>();
for (Mig_FreeeInvoiceWork__c work : [
    SELECT FreeeInvoiceId__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE BillingDate__c >= :startDate
      AND BillingDate__c <= :endDate
]) {
    if (!String.isBlank(work.FreeeInvoiceId__c)) {
        workIds.add(work.FreeeInvoiceId__c);
    }
}

List<String> missingIds = new List<String>();
for (String freeeId : freeeIds) {
    if (!workIds.contains(freeeId)) {
        missingIds.add(freeeId);
    }
}
missingIds.sort();

Map<Date, Integer> missingCountByDate = new Map<Date, Integer>();
for (String missingId : missingIds) {
    Date billingDate = billingDateById.get(missingId);
    Integer current = missingCountByDate.containsKey(billingDate) ? missingCountByDate.get(billingDate) : 0;
    missingCountByDate.put(billingDate, current + 1);
}

System.debug('SUMMARY freeeCount=' + freeeIds.size() + ', workCount=' + workIds.size() + ', missingCount=' + missingIds.size());
System.debug('MISSING_BY_DATE=' + missingCountByDate);
System.debug('MISSING_IDS=' + String.join(missingIds, ','));
