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
        'a00RB000024Vf1yYAC',
        'a00RB000027fzNjYAI',
        'a00RB000027fzNlYAI',
        'a00RB000027fzNvYAI'
    )
    ORDER BY Id
];

FreeeInvoiceStatusSyncService.syncInvoices(invoices);
