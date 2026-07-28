@isTest
private class ContractOppClassificationSyncServiceTest {
    @isTest
    static void syncsClassificationToRelatedContractsWhenOpportunityChanges() {
        Account accountRecord = new Account(Name = 'Classification Account');
        insert accountRecord;

        String opportunityContractUpdateValue =
            Opportunity__c.ContractUpdate__c.getDescribe().getPicklistValues()[0].getValue();
        Opportunity__c opportunityRecord = new Opportunity__c(
            Name = 'Classification Opportunity',
            Account__c = accountRecord.Id,
            ContractUpdate__c = opportunityContractUpdateValue,
            StageName__c = 'Prospecting',
            StartDate__c = Date.newInstance(2026, 7, 1),
            ProductCategory__c = 'Rendery',
            PlanCategory__c = 'Pro',
            AccountCount__c = 3
        );
        insert opportunityRecord;

        String contractUpdateValue =
            Contract__c.ContractUpdate__c.getDescribe().getPicklistValues()[0].getValue();
        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = 'Classification Contract',
            ContractUpdate__c = contractUpdateValue,
            Oppotunity__c = opportunityRecord.Id,
            StartDate__c = Date.newInstance(2026, 7, 1),
            Status__c = 'Activated'
        );
        insert contractRecord;

        Test.startTest();
        opportunityRecord.ProductCategory__c = 'knock knock AI';
        opportunityRecord.PlanCategory__c = 'Enterprise';
        opportunityRecord.AccountCount__c = 10;
        update opportunityRecord;
        Test.stopTest();

        Contract__c syncedContract = [
            SELECT ProductCategory__c,
                   PlanCategory__c,
                   AccountCount__c
            FROM Contract__c
            WHERE Id = :contractRecord.Id
        ];
        System.assertEquals('knock knock AI', syncedContract.ProductCategory__c);
        System.assertEquals('Enterprise', syncedContract.PlanCategory__c);
        System.assertEquals(10, syncedContract.AccountCount__c);
    }
}
