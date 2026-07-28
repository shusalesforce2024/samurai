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
        'a00RB000027fzNoYAI',
        'a00RB000027fzNpYAI',
        'a00RB000027fzNqYAI',
        'a00RB000027fzNrYAI',
        'a00RB000027fzNsYAI',
        'a00RB000027fzNtYAI',
        'a00RB000027fzNwYAI',
        'a00RB000027fzNxYAI'
    )
    ORDER BY Id
];

FreeeInvoiceStatusSyncService.syncInvoices(invoices);
