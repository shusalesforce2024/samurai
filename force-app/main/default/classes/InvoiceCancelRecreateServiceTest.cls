@isTest
private class InvoiceCancelRecreateServiceTest {
    @isTest
    static void cancelsAndRecreatesSalesforceInvoice() {
        Account accountRecord = new Account(Name = 'Cancel Account');
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 6, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Status__c = '送付待ち',
            Freee_Sync_Status__c = 'Processing',
            PaymentStatus__c = '決済待ち',
            Payment_Date__c = Date.newInstance(2026, 7, 31),
            Subject__c = 'Cancel Invoice'
        );
        insert invoiceRecord;

        insert new InvoiceLine__c(
            Description__c = 'Usage Fee',
            Invoice__c = invoiceRecord.Id,
            Quantity__c = 1,
            Tax_Rate__c = 10,
            Unit_Price__c = 1000
        );

        Test.startTest();
        InvoiceCancelService.cancelInvoice(invoiceRecord.Id);
        Id recreatedId = InvoiceRecreateService.recreateInvoice(invoiceRecord.Id);
        Test.stopTest();

        Invoice__c cancelled = [
            SELECT CancelStatus__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
            LIMIT 1
        ];
        System.assertEquals('取消済', cancelled.CancelStatus__c);

        Invoice__c recreated = [
            SELECT OriginalInvoice__c,
                   Sent_To_Freee__c,
                   PaymentStatus__c
            FROM Invoice__c
            WHERE Id = :recreatedId
            LIMIT 1
        ];
        System.assertEquals(invoiceRecord.Id, recreated.OriginalInvoice__c);
        System.assertEquals(false, recreated.Sent_To_Freee__c);
        System.assertEquals('決済待ち', recreated.PaymentStatus__c);

        System.assertEquals(1, [
            SELECT COUNT()
            FROM InvoiceLine__c
            WHERE Invoice__c = :recreatedId
        ]);
    }

    @isTest
    static void blocksBusinessEditAfterFreeeSync() {
        Account firstAccount = new Account(Name = 'First Account');
        Account secondAccount = new Account(Name = 'Second Account');
        insert new List<Account>{ firstAccount, secondAccount };

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = firstAccount.Id,
            Billing_Date__c = Date.newInstance(2026, 6, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Status__c = '送付待ち',
            Freee_Sync_Status__c = 'Success',
            PaymentStatus__c = '決済待ち',
            Payment_Date__c = Date.newInstance(2026, 7, 31),
            Sent_To_Freee__c = true,
            Subject__c = 'Synced Invoice'
        );
        insert invoiceRecord;

        try {
            update new Invoice__c(
                Id = invoiceRecord.Id,
                Account__c = secondAccount.Id
            );
            System.assert(false, 'Expected validation error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('freee連携済み'));
        }
    }
}
