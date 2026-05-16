trigger OpportunityTrigger on Opportunity__c (before insert, before update) {
    if (Trigger.isBefore) {
        OpportunityStageProbabilityService.syncProbability(Trigger.new, Trigger.oldMap);
    }
}
