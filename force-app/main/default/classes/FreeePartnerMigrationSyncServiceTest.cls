@isTest
private class FreeePartnerMigrationSyncServiceTest {
    private class PartnerSyncMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(request.getMethod() == 'GET' ? 200 : 201);
            response.setBody(
                request.getMethod() == 'GET'
                    ? '{"partners":[]}'
                    : '{"partner":{"id":998877}}'
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
    static void queueableCallsBulkSyncService() {
        List<Id> accountIds = new List<Id>{
            Account.SObjectType.getDescribe().getKeyPrefix() + '000000000001'
        };
        Test.startTest();
        new FreeePartnerBulkSyncQueueable(accountIds).execute(null);
        Test.stopTest();
    }

    @isTest
    static void enqueueCreatesSingleQueueableJob() {
        List<Id> accountIds = new List<Id>{
            Account.SObjectType.getDescribe().getKeyPrefix() + '000000000001',
            Account.SObjectType.getDescribe().getKeyPrefix() + '000000000002'
        };

        Test.startTest();
        List<Id> jobIds = FreeePartnerMigrationSyncService.enqueue(accountIds);
        Test.stopTest();

        System.assertEquals(1, jobIds.size());
    }

    @isTest
    static void enqueueTodayUnsyncedUsesTodayUnsyncedAccounts() {
        insert new List<Account>{
            new Account(Name = 'Migration Query Partner 1'),
            new Account(Name = 'Migration Query Partner 2', Freee_Partner_Id__c = 123456)
        };

        Test.startTest();
        List<Id> jobIds = FreeePartnerMigrationSyncService.enqueueTodayUnsynced(1);
        Test.stopTest();

        System.assertEquals(1, jobIds.size());
    }

    @isTest
    static void enqueueTodayUnsyncedRejectsInvalidLimit() {
        try {
            FreeePartnerMigrationSyncService.enqueueTodayUnsynced(FreeePartnerMigrationSyncService.MAX_MIGRATION_SIZE + 1);
            System.assert(false, 'Expected MigrationSyncException');
        } catch (FreeePartnerMigrationSyncService.MigrationSyncException e) {
            System.assert(e.getMessage().contains(String.valueOf(FreeePartnerMigrationSyncService.MAX_MIGRATION_SIZE)));
        }
    }

    @isTest
    static void enqueueSplitsMigrationIdsIntoQueueableJobs() {
        List<Id> accountIds = new List<Id>();
        for (Integer i = 0; i < FreeePartnerMigrationSyncService.QUEUEABLE_SCOPE_SIZE + 1; i++) {
            accountIds.add(Account.SObjectType.getDescribe().getKeyPrefix() + String.valueOf(i).leftPad(12, '0'));
        }

        Test.startTest();
        List<Id> jobIds = FreeePartnerMigrationSyncService.enqueue(accountIds);
        Test.stopTest();

        System.assertEquals(2, jobIds.size());
    }

    @isTest
    static void enqueueRejectsMoreThanMigrationLimit() {
        List<Id> accountIds = new List<Id>();
        for (Integer i = 0; i < FreeePartnerMigrationSyncService.MAX_MIGRATION_SIZE + 1; i++) {
            accountIds.add(Account.SObjectType.getDescribe().getKeyPrefix() + String.valueOf(i).leftPad(12, '0'));
        }

        try {
            FreeePartnerMigrationSyncService.enqueue(accountIds);
            System.assert(false, 'Expected MigrationSyncException');
        } catch (FreeePartnerMigrationSyncService.MigrationSyncException e) {
            System.assert(e.getMessage().contains(String.valueOf(FreeePartnerMigrationSyncService.MAX_MIGRATION_SIZE)));
        }
    }
}
