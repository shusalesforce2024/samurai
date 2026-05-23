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
        req.setEndpoint(ENDPOINT + '/' + String.valueOf(freeeInvoiceId.longValue()));
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
        req.setEndpoint(ENDPOINT + '/' + String.valueOf(freeeInvoiceId.longValue()) + '/cancel');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(60000);

        Http http = new Http();
        return http.send(req);
    }
}
