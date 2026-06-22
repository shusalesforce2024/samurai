FreeeConfigService.Config config = FreeeConfigService.getConfig();
for (Integer perPage : new List<Integer>{20, 50, 100}) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(
        'callout:Freee_iv/invoices'
        + '?company_id=' + String.valueOf(config.companyId)
        + '&page=1'
        + '&per_page=' + perPage
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
    System.debug(
        'MIG_FREEE_PER_PAGE_PROBE perPage=' + perPage +
        ' status=' + response.getStatusCode() +
        ' count=' + invoices.size()
    );
}
