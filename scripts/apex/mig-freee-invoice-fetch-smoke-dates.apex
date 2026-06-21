Date startDate = Date.newInstance(2026, 3, 1);
Date endDate = Date.newInstance(2026, 6, 30);
Integer page = 1;
Integer perPage = 10;

HttpResponse response = FreeeInvoiceService.getInvoices(startDate, endDate, page, perPage);
System.debug('MIG_FREEE_FETCH_SMOKE_STATUS=' + response.getStatusCode());
System.debug('MIG_FREEE_FETCH_SMOKE_BODY_LENGTH=' + (response.getBody() == null ? 0 : response.getBody().length()));

Object parsed = JSON.deserializeUntyped(response.getBody());
List<Object> invoices = new List<Object>();
if (parsed instanceof Map<String, Object>) {
    Map<String, Object> root = (Map<String, Object>) parsed;
    for (String key : new List<String>{ 'invoices', 'data', 'records' }) {
        Object value = root.get(key);
        if (value instanceof List<Object>) {
            invoices = (List<Object>) value;
            break;
        }
    }
}
System.debug('MIG_FREEE_FETCH_SMOKE_INVOICE_COUNT=' + invoices.size());
for (Integer i = 0; i < invoices.size(); i++) {
    if (!(invoices[i] instanceof Map<String, Object>)) {
        continue;
    }
    Map<String, Object> invoiceMap = (Map<String, Object>) invoices[i];
    System.debug(
        'MIG_FREEE_FETCH_SMOKE_ROW_' + i +
        ' id=' + String.valueOf(invoiceMap.get('id')) +
        ' number=' + String.valueOf(invoiceMap.get('invoice_number')) +
        ' issue_date=' + String.valueOf(invoiceMap.get('issue_date')) +
        ' billing_date=' + String.valueOf(invoiceMap.get('billing_date')) +
        ' payment_limit_date=' + String.valueOf(invoiceMap.get('payment_limit_date'))
    );
}
