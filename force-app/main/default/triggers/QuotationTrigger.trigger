trigger QuotationTrigger on Quotation__c (after insert, after update, after delete, after undelete) {
    OpportunityMrrSyncService.syncFromQuotations(Trigger.new, Trigger.old);
}