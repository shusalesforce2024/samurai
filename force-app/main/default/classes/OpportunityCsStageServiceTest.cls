@isTest
private class OpportunityCsStageServiceTest {
    @isTest
    static void initializesOnlyEligibleWonRenderyEnterpriseRecords() {
        String contractUpdateValue = Opportunity__c.ContractUpdate__c
            .getDescribe().getPicklistValues()[0].getValue();

        Opportunity__c eligible = new Opportunity__c(
            Name = 'Eligible CS opportunity',
            StageName__c = 'Closed Won',
            ProductCategory__c = 'Rendery',
            PlanCategory__c = 'Enterprise',
            ContractUpdate__c = contractUpdateValue
        );
        Opportunity__c ineligible = new Opportunity__c(
            Name = 'Ineligible CS opportunity',
            StageName__c = 'Prospecting',
            ProductCategory__c = 'Rendery',
            PlanCategory__c = 'Enterprise',
            ContractUpdate__c = contractUpdateValue
        );
        insert new List<Opportunity__c>{ eligible, ineligible };

        Map<Id, Opportunity__c> insertedRecords = new Map<Id, Opportunity__c>([
            SELECT CsStage__c
            FROM Opportunity__c
            WHERE Id IN :new Set<Id>{ eligible.Id, ineligible.Id }
        ]);
        System.assertEquals('S1', insertedRecords.get(eligible.Id).CsStage__c);
        System.assertEquals(null, insertedRecords.get(ineligible.Id).CsStage__c);
    }

    @isTest
    static void preservesAnExistingCsStage() {
        String contractUpdateValue = Opportunity__c.ContractUpdate__c
            .getDescribe().getPicklistValues()[0].getValue();
        Opportunity__c record = new Opportunity__c(
            Name = 'Established CS opportunity',
            StageName__c = 'Closed Won',
            ProductCategory__c = 'Rendery',
            PlanCategory__c = 'Enterprise',
            CsStage__c = 'S4',
            ContractUpdate__c = contractUpdateValue
        );
        insert record;

        record.Name = 'Established CS opportunity updated';
        update record;

        Opportunity__c updatedRecord = [
            SELECT CsStage__c
            FROM Opportunity__c
            WHERE Id = :record.Id
        ];
        System.assertEquals('S4', updatedRecord.CsStage__c);
    }
}
