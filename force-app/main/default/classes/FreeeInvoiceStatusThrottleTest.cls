@isTest
private class FreeeInvoiceStatusThrottleTest {
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            Integer marker = request.getEndpoint().indexOf('/invoices/');
            Integer startPosition = marker + '/invoices/'.length();
            Integer endPosition = request.getEndpoint().indexOf('?', startPosition);
            String invoiceId = request.getEndpoint().substring(startPosition, endPosition);

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody(
                '{"invoice":{"id":'
                + invoiceId
                + ',"sending_status":"sent","payment_status":"unpaid","payment_date":"'
                + String.valueOf(Date.today())
                + '"}}'
            );
            return response;
        }
    }

    private class RateLimitMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(429);
            response.setHeader('Content-Type', 'application/json');
            response.setBody(
                '{"status_code":429,"meta":{"limit":30,"period":60,"remaining":0}}'
            );
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
    static void processesTwentyInvoicesAndSchedulesTheRemainder() {
        List<Invoice__c> invoices = createInvoices(21, 5000);
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        FreeeInvoiceStatusSyncThrottledScheduler.skipSchedulingForTest = true;

        Test.startTest();
        System.enqueueJob(new FreeeInvoiceStatusSyncThrottledQueueable(
            Date.today(),
            null,
            0,
            false
        ));
        Test.stopTest();

        System.assertEquals(
            20,
            [
                SELECT COUNT()
                FROM Invoice__c
                WHERE Id IN :invoices
                  AND Freee_Sync_Status__c = 'Success'
            ]
        );
        System.assertEquals(
            FreeeInvoiceStatusSyncThrottledQueueable.NEXT_CHUNK_DELAY_MINUTES,
            FreeeInvoiceStatusSyncThrottledScheduler.lastRequestedDelayMinutes
        );
    }

    @isTest
    static void rateLimitSchedulesRetryAndKeepsTheInvoiceFailedUntilRetry() {
        List<Invoice__c> invoices = createInvoices(1, 6000);
        Test.setMock(HttpCalloutMock.class, new RateLimitMock());
        FreeeInvoiceStatusSyncThrottledScheduler.skipSchedulingForTest = true;

        Test.startTest();
        System.enqueueJob(new FreeeInvoiceStatusSyncThrottledQueueable(
            Date.today(),
            null,
            0,
            false
        ));
        Test.stopTest();

        Invoice__c failedInvoice = [
            SELECT Freee_Sync_Status__c,
                   Freee_Sync_Message__c
            FROM Invoice__c
            WHERE Id = :invoices[0].Id
        ];
        System.assertEquals('Failed', failedInvoice.Freee_Sync_Status__c);
        System.assert(failedInvoice.Freee_Sync_Message__c.contains('freee APIの利用上限'));
        System.assertEquals(3, FreeeInvoiceStatusSyncThrottledScheduler.lastRequestedDelayMinutes);
    }

    @isTest
    static void scheduledEntryPointStartsTheThrottledQueueable() {
        List<Invoice__c> invoices = createInvoices(1, 7000);
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        FreeeInvoiceStatusSyncThrottledScheduler.skipActiveChainCheckForTest = true;

        Test.startTest();
        new FreeeInvoiceStatusSyncBatch().execute((SchedulableContext) null);
        Test.stopTest();

        System.assertEquals(
            'Success',
            [
                SELECT Freee_Sync_Status__c
                FROM Invoice__c
                WHERE Id = :invoices[0].Id
            ].Freee_Sync_Status__c
        );
    }

    @isTest
    static void preservesRateLimitedAndUnprocessedIdsForTheNextChunk() {
        List<Invoice__c> invoices = createInvoices(3, 8000);
        List<Id> workIds = new List<Id>{
            invoices[0].Id,
            invoices[1].Id,
            invoices[2].Id
        };

        List<Id> nextIds =
            FreeeInvoiceStatusSyncThrottledQueueable.buildNextIds(
                workIds,
                workIds,
                invoices[1].Id
            );

        System.assertEquals(
            new List<Id>{invoices[1].Id, invoices[2].Id},
            nextIds
        );
    }

    @isTest
    static void schedulerCreatesDetectsAndAbortsAWaitingChunk() {
        DateTime runAt = System.now().addMinutes(5);
        Id scheduledJobId = FreeeInvoiceStatusSyncThrottledScheduler.scheduleNextRun(
            Date.today(),
            new List<Id>(),
            0,
            false,
            5
        );

        System.assertNotEquals(null, scheduledJobId);
        System.assertEquals(5, FreeeInvoiceStatusSyncThrottledScheduler.lastRequestedDelayMinutes);
        System.assertEquals(true, FreeeInvoiceStatusSyncThrottledScheduler.hasActiveChain());
        System.assertEquals(
            1,
            FreeeInvoiceStatusSyncThrottledScheduler.abortWaitingChunkSchedules()
        );
        System.assertEquals(false, FreeeInvoiceStatusSyncThrottledScheduler.hasActiveChain());

        String cronExpression = FreeeInvoiceStatusSyncThrottledScheduler.cronFor(runAt);
        System.assert(cronExpression.endsWith(String.valueOf(runAt.year())));
    }

    @isTest
    static void schedulerExecuteEnqueuesAQueueableWithNoRemainingWork() {
        FreeeInvoiceStatusSyncThrottledScheduler scheduler =
            new FreeeInvoiceStatusSyncThrottledScheduler(
                Date.today(),
                new List<Id>(),
                0,
                false
            );

        Test.startTest();
        scheduler.execute((SchedulableContext) null);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Invoice__c]);
    }

    private static List<Invoice__c> createInvoices(Integer count, Integer firstFreeeId) {
        Account accountRecord = new Account(Name = 'Throttled Status Sync Account ' + firstFreeeId);
        insert accountRecord;

        List<Invoice__c> invoices = new List<Invoice__c>();
        for (Integer i = 0; i < count; i++) {
            invoices.add(new Invoice__c(
                Account__c = accountRecord.Id,
                Billing_Date__c = Date.today(),
                Freee_Account_Item_Picklist__c = 'Sales',
                Freee_Invoice_Id__c = firstFreeeId + i,
                InvoiceAmount__c = 1100,
                Payment_Date__c = Date.today(),
                Sent_To_Freee__c = true,
                Subject__c = 'Throttled Status Invoice ' + i
            ));
        }
        insert invoices;
        return invoices;
    }
}
