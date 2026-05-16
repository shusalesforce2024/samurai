public with sharing class FreeePartnerService {
    public class FreeePartnerException extends Exception {}

    public static HttpResponse createPartner(String requestBody) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:FreeeAPI/api/1/partners');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(requestBody);
        req.setTimeout(60000);

        Http http = new Http();
        return http.send(req);
    }
}