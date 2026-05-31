@isTest
private class InvoiceCancelRecreateServiceTest {
    @isTest
    static void cancelsAndRecreatesSalesforceInvoice() {
        Account accountRecord = new Account(Name = 'Cancel Account');
        insert accountRecord;

        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = 'Cancel Contract',
            ContractUpdate__c = '月',
            StartDate__c = Date.newInstance(2026, 6, 1),
            Status__c = 'Draft'
        );
        insert contractRecord;

        ContractPeriod__c periodRecord = new ContractPeriod__c(
            Contract__c = contractRecord.Id,
            PeriodStartDate__c = Date.newInstance(2026, 6, 1),
            PeriodEndDate__c = Date.newInstance(2026, 6, 30)
        );
        insert periodRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 6, 20),
            ContractPeriod__c = periodRecord.Id,
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Status__c = '送付待ち',
            Freee_Sync_Status__c = 'Processing',
            PaymentStatus__c = '決済待ち',
            Payment_Date__c = Date.newInstance(2026, 7, 31),
            Subject__c = 'Cancel Invoice'
        );
        insert invoiceRecord;

        update new ContractPeriod__c(
            Id = periodRecord.Id,
            RelatedInvoice__c = invoiceRecord.Id
        );

        insert new InvoiceLine__c(
            Description__c = 'Usage Fee',
            Invoice__c = invoiceRecord.Id,
            Quantity__c = 1,
            Tax_Rate__c = 10,
            Unit_Price__c = 1000
        );

        ContractLineItem__c contractLine = new ContractLineItem__c(
            Account__c = accountRecord.Id,
            ContractPeriod__c = periodRecord.Id,
            ContractYearMonth__c = '2026/06',
            MasterContract__c = contractRecord.Id,
            Month__c = '2026/06',
            PeriodStartDate__c = Date.newInstance(2026, 6, 1),
            PeriodEndDate__c = Date.newInstance(2026, 6, 30),
            RelatedInvoice__c = invoiceRecord.Id,
            RevenueAmount__c = 1000,
            Total__c = 1000
        );
        insert contractLine;

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

        ContractPeriod__c updatedPeriod = [
            SELECT RelatedInvoice__c
            FROM ContractPeriod__c
            WHERE Id = :periodRecord.Id
            LIMIT 1
        ];
        System.assertEquals(recreatedId, updatedPeriod.RelatedInvoice__c);

        ContractLineItem__c updatedLine = [
            SELECT RelatedInvoice__c
            FROM ContractLineItem__c
            WHERE Id = :contractLine.Id
            LIMIT 1
        ];
        System.assertEquals(recreatedId, updatedLine.RelatedInvoice__c);

        System.assertEquals(2, [
            SELECT COUNT()
            FROM Invoice__c
            WHERE ContractPeriod__c = :periodRecord.Id
        ]);

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
            System.assertEquals('FIELD_CUSTOM_VALIDATION_EXCEPTION', e.getDmlStatusCode(0));
        }
    }

    @isTest
    static void blocksInvoiceLineEditAfterFreeeSync() {
        Account accountRecord = new Account(Name = 'Line Validation Account');
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 6, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Status__c = '送付待ち',
            Freee_Sync_Status__c = 'Processing',
            PaymentStatus__c = '決済待ち',
            Payment_Date__c = Date.newInstance(2026, 7, 31),
            Sent_To_Freee__c = false,
            Subject__c = 'Line Validation Invoice'
        );
        insert invoiceRecord;

        InvoiceLine__c lineRecord = new InvoiceLine__c(
            Description__c = 'Editable before sync',
            Invoice__c = invoiceRecord.Id,
            Quantity__c = 1,
            Tax_Rate__c = 10,
            Unit_Price__c = 1000
        );
        insert lineRecord;

        update new Invoice__c(
            Id = invoiceRecord.Id,
            Freee_Sync_Status__c = 'Success',
            Sent_To_Freee__c = true
        );

        try {
            update new InvoiceLine__c(
                Id = lineRecord.Id,
                Unit_Price__c = 2000
            );
            System.assert(false, 'Expected validation error');
        } catch (DmlException e) {
            System.assertEquals('FIELD_CUSTOM_VALIDATION_EXCEPTION', e.getDmlStatusCode(0));
        }
    }
}
