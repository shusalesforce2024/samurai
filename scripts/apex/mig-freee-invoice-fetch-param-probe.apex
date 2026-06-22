FreeeConfigService.Config config = FreeeConfigService.getConfig();
List<String> queryStrings = new List<String>{
    'company_id=' + String.valueOf(config.companyId) + '&page=1&per_page=10&start_issue_date=2026-03-01&end_issue_date=2026-06-30',
    'company_id=' + String.valueOf(config.companyId) + '&page=1&per_page=10&start_billing_date=2026-03-01&end_billing_date=2026-06-30',
    'company_id=' + String.valueOf(config.companyId) + '&page=1&per_page=10&billing_date_start=2026-03-01&billing_date_end=2026-06-30',
    'company_id=' + String.valueOf(config.companyId) + '&page=1&per_page=10&from_billing_date=2026-03-01&to_billing_date=2026-06-30'
};

Integer probeNo = 0;
for (String queryString : queryStrings) {
    probeNo++;
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:Freee_iv/invoices?' + queryString);
    req.setMethod('GET');
    req.setHeader('Content-Type', 'application/json');
    req.setTimeout(60000);

    HttpResponse response = new Http().send(req);
    System.debug('MIG_FREEE_PARAM_PROBE_' + probeNo + '_STATUS=' + response.getStatusCode());
    System.debug('MIG_FREEE_PARAM_PROBE_' + probeNo + '_BODY_LENGTH=' + (response.getBody() == null ? 0 : response.getBody().length()));

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
    System.debug('MIG_FREEE_PARAM_PROBE_' + probeNo + '_COUNT=' + invoices.size());
    if (!invoices.isEmpty() && invoices[0] instanceof Map<String, Object>) {
        Map<String, Object> invoiceMap = (Map<String, Object>) invoices[0];
        System.debug(
            'MIG_FREEE_PARAM_PROBE_' + probeNo +
            '_FIRST id=' + String.valueOf(invoiceMap.get('id')) +
            ' number=' + String.valueOf(invoiceMap.get('invoice_number')) +
            ' billing_date=' + String.valueOf(invoiceMap.get('billing_date')) +
            ' issue_date=' + String.valueOf(invoiceMap.get('issue_date'))
        );
    }
}
