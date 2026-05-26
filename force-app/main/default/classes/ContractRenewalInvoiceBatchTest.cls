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
            ORDER BY PeriodStartDate__c DESC
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

    @isTest
    static void createsYearlyRenewalInvoiceInPreviousMonth() {
        Account accountRecord = new Account(
            Name = 'Yearly Renewal Account',
            Freee_Partner_Id__c = 98765
        );
        insert accountRecord;

        ProductMaster__c productRecord = new ProductMaster__c(
            Name = 'Yearly Product',
            ProductType__c = '継続費用',
            BillingTiming__c = '年一括',
            AnnualMonthlyPrice__c = 1000,
            MRR_Target__c = true,
            ARR_Target__c = true
        );
        insert productRecord;

        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = 'Yearly Contract',
            ContractUpdate__c = '年',
            StartDate__c = Date.newInstance(2026, 6, 1),
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
            Subject__c = 'Initial Yearly Invoice'
        );
        update new Contract__c(Id = contractRecord.Id, Status__c = 'Activated');

        insert new ContractLineItem__c(
            Account__c = accountRecord.Id,
            ARR_Target__c = true,
            InitialFee__c = false,
            MasterContract__c = contractRecord.Id,
            MRR_Target__c = true,
            PeopleNumber__c = 1,
            PeriodStartDate__c = Date.newInstance(2026, 6, 1),
            PeriodEndDate__c = Date.newInstance(2026, 6, 30),
            ProductMaster__c = productRecord.Id,
            RevenueAmount__c = 1000,
            Total__c = 1000
        );

        Test.startTest();
        Database.executeBatch(
            new ContractRenewalInvoiceBatch(Date.newInstance(2027, 5, 11)),
            100
        );
        Test.stopTest();

        ContractPeriod__c createdPeriod = [
            SELECT Id,
                   PeriodStartDate__c,
                   PeriodEndDate__c,
                   RelatedInvoice__c
            FROM ContractPeriod__c
            WHERE Contract__c = :contractRecord.Id
            LIMIT 1
        ];
        System.assertEquals(Date.newInstance(2027, 6, 1), createdPeriod.PeriodStartDate__c);
        System.assertEquals(Date.newInstance(2028, 5, 31), createdPeriod.PeriodEndDate__c);
        System.assertNotEquals(null, createdPeriod.RelatedInvoice__c);

        System.assertEquals(1, [
            SELECT COUNT()
            FROM InvoiceLine__c
            WHERE Invoice__c = :createdPeriod.RelatedInvoice__c
              AND Quantity__c = 1
              AND Unit_Price__c = 12000
        ]);
        Set<String> createdMonths = new Set<String>();
        for (ContractLineItem__c lineRecord : [
            SELECT Month__c
            FROM ContractLineItem__c
            WHERE ContractPeriod__c = :createdPeriod.Id
        ]) {
            createdMonths.add(lineRecord.Month__c);
        }
        System.assertEquals(12, createdMonths.size());
    }

    @isTest
    static void skipsRenewalStoppedContract() {
        Account accountRecord = new Account(Name = 'Renewal Stop Account');
        insert accountRecord;

        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = 'Renewal Stop Contract',
            ContractUpdate__c = '月',
            RenewalStop__c = true,
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

        insert new ContractLineItem__c(
            Account__c = accountRecord.Id,
            InitialFee__c = false,
            MasterContract__c = contractRecord.Id,
            PeopleNumber__c = 1,
            PeriodStartDate__c = Date.newInstance(2026, 5, 1),
            PeriodEndDate__c = Date.newInstance(2026, 5, 31),
            RevenueAmount__c = 1000,
            Total__c = 1000
        );

        Test.startTest();
        Database.executeBatch(
            new ContractRenewalInvoiceBatch(Date.newInstance(2026, 6, 11)),
            100
        );
        Test.stopTest();

        System.assertEquals(0, [
            SELECT COUNT()
            FROM ContractPeriod__c
            WHERE Contract__c = :contractRecord.Id
        ]);
    }
}
