trigger InvoiceLineTrigger on InvoiceLine__c (
    before insert,
    before update,
    after insert,
    after update
) {
    if (Trigger.isBefore) {
        ProductUnitPriceSyncService.syncInvoiceLineUnitPrice(
            Trigger.new,
            Trigger.oldMap
        );
    }
    if (Trigger.isAfter) {
        ContractClassBackfillService.syncFromInvoiceLines(Trigger.new);
    }
}
