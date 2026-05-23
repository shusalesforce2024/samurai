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

    @isTest
    static void syncsUnpaidFreeeInvoices() {
        Account accountRecord = new Account(Name = 'Sync Account');
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 6, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Id__c = 999,
            Freee_Invoice_Status__c = '送付待ち',
            Freee_Sync_Status__c = 'Success',
            PaymentStatus__c = '決済待ち',
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
        System.assertEquals('送付済み', synced.Freee_Invoice_Status__c);
        System.assertEquals('決済済み', synced.PaymentStatus__c);
        System.assertEquals(1100, synced.PaidAmount__c);
        System.assertEquals(0, synced.UnpaidAmount__c);
        System.assertEquals(Date.newInstance(2026, 6, 20), synced.PaymentReceivedDate__c);
        System.assertEquals(Date.newInstance(2026, 6, 30), synced.Payment_Date__c);
        System.assertEquals('Success', synced.Freee_Sync_Status__c);
    }
}
