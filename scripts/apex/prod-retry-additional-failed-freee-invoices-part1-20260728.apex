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
        'a00RB000024Ux4bYAC',
        'a00RB000024Ux4cYAC',
        'a00RB000024Ux4dYAC',
        'a00RB000024Ux4PYAS',
        'a00RB000024Ux4uYAC',
        'a00RB000024Ux53YAC',
        'a00RB000024Ux54YAC',
        'a00RB000024Ux5CYAS'
    )
    ORDER BY Id
];

FreeeInvoiceStatusSyncService.syncInvoices(invoices);
