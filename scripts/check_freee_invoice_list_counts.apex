Date startDate = Date.newInstance(2026, 6, 16);
Date endDate = Date.newInstance(2026, 6, 30);
Integer perPage = 90;

Date targetDate = startDate;
while (targetDate <= endDate) {
    HttpResponse response = FreeeInvoiceService.getInvoices(targetDate, targetDate, 1, perPage);
    if (response.getStatusCode() == 429) {
        System.debug('RATE_LIMIT date=' + targetDate + ' body=' + response.getBody());
        break;
    }
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
        System.debug('ERROR date=' + targetDate + ' status=' + response.getStatusCode() + ' body=' + response.getBody());
        targetDate = targetDate.addDays(1);
        continue;
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
    System.debug('LIST date=' + targetDate + ' count=' + invoices.size());
    targetDate = targetDate.addDays(1);
}
