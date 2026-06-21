Date startDate = Date.newInstance(2026, 3, 1);
Date endDate = Date.newInstance(2026, 6, 30);
Integer page = 1;
Integer perPage = 5;

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
if (!invoices.isEmpty() && invoices[0] instanceof Map<String, Object>) {
    Map<String, Object> firstInvoice = (Map<String, Object>) invoices[0];
    System.debug('MIG_FREEE_FETCH_SMOKE_FIRST_ID=' + String.valueOf(firstInvoice.get('id')));
    System.debug('MIG_FREEE_FETCH_SMOKE_FIRST_NUMBER=' + String.valueOf(firstInvoice.get('invoice_number')));
}
