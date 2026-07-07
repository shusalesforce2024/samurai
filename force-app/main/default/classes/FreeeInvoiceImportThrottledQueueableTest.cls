@isTest
private class FreeeInvoiceImportThrottledQueueableTest {
    private class InvoiceImportMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            if (request.getEndpoint().contains('/invoices/555')) {
                response.setStatusCode(200);
                response.setBody(
                    '{"invoice":' +
                    '{"id":555,"invoice_number":"INV-555","partner_id":901,"partner_name":"Throttle Account",' +
                    '"issue_date":"2026-03-20","payment_limit_date":"2026-04-30","subject":"March usage",' +
                    '"total_amount":1100,"total_vat":100,"paid_amount":0,"unpaid_amount":1100,' +
                    '"sending_status":"sent","payment_status":"unpaid",' +
                    '"invoice_lines":[{"id":1,"description":"Rendary","quantity":1,"unit_price":1000,"amount":1000,"tax_rate":10,"tax_amount":100}]}' +
                    '}'
                );
                return response;
            }

            response.setStatusCode(200);
            if (request.getEndpoint().contains('start_billing_date=2026-03-20')) {
                response.setBody(
                    '{"invoices":[' +
                    '{"id":555,"invoice_number":"INV-555","partner_id":901,"partner_name":"Throttle Account",' +
                    '"issue_date":"2026-03-20","payment_limit_date":"2026-04-30","subject":"March usage",' +
                    '"total_amount":1100,"total_vat":100,"paid_amount":0,"unpaid_amount":1100,' +
                    '"sending_status":"sent","payment_status":"unpaid"}' +
                    ']}'
                );
            } else {
                response.setBody('{"invoices":[]}');
            }
            return response;
        }
    }

    private class RateLimitMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(429);
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"status_code":429,"meta":{"limit":30,"period":60,"remaining":0}}');
            return response;
        }
    }

    @testSetup
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

    @isTest
    static void fetchesOnePageFromQueueable() {
        Test.setMock(HttpCalloutMock.class, new InvoiceImportMock());

        Test.startTest();
        System.enqueueJob(new FreeeInvoiceImportThrottledQueueable(
            Date.newInstance(2026, 3, 20),
            Date.newInstance(2026, 3, 20),
            Date.newInstance(2026, 3, 20),
            1,
            20
        ));
        Test.stopTest();

        Mig_FreeeInvoiceWork__c workRecord = [
            SELECT FreeeInvoiceId__c,
                   InvoiceAmount__c,
                   TaxAmount__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE FreeeInvoiceId__c = '555'
            LIMIT 1
        ];
        System.assertEquals('555', workRecord.FreeeInvoiceId__c);
        System.assertEquals(1100, workRecord.InvoiceAmount__c);
        System.assertEquals(100, workRecord.TaxAmount__c);
    }

    @isTest
    static void rateLimitSchedulesRetryWithoutThrowing() {
        Test.setMock(HttpCalloutMock.class, new RateLimitMock());

        Test.startTest();
        System.enqueueJob(new FreeeInvoiceImportThrottledQueueable(
            Date.newInstance(2026, 3, 20),
            Date.newInstance(2026, 3, 20),
            Date.newInstance(2026, 3, 20),
            1,
            20
        ));
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Mig_FreeeInvoiceWork__c]);
    }

    @isTest
    static void serviceSchedulesThrottledImportAndCapsPerPage() {
        FreeeInvoiceImportThrottledScheduler.skipSchedulingForTest = true;

        FreeeInvoiceImportService.ImportResult result = FreeeInvoiceImportService.enqueueImport(
            Date.newInstance(2026, 3, 20),
            Date.newInstance(2026, 3, 20),
            200
        );

        System.assertNotEquals(null, result.jobId);
        System.assertEquals(10, result.perPage);
    }

    @isTest
    static void serviceBuildsDefaultRequestAndCapsBatchPerPage() {
        FreeeInvoiceImportService.ImportRequest request = FreeeInvoiceImportService.buildDefaultRequest(
            Date.newInstance(2026, 6, 25)
        );
        System.assertEquals(Date.newInstance(2026, 5, 1), request.rangeStartDate);
        System.assertEquals(Date.newInstance(2026, 6, 30), request.rangeEndDate);
        System.assertEquals(FreeeInvoiceImportService.DEFAULT_PER_PAGE, request.perPage);

        FreeeInvoiceImportService.skipBatchExecutionForTest = true;
        FreeeInvoiceImportService.ImportResult batchResult = FreeeInvoiceImportService.enqueueBatchImport(
            Date.newInstance(2026, 3, 20),
            Date.newInstance(2026, 3, 20),
            200
        );
        System.assertNotEquals(null, batchResult.jobId);
        System.assertEquals(90, batchResult.perPage);

        FreeeInvoiceImportThrottledScheduler.skipSchedulingForTest = true;
        FreeeInvoiceImportService.ImportResult defaultResult = FreeeInvoiceImportService.enqueueDefaultImport();
        System.assertNotEquals(null, defaultResult.jobId);

        System.assertEquals(0, FreeeInvoiceImportService.abortContractRenewalInvoiceSchedules());
    }

    @isTest
    static void serviceCalculatesRetryDelayFromRateLimitPeriod() {
        System.assertEquals(10, Mig_FreeeInvoiceFetchService.normalizeThrottledPerPage(null));
        System.assertEquals(10, Mig_FreeeInvoiceFetchService.normalizeThrottledPerPage(200));
        System.assertEquals(5, Mig_FreeeInvoiceFetchService.normalizeThrottledPerPage(5));
        System.assertEquals(
            3,
            Mig_FreeeInvoiceFetchService.calculateRateLimitRetryMinutes(
                '{"status_code":429,"meta":{"limit":30,"period":60,"remaining":0}}'
            )
        );
        System.assertEquals(
            480,
            Mig_FreeeInvoiceFetchService.calculateRateLimitRetryMinutes(
                '{"status_code":429,"meta":{"limit":3000,"period":86400,"remaining":0}}'
            )
        );
        System.assertEquals(30, Mig_FreeeInvoiceFetchService.calculateRateLimitRetryMinutes(null));
        System.assertEquals(30, Mig_FreeeInvoiceFetchService.calculateRateLimitRetryMinutes('[]'));
        System.assertEquals(30, Mig_FreeeInvoiceFetchService.calculateRateLimitRetryMinutes('{"meta":{}}'));

        try {
            Mig_FreeeInvoiceFetchService.fetchPage(null, 1, 10);
            System.assert(false, 'Expected null target date to be rejected.');
        } catch (IllegalArgumentException expected) {
            System.assert(expected.getMessage().contains('targetDate'));
        }
    }

    @isTest
    static void batchFetchesOneDateWithSafePageSize() {
        Test.setMock(HttpCalloutMock.class, new InvoiceImportMock());

        Test.startTest();
        Database.executeBatch(
            new Mig_FreeeInvoiceFetchBatch(
                Date.newInstance(2026, 3, 20),
                Date.newInstance(2026, 3, 20),
                90
            ),
            1
        );
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Mig_FreeeInvoiceWork__c WHERE FreeeInvoiceId__c = '555']);
    }

    @isTest
    static void serviceRejectsInvalidDateRanges() {
        try {
            FreeeInvoiceImportService.enqueueImport(null, Date.newInstance(2026, 3, 20), 20);
            System.assert(false, 'Expected null rangeStartDate to be rejected.');
        } catch (IllegalArgumentException expected) {
            System.assert(expected.getMessage().contains('required'));
        }

        try {
            FreeeInvoiceImportService.enqueueImport(
                Date.newInstance(2026, 3, 21),
                Date.newInstance(2026, 3, 20),
                20
            );
            System.assert(false, 'Expected inverted date range to be rejected.');
        } catch (IllegalArgumentException expected) {
            System.assert(expected.getMessage().contains('before or equal'));
        }
    }
}
