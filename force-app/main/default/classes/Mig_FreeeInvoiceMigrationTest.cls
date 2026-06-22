@isTest
private class Mig_FreeeInvoiceMigrationTest {
    private class FreeeInvoiceListMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('GET', request.getMethod());
            if (request.getEndpoint().contains('/invoices/555')) {
                HttpResponse response = new HttpResponse();
                response.setStatusCode(200);
                response.setHeader('Content-Type', 'application/json');
                response.setBody(
                    '{"invoice":' +
                    '{"id":555,"invoice_number":"INV-555","partner_id":901,"partner_name":"Migration Account",' +
                    '"issue_date":"2026-03-20","payment_limit_date":"2026-04-30","subject":"March usage",' +
                    '"total_amount":1100,"total_vat":100,"paid_amount":0,"unpaid_amount":1100,' +
                    '"sending_status":"sent","payment_status":"unpaid","target_period_start_date":"2026-03-01","target_period_end_date":"2026-03-31",' +
                    '"invoice_lines":[{"id":1,"description":"Rendary","quantity":1,"unit_price":1000,"amount":1000,"tax_rate":10,"tax_amount":100}]}' +
                    '}'
                );
                return response;
            }

            System.assert(request.getEndpoint().contains('/invoices?'));
            System.assert(request.getEndpoint().contains('company_id=12345'));
            System.assert(request.getEndpoint().contains('start_billing_date='));
            System.assert(request.getEndpoint().contains('end_billing_date='));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody(
                '{"invoices":[' +
                '{"id":555,"invoice_number":"INV-555","partner_id":901,"partner_name":"Migration Account",' +
                '"issue_date":"2026-03-20","payment_limit_date":"2026-04-30","subject":"March usage",' +
                '"total_amount":1100,"total_vat":100,"paid_amount":0,"unpaid_amount":1100,' +
                '"sending_status":"sent","payment_status":"unpaid","target_period_start_date":"2026-03-01","target_period_end_date":"2026-03-31"}' +
                ']}'
            );
            return response;
        }
    }

    private class FreeeInvoiceOutOfPeriodListMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('GET', request.getMethod());
            System.assert(request.getEndpoint().contains('/invoices?'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody(
                '{"invoices":[' +
                '{"id":777001,"invoice_number":"INV-OLD","partner_id":901,"partner_name":"Migration Account",' +
                '"issue_date":"2023-07-10","payment_limit_date":"2023-08-31","subject":"Old usage",' +
                '"total_amount":1100,"total_vat":100,"paid_amount":0,"unpaid_amount":1100,' +
                '"sending_status":"sent","payment_status":"unpaid"}' +
                ']}'
            );
            return response;
        }
    }

    @testSetup
    static void setupData() {
        insert new Freee_Configs__c(
            Name = 'Default',
            Company_Id__c = '12345',
            Invoice_Base_Url__c = 'https://secure.freee.co.jp/invoices/',
            Payment_Type__c = 'transfer',
            Quotation_Template_Id__c = '98765',
            Tax_Entry_Method__c = 'exclusive',
            Tax_Fraction__c = 'round_down',
            Template_Id__c = '67890',
            Withholding__c = 'false',
            Withholding_Tax_Entry_Method__c = 'IN'
        );

        Account accountRecord = new Account(
            Name = 'Migration Account',
            Freee_Partner_Id__c = 901
        );
        insert accountRecord;

        ProductMaster__c productRecord = new ProductMaster__c(
            Name = 'Rendary',
            ProductType__c = '継続費用',
            BillingTiming__c = '毎月',
            AnnualMonthlyPrice__c = 1000,
            MRR_Target__c = true,
            ARR_Target__c = true
        );
        insert productRecord;

        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = 'Migration Contract',
            ContractUpdate__c = '月',
            StartDate__c = Date.newInstance(2026, 3, 1),
            EndDate__c = Date.newInstance(2026, 6, 30),
            Status__c = 'Draft'
        );
        insert contractRecord;

        ContractPeriod__c periodRecord = new ContractPeriod__c(
            Contract__c = contractRecord.Id,
            ContractUpdate__c = '月',
            PeriodStartDate__c = Date.newInstance(2026, 3, 1),
            PeriodEndDate__c = Date.newInstance(2026, 3, 31),
            FreeeSyncStatus__c = '未連携',
            InvoiceCreationStatus__c = '未作成',
            IsInitialPeriod__c = true
        );
        insert periodRecord;

        insert new ContractLineItem__c(
            Account__c = accountRecord.Id,
            ARR_Target__c = true,
            ContractPeriod__c = periodRecord.Id,
            InitialFee__c = false,
            MasterContract__c = contractRecord.Id,
            MRR_Target__c = true,
            PeopleNumber__c = 1,
            PeriodStartDate__c = Date.newInstance(2026, 3, 1),
            PeriodEndDate__c = Date.newInstance(2026, 3, 31),
            ProductMaster__c = productRecord.Id,
            RevenueAmount__c = 1000,
            Total__c = 1000
        );

        insert new Invoice__c(
            Account__c = accountRecord.Id,
            ParentContract__c = contractRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 3, 20),
            Payment_Date__c = Date.newInstance(2026, 4, 30),
            Subject__c = 'Migration Setup Invoice',
            InvoiceAmount__c = 1100,
            AmountWithTax__c = 1100,
            TaxAmount__c = 100,
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Sync_Status__c = 'Success',
            Sent_To_Freee__c = false
        );

        contractRecord.Status__c = 'Activated';
        update contractRecord;
    }

    @isTest
    static void fetchBatchCreatesReadyWorkRecords() {
        Contract__c activeContract = [
            SELECT Id,
                   Account__c,
                   ContractUpdate__c
            FROM Contract__c
            WHERE ContractName__c = 'Migration Contract'
            LIMIT 1
        ];
        ContractPeriod__c activePeriod = [
            SELECT ContractUpdate__c,
                   FreeeSyncStatus__c,
                   InvoiceCreationStatus__c
            FROM ContractPeriod__c
            WHERE Contract__c = :activeContract.Id
            LIMIT 1
        ];
        Contract__c draftContract = new Contract__c(
            Account__c = activeContract.Account__c,
            ContractName__c = 'Migration Draft Contract',
            ContractUpdate__c = activeContract.ContractUpdate__c,
            StartDate__c = Date.newInstance(2026, 3, 1),
            EndDate__c = Date.newInstance(2026, 6, 30),
            Status__c = 'Draft'
        );
        insert draftContract;
        insert new ContractPeriod__c(
            Contract__c = draftContract.Id,
            ContractUpdate__c = activePeriod.ContractUpdate__c,
            PeriodStartDate__c = Date.newInstance(2026, 3, 1),
            PeriodEndDate__c = Date.newInstance(2026, 3, 31),
            FreeeSyncStatus__c = activePeriod.FreeeSyncStatus__c,
            InvoiceCreationStatus__c = activePeriod.InvoiceCreationStatus__c,
            IsInitialPeriod__c = true
        );

        Test.setMock(HttpCalloutMock.class, new FreeeInvoiceListMock());

        Test.startTest();
        Database.executeBatch(new Mig_FreeeInvoiceFetchBatch(2026, 3, 6), 1);
        Test.stopTest();

        Mig_FreeeInvoiceWork__c workRecord = [
            SELECT FreeeInvoiceId__c,
                   ImportStatus__c,
                   ResolvedAccount__c,
                   ResolvedContract__c,
                   ResolvedContractPeriod__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE FreeeInvoiceId__c = '555'
            LIMIT 1
        ];
        System.assertEquals(Mig_FreeeInvoiceWorkService.STATUS_READY, workRecord.ImportStatus__c);
        System.assertNotEquals(null, workRecord.ResolvedAccount__c);
        System.assertNotEquals(null, workRecord.ResolvedContract__c);
        System.assertNotEquals(null, workRecord.ResolvedContractPeriod__c);

        Mig_FreeeInvoiceLineWork__c lineWork = [
            SELECT ConfirmedProductMaster__c,
                   ResolvedContractLineItem__c,
                   ProductResolveStatus__c
            FROM Mig_FreeeInvoiceLineWork__c
            WHERE InvoiceWork__c = :workRecord.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, lineWork.ConfirmedProductMaster__c);
        System.assertNotEquals(null, lineWork.ResolvedContractLineItem__c);
        System.assertEquals(Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED, lineWork.ProductResolveStatus__c);
    }

    @isTest
    static void fetchBatchSkipsOutOfPeriodInvoicesReturnedByFreee() {
        Test.setMock(HttpCalloutMock.class, new FreeeInvoiceOutOfPeriodListMock());

        Test.startTest();
        Database.executeBatch(new Mig_FreeeInvoiceFetchBatch(2026, 3, 6), 1);
        Test.stopTest();

        Integer workCount = [
            SELECT COUNT()
            FROM Mig_FreeeInvoiceWork__c
            WHERE FreeeInvoiceId__c = '777001'
        ];
        System.assertEquals(0, workCount);
    }

    @isTest
    static void fetchBatchStartUsesSingleDateInTestsAndValidatesParameters() {
        Mig_FreeeInvoiceFetchBatch batch = new Mig_FreeeInvoiceFetchBatch(2026, 3, 6);
        List<Date> targetDates = new List<Date>();
        for (Date targetDate : batch.start(null)) {
            targetDates.add(targetDate);
        }

        System.assertEquals(1, targetDates.size());
        System.assertEquals(Date.newInstance(2026, 3, 20), targetDates[0]);

        List<Date> productionDates = batch.buildTargetDates(false);
        System.assertEquals(Date.newInstance(2026, 3, 1), productionDates[0]);
        System.assertEquals(Date.newInstance(2026, 6, 30), productionDates[productionDates.size() - 1]);
        System.assertEquals(122, productionDates.size());

        Mig_FreeeInvoiceFetchBatch rangedBatch = new Mig_FreeeInvoiceFetchBatch(
            Date.newInstance(2026, 4, 11),
            Date.newInstance(2026, 4, 20)
        );
        List<Date> rangedDates = rangedBatch.buildTargetDates(false);
        System.assertEquals(10, rangedDates.size());
        System.assertEquals(Date.newInstance(2026, 4, 11), rangedDates[0]);
        System.assertEquals(Date.newInstance(2026, 4, 20), rangedDates[rangedDates.size() - 1]);

        try {
            new Mig_FreeeInvoiceFetchBatch(1999, 3, 6).start(null);
            System.assert(false, 'Expected invalid targetYear.');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('targetYear'));
        }

        try {
            new Mig_FreeeInvoiceFetchBatch(2026, 7, 6).start(null);
            System.assert(false, 'Expected invalid month range.');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('startMonth/endMonth'));
        }
    }

    @isTest
    static void finalizesReadyWorkToInvoiceAndInvoiceLine() {
        Test.setMock(HttpCalloutMock.class, new FreeeInvoiceListMock());
        Test.startTest();
        Database.executeBatch(new Mig_FreeeInvoiceFetchBatch(2026, 3, 6), 1);
        Test.stopTest();

        Mig_FreeeInvoiceWork__c workRecord = [
            SELECT Id
            FROM Mig_FreeeInvoiceWork__c
            WHERE FreeeInvoiceId__c = '555'
            LIMIT 1
        ];

        Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(new List<Id>{workRecord.Id});

        Invoice__c invoiceRecord = [
            SELECT Id,
                   Freee_Invoice_Id__c,
                   Freee_External_Key__c,
                   Sent_To_Freee__c,
                   Freee_Sync_Status__c,
                   MigrationSourceWork__c,
                   ParentContract__c,
                   ContractPeriod__c,
                   PaymentStatus__c,
                   Freee_Invoice_Status__c
            FROM Invoice__c
            WHERE MigrationSourceWork__c = :workRecord.Id
            LIMIT 1
        ];
        System.assertEquals(555, invoiceRecord.Freee_Invoice_Id__c);
        System.assertEquals(true, invoiceRecord.Sent_To_Freee__c);
        System.assertEquals('Success', invoiceRecord.Freee_Sync_Status__c);
        System.assertEquals('決済待ち', invoiceRecord.PaymentStatus__c);
        System.assertEquals('送付済み', invoiceRecord.Freee_Invoice_Status__c);
        System.assertNotEquals(null, invoiceRecord.ParentContract__c);
        System.assertNotEquals(null, invoiceRecord.ContractPeriod__c);

        InvoiceLine__c invoiceLine = [
            SELECT Id,
                   Invoice__c,
                   ProductMaster__c,
                   Freee_Line_Id__c,
                   Freee_External_Key__c,
                   MigrationSourceLineWork__c
            FROM InvoiceLine__c
            WHERE Invoice__c = :invoiceRecord.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, invoiceLine.ProductMaster__c);
        System.assertEquals('1', invoiceLine.Freee_Line_Id__c);
        System.assertNotEquals(null, invoiceLine.MigrationSourceLineWork__c);

        ContractLineItem__c monthlyLine = [
            SELECT RelatedInvoice__c
            FROM ContractLineItem__c
            WHERE ProductMaster__c = :invoiceLine.ProductMaster__c
            LIMIT 1
        ];
        System.assertEquals(invoiceRecord.Id, monthlyLine.RelatedInvoice__c);

        Mig_FreeeInvoiceMigrationController.validateAll();
        Mig_FreeeInvoiceMigrationController.finalizeByIds(new List<Id>());
        Mig_FreeeInvoiceMigrationController.finalizeReady();
        Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(new List<Id>());
    }

    @isTest
    static void finalizesReadyWorkIntoExistingInvoiceWithSameFreeeId() {
        Test.setMock(HttpCalloutMock.class, new FreeeInvoiceListMock());
        Test.startTest();
        Database.executeBatch(new Mig_FreeeInvoiceFetchBatch(2026, 3, 6), 1);
        Test.stopTest();

        Account accountRecord = [
            SELECT Id
            FROM Account
            WHERE Name = 'Migration Account'
            LIMIT 1
        ];

        Invoice__c existingInvoice = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 3, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Id__c = 555,
            Freee_Sync_Status__c = 'Success',
            Payment_Date__c = Date.newInstance(2026, 4, 30),
            Sent_To_Freee__c = false,
            Subject__c = 'Existing Imported Invoice'
        );
        insert existingInvoice;

        Mig_FreeeInvoiceWork__c workRecord = [
            SELECT Id, ExternalKey__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE FreeeInvoiceId__c = '555'
            LIMIT 1
        ];

        Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(new List<Id>{workRecord.Id});

        List<Invoice__c> invoices = [
            SELECT Id,
                   Freee_Invoice_Id__c,
                   Freee_External_Key__c,
                   MigrationSourceWork__c
            FROM Invoice__c
            WHERE Freee_Invoice_Id__c = 555
        ];
        System.assertEquals(1, invoices.size());
        System.assertEquals(existingInvoice.Id, invoices[0].Id);
        System.assertEquals(workRecord.ExternalKey__c, invoices[0].Freee_External_Key__c);
        System.assertEquals(workRecord.Id, invoices[0].MigrationSourceWork__c);
    }

    @isTest
    static void validatorKeepsUnresolvedWorkInReview() {
        insert new Mig_FreeeInvoiceWork__c(
            ExternalKey__c = 'freee_invoice:12345:999',
            FreeeInvoiceId__c = '999',
            FreeePartnerId__c = '999999',
            BillingDate__c = Date.newInstance(2026, 3, 20),
            InvoiceAmount__c = 1000,
            ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_FETCHED
        );

        Test.startTest();
        Mig_FreeeInvoiceValidator.validateAll();
        Test.stopTest();

        Mig_FreeeInvoiceWork__c workRecord = [
            SELECT ImportStatus__c, ValidationMessage__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE FreeeInvoiceId__c = '999'
            LIMIT 1
        ];
        System.assertEquals(Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW, workRecord.ImportStatus__c);
        System.assert(workRecord.ValidationMessage__c.contains('ResolvedAccount__c'));
    }

    @isTest
    static void productResolverUsesMappingAsCandidateWhenNotExact() {
        ProductMaster__c productRecord = [
            SELECT Id
            FROM ProductMaster__c
            WHERE Name = 'Rendary'
            LIMIT 1
        ];

        insert new Mig_FreeeInvoiceLineProductMap__c(
            Name = 'Security Option Map',
            Keyword__c = 'security',
            MatchType__c = '部分一致',
            Priority__c = 1,
            ProductMaster__c = productRecord.Id,
            IsActive__c = true
        );

        Mig_FreeeInvoiceWork__c workRecord = new Mig_FreeeInvoiceWork__c(
            ExternalKey__c = 'freee_invoice:12345:777',
            FreeeInvoiceId__c = '777',
            ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_FETCHED
        );
        insert workRecord;

        insert new Mig_FreeeInvoiceLineWork__c(
            InvoiceWork__c = workRecord.Id,
            ExternalKey__c = 'freee_invoice_line:12345:777:1',
            FreeeLineId__c = '1',
            Description__c = 'security option',
            LineAmount__c = 1234,
            ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_FETCHED
        );

        Test.startTest();
        Mig_FreeeInvoiceProductResolver.resolveProducts();
        Test.stopTest();

        Mig_FreeeInvoiceLineWork__c lineWork = [
            SELECT SuggestedProductMaster__c,
                   ConfirmedProductMaster__c,
                   ProductResolveStatus__c
            FROM Mig_FreeeInvoiceLineWork__c
            WHERE InvoiceWork__c = :workRecord.Id
            LIMIT 1
        ];
        System.assertEquals(productRecord.Id, lineWork.SuggestedProductMaster__c);
        System.assertEquals(null, lineWork.ConfirmedProductMaster__c);
        System.assertEquals(Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CANDIDATE, lineWork.ProductResolveStatus__c);
    }
}
