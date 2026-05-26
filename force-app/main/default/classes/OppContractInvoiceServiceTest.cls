@isTest
private class OppContractInvoiceServiceTest {
    @isTest
    static void createsContractInvoiceAndInvoiceLinesFromController() {
        Account accountRecord = new Account(Name = 'Test Account');
        insert accountRecord;

        Opportunity__c opportunityRecord = new Opportunity__c(
            Name = 'Test Opportunity',
            Account__c = accountRecord.Id,
            StageName__c = 'Closed Won',
            ContractUpdate__c = '月',
            StartDate__c = Date.newInstance(2026, 5, 15),
            ExpectedDuration__c = 12,
            MRR__c = 1000,
            ACV__c = 12000,
            Description__c = 'Opportunity description'
        );
        insert opportunityRecord;

        Quotation__c quotationRecord = new Quotation__c(
            Account__c = accountRecord.Id,
            Freee_Account_Item_Picklist__c = 'sales',
            Freee_Partner_Id__c = 1001,
            Issue_Date__c = Date.newInstance(2026, 5, 10),
            Memo__c = 'Quotation memo',
            Oppotunity__c = opportunityRecord.Id,
            Quotation_Status__c = 'Accepted',
            Subject__c = 'Accepted quotation'
        );
        insert quotationRecord;

        insert new List<QuotationLine__c>{
            new QuotationLine__c(
                Description__c = 'Line 1',
                Freee_Account_Item_Id__c = '1',
                Quantity__c = 2,
                Quotation__c = quotationRecord.Id,
                Tax_Rate__c = '10',
                Unit_Price__c = 100,
                Withholding__c = false
            ),
            new QuotationLine__c(
                Description__c = 'Line 2',
                Freee_Account_Item_Id__c = '2',
                Quantity__c = 3,
                Quotation__c = quotationRecord.Id,
                Tax_Rate__c = '10',
                Unit_Price__c = 100,
                Withholding__c = true
            )
        };

        Test.startTest();
        String message =
            OppContractInvoiceController.createContractAndInvoice(opportunityRecord.Id);
        Test.stopTest();

        System.assertEquals(
            '契約・請求・請求明細を作成しました。 契約: 1件 / 請求: 1件 / 請求明細: 2件',
            message
        );

        Contract__c createdContract = [
            SELECT Account__c,
                   ACV__c,
                   ARR__c,
                   ContractName__c,
                   Description__c,
                   ExpectedDuration__c,
                   MRR__c,
                   Oppotunity__c,
                   Pricebook2__c,
                   StartDate__c,
                   Status__c
            FROM Contract__c
            WHERE Oppotunity__c = :opportunityRecord.Id
            LIMIT 1
        ];
        System.assertEquals(accountRecord.Id, createdContract.Account__c);
        System.assertEquals('Test Opportunity_2026-05-15', createdContract.ContractName__c);
        System.assertEquals('Draft', createdContract.Status__c);
        System.assertEquals(6000, createdContract.ARR__c);

        Invoice__c createdInvoice = [
            SELECT Account__c,
                   Freee_Account_Item_Picklist__c,
                   Freee_Partner_Id__c,
                   Memo__c,
                   ParentContract__c,
                   ParentOpportunity__c,
                   Subject__c,
                   TotalAmount__c
            FROM Invoice__c
            WHERE ParentOpportunity__c = :opportunityRecord.Id
            LIMIT 1
        ];
        System.assertEquals(accountRecord.Id, createdInvoice.Account__c);
        System.assertEquals('Sales', createdInvoice.Freee_Account_Item_Picklist__c);
        System.assertEquals(1001, createdInvoice.Freee_Partner_Id__c);
        System.assertEquals('Quotation memo', createdInvoice.Memo__c);
        System.assertEquals(createdContract.Id, createdInvoice.ParentContract__c);
        System.assertEquals(opportunityRecord.Id, createdInvoice.ParentOpportunity__c);
        System.assertEquals('Accepted quotation', createdInvoice.Subject__c);
        System.assertEquals(500, createdInvoice.TotalAmount__c);

        List<InvoiceLine__c> createdLines = [
            SELECT Description__c,
                   Freee_Account_Item_Id__c,
                   Invoice__c,
                   Line_Amount__c,
                   Quantity__c,
                   Tax_Rate__c,
                   Unit_Price__c,
                   Withholding__c
            FROM InvoiceLine__c
            WHERE Invoice__c = :createdInvoice.Id
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(2, createdLines.size());
        System.assertEquals('Line 1', createdLines[0].Description__c);
        System.assertEquals(200, createdLines[0].Line_Amount__c);
        System.assertEquals(2, createdLines[0].Quantity__c);
        System.assertEquals(10, createdLines[0].Tax_Rate__c);
        System.assertEquals(100, createdLines[0].Unit_Price__c);
        System.assertEquals(false, createdLines[0].Withholding__c);
        System.assertEquals('Line 2', createdLines[1].Description__c);
        System.assertEquals(300, createdLines[1].Line_Amount__c);
        System.assertEquals(3, createdLines[1].Quantity__c);
        System.assertEquals(10, createdLines[1].Tax_Rate__c);
        System.assertEquals(100, createdLines[1].Unit_Price__c);
        System.assertEquals(true, createdLines[1].Withholding__c);
    }

    @isTest
    static void throwsErrorWhenOpportunityIsNotClosedWon() {
        Account accountRecord = new Account(Name = 'Error Account');
        insert accountRecord;

        Opportunity__c opportunityRecord = new Opportunity__c(
            Name = 'Error Opportunity',
            Account__c = accountRecord.Id,
            StageName__c = 'Prospecting',
            ContractUpdate__c = '月',
            StartDate__c = Date.newInstance(2026, 5, 16)
        );
        insert opportunityRecord;

        try {
            OppContractInvoiceController.createContractAndInvoice(opportunityRecord.Id);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
    }

    @isTest
    static void throwsErrorWhenRecordsAlreadyCreated() {
        Account accountRecord = new Account(Name = 'Duplicate Test Account');
        insert accountRecord;

        Opportunity__c opportunityRecord = new Opportunity__c(
            Name = 'Duplicate Opportunity',
            Account__c = accountRecord.Id,
            StageName__c = 'Closed Won',
            ContractUpdate__c = '月',
            StartDate__c = Date.newInstance(2026, 5, 16)
        );
        insert opportunityRecord;

        Quotation__c quotationRecord = new Quotation__c(
            Account__c = accountRecord.Id,
            Freee_Account_Item_Picklist__c = 'sales',
            Issue_Date__c = Date.newInstance(2026, 5, 10),
            Oppotunity__c = opportunityRecord.Id,
            Quotation_Status__c = 'Accepted',
            Subject__c = 'Accepted quotation'
        );
        insert quotationRecord;

        insert new QuotationLine__c(
            Description__c = 'Line 1',
            Quantity__c = 1,
            Quotation__c = quotationRecord.Id,
            Tax_Rate__c = '10',
            Unit_Price__c = 100,
            Withholding__c = false
        );

        OppContractInvoiceController.createContractAndInvoice(opportunityRecord.Id);

        try {
            OppContractInvoiceController.createContractAndInvoice(opportunityRecord.Id);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
    }

    @isTest
    static void throwsErrorWhenMultipleAcceptedQuotationsExist() {
        Account accountRecord = new Account(Name = 'Multiple Accepted Account');
        insert accountRecord;

        Opportunity__c opportunityRecord = new Opportunity__c(
            Name = 'Multiple Accepted Opportunity',
            Account__c = accountRecord.Id,
            StageName__c = 'Closed Won',
            ContractUpdate__c = '月',
            StartDate__c = Date.newInstance(2026, 5, 16)
        );
        insert opportunityRecord;

        insert new List<Quotation__c>{
            new Quotation__c(
                Account__c = accountRecord.Id,
                Freee_Account_Item_Picklist__c = 'sales',
                Issue_Date__c = Date.newInstance(2026, 5, 10),
                Oppotunity__c = opportunityRecord.Id,
                Quotation_Status__c = 'Accepted',
                Subject__c = 'Accepted quotation 1'
            ),
            new Quotation__c(
                Account__c = accountRecord.Id,
                Freee_Account_Item_Picklist__c = 'sales',
                Issue_Date__c = Date.newInstance(2026, 5, 11),
                Oppotunity__c = opportunityRecord.Id,
                Quotation_Status__c = 'Accepted',
                Subject__c = 'Accepted quotation 2'
            )
        };

        try {
            OppContractInvoiceController.createContractAndInvoice(opportunityRecord.Id);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
    }

    @isTest
    static void roundsTaxAmountUpWhenFractionOccurs() {
        Account accountRecord = new Account(Name = 'Tax Rounding Account');
        insert accountRecord;

        Opportunity__c opportunityRecord = new Opportunity__c(
            Name = 'Tax Rounding Opportunity',
            Account__c = accountRecord.Id,
            StageName__c = 'Closed Won',
            ContractUpdate__c = '月',
            StartDate__c = Date.newInstance(2026, 5, 16)
        );
        insert opportunityRecord;

        Quotation__c quotationRecord = new Quotation__c(
            Account__c = accountRecord.Id,
            Freee_Account_Item_Picklist__c = 'sales',
            Issue_Date__c = Date.newInstance(2026, 5, 10),
            Oppotunity__c = opportunityRecord.Id,
            Quotation_Status__c = 'Accepted',
            Subject__c = 'Tax rounding quotation'
        );
        insert quotationRecord;

        insert new QuotationLine__c(
            Description__c = 'Fraction tax line',
            Quantity__c = 1,
            Quotation__c = quotationRecord.Id,
            Tax_Rate__c = '10',
            Unit_Price__c = 101,
            Withholding__c = false
        );

        Test.startTest();
        OppContractInvoiceController.createContractAndInvoice(opportunityRecord.Id);
        Test.stopTest();

        InvoiceLine__c createdLine = [
            SELECT AmountWithTax__c,
                   Line_Amount__c,
                   TaxAmount__c
            FROM InvoiceLine__c
            WHERE Invoice__r.ParentOpportunity__c = :opportunityRecord.Id
            LIMIT 1
        ];
        System.assertEquals(101, createdLine.Line_Amount__c);
        System.assertEquals(11, createdLine.TaxAmount__c);
        System.assertEquals(112, createdLine.AmountWithTax__c);
    }

    @isTest
    static void createsAnnualContractWithInitialFeeAndMonthlyRevenueLines() {
        Account accountRecord = new Account(Name = 'Annual Account');
        insert accountRecord;

        ProductMaster__c annualProduct = new ProductMaster__c(
            Name = 'Rendery Annual',
            ProductType__c = '継続費用',
            BillingTiming__c = '年一括',
            AnnualMonthlyPrice__c = 1000,
            MRR_Target__c = true,
            ARR_Target__c = true
        );
        ProductMaster__c optionProduct = new ProductMaster__c(
            Name = 'Security Option',
            ProductType__c = 'オプション',
            BillingTiming__c = '年一括',
            AnnualMonthlyPrice__c = 500,
            MRR_Target__c = true,
            ARR_Target__c = true
        );
        ProductMaster__c initialFeeProduct = new ProductMaster__c(
            Name = 'Initial Fee',
            ProductType__c = '初期費用',
            BillingTiming__c = '初回のみ',
            MRR_Target__c = false,
            ARR_Target__c = false
        );
        insert new List<ProductMaster__c>{ annualProduct, optionProduct, initialFeeProduct };

        Opportunity__c opportunityRecord = new Opportunity__c(
            Name = 'Annual Opportunity',
            Account__c = accountRecord.Id,
            StageName__c = 'Closed Won',
            ContractUpdate__c = '年',
            StartDate__c = Date.newInstance(2026, 5, 1),
            ExpectedDuration__c = 12,
            MRR__c = 1500,
            ACV__c = 18000
        );
        insert opportunityRecord;

        Quotation__c quotationRecord = new Quotation__c(
            Account__c = accountRecord.Id,
            Freee_Account_Item_Picklist__c = 'sales',
            Issue_Date__c = Date.newInstance(2026, 4, 20),
            Oppotunity__c = opportunityRecord.Id,
            Quotation_Status__c = 'Accepted',
            Subject__c = 'Annual accepted quotation'
        );
        insert quotationRecord;

        insert new List<QuotationLine__c>{
            new QuotationLine__c(
                Description__c = 'Rendery annual',
                ProductMaster__c = annualProduct.Id,
                Quantity__c = 1,
                Quotation__c = quotationRecord.Id,
                Tax_Rate__c = '10',
                Unit_Price__c = 12000,
                Withholding__c = false
            ),
            new QuotationLine__c(
                Description__c = 'Security option',
                ProductMaster__c = optionProduct.Id,
                Quantity__c = 1,
                Quotation__c = quotationRecord.Id,
                Tax_Rate__c = '10',
                Unit_Price__c = 6000,
                Withholding__c = false
            ),
            new QuotationLine__c(
                Description__c = 'Initial setup',
                ProductMaster__c = initialFeeProduct.Id,
                Quantity__c = 1,
                Quotation__c = quotationRecord.Id,
                Tax_Rate__c = '10',
                Unit_Price__c = 3000,
                Withholding__c = false
            )
        };

        Test.startTest();
        OppContractInvoiceController.createContractAndInvoice(opportunityRecord.Id);
        Test.stopTest();

        Invoice__c createdInvoice = [
            SELECT Id,
                   TargetPeriodStartDate__c,
                   TargetPeriodEndDate__c
            FROM Invoice__c
            WHERE ParentOpportunity__c = :opportunityRecord.Id
            LIMIT 1
        ];
        System.assertEquals(Date.newInstance(2026, 5, 1), createdInvoice.TargetPeriodStartDate__c);
        System.assertEquals(Date.newInstance(2027, 4, 30), createdInvoice.TargetPeriodEndDate__c);

        List<InvoiceLine__c> invoiceLines = [
            SELECT Description__c,
                   Line_Amount__c,
                   ProductMaster__c,
                   Quantity__c
            FROM InvoiceLine__c
            WHERE Invoice__c = :createdInvoice.Id
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(2, invoiceLines.size());
        System.assertEquals('Initial setup', invoiceLines[0].Description__c);
        System.assertEquals(3000, invoiceLines[0].Line_Amount__c);
        System.assertEquals(18000, invoiceLines[1].Line_Amount__c);
        System.assertEquals(1, invoiceLines[1].Quantity__c);

        List<ContractLineItem__c> contractLines = [
            SELECT InitialFee__c,
                   ProductMaster__c,
                   RevenueAmount__c
            FROM ContractLineItem__c
            WHERE RelatedInvoice__c = :createdInvoice.Id
        ];
        System.assertEquals(25, contractLines.size());

        Integer initialFeeLineCount = 0;
        Decimal recurringRevenueTotal = 0;
        for (ContractLineItem__c line : contractLines) {
            if (line.InitialFee__c) {
                initialFeeLineCount++;
                System.assertEquals(initialFeeProduct.Id, line.ProductMaster__c);
            } else {
                recurringRevenueTotal += line.RevenueAmount__c;
            }
        }
        System.assertEquals(1, initialFeeLineCount);
        System.assertEquals(18000, recurringRevenueTotal);
    }
}
