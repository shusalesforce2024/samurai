trigger OpportunityTrigger on Opportunity__c (before insert, before update) {
    OpportunityStageProbabilityService.syncProbability(Trigger.new, Trigger.oldMap);
}