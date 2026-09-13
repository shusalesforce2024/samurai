@IsTest
private class ContractClassBackfillServiceTest {
    @IsTest
    static void invoiceLineInsertBackfillsFromLatestInvoiceLine() {
        Account accountRecord = new Account(Name = 'Backfill Account');
        insert accountRecord;

        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = 'Backfill Contract',
            StartDate__c = Date.newInstance(2026, 7, 1),
            ContractUpdate__c = Contract__c.ContractUpdate__c.getDescribe().getPicklistValues()[0].getValue(),
            Status__c = 'Activated'
        );
        insert contractRecord;

        ProductMaster__c productRecord = new ProductMaster__c(
            Name = 'Rendery Pro'
        );
        insert productRecord;

        Invoice__c olderInvoice = createInvoice(accountRecord.Id, contractRecord.Id, Date.newInstance(2026, 6, 20));
        Invoice__c latestInvoice = createInvoice(accountRecord.Id, contractRecord.Id, Date.newInstance(2026, 7, 20));

        Test.startTest();
        insert new List<InvoiceLine__c>{
            new InvoiceLine__c(
                Invoice__c = olderInvoice.Id,
                Description__c = 'Rendery Basic',
                ProductMaster__c = productRecord.Id,
                Quantity__c = 2,
                Unit_Price__c = 1000,
                AmountWithTax__c = 2200,
                LineType__c = '継続費用'
            ),
            new InvoiceLine__c(
                Invoice__c = latestInvoice.Id,
                Description__c = 'Rendery Pro 5アカウント',
                ProductMaster__c = productRecord.Id,
                Quantity__c = 5,
                Unit_Price__c = 1000,
                AmountWithTax__c = 5500,
                LineType__c = '継続費用'
            )
        };

        Test.stopTest();

        Contract__c updated = [
            SELECT ProductCategory__c,
                   PlanCategory__c,
                   AccountCount__c
            FROM Contract__c
            WHERE Id = :contractRecord.Id
        ];
        System.assertEquals('Rendery', updated.ProductCategory__c);
        System.assertEquals('Pro', updated.PlanCategory__c);
        System.assertEquals(5, updated.AccountCount__c);
    }

    @IsTest
    static void dryRunDoesNotUpdate() {
        Account accountRecord = new Account(Name = 'DryRun Account');
        insert accountRecord;

        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = 'DryRun Contract',
            StartDate__c = Date.newInstance(2026, 7, 1),
            ContractUpdate__c = Contract__c.ContractUpdate__c.getDescribe().getPicklistValues()[0].getValue(),
            Status__c = 'Draft'
        );
        insert contractRecord;

        Invoice__c invoiceRecord = createInvoice(accountRecord.Id, contractRecord.Id, Date.newInstance(2026, 7, 20));
        insert new InvoiceLine__c(
            Invoice__c = invoiceRecord.Id,
            Description__c = 'knock knock AI Enterprise',
            Quantity__c = 10,
            Unit_Price__c = 1000,
            AmountWithTax__c = 11000,
            LineType__c = '継続費用'
        );
        contractRecord.Status__c = 'Activated';
        update contractRecord;

        Test.startTest();
        ContractClassBackfillService.Result result = ContractClassBackfillService.dryRun();
        Test.stopTest();

        System.assertEquals(1, result.targetContracts);
        System.assertEquals(1, result.updatableContracts);

        Contract__c notUpdated = [
            SELECT ProductCategory__c,
                   PlanCategory__c,
                   AccountCount__c
            FROM Contract__c
            WHERE Id = :contractRecord.Id
        ];
        System.assertEquals(null, notUpdated.ProductCategory__c);
        System.assertEquals(null, notUpdated.PlanCategory__c);
        System.assertEquals(null, notUpdated.AccountCount__c);
    }

    @IsTest
    static void annualMonthQuantityDoesNotBecomeAccountCount() {
        Account accountRecord = new Account(Name = 'Annual Quantity Account');
        insert accountRecord;

        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = 'Annual Quantity Contract',
            StartDate__c = Date.newInstance(2026, 7, 1),
            ContractUpdate__c =
                Contract__c.ContractUpdate__c.getDescribe().getPicklistValues()[0].getValue(),
            Status__c = 'Activated'
        );
        insert contractRecord;

        ProductMaster__c productRecord = new ProductMaster__c(
            Name = 'knock knock AI Enterprise annual',
            BillingTiming__c = '年一括'
        );
        insert productRecord;

        Invoice__c invoiceRecord = createInvoice(
            accountRecord.Id,
            contractRecord.Id,
            Date.newInstance(2026, 7, 20)
        );

        Test.startTest();
        insert new InvoiceLine__c(
            Invoice__c = invoiceRecord.Id,
            Description__c = 'knock knock AI Enterprise 年間利用料',
            ProductMaster__c = productRecord.Id,
            Quantity__c = 12,
            Unit__c = '月',
            Unit_Price__c = 261000,
            AmountWithTax__c = 3445200,
            LineType__c = '年間利用料'
        );
        Test.stopTest();

        Contract__c updated = [
            SELECT ProductCategory__c,
                   PlanCategory__c,
                   AccountCount__c
            FROM Contract__c
            WHERE Id = :contractRecord.Id
        ];
        System.assertEquals('knock knock AI', updated.ProductCategory__c);
        System.assertEquals('Enterprise', updated.PlanCategory__c);
        System.assertEquals(
            null,
            updated.AccountCount__c,
            '年払明細の12か月を12アカウントとして扱わない'
        );
    }

    private static Invoice__c createInvoice(Id accountId, Id contractId, Date billingDate) {
        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountId,
            ParentContract__c = contractId,
            Subject__c = 'Backfill Invoice',
            Billing_Date__c = billingDate,
            Payment_Date__c = billingDate.addDays(30),
            Payment_Type__c = Invoice__c.Payment_Type__c.getDescribe().getPicklistValues()[0].getValue(),
            Freee_Account_Item_Picklist__c =
                Invoice__c.Freee_Account_Item_Picklist__c.getDescribe().getPicklistValues()[0].getValue(),
            CancelStatus__c = Invoice__c.CancelStatus__c.getDescribe().getPicklistValues()[0].getValue()
        );
        insert invoiceRecord;
        return invoiceRecord;
    }
}
