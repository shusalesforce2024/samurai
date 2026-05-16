trigger QuotationLineTrigger on QuotationLine__c (
    before insert,
    before update,
    after insert,
    after update,
    after delete,
    after undelete
) {
    if (Trigger.isBefore) {
        ProductUnitPriceSyncService.syncQuotationLineUnitPrice(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter) {
        OpportunityMrrSyncService.syncFromQuotationLines(Trigger.new, Trigger.old);
    }
}