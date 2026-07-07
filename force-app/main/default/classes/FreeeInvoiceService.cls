public with sharing class FreeeInvoiceService {
    private static final String ENDPOINT = 'callout:Freee_iv/invoices';
    private static final Integer DEFAULT_LIST_LIMIT = 100;
    private static final Integer MAX_LIST_LIMIT = 100;

    public static HttpResponse createInvoice(String requestBody) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(requestBody);
        req.setTimeout(60000);

        Http http = new Http();
        return http.send(req);
    }

    public static HttpResponse getInvoice(Decimal freeeInvoiceId) {
        if (freeeInvoiceId == null) {
            throw new AuraHandledException('freee請求書IDが指定されていません。');
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(buildInvoiceEndpoint(freeeInvoiceId, null));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(60000);

        Http http = new Http();
        return http.send(req);
    }

    public static HttpResponse getInvoices(Date startDate, Date endDate, Integer page, Integer perPage) {
        Integer safePage = page == null || page < 1 ? 1 : page;
        Integer safeLimit = normalizeListLimit(perPage);
        Integer offset = (safePage - 1) * safeLimit;
        return getInvoicesByOffset(startDate, endDate, offset, safeLimit);
    }

    public static HttpResponse getInvoicesByOffset(Date startDate, Date endDate, Integer offset, Integer limitSize) {
        FreeeConfigService.Config config = FreeeConfigService.getConfig();
        Integer safeOffset = offset == null || offset < 0 ? 0 : offset;
        Integer safeLimit = normalizeListLimit(limitSize);

        List<String> params = new List<String>{
            'company_id=' + String.valueOf(config.companyId),
            'limit=' + String.valueOf(safeLimit),
            'offset=' + String.valueOf(safeOffset)
        };
        if (startDate != null) {
            params.add('start_billing_date=' + String.valueOf(startDate));
        }
        if (endDate != null) {
            params.add('end_billing_date=' + String.valueOf(endDate));
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT + '?' + String.join(params, '&'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(60000);

        Http http = new Http();
        return http.send(req);
    }

    private static Integer normalizeListLimit(Integer limitSize) {
        if (limitSize == null || limitSize < 1) {
            return DEFAULT_LIST_LIMIT;
        }
        return Math.min(limitSize, MAX_LIST_LIMIT);
    }

    public static HttpResponse cancelInvoice(Decimal freeeInvoiceId) {
        if (freeeInvoiceId == null) {
            throw new AuraHandledException('freee請求書IDが指定されていません。');
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(buildInvoiceEndpoint(freeeInvoiceId, 'cancel'));
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(60000);

        Http http = new Http();
        return http.send(req);
    }

    private static String buildInvoiceEndpoint(Decimal freeeInvoiceId, String actionPath) {
        FreeeConfigService.Config config = FreeeConfigService.getConfig();
        String endpoint = ENDPOINT + '/' + String.valueOf(freeeInvoiceId.longValue());
        if (!String.isBlank(actionPath)) {
            endpoint += '/' + actionPath;
        }
        return endpoint + '?company_id=' + String.valueOf(config.companyId);
    }
}
