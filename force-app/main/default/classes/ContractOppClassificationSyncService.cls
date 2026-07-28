public with sharing class ContractOppClassificationSyncService {
    public static void syncFromOpportunityUpdates(
        List<Opportunity__c> newRecords,
        Map<Id, Opportunity__c> oldMap
    ) {
        Set<Id> changedOpportunityIds = new Set<Id>();
        for (Opportunity__c opportunityRecord : newRecords) {
            Opportunity__c oldRecord = oldMap == null ? null : oldMap.get(opportunityRecord.Id);
            if (oldRecord == null || hasClassificationChanged(opportunityRecord, oldRecord)) {
                changedOpportunityIds.add(opportunityRecord.Id);
            }
        }

        if (changedOpportunityIds.isEmpty()) {
            return;
        }

        Map<Id, Opportunity__c> opportunitiesById = new Map<Id, Opportunity__c>([
            SELECT Id,
                   ProductCategory__c,
                   PlanCategory__c,
                   AccountCount__c
            FROM Opportunity__c
            WHERE Id IN :changedOpportunityIds
        ]);

        List<Contract__c> contractsToUpdate = new List<Contract__c>();
        for (Contract__c contractRecord : [
            SELECT Id,
                   Oppotunity__c,
                   ProductCategory__c,
                   PlanCategory__c,
                   AccountCount__c
            FROM Contract__c
            WHERE Oppotunity__c IN :changedOpportunityIds
        ]) {
            Opportunity__c opportunityRecord = opportunitiesById.get(contractRecord.Oppotunity__c);
            if (opportunityRecord == null) {
                continue;
            }

            if (needsUpdate(contractRecord, opportunityRecord)) {
                contractsToUpdate.add(new Contract__c(
                    Id = contractRecord.Id,
                    ProductCategory__c = opportunityRecord.ProductCategory__c,
                    PlanCategory__c = opportunityRecord.PlanCategory__c,
                    AccountCount__c = opportunityRecord.AccountCount__c
                ));
            }
        }

        if (!contractsToUpdate.isEmpty()) {
            update contractsToUpdate;
        }
    }

    private static Boolean hasClassificationChanged(
        Opportunity__c newRecord,
        Opportunity__c oldRecord
    ) {
        return newRecord.ProductCategory__c != oldRecord.ProductCategory__c
            || newRecord.PlanCategory__c != oldRecord.PlanCategory__c
            || newRecord.AccountCount__c != oldRecord.AccountCount__c;
    }

    private static Boolean needsUpdate(
        Contract__c contractRecord,
        Opportunity__c opportunityRecord
    ) {
        return contractRecord.ProductCategory__c != opportunityRecord.ProductCategory__c
            || contractRecord.PlanCategory__c != opportunityRecord.PlanCategory__c
            || contractRecord.AccountCount__c != opportunityRecord.AccountCount__c;
    }
}
