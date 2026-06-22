@IsTest
private class FreeeInvoiceImportServiceTest {
    @TestSetup
    static void setupData() {
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
    static void buildDefaultRequestUsesPreviousAndCurrentMonth() {
        FreeeInvoiceImportService.ImportRequest request =
            FreeeInvoiceImportService.buildDefaultRequest(Date.newInstance(2026, 6, 22));

        System.assertEquals(Date.newInstance(2026, 5, 1), request.rangeStartDate);
        System.assertEquals(Date.newInstance(2026, 6, 30), request.rangeEndDate);
        System.assertEquals(FreeeInvoiceImportService.DEFAULT_PER_PAGE, request.perPage);
    }

    @IsTest
    static void enqueueImportRejectsInvalidRange() {
        try {
            FreeeInvoiceImportService.enqueueImport(
                Date.newInstance(2026, 6, 30),
                Date.newInstance(2026, 6, 1),
                200
            );
            System.assert(false, 'Expected invalid range exception.');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('rangeStartDate'));
        }
    }

    @IsTest
    static void schedulerStartsDefaultImport() {
        Test.setMock(HttpCalloutMock.class, new EmptyFreeeInvoiceMock());
        Test.startTest();
        String jobId = System.schedule(
            'FreeeInvoiceImportScheduler_Test',
            '0 0 1 1 1 ? 2099',
            new FreeeInvoiceImportScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    @IsTest
    static void manualControllerStartsImport() {
        Test.setMock(HttpCalloutMock.class, new EmptyFreeeInvoiceMock());
        FreeeInvoiceImportManualController controller = new FreeeInvoiceImportManualController();
        controller.rangeStartDate = Date.newInstance(2026, 6, 1);
        controller.rangeEndDate = Date.newInstance(2026, 6, 1);
        controller.perPage = 1;

        Test.startTest();
        controller.runImport();
        Test.stopTest();

        String errorMessage = controller.errorMessage == null ? '' : controller.errorMessage;
        System.assertEquals(true, controller.getHasMessage(), errorMessage);
        System.assertEquals(false, controller.getHasError(), errorMessage);
    }

    private class EmptyFreeeInvoiceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            if (request.getEndpoint().contains('/invoices/')) {
                response.setBody('{"invoice":{"id":123,"invoice_number":"INV-123","billing_date":"2026-06-01","lines":[]}}');
            } else {
                response.setBody('{"invoices":[]}');
            }
            return response;
        }
    }
}
