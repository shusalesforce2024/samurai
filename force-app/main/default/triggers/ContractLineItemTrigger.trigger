trigger ContractLineItemTrigger on ContractLineItem__c (before insert, before update) {
    ContractLineItemPeriodService.populatePeriodFields(Trigger.new);
}
