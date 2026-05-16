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
}