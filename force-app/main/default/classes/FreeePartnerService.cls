public with sharing class FreeePartnerService {
    public class FreeePartnerException extends Exception {}

    public static HttpResponse searchPartners(String companyId, String keyword) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            'callout:FreeeAPI/api/1/partners'
            + '?company_id=' + EncodingUtil.urlEncode(companyId, 'UTF-8')
            + '&keyword=' + EncodingUtil.urlEncode(keyword, 'UTF-8')
        );
        req.setMethod('GET');
        req.setTimeout(60000);

        Http http = new Http();
        return http.send(req);
    }

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
