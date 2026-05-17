trigger ContractTrigger on Contract__c (after insert, after update) {
    ContractMonthlyLineBatch.createInitialLinesForActivatedContracts(
        Trigger.new,
        Trigger.isUpdate ? Trigger.oldMap : null
    );
}