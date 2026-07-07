@IsTest
private class FreeeInvoiceServiceTest {
    private class InvoiceServiceMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');

            String endpoint = request.getEndpoint();
            if (request.getMethod() == 'GET' && endpoint.contains('/invoices?')) {
                System.assert(endpoint.contains('company_id=12345'), endpoint);
                System.assert(endpoint.contains('limit='), endpoint);
                System.assert(endpoint.contains('offset='), endpoint);
                System.assert(!endpoint.contains('page='), endpoint);
                System.assert(!endpoint.contains('per_page='), endpoint);
                response.setBody('{"invoices":[]}');
                return response;
            }

            if (request.getMethod() == 'GET' && endpoint.contains('/invoices/555')) {
                response.setBody('{"invoice":{"id":555}}');
                return response;
            }

            if (request.getMethod() == 'POST' && endpoint.endsWith('/invoices')) {
                response.setBody('{"invoice":{"id":556}}');
                return response;
            }

            if (request.getMethod() == 'POST' && endpoint.contains('/invoices/555/cancel')) {
                response.setBody('{"invoice":{"id":555,"cancel_status":"canceled"}}');
                return response;
            }

            System.assert(false, 'Unexpected request: ' + request.getMethod() + ' ' + endpoint);
            return response;
        }
    }

    @TestSetup
    static void setupConfig() {
        insert new Freee_Configs__c(
            Name = 'Default',
            Company_Id__c = '12345',
            Invoice_Base_Url__c = 'https://secure.freee.co.jp/invoices/',
            Payment_Type__c = 'transfer',
            Quotation_Template_Id__c = '98765',
            Tax_Entry_Method__c = 'exclusive',
            Tax_Fraction__c = 'round_down',
            Template_Id__c = '67890',
            Withholding__c = 'false',
            Withholding_Tax_Entry_Method__c = 'IN'
        );
    }

    @IsTest
    static void listUsesLimitOffsetInsteadOfPagePerPage() {
        Test.setMock(HttpCalloutMock.class, new InvoiceServiceMock());

        Test.startTest();
        HttpResponse pageResponse = FreeeInvoiceService.getInvoices(
            Date.newInstance(2026, 6, 20),
            Date.newInstance(2026, 6, 20),
            3,
            20
        );
        HttpResponse offsetResponse = FreeeInvoiceService.getInvoicesByOffset(
            Date.newInstance(2026, 6, 20),
            Date.newInstance(2026, 6, 20),
            40,
            20
        );
        HttpResponse defaultResponse = FreeeInvoiceService.getInvoices(null, null, null, null);
        Test.stopTest();

        System.assertEquals(200, pageResponse.getStatusCode());
        System.assertEquals(200, offsetResponse.getStatusCode());
        System.assertEquals(200, defaultResponse.getStatusCode());
    }

    @IsTest
    static void invoiceDetailCreateAndCancelUseExpectedEndpoints() {
        Test.setMock(HttpCalloutMock.class, new InvoiceServiceMock());

        Test.startTest();
        HttpResponse createResponse = FreeeInvoiceService.createInvoice('{"invoice":true}');
        HttpResponse getResponse = FreeeInvoiceService.getInvoice(555);
        HttpResponse cancelResponse = FreeeInvoiceService.cancelInvoice(555);
        Test.stopTest();

        System.assertEquals(200, createResponse.getStatusCode());
        System.assertEquals(200, getResponse.getStatusCode());
        System.assertEquals(200, cancelResponse.getStatusCode());
    }

    @IsTest
    static void invoiceIdIsRequiredForDetailAndCancel() {
        try {
            FreeeInvoiceService.getInvoice(null);
            System.assert(false, 'Expected missing invoice id error.');
        } catch (AuraHandledException expected) {
            System.assertNotEquals(null, expected.getMessage());
        }

        try {
            FreeeInvoiceService.cancelInvoice(null);
            System.assert(false, 'Expected missing invoice id error.');
        } catch (AuraHandledException expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
    }
}
