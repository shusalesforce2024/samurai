@isTest
private class ContractRenewalInvoiceBatchTest {
    @isTest
    static void createsMonthlyRenewalInvoiceSetOnEleventh() {
        Account accountRecord = new Account(
            Name = 'Renewal Account',
            Freee_Partner_Id__c = 12345
        );
        insert accountRecord;

        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = 'Monthly Contract',
            ContractUpdate__c = '月',
            StartDate__c = Date.newInstance(2026, 5, 1),
            Status__c = 'Draft'
        );
        insert contractRecord;

        insert new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 5, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            ParentContract__c = contractRecord.Id,
            PaymentStatus__c = '決済待ち',
            Payment_Date__c = Date.newInstance(2026, 6, 30),
            Subject__c = 'Initial Invoice'
        );
        update new Contract__c(Id = contractRecord.Id, Status__c = 'Activated');

        Test.startTest();
        Database.executeBatch(
            new ContractRenewalInvoiceBatch(Date.newInstance(2026, 6, 11)),
            100
        );
        Test.stopTest();

        ContractPeriod__c createdPeriod = [
            SELECT Contract__c,
                   PeriodStartDate__c,
                   PeriodEndDate__c,
                   RelatedInvoice__c
            FROM ContractPeriod__c
            WHERE Contract__c = :contractRecord.Id
            LIMIT 1
        ];
        System.assertEquals(Date.newInstance(2026, 7, 1), createdPeriod.PeriodStartDate__c);
        System.assertEquals(Date.newInstance(2026, 7, 31), createdPeriod.PeriodEndDate__c);
        System.assertNotEquals(null, createdPeriod.RelatedInvoice__c);

        Invoice__c createdInvoice = [
            SELECT Billing_Date__c,
                   Payment_Date__c,
                   ParentContract__c,
                   PaymentStatus__c
            FROM Invoice__c
            WHERE Id = :createdPeriod.RelatedInvoice__c
            LIMIT 1
        ];
        System.assertEquals(contractRecord.Id, createdInvoice.ParentContract__c);
        System.assertEquals(Date.newInstance(2026, 6, 19), createdInvoice.Billing_Date__c);
        System.assertEquals(Date.newInstance(2026, 7, 31), createdInvoice.Payment_Date__c);
        System.assertEquals('決済待ち', createdInvoice.PaymentStatus__c);

        System.assertEquals(1, [
            SELECT COUNT()
            FROM InvoiceLine__c
            WHERE Invoice__c = :createdInvoice.Id
        ]);
    }

    @isTest
    static void skipsWhenNotEleventh() {
        Account accountRecord = new Account(Name = 'Skip Account');
        insert accountRecord;

        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = 'Skip Contract',
            ContractUpdate__c = '月',
            StartDate__c = Date.newInstance(2026, 5, 1),
            Status__c = 'Draft'
        );
        insert contractRecord;

        insert new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 5, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            ParentContract__c = contractRecord.Id,
            PaymentStatus__c = '決済待ち',
            Payment_Date__c = Date.newInstance(2026, 6, 30),
            Subject__c = 'Initial Invoice'
        );
        update new Contract__c(Id = contractRecord.Id, Status__c = 'Activated');

        Test.startTest();
        Database.executeBatch(
            new ContractRenewalInvoiceBatch(Date.newInstance(2026, 6, 10)),
            100
        );
        Test.stopTest();

        Date skippedTargetDate = Date.newInstance(2026, 7, 1);
        System.assertEquals(0, [
            SELECT COUNT()
            FROM Invoice__c
            WHERE ParentContract__c = :contractRecord.Id
              AND TargetPeriodStartDate__c = :skippedTargetDate
        ]);
    }
}
