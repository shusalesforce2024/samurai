public with sharing class FreeeQuotationContext {
    public Quotation__c quotation;
    public List<QuotationLine__c> lines;
    public FreeeConfigService.Config config;
    public String requestBody;
    public HttpResponse response;
}