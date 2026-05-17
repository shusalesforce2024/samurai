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
}