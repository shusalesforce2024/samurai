List<Mig_FreeeInvoiceWork__c> updates = new List<Mig_FreeeInvoiceWork__c>();

for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id, InvoiceAmount__c, TaxAmount__c, FreeeInvoiceId__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c != null
      AND InvoiceAmount__c = 0
      AND TaxAmount__c = null
]) {
    updates.add(new Mig_FreeeInvoiceWork__c(
        Id = workRecord.Id,
        TaxAmount__c = 0
    ));
}

if (!updates.isEmpty()) {
    update updates;
}

System.debug('BACKFILL_ZERO_TAX_FREEE_INVOICE_WORK updates=' + updates.size());
