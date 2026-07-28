trigger OpportunityTrigger on Opportunity__c (before insert, before update, after update) {
    if (Trigger.isBefore) {
        OpportunityStageProbabilityService.syncProbability(Trigger.new, Trigger.oldMap);
        OpportunityCsStageService.initializeCsStage(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        ContractOppClassificationSyncService.syncFromOpportunityUpdates(
            Trigger.new,
            Trigger.oldMap
        );
    }
}
