List<Invoice__c> invoices = [
    SELECT Id, Name, Freee_Invoice_Id__c, Freee_Invoice_URL__c
    FROM Invoice__c
    WHERE Freee_Invoice_Id__c != null
      AND (Freee_Invoice_URL__c = null OR Freee_Invoice_URL__c = '')
];

for (Invoice__c invoice : invoices) {
    invoice.Freee_Invoice_URL__c =
        'https://invoice.secure.freee.co.jp/reports/invoices/' +
        String.valueOf(invoice.Freee_Invoice_Id__c.longValue());
}

if (!invoices.isEmpty()) {
    update invoices;
}

System.debug('updatedInvoiceUrlCount=' + invoices.size());
