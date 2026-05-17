@isTest
private class TriggerSyncServicesTest {
    @isTest
    static void opportunityStageProbabilitySyncsOnInsertAndUpdate() {
        Opportunity__c opportunityRecord = new Opportunity__c(
            Name = 'Probability Opportunity',
            StageName__c = 'Prospecting',
            ContractUpdate__c = '月'
        );

        insert opportunityRecord;
        Opportunity__c insertedRecord = [
            SELECT StandardProbability__c
            FROM Opportunity__c
            WHERE Id = :opportunityRecord.Id
        ];
        System.assertEquals(10, insertedRecord.StandardProbability__c);

        opportunityRecord.StageName__c = 'Negotiation';
        update opportunityRecord;

        Opportunity__c updatedRecord = [
            SELECT StandardProbability__c
            FROM Opportunity__c
            WHERE Id = :opportunityRecord.Id
        ];
        System.assertEquals(80, updatedRecord.StandardProbability__c);
    }

    @isTest
    static void productUnitPriceSyncsQuotationAndInvoiceLines() {
        Product2 firstProduct = new Product2(
            Name = 'First Product',
            IsActive = true,
            UnitPrice__c = 2500
        );
        Product2 secondProduct = new Product2(
            Name = 'Second Product',
            IsActive = true,
            UnitPrice__c = 3500
        );
        insert new List<Product2>{ firstProduct, secondProduct };

        Account accountRecord = new Account(Name = 'Unit Price Account');
        insert accountRecord;

        Quotation__c quotationRecord = new Quotation__c(
            Account__c = accountRecord.Id,
            Issue_Date__c = Date.newInstance(2026, 5, 3),
            Subject__c = 'Unit price quotation'
        );
        insert quotationRecord;

        QuotationLine__c quotationLine = new QuotationLine__c(
            Quotation__c = quotationRecord.Id,
            Product2__c = firstProduct.Id,
            Description__c = 'Quotation product',
            Quantity__c = 1,
            Tax_Rate__c = '10'
        );
        insert quotationLine;

        quotationLine = [
            SELECT Product2__c, Unit_Price__c
            FROM QuotationLine__c
            WHERE Id = :quotationLine.Id
        ];
        System.assertEquals(2500, quotationLine.Unit_Price__c);

        quotationLine.Product2__c = secondProduct.Id;
        update quotationLine;
        quotationLine = [
            SELECT Unit_Price__c
            FROM QuotationLine__c
            WHERE Id = :quotationLine.Id
        ];
        System.assertEquals(3500, quotationLine.Unit_Price__c);

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 5, 4),
            Freee_Account_Item_Picklist__c = 'Sales',
            Subject__c = 'Unit price invoice'
        );
        insert invoiceRecord;

        InvoiceLine__c invoiceLine = new InvoiceLine__c(
            Invoice__c = invoiceRecord.Id,
            Product2__c = firstProduct.Id,
            Description__c = 'Invoice product',
            Quantity__c = 1,
            Tax_Rate__c = 10
        );
        insert invoiceLine;

        invoiceLine = [
            SELECT Unit_Price__c
            FROM InvoiceLine__c
            WHERE Id = :invoiceLine.Id
        ];
        System.assertEquals(2500, invoiceLine.Unit_Price__c);
    }

    @isTest
    static void opportunityMrrSyncsFromQuotationHeadersAndLines() {
        Account accountRecord = new Account(Name = 'MRR Account');
        insert accountRecord;

        Opportunity__c opportunityRecord = new Opportunity__c(
            Name = 'MRR Opportunity',
            Account__c = accountRecord.Id,
            StageName__c = 'Prospecting',
            ContractUpdate__c = '月'
        );
        insert opportunityRecord;

        Quotation__c quotationRecord = new Quotation__c(
            Account__c = accountRecord.Id,
            Issue_Date__c = Date.newInstance(2026, 5, 5),
            Oppotunity__c = opportunityRecord.Id,
            Subject__c = 'MRR quotation'
        );
        insert quotationRecord;

        Opportunity__c afterQuotationInsert = [
            SELECT MRR__c
            FROM Opportunity__c
            WHERE Id = :opportunityRecord.Id
        ];
        System.assert(
            afterQuotationInsert.MRR__c == null || afterQuotationInsert.MRR__c == 0
        );

        insert new List<QuotationLine__c>{
            new QuotationLine__c(
                Quotation__c = quotationRecord.Id,
                Description__c = 'MRR line 1',
                Quantity__c = 2,
                Unit_Price__c = 100,
                Tax_Rate__c = '10'
            ),
            new QuotationLine__c(
                Quotation__c = quotationRecord.Id,
                Description__c = 'MRR line 2',
                Quantity__c = 3,
                Unit_Price__c = 200,
                Tax_Rate__c = '10'
            )
        };

        Opportunity__c afterLineInsert = [
            SELECT MRR__c
            FROM Opportunity__c
            WHERE Id = :opportunityRecord.Id
        ];
        System.assertEquals(800, afterLineInsert.MRR__c);
    }

    @isTest
    static void securityUtilityChecksDoNotThrowForDefaultTestUser() {
        FreeeSecurityUtil.checkInvoiceRead();
        FreeeSecurityUtil.checkInvoiceUpdate();
        FreeeSecurityUtil.checkInvoiceLineRead();
        FreeeSecurityUtil.checkSyncLogCreate();
        FreeeSecurityUtil.checkConfigRead();
    }
}