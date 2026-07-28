trigger InvoiceTrigger on Invoice__c (before insert) {
    InvoiceDefaultsService.applyBeforeInsert(Trigger.new);
}
