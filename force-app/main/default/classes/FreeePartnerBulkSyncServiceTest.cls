@isTest
private class FreeePartnerBulkSyncServiceTest {
    private class BulkPartnerSyncMock implements HttpCalloutMock {
        Integer getCallCount = 0;
        Integer postCallCount = 0;

        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();

            if (request.getMethod() == 'GET') {
                getCallCount++;
                response.setStatusCode(200);
                response.setBody(
                    request.getEndpoint().contains('Existing')
                        ? '{"partners":[{"id":777001,"name":"Existing Partner"}]}'
                        : '{"partners":[]}'
                );
                return response;
            }

            System.assertEquals('POST', request.getMethod());
            System.assertEquals('application/json', request.getHeader('Content-Type'));
            System.assert(String.isNotBlank(request.getBody()));
            postCallCount++;

            response.setStatusCode(201);
            response.setBody('{"partner":{"id":999001}}');
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
    static void syncPartnersCreatesFindsAndSkipsAccounts() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'New Partner'),
            new Account(Name = 'Existing Partner'),
            new Account(Name = 'Already Synced', Freee_Partner_Id__c = 111001)
        };
        insert accounts;

        BulkPartnerSyncMock mock = new BulkPartnerSyncMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        FreeePartnerBulkSyncService.Summary summary = FreeePartnerBulkSyncService.syncPartners(
            new List<Id>{ accounts[0].Id, accounts[1].Id, accounts[2].Id }
        );
        Test.stopTest();

        Map<Id, Account> updatedAccounts = new Map<Id, Account>([
            SELECT Freee_Partner_Id__c
            FROM Account
            WHERE Id IN :accounts
        ]);

        System.assertEquals(3, summary.totalCount);
        System.assertEquals(2, summary.successCount);
        System.assertEquals(1, summary.skippedCount);
        System.assertEquals(0, summary.failedCount);
        System.assertEquals(2, mock.getCallCount);
        System.assertEquals(1, mock.postCallCount);
        System.assertEquals(Decimal.valueOf(999001), updatedAccounts.get(accounts[0].Id).Freee_Partner_Id__c);
        System.assertEquals(Decimal.valueOf(777001), updatedAccounts.get(accounts[1].Id).Freee_Partner_Id__c);
        System.assertEquals(Decimal.valueOf(111001), updatedAccounts.get(accounts[2].Id).Freee_Partner_Id__c);
    }

    @isTest
    static void controllerProcessesSelectedAccounts() {
        Account accountRecord = new Account(Name = 'Controller Partner');
        insert accountRecord;

        BulkPartnerSyncMock mock = new BulkPartnerSyncMock();
        Test.setMock(HttpCalloutMock.class, mock);

        ApexPages.StandardSetController controller = new ApexPages.StandardSetController([
            SELECT Id
            FROM Account
            WHERE Id = :accountRecord.Id
        ]);
        controller.setSelected(new List<Account>{ accountRecord });

        Test.startTest();
        FreeePartnerBulkSyncController extension = new FreeePartnerBulkSyncController(controller);
        extension.sync();
        Test.stopTest();

        Account updatedAccount = [
            SELECT Freee_Partner_Id__c
            FROM Account
            WHERE Id = :accountRecord.Id
        ];

        System.assertEquals(false, extension.getHasError());
        System.assertEquals(true, extension.getHasResults());
        System.assertEquals(Decimal.valueOf(999001), updatedAccount.Freee_Partner_Id__c);
    }

    @isTest
    static void controllerProcessesIdsParameterWhenSelectedRowsAreEmpty() {
        Account accountRecord = new Account(Name = 'Controller Url Partner');
        insert accountRecord;

        BulkPartnerSyncMock mock = new BulkPartnerSyncMock();
        Test.setMock(HttpCalloutMock.class, mock);

        ApexPages.StandardSetController controller = new ApexPages.StandardSetController([
            SELECT Id
            FROM Account
            WHERE Id = :accountRecord.Id
        ]);
        controller.setSelected(new List<Account>());
        ApexPages.currentPage().getParameters().put('ids', String.valueOf(accountRecord.Id));

        Test.startTest();
        FreeePartnerBulkSyncController extension = new FreeePartnerBulkSyncController(controller);
        extension.sync();
        Test.stopTest();

        Account updatedAccount = [
            SELECT Freee_Partner_Id__c
            FROM Account
            WHERE Id = :accountRecord.Id
        ];

        System.assertEquals(false, extension.getHasError());
        System.assertEquals(true, extension.getHasResults());
        System.assertEquals(Decimal.valueOf(999001), updatedAccount.Freee_Partner_Id__c);
    }

    @isTest
    static void controllerProcessesBracketedIdsParameter() {
        Account accountRecord = new Account(Name = 'Controller Bracket Url Partner');
        insert accountRecord;

        BulkPartnerSyncMock mock = new BulkPartnerSyncMock();
        Test.setMock(HttpCalloutMock.class, mock);

        ApexPages.StandardSetController controller = new ApexPages.StandardSetController([
            SELECT Id
            FROM Account
            WHERE Id = :accountRecord.Id
        ]);
        controller.setSelected(new List<Account>());
        ApexPages.currentPage().getParameters().put('ids', '[' + String.valueOf(accountRecord.Id) + ']');

        Test.startTest();
        FreeePartnerBulkSyncController extension = new FreeePartnerBulkSyncController(controller);
        extension.sync();
        Test.stopTest();

        Account updatedAccount = [
            SELECT Freee_Partner_Id__c
            FROM Account
            WHERE Id = :accountRecord.Id
        ];

        System.assertEquals(false, extension.getHasError());
        System.assertEquals(true, extension.getHasResults());
        System.assertEquals(Decimal.valueOf(999001), updatedAccount.Freee_Partner_Id__c);
    }

    @isTest
    static void standaloneControllerProcessesSelectedParameter() {
        Account accountRecord = new Account(Name = 'Standalone Url Partner');
        insert accountRecord;

        BulkPartnerSyncMock mock = new BulkPartnerSyncMock();
        Test.setMock(HttpCalloutMock.class, mock);
        ApexPages.currentPage().getParameters().put('selected', '[' + String.valueOf(accountRecord.Id) + ']');

        Test.startTest();
        FreeePartnerBulkSyncController controller = new FreeePartnerBulkSyncController();
        controller.sync();
        Test.stopTest();

        Account updatedAccount = [
            SELECT Freee_Partner_Id__c
            FROM Account
            WHERE Id = :accountRecord.Id
        ];

        System.assertEquals(false, controller.getHasError());
        System.assertEquals(true, controller.getHasResults());
        System.assertEquals(Decimal.valueOf(999001), updatedAccount.Freee_Partner_Id__c);
    }

    @isTest
    static void controllerShowsReadableErrorWhenNoRowsAreSelected() {
        ApexPages.StandardSetController controller = new ApexPages.StandardSetController([
            SELECT Id
            FROM Account
            LIMIT 1
        ]);
        controller.setSelected(new List<Account>());

        Test.startTest();
        FreeePartnerBulkSyncController extension = new FreeePartnerBulkSyncController(controller);
        extension.sync();
        Test.stopTest();

        System.assertEquals(true, extension.getHasError());
        System.assertNotEquals('Script-thrown exception', extension.errorMessage);
        System.assert(extension.errorMessage.contains('同期対象の取引先を選択してください'));
    }

    @isTest
    static void syncPartnersRejectsTooManyAccounts() {
        List<Id> ids = new List<Id>();
        for (Integer i = 0; i < FreeePartnerBulkSyncService.MAX_SYNC_SIZE + 1; i++) {
            ids.add(Account.SObjectType.getDescribe().getKeyPrefix() + String.valueOf(i).leftPad(12, '0'));
        }

        try {
            FreeePartnerBulkSyncService.syncPartners(ids);
            System.assert(false, 'Expected BulkSyncException');
        } catch (FreeePartnerBulkSyncService.BulkSyncException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
    }
}
