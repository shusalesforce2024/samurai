FreeeConfigService.Config config = FreeeConfigService.getConfig();
for (Integer page = 1; page <= 6; page++) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(
        'callout:Freee_iv/invoices'
        + '?company_id=' + String.valueOf(config.companyId)
        + '&page=' + page
        + '&per_page=20'
        + '&start_billing_date=2026-03-01'
        + '&end_billing_date=2026-06-30'
    );
    req.setMethod('GET');
    req.setHeader('Content-Type', 'application/json');
    req.setTimeout(60000);

    HttpResponse response = new Http().send(req);
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
    String firstDate = null;
    String lastDate = null;
    if (!invoices.isEmpty()) {
        Object firstObject = invoices[0];
        Object lastObject = invoices[invoices.size() - 1];
        if (firstObject instanceof Map<String, Object>) {
            firstDate = String.valueOf(((Map<String, Object>) firstObject).get('billing_date'));
        }
        if (lastObject instanceof Map<String, Object>) {
            lastDate = String.valueOf(((Map<String, Object>) lastObject).get('billing_date'));
        }
    }
    System.debug(
        'MIG_FREEE_PAGE_PROBE page=' + page +
        ' status=' + response.getStatusCode() +
        ' count=' + invoices.size() +
        ' firstDate=' + firstDate +
        ' lastDate=' + lastDate
    );
}
