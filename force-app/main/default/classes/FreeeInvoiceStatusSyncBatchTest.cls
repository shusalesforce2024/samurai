@isTest
private class FreeeInvoiceStatusSyncBatchTest {
    private class InvoiceStatusMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assert(request.getEndpoint().contains('?company_id=12345'));
            String invoiceId = extractInvoiceIdFromEndpoint(request.getEndpoint());

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"invoice":{"id":' + invoiceId + ',"sending_status":"sent","payment_status":"paid","paid_at":"2026-06-20","payment_date":"2026-06-30"}}');
            return response;
        }
    }

    private class AlternateInvoiceStatusMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assert(request.getEndpoint().contains('?company_id=12345'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"id":1002,"send_status":"draft","settlement_status":"unsettled","payment_amount":"bad-decimal","balance":2200,"paid_at":"bad-date","due_date":"2026-08-20"}');
            return response;
        }
    }

    private class MismatchedInvoiceStatusMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assert(request.getEndpoint().contains('?company_id=12345'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"invoice":{"id":999999,"sending_status":"sent","payment_status":"paid"}}');
            return response;
        }
    }

    private class FailedInvoiceStatusMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assert(request.getEndpoint().contains('?company_id=12345'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setHeader('Content-Type', 'application/json');
            response.setBody('');
            return response;
        }
    }

    private class ThrowingInvoiceStatusMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assert(request.getEndpoint().contains('?company_id=12345'));
            throw new CalloutException('network failure');
        }
    }

    private class ServiceEndpointMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            if (request.getMethod() == 'POST' && request.getEndpoint().endsWith('/invoices')) {
                System.assertEquals('{"invoice":true}', request.getBody());
                return buildResponse(201, '{"invoice":{"id":1005}}');
            }

            if (request.getMethod() == 'GET') {
                System.assert(request.getEndpoint().contains('/invoices/1005?company_id=12345'));
                return buildResponse(200, '{"invoice":{"id":1005}}');
            }

            System.assertEquals('POST', request.getMethod());
            System.assert(request.getEndpoint().contains('/invoices/1005/cancel?company_id=12345'));
            return buildResponse(200, '{"invoice":{"id":1005,"cancel_status":"cancelled"}}');
        }

        private HttpResponse buildResponse(Integer statusCode, String body) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setHeader('Content-Type', 'application/json');
            response.setBody(body);
            return response;
        }
    }

    private static String extractInvoiceIdFromEndpoint(String endpoint) {
        Integer marker = endpoint.indexOf('/invoices/');
        System.assert(marker >= 0, 'Endpoint must include /invoices/. endpoint=' + endpoint);
        Integer startPos = marker + '/invoices/'.length();
        Integer endPos = endpoint.indexOf('?', startPos);
        return endpoint.substring(startPos, endPos);
    }

    @testSetup
    static void setupFreeeConfig() {
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
    static void syncsUnpaidFreeeInvoices() {
        Account accountRecord = new Account(Name = 'Sync Account');
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 6, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Id__c = 999,
            Freee_Sync_Status__c = 'Success',
            InvoiceAmount__c = 1100,
            Payment_Date__c = Date.newInstance(2026, 7, 31),
            Sent_To_Freee__c = true,
            Subject__c = 'Sync Invoice'
        );
        insert invoiceRecord;

        Test.setMock(HttpCalloutMock.class, new InvoiceStatusMock());

        Test.startTest();
        Database.executeBatch(new FreeeInvoiceStatusSyncBatch(), 50);
        Test.stopTest();

        Invoice__c synced = [
            SELECT Freee_Invoice_Status__c,
                   PaymentStatus__c,
                   PaidAmount__c,
                   UnpaidAmount__c,
                   PaymentReceivedDate__c,
                   Payment_Date__c,
                   Freee_Sync_Status__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, synced.Freee_Invoice_Status__c);
        System.assertNotEquals(null, synced.PaymentStatus__c);
        System.assertEquals(1100, synced.PaidAmount__c);
        System.assertEquals(0, synced.UnpaidAmount__c);
        System.assertEquals(Date.newInstance(2026, 6, 20), synced.PaymentReceivedDate__c);
        System.assertEquals(Date.newInstance(2026, 6, 30), synced.Payment_Date__c);
        System.assertEquals('Success', synced.Freee_Sync_Status__c);
    }

    @isTest
    static void syncsMultipleInvoicesWithoutUncommittedWorkError() {
        Account accountRecord = new Account(Name = 'Multiple Sync Account');
        insert accountRecord;

        List<Invoice__c> invoiceRecords = new List<Invoice__c>{
            new Invoice__c(
                Account__c = accountRecord.Id,
                Billing_Date__c = Date.newInstance(2026, 6, 20),
                Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Id__c = 2001,
            Freee_Sync_Status__c = 'Success',
            InvoiceAmount__c = 1100,
            Payment_Date__c = Date.newInstance(2026, 7, 31),
                Sent_To_Freee__c = true,
                Subject__c = 'Multiple Sync Invoice 1'
            ),
            new Invoice__c(
                Account__c = accountRecord.Id,
                Billing_Date__c = Date.newInstance(2026, 6, 20),
                Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Id__c = 2002,
            Freee_Sync_Status__c = 'Success',
            InvoiceAmount__c = 1100,
            Payment_Date__c = Date.newInstance(2026, 7, 31),
                Sent_To_Freee__c = true,
                Subject__c = 'Multiple Sync Invoice 2'
            )
        };
        insert invoiceRecords;

        Test.setMock(HttpCalloutMock.class, new InvoiceStatusMock());

        Test.startTest();
        FreeeInvoiceStatusSyncService.syncInvoices(invoiceRecords);
        Test.stopTest();

        for (Invoice__c synced : [
            SELECT Freee_Sync_Status__c,
                   PaymentStatus__c
            FROM Invoice__c
            WHERE Id IN :invoiceRecords
        ]) {
            System.assertEquals('Success', synced.Freee_Sync_Status__c);
            System.assertEquals('決済済み', synced.PaymentStatus__c);
        }
    }

    @isTest
    static void syncBackfillsRequiredAccountItemWhenFieldIsNotLoaded() {
        Account accountRecord = new Account(Name = 'Legacy Sync Account');
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 6, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Id__c = 1001,
            Freee_Sync_Status__c = 'Success',
            Payment_Date__c = Date.newInstance(2026, 7, 31),
            Sent_To_Freee__c = true,
            Subject__c = 'Legacy Sync Invoice'
        );
        insert invoiceRecord;

        Invoice__c partiallyLoadedInvoice = [
            SELECT Id,
                   Freee_Invoice_Id__c,
                   Freee_Invoice_Status__c,
                   InvoiceAmount__c,
                   PaymentStatus__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new InvoiceStatusMock());

        Test.startTest();
        FreeeInvoiceStatusSyncService.syncInvoices(new List<Invoice__c>{ partiallyLoadedInvoice });
        Test.stopTest();

        Invoice__c synced = [
            SELECT Freee_Account_Item_Picklist__c,
                   Freee_Invoice_Status__c,
                   PaymentStatus__c,
                   Freee_Sync_Status__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
            LIMIT 1
        ];
        System.assertEquals('Sales', synced.Freee_Account_Item_Picklist__c);
        System.assertNotEquals(null, synced.Freee_Invoice_Status__c);
        System.assertNotEquals(null, synced.PaymentStatus__c);
        System.assertEquals('Success', synced.Freee_Sync_Status__c);
    }
    @isTest
    static void syncHandlesAlternateResponseKeysAndInvalidValues() {
        Account accountRecord = new Account(Name = 'Alternate Sync Account');
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 7, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Id__c = 1002,
            Freee_Sync_Status__c = 'Success',
            InvoiceAmount__c = 2200,
            Payment_Date__c = Date.newInstance(2026, 7, 31),
            Sent_To_Freee__c = true,
            Subject__c = 'Alternate Sync Invoice'
        );
        insert invoiceRecord;

        Test.setMock(HttpCalloutMock.class, new AlternateInvoiceStatusMock());

        Test.startTest();
        FreeeInvoiceStatusSyncService.syncInvoices(new List<Invoice__c>{ invoiceRecord });
        Test.stopTest();

        Invoice__c synced = [
            SELECT Freee_Invoice_Status__c,
                   PaymentStatus__c,
                   PaidAmount__c,
                   UnpaidAmount__c,
                   PaymentReceivedDate__c,
                   Payment_Date__c,
                   Freee_Sync_Status__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, synced.Freee_Invoice_Status__c);
        System.assertNotEquals(null, synced.PaymentStatus__c);
        System.assertEquals(0, synced.PaidAmount__c);
        System.assertEquals(2200, synced.UnpaidAmount__c);
        System.assertEquals(null, synced.PaymentReceivedDate__c);
        System.assertEquals(Date.newInstance(2026, 8, 20), synced.Payment_Date__c);
        System.assertEquals('Success', synced.Freee_Sync_Status__c);
    }

    @isTest
    static void syncMarksInvoiceFailedWhenFreeeRespondsWithError() {
        Account accountRecord = new Account(Name = 'Failed Sync Account');
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 8, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Id__c = 1003,
            Freee_Sync_Status__c = 'Success',
            Payment_Date__c = Date.newInstance(2026, 8, 31),
            Sent_To_Freee__c = true,
            Subject__c = 'Failed Sync Invoice'
        );
        insert invoiceRecord;

        Test.setMock(HttpCalloutMock.class, new FailedInvoiceStatusMock());

        Test.startTest();
        FreeeInvoiceStatusSyncService.syncInvoices(new List<Invoice__c>{ invoiceRecord });
        Test.stopTest();

        Invoice__c synced = [
            SELECT Freee_Sync_Status__c,
                   Freee_Sync_Message__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
            LIMIT 1
        ];
        System.assertEquals('Failed', synced.Freee_Sync_Status__c);
        System.assertNotEquals(null, synced.Freee_Sync_Message__c);
    }

    @isTest
    static void syncMarksInvoiceFailedWhenCalloutThrowsException() {
        Account accountRecord = new Account(Name = 'Exception Sync Account');
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 9, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Id__c = 1004,
            Freee_Sync_Status__c = 'Success',
            Payment_Date__c = Date.newInstance(2026, 9, 30),
            Sent_To_Freee__c = true,
            Subject__c = 'Exception Sync Invoice'
        );
        insert invoiceRecord;

        Test.setMock(HttpCalloutMock.class, new ThrowingInvoiceStatusMock());

        Test.startTest();
        FreeeInvoiceStatusSyncService.syncInvoices(new List<Invoice__c>{ invoiceRecord });
        Test.stopTest();

        Invoice__c synced = [
            SELECT Freee_Sync_Status__c,
                   Freee_Sync_Message__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
            LIMIT 1
        ];
        System.assertEquals('Failed', synced.Freee_Sync_Status__c);
        System.assert(synced.Freee_Sync_Message__c.contains('network failure'));
    }

    @isTest
    static void syncMarksInvoiceFailedWhenFreeeResponseIdDoesNotMatch() {
        Account accountRecord = new Account(Name = 'Mismatch Sync Account');
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 11, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Id__c = 1101,
            Freee_Sync_Status__c = 'Success',
            Payment_Date__c = Date.newInstance(2026, 11, 30),
            Sent_To_Freee__c = true,
            Subject__c = 'Mismatch Sync Invoice'
        );
        insert invoiceRecord;

        Test.setMock(HttpCalloutMock.class, new MismatchedInvoiceStatusMock());

        Test.startTest();
        FreeeInvoiceStatusSyncService.syncInvoices(new List<Invoice__c>{ invoiceRecord });
        Test.stopTest();

        Invoice__c synced = [
            SELECT Freee_Sync_Status__c,
                   Freee_Sync_Message__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
            LIMIT 1
        ];
        System.assertEquals('Failed', synced.Freee_Sync_Status__c);
        System.assert(synced.Freee_Sync_Message__c.contains('freee invoice id mismatch'));
    }

    @isTest
    static void syncIgnoresBlankInputsAndInvoicesWithoutFreeeId() {
        Account accountRecord = new Account(Name = 'Skipped Sync Account');
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 10, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Sync_Status__c = 'Success',
            Payment_Date__c = Date.newInstance(2026, 10, 31),
            Sent_To_Freee__c = true,
            Subject__c = 'Skipped Sync Invoice'
        );
        insert invoiceRecord;

        Test.startTest();
        FreeeInvoiceStatusSyncService.syncInvoices(null);
        FreeeInvoiceStatusSyncService.syncInvoices(new List<Invoice__c>());
        FreeeInvoiceStatusSyncService.syncInvoices(new List<Invoice__c>{ invoiceRecord });
        Test.stopTest();

        Invoice__c synced = [
            SELECT Freee_Sync_Status__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
            LIMIT 1
        ];
        System.assertEquals('Success', synced.Freee_Sync_Status__c);
    }

    @isTest
    static void invoiceServiceAddsCompanyIdToReadAndCancelEndpoints() {
        Test.setMock(HttpCalloutMock.class, new ServiceEndpointMock());

        Test.startTest();
        HttpResponse createResponse = FreeeInvoiceService.createInvoice('{"invoice":true}');
        HttpResponse getResponse = FreeeInvoiceService.getInvoice(1005);
        HttpResponse cancelResponse = FreeeInvoiceService.cancelInvoice(1005);
        Test.stopTest();

        System.assertEquals(201, createResponse.getStatusCode());
        System.assertEquals(200, getResponse.getStatusCode());
        System.assertEquals(200, cancelResponse.getStatusCode());
    }
}

