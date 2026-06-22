List<Invoice__c> updates = new List<Invoice__c>();
for (Invoice__c invoiceRecord : [
    SELECT Id,
           Freee_Invoice_Id__c,
           TotalAmount__c,
           InvoiceAmount__c,
           TaxAmount__c
    FROM Invoice__c
    WHERE Freee_Invoice_Id__c != null
      AND TaxAmount__c = null
      AND TotalAmount__c != null
      AND InvoiceAmount__c != null
]) {
    updates.add(new Invoice__c(
        Id = invoiceRecord.Id,
        TaxAmount__c = invoiceRecord.InvoiceAmount__c - invoiceRecord.TotalAmount__c
    ));
}

if (!updates.isEmpty()) {
    update updates;
}

System.debug('MIG_FREEE_FILLED_INVOICE_TAX_AMOUNTS=' + updates.size());
