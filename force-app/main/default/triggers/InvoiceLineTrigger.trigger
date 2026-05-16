trigger InvoiceLineTrigger on InvoiceLine__c (before insert, before update) {
    ProductUnitPriceSyncService.syncInvoiceLineUnitPrice(Trigger.new, Trigger.oldMap);
}