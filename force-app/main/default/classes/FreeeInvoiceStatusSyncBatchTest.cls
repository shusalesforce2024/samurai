@isTest
private class FreeeInvoiceStatusSyncBatchTest {
    private class InvoiceStatusMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"invoice":{"sending_status":"sent","payment_status":"paid","paid_amount":1100,"unpaid_amount":0,"payment_date":"2026-06-20","payment_limit_date":"2026-06-30"}}');
            return response;
        }
    }

    private class AlternateInvoiceStatusMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"send_status":"draft","settlement_status":"unsettled","payment_amount":"bad-decimal","balance":2200,"paid_at":"bad-date","due_date":"2026-08-20"}');
            return response;
        }
    }

    private class FailedInvoiceStatusMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setHeader('Content-Type', 'application/json');
            response.setBody('');
            return response;
        }
    }

    private class ThrowingInvoiceStatusMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            throw new CalloutException('network failure');
        }
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
        System.assertEquals(null, synced.PaidAmount__c);
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
}

