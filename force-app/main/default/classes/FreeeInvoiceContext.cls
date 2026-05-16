public with sharing class FreeeInvoiceContext {
    public Invoice__c invoice;
    public List<InvoiceLine__c> lines;
    public FreeeConfigService.Config config;
    public String requestBody;
    public HttpResponse response;
}