public with sharing class FreeeInvoiceService {
    private static final String ENDPOINT = 'callout:Freee_iv/invoices';

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
        FreeeConfigService.Config config = FreeeConfigService.getConfig();
        Integer safePage = page == null || page < 1 ? 1 : page;
        Integer safePerPage = perPage == null || perPage < 1 ? 100 : perPage;

        List<String> params = new List<String>{
            'company_id=' + String.valueOf(config.companyId),
            'page=' + String.valueOf(safePage),
            'per_page=' + String.valueOf(safePerPage)
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
