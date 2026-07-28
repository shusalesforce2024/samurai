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
        'a00RB000024Ux5IYAS',
        'a00RB000024Ux5KYAS',
        'a00RB000027fzNeYAI',
        'a00RB000027fzNgYAI',
        'a00RB000027fzNhYAI',
        'a00RB000027fzNiYAI',
        'a00RB000027fzNkYAI',
        'a00RB000027fzNmYAI'
    )
    ORDER BY Id
];

FreeeInvoiceStatusSyncService.syncInvoices(invoices);
