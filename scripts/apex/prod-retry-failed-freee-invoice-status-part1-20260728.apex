List<Invoice__c> invoices = [
    SELECT Id,
           Freee_Invoice_Id__c,
           Freee_Invoice_Status__c,
           Freee_Account_Item_Picklist__c,
           InvoiceAmount__c,
           PaymentStatus__c,
           CancelStatus__c
    FROM Invoice__c
    WHERE Id IN (
        'a00RB000024Ux4nYAC',
        'a00RB000024Ux5BYAS',
        'a00RB000024Ux5DYAS',
        'a00RB000024Ux5EYAS',
        'a00RB000024Ux5JYAS'
    )
    ORDER BY Id
];

FreeeInvoiceStatusSyncService.syncInvoices(invoices);
